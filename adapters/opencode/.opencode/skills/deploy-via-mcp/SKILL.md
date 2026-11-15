---
name: deploy-via-mcp
description: MCP-orchestrated creation of Fabric items from repo definitions, with connection handshakes and ID injection. Use for any new workspace deployment.
---

# Deploy via MCP

This skill creates Fabric items through the `fabric-core` MCP server using the repository's
item folders as the definition library. It replaces the Git-sync deployment path, which is
abandoned.

## Preconditions

- Tenant and target workspace confirmed with the human.
- Source-connection manifest (`fabric/source-connections.yaml`) populated or handshakes
  accepted.
- Human approval to execute write tools.

## Steps

1. **Provision workspace** — `create_workspace(displayName, capacityId)`. Record `workspaceId`.
2. **Create folders** if the layout requires them.
3. **Create core items** in dependency order: Lakehouses → Warehouse → SQLDatabase →
   Notebooks → VariableLibrary. For each, read the repo folder, base64-encode its parts, and call
   `create_item(type, definition)`. Record every returned ID.
   - **Shell-then-apply for child pipelines:** create child DataPipelines with `.platform` only
     first (to reserve IDs for `referenceName` rewriting in parent orchestrators), then apply
     full definitions via `update_item_definition` with injected IDs. Verify
     `activities.length > 0` after the second pass — shells show `activities: []`.
   - **Notebooks created with `.platform` only** need a second `update_item_definition` pass
     to apply `notebook-content.py`.
   - **`%run` helpers first.** Deploy a helper notebook such as `gold_sql_utils` before any
     notebook that `%run`s it. A missing helper surfaces as a generic
     `System_Cancelled_Session_Statements_Failed`, not as a missing-notebook error.
   - **No placeholder GUIDs in the VariableLibrary.** Resolve every variable to the deployed value
     before creating it. A stale GUID fails inside a notebook later, with no pointer back to the
     library.
4. **Handshake B** — pause. Human creates a connection to controlDB's SQL analytics endpoint
   and returns the connection ID. Do not proceed without it.
   - **controlDB DDL via sqlcmd:** retrieve the real connection string via
     `GET /v1/workspaces/{ws}/sqlDatabases/{sqlDatabaseId}` (returns `serverFqdn` and
     `databaseName`). Apply `dateng/controlDB-deploy.sql` via sqlcmd with
     `ActiveDirectoryAzCli` auth. MCP `execute_query` hits the SQL analytics endpoint
     (system tables only) and cannot create tables (external policy blocks
     `Microsoft.Sql/.../Tables/Create`).
   - **Pipeline connections must be type `SQL`, not `OneLakeSql`.** `OneLakeSql` is read-only:
     Lookup and Copy-source work, Copy-sink, `SqlServerStoredProcedure` and `Script` fail at run
     time. See runbook 03.
5. **Create DataPipelines** — for each pipeline in the source-connection manifest's matched
   pattern, inject workspace/item/connection IDs into the definition, then `create_item`.
6. **Gold layer** — tables and `gold.create_*` procedures are part of the Warehouse definition
   (step 3); the orchestrator is a notebook. Adding objects later means fetching the current
   warehouse definition, overlaying the repo `.sql` files, and re-sending **all** parts, including
   the `.gitattributes` / `.gitignore` parts that exist only in the definition. Prove the path by
   running `gold_dim_calendar`, which has no silver dependency.
7. **Create MirroredDatabase** (optional) — inject the source connection ID.
8. **Verify** — `list_items` + `get_item_definition` per item. Report which checks are
   agent-verifiable and which remain UI-only.

## Handshakes

- **Handshake A (source):** before step 5, if the source connection is not yet declared.
- **Handshake B (controlDB):** between steps 3 and 5.

The agent must not create any item that binds a connection before its handshake completes.

## Injection

Replace environment-scoped GUIDs in definitions with deployed values before creation. See
runbook 06 for the injection table.

## Verification

State plainly which checks are agent-verifiable (item presence, definition content) and which
are UI-only (connections, runtime binding, promotion results). Never present a UI-only check as
confirmed.