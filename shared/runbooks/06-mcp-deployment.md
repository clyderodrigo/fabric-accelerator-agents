# Runbook 6 â€” MCP-driven deployment

| | |
| --- | --- |
| **Performed by** | Agent creates items via `fabric-core` MCP; human approves writes and supplies connections |
| **Agent role** | Orchestrates creation in dependency order, injects resolved IDs, verifies |
| **Verifiable via official MCP** | **Partially.** Creation is verifiable via `list_items` / `get_item` / `get_item_definition`. Runtime binding is not. |
| **Order** | After capacity assignment and workspace creation |
| **Applies to** | All three workspaces |

## Why this replaces Git sync

MCP-created items receive a nil logicalId and are not identity-compatible with Git-synced items.
Mixing the two in one workspace produces duplicates. In the MCP-driven model the repository is the
definition library and the agent is the deployer: it reads item folders, base64-encodes their parts,
and calls `create_item` with the definition payload.

## Prerequisites

- [ ] Target workspace exists with capacity assigned (runbook 01)
- [ ] Source-connection manifest (`fabric/source-connections.yaml`) populated with connection IDs
- [ ] Human has created all source connections in the portal (runbook 03, handshake A)
- [ ] Agent has explicit approval to execute write tools

## Build sequence

1. **Workspace** â€” `create_workspace(displayName, capacityId)` â†’ `workspaceId`.
2. **Folders** â€” `create_folder` for logical grouping (optional).
3. **Lakehouses** â€” `create_item(type=Lakehouse, definition)` â†’ `lakehouseId`.
4. **Warehouse** â€” `create_item(type=Warehouse, definition)` â†’ `warehouseId`.
5. **SQLDatabase** â€” `create_item(type=SQLDatabase, definition)` â†’ `sqlDatabaseId`.
   - â¸ **Handshake B** â€” human creates a connection to controlDB's SQL analytics endpoint and
     returns the connection ID.
    - **controlDB DDL via sqlcmd** - retrieve the real connection string via
      GET /v1/workspaces/{ws}/sqlDatabases/{sqlDatabaseId} (returns serverFqdn and
      databaseName). Apply dateng/controlDB-deploy.sql via sqlcmd with
      ActiveDirectoryAzCli auth. MCP execute_query hits the SQL analytics endpoint
      (system tables only) and cannot create tables (external policy blocks
      Microsoft.Sql/.../Tables/Create). Verify with
      SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='ELT' via sqlcmd.
6. **Notebooks** â€” `create_item(type=Notebook, definition)` â†’ `notebookId`.
   - Notebooks created with .platform only (empty shells) need a second
     update_item_definition pass to apply notebook-content.py.
   - Create `%run` helper notebooks (for example `gold_sql_utils`) **before** any notebook that
     `%run`s them, otherwise the child fails with a generic session error and no useful message.
   - Before creating the VariableLibrary, replace every placeholder GUID in `variables.json` with
     the deployed value. A placeholder here does not fail loudly; it fails later inside whichever
     notebook reads it.
7. **VariableLibrary** â€” `create_item(type=VariableLibrary, definition)` with item IDs injected
   â†’ `variableLibraryId`.
8. **DataPipelines** â€” `create_item(type=DataPipeline, definition)` with:
   - connection IDs from the source manifest and handshake B
   - item IDs from steps 3-7
   - child pipeline `referenceName` values rewritten to deployed IDs
   - `libraryVariables.libraryId` rewritten to the deployed VariableLibrary ID
9. **MirroredDatabase** (optional) â€” `create_item(type=MirroredDatabase, definition)` with the
   source connection ID injected.
10. **Verify** â€” `list_items` + `get_item_definition` per item.

## Injection rules

Before creating a downstream item, replace every environment-scoped GUID in its definition with
the deployed value:

| Source value | Replace with |
| --- | --- |
| Workspace GUID | `workspaceId` from step 1 |
| Lakehouse item ID | `lakehouseId` from step 3 |
| Warehouse item ID | `warehouseId` from step 4 |
| SQLDatabase item ID | `sqlDatabaseId` from step 5 |
| Notebook item ID | `notebookId` from step 6 |
| VariableLibrary item ID | `variableLibraryId` from step 7 |
| Child pipeline referenceName | deployed child pipeline ID |
| Connection GUID | connection ID from the manifest or handshake |

## Handshakes

The agent pauses and waits for the human to return a connection ID. No item that binds a
connection may be created before its handshake completes.

- **Handshake A (source):** before step 8, if the source connection is not yet declared.
- **Handshake B (controlDB):** between steps 5 and 8.

## Capability limits

- Connections cannot be created, read, or bound via MCP. Human portal step.
- Deployment pipelines (stages, rules, promotions) have no MCP tool. Manual per stage.
- Capacity reassignment of an existing workspace is not exposed. Assign at `create_workspace`.
- Git integration configuration is UI-only.

## Updating a Warehouse definition

`update_item_definition` replaces the definition wholesale: "You must submit all the required
parts, not a partial patch." Building the payload from the repo folder alone fails, because a
Warehouse definition carries parts that never appear in the repo:

```
GET  .../warehouses/{id}/getDefinition      (202, poll operation, then /result)
overlay the repo files onto the returned parts
POST .../warehouses/{id}/updateDefinition
```

Measured shape of `dw_gold` while adding the gold star schema:

| Part | Where it comes from |
| --- | --- |
| `.platform` | repo |
| `.gitattributes`, `.gitignore` | **definition only** - must be re-sent verbatim |
| `dw_gold.sqlproj` | repo |
| `Security/gold.sql` | repo `gold/gold.sql` (the schema script is filed under `Security/`) |
| `gold/Tables/*.sql` | repo |
| `gold/StoredProcedures/*.sql` | repo |

`xmla.json` in the repo folder is **not** a definition part. It is a Git-integration artifact for
the Direct Lake model and is ignored on `updateDefinition`, so a warehouse definition update does
not touch the semantic model. New tables therefore need a separate model refresh before they are
visible to Direct Lake, and `xmla.json` will drift from the warehouse until then.

Send only `definition.parts`, never a `.platform` part for a DataPipeline (that returns
`InvalidPlatformFile`). Warehouses, notebooks and variable libraries do accept `.platform`.

### Warehouse DDL restrictions

`tinyint` is rejected by the warehouse schema provider on import:

```
Msg 24574: The data type 'tinyint' in column 'MonthNumber' is not supported in this edition of SQL Server.
```

SQL functions that do work: `GENERATE_SERIES`, `DATEFROMPARTS`, `CHOOSE`, `DROP TABLE IF EXISTS`,
`CREATE TABLE ... AS SELECT` including `WITH` CTEs and window functions. Recursive CTEs with
`OPTION (MAXRECURSION n)` do **not** work - the hint is rejected as `Query hint 'unknown hint' is
not allowed`. Generate date spines with `GENERATE_SERIES`.

## The gold layer is a Warehouse, not a lakehouse

Spark cannot write to a Fabric Warehouse, so the usual pattern (a PySpark notebook that builds a
table) does not apply. The working design, deployed and measured:

- **Tables** - `gold/Tables/*.sql` DDL, one file per table.
- **Load logic** - `gold/create_<table>` procedures taking the framework's L2 parameter signature
  (`@L2TransformInstanceID ... @OutputDWTableWriteMode`) so `Level2 Transform` can still call them
  through `ComputeName = [gold].[create_<stream>]`.
- **Orchestration** - `gold_00_orchestration` fans out to one child notebook per table with
  `notebookutils.notebook.runMultiple`, dims in parallel and the fact dependent on all dims.
- **Transport** - each child executes its procedure over TDS with `pyodbc` plus the notebook's own
  AAD token.

```python
import struct, pyodbc

SQL_COPT_SS_ACCESS_TOKEN = 1256

def gold_connect(server, database="dw_gold"):
    token = notebookutils.credentials.getToken("https://database.windows.net/")
    token_bytes = token.encode("utf-16-le")
    token_struct = struct.pack(f"<I{len(token_bytes)}s", len(token_bytes), token_bytes)
    return pyodbc.connect(
        "DRIVER={ODBC Driver 18 for SQL Server};"
        f"SERVER={server},1433;DATABASE={database};Encrypt=yes;TrustServerCertificate=no;",
        attrs_before={SQL_COPT_SS_ACCESS_TOKEN: token_struct},
    )
```

Confirmed in the Fabric runtime: Python 3.13.11, `pyodbc` 5.3.0, `ODBC Driver 18 for SQL Server`
present, `notebookutils.credentials.getToken("https://database.windows.net/")` returns a token the
warehouse accepts.

Child notebooks receive their parameters through `runMultiple`, which requires the standard
`# PARAMETERS CELL` marker. With a `None` default the notebook fails fast when run standalone - that
is intentional, and it costs one debugging cycle if you forget it.

### CTAS procedures are not atomic

`gold.create_<table>` drops the table and then rebuilds it with `CREATE TABLE ... AS SELECT`. If
the select fails - a missing silver table, for example - the drop has already committed and the
gold table is gone. Re-apply the warehouse definition to recreate the empty tables, and treat a
failed gold run as "rebuild required", not "left as it was".

## Diagnosing notebook job failures

`GET .../items/{id}/jobs/instances/{jobId}` returns only
`System_Cancelled_Session_Statements_Failed`. There is no endpoint that returns the cell output.
Write diagnostics out of the notebook instead:

```python
DIAG = ("abfss://<workspaceId>@onelake.dfs.fabric.microsoft.com/<lakehouseId>/Files/diag/run.log")
notebookutils.fs.rm(DIAG, True)
notebookutils.fs.append(DIAG, "step 1 ok\n", True)
```

Read it back with a storage-scoped token - no PowerShell storage cmdlet is needed:

```
az account get-access-token --resource https://storage.azure.com
GET https://onelake.dfs.fabric.microsoft.com/<workspaceId>/<itemId>/Files/diag/run.log
```

A `resource=file` query parameter is rejected with `UnsupportedQueryParameter`; the bare path works.

Shell note: `Invoke-WebRequest` fails in non-interactive hosts ("NonInteractive mode", or a
`NullReferenceException` on POST). Use `curl.exe`, and put long JSON bodies in a file and pass
`--data-binary "@file"` to stay under the command-line limit.

## Known data-layer gap: L1 transform definitions

`ELT.L1TransformDefinition` is not seeded by anything in this repository. `source-elt-metadata`
populates `ELT.IngestDefinition` only, and no procedure inserts L1 rows.

Measured state after controlDB DDL plus a metadata run attempt:

```
IngestDefinition        0 rows
L1TransformDefinition   0 rows
EXEC [ELT].[GetTransformInstance_L1] @SourceSystemName='AdventureWorks'   -> 0 rows
```

`Master Level1 Transform` iterates the result of that procedure, so with no L1 definitions the
stage is a silent no-op: no silver tables are written, and every gold procedure except
`gold_dim_calendar` fails with `Invalid object name 'lh_silver.dbo.silver_saleslt_*'`.

This is a **repository gap**, not a tool limitation or a tenant setting. Seeding L1 requires the
`IngestID` values created by `source-elt-metadata`, so the order is fixed: fix the source
connection, run `source-elt-metadata`, then insert the L1 definitions. The silver naming contract
the gold procedures expect is `OutputDWTable = silver.saleslt_<table>`. `DeltaLakeFunctions`
(`insertDelta` / `upsertDelta`) only replaces `.` with `_`, so that value becomes the lakehouse
table `silver_saleslt_<table>`. Case and punctuation written there decide the physical table name,
and the gold procedures are matched to it.

Do not invent these rows. Ask for the seeding decision rather than guessing framework
configuration.

## Verification

After deployment, verify per item:

```
list_items            per workspace
get_item_definition   for each item created
```

Confirm item types, display names, and that definitions contain the injected (not source) IDs.
State clearly which checks are agent-verifiable and which remain UI-only.
