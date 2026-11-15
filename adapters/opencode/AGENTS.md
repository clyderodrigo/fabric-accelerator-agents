# Fabric Deployment Agent — Instructions

Source of truth for every agent surface in this toolkit. Claude Code reads this file through
`CLAUDE.md`; OpenCode loads it directly. Do not duplicate these rules into adapter files —
the build script copies this file, so edits here are the only edits that count.

---

## 1. What this toolkit is

A guide-and-deploy layer for deploying Microsoft Fabric environments. The agent creates and
mutates Fabric items through the official `fabric-core` MCP server (write tools are
approval-gated), using the repository's item folders as the definition library. The human
supplies connections, capacity, and approvals; the agent orchestrates creation in dependency
order and then verifies read-only.

```
Human supplies inputs + approvals  →  Agent creates/mutates via MCP  →  Agent verifies read-only
```

There is no Git sync deployment, no `fabric-cicd` publishing, and no custom code that calls
Fabric REST APIs outside the official MCP server. The Git-sync path is abandoned: MCP-created
items are not identity-compatible with Git-synced items (logicalId is forced to nil on API
create), so the two deployment modes must not be mixed in one workspace.

## 2. Environment model

One development repository, one folder per item type collection. The repository holds item
definitions that the agent deploys; it is not pushed to a workspace by Git integration.

### Workspaces and dependency order

Provision and deploy in this order. Later workspaces consume assets from earlier ones.

| Order | Workspace key | Display name | Depends on |
| --- | --- | --- | --- |
| 1 | `dateng` | `[DEV] DatEng` | — |
| 2 | `data` | `[DEV] Data` | `dateng` |
| 3 | `analytics` | `[DEV] Analytics` | `data` |

Ordering matters because a workspace that consumes a shortcut, connection, or mirrored
database from an earlier workspace cannot be verified until that earlier workspace is complete.

### Item types in scope (release 1)

`Lakehouse`, `Warehouse`, `Notebook`, `DataPipeline`, `MirroredDatabase`, `SQLDatabase`,
`VariableLibrary`.

Anything else found in a workspace is reported as *out of scope* rather than silently ignored.

## 3. Official MCP servers

Two servers, both Microsoft-published. Register these and nothing else.

| Server name | Type | Endpoint / command | Purpose here |
| --- | --- | --- | --- |
| `fabric-core` | remote, Streamable HTTP | `https://api.fabric.microsoft.com/v1/mcp/core` | Live reads **and** writes: workspaces, items, roles, folders, capacities, definitions, OneLake |
| `fabric-local` | local, stdio | `npx -y @microsoft/fabric-mcp@latest server start --mode all --namespace docs` | Offline API specs, item definition schemas, best practices |

`fabric-local` is deliberately started with `--namespace docs` only.

### Capability summary (fabric-core)

**Read (allow):** `search_catalog`, `list_workspaces`, `get_workspace`, `list_workspace_roles`,
`get_workspace_role`, `list_items`, `get_item`, `get_item_definition`, `list_folders`,
`get_folder`, `list_capacities`, `get_operation_state`, `get_operation_result`,
`get_knowledge`, `onelake_list_shortcuts`, `onelake_get_shortcut`,
`onelake_list_data_access_roles`, `onelake_get_settings`.

**Write (ask — approval-gated):** `create_workspace`, `update_workspace`, `add_workspace_role`,
`update_workspace_role`, `create_item`, `update_item`, `update_item_definition`,
`create_folder`, `update_folder`, `move_folder`, `bulk_move_items`,
`onelake_create_shortcut`, `onelake_create_shortcuts_in_bulk`,
`onelake_create_or_update_single_data_access_role`,
`onelake_create_or_update_data_access_roles`, `onelake_modify_default_tier`,
`onelake_modify_diagnostics`, `onelake_modify_immutability_policy`,
`onelake_reset_shortcut_cache`.

**Delete (deny):** `delete_workspace`, `delete_item`, `delete_folder`, `delete_workspace_role`,
`onelake_delete_shortcut`, `onelake_delete_data_access_role`.

**Not available (no MCP tool):** connections, deployment pipelines, capacity reassignment of an
existing workspace, Git integration configuration.

## 4. Non-negotiable guardrails

1. **The human supplies inputs and approves mutations.** Creating workspaces, assigning capacity,
   creating connections, configuring deployment pipelines, and editing roles are either portal
   actions or approval-gated MCP calls. The agent walks the person through them and then creates
   or verifies.
2. **Verification is read-only.** Only tools in the `read` list of `tool-names.json` may be used
   without approval.
3. **`delete_*` is denied**, not merely discouraged. Permission rules enforce this in both hosts.
4. **Role changes require explicit approval.** `add_workspace_role`, `update_workspace_role` and
   `delete_workspace_role` are approval-gated. A role change is a security change.
5. **Write tools are approval-gated.** `create_*`, `update_*` require explicit human approval
   before execution. The agent proposes the payload and waits.
6. **Never invent tenant state.** If a tool cannot verify something, say so. "I could not verify
   this via MCP" is a correct and expected answer.
7. **No credentials in the repo.** Tokens come from Azure CLI at connect time. Never write a
   token, connection string, or client secret into a tracked file.
8. **Never assume the environment.** Confirm the signed-in tenant and the target workspace before
   any deployment run, and say which tenant you checked.
9. **MCP-driven and Git-driven deployment must not be mixed in one workspace.** API-created items
   receive a nil logicalId and are not identity-compatible with Git-synced items.

## 5. Deployment honesty matrix

| State | Verifiable read-only via official MCP? | How |
| --- | --- | --- |
| Workspace exists | Yes | `list_workspaces`, `get_workspace` |
| Workspace capacity assignment | Yes | `get_workspace` → `capacityId`, cross-checked with `list_capacities` |
| Workspace roles | Yes | `list_workspace_roles`, `get_workspace_role` |
| Items present in a workspace | Yes | `list_items`, `get_item` |
| Item definitions match the repo | Yes | `get_item_definition` — compare semantically, not byte-for-byte |
| Folders | Yes | `list_folders`, `get_folder` |
| Capacity name, SKU, region, state | Yes | `list_capacities` |
| Item created by agent (MCP) | Yes | `list_items`, `get_item` — creation is verifiable |
| Connections created and bound | **No** | Fabric portal only — no MCP tool exposes them |
| Deployment pipeline stages, assignments, rules | **No** | Fabric portal only |
| Deployment pipeline deploy result | **No** | Fabric portal only |
| Item-level binding correctness after promotion | **No** | Must be tested in the target stage |
| SQL Database schema (tables/procs/functions) | **Partial** | MCP `execute_query` hits the SQL analytics endpoint (system tables only). Retrieve the real connection string via `GET /v1/workspaces/{ws}/sqlDatabases/{id}` and apply DDL via sqlcmd. Verify with `INFORMATION_SCHEMA.TABLES` via sqlcmd. |
| Warehouse tables, procedures, row counts | **Yes, via sqlcmd** | `INFORMATION_SCHEMA.TABLES` / `sys.procedures` / `SELECT COUNT(*)` against `<warehouse-endpoint>,1433` with `ActiveDirectoryAzCli`. MCP has no warehouse query tool. |
| Notebook cell output and failure detail | **No** | Job status returns only `System_Cancelled_Session_Statements_Failed`. Have the notebook append diagnostics to OneLake and read them back with a `storage.azure.com` token. |
| Definition parts list for an item | Yes | `get_item_definition` (202 + poll, then `/result`) |

When a row says **No**, the runbook's verification step is a UI check that the human performs and
reports back. Never present a UI-only check as if the agent confirmed it.

## 6. Working method

When asked to provision or deploy an environment:

1. Read the declared configuration (`fabric/declared-environment.yaml` and
   `fabric/source-connections.yaml` in the consuming repo).
2. Confirm the tenant and target workspace with the human.
3. Load the matching skill: `provision-checklist`, `deploy-via-mcp`, `verify-environment`, or
   `drift-check`.
4. Walk the runbooks in dependency order — `dateng`, then `data`, then `analytics`.
5. For MCP-driven deployment, create items in dependency order, pausing for human inputs
   (connections) at the handshakes. Inject resolved IDs into downstream definitions before
   creating them. Two ordering rules discovered in practice:
   - **Shell-then-apply for child pipelines:** create child DataPipelines with `.platform`
     only first (to reserve IDs for `referenceName` rewriting in parent orchestrators),
     then apply full definitions via `update_item_definition` with injected IDs. Verify
     `activities.length > 0` after the second pass — shells show `activities: []`.
   - **controlDB DDL via sqlcmd:** after creating the SQLDatabase item, retrieve its
     real connection string via `GET /v1/workspaces/{ws}/sqlDatabases/{id}` (returns
     `serverFqdn` and `databaseName`). Apply the consolidated DDL (`controlDB-deploy.sql`)
     via sqlcmd with `ActiveDirectoryAzCli` auth. MCP `execute_query` hits the SQL analytics
     endpoint (system tables only) and cannot create tables (external policy blocks
     `Microsoft.Sql/Sqlservers/Databases/Schemas/Tables/Create`).
   - **Pipeline connections must be type `SQL`, not `OneLakeSql`:** `OneLakeSql` is read-only.
     Lookup and Copy-source work; Copy-sink, `SqlServerStoredProcedure` and `Script` fail at run
     time. The replacement connection is a portal action, because REST creation of an `SQL`
     connection to a Fabric SQL Database is rejected for every credential type the agent can use.
   - **Warehouse definitions are full replacements:** fetch the current definition, overlay the
     repo `.sql` files, and re-send every part. `.gitattributes` and `.gitignore` exist only in
     the definition; `xmla.json` exists only in the repo. Warehouse DDL rejects `tinyint` (use
     `smallint`) and rejects `OPTION (MAXRECURSION n)` (use `GENERATE_SERIES`).
   - **Gold is a Warehouse, so Spark cannot load it.** The working shape is DDL plus
     `gold.create_<table>` procedures, driven by `notebookutils.notebook.runMultiple` fanning out
     to per-table notebooks that execute the procedure over TDS with `pyodbc` and the notebook's
     own AAD token. `CREATE TABLE ... AS SELECT` procedures are not atomic: a failure after the
     drop leaves the table missing, so re-apply the definition.
   - **Notebook job failures are undiagnosable from REST.** Job status returns a generic
     session error. Have the notebook append a log to OneLake with `notebookutils.fs.append` and
     read it back via `https://onelake.dfs.fabric.microsoft.com/<ws>/<item>/<path>` with a
     `storage.azure.com` token. Do this before rewriting a notebook blind.
6. After each step, verify what is verifiable. Mark the rest as unverified and say why.
7. Report in the format the skill specifies. Never summarise unverified steps as complete.

## 7. Index

**Skills** (`skills/`)

- `provision-checklist` — ordered provisioning gates across the three workspaces
- `deploy-via-mcp` — MCP-orchestrated creation from repo definitions with connection handshakes
- `verify-environment` — read-only verification with exact tool calls
- `drift-check` — declared config versus tenant state, with unverifiable items called out

**Runbooks** (`fabric/runbooks/`)

1. `01-capacity-assignment.md` — assign capacity per workspace
2. `03-connections.md` — connection creation and binding per workspace
3. `05-deployment-pipelines.md` — stages, workspace assignment, rules
4. `06-mcp-deployment.md` — MCP-driven creation, handshakes, verification

**Policy** (`policy/`)

- `official-mcp-servers.md` — tool inventory and verification limits
- `guardrails.md` — enforcement model and rationale
- `tool-names.json` — canonical tool list that generates permission rules

**Config contract** (`fabric/`)

- `declared-environment.md` — the human-readable environment description
- `declared-environment.example.yaml` — worked example matching a three-workspace repo
- `source-connections.example.yaml` — source-connection manifest format

## 8. Out of scope for release 1

Listed here so nobody quietly builds them mid-task.

1. Git sync deployment — abandoned; replaced by MCP-driven deployment.
2. Connection creation and binding automation — no MCP coverage; human portal step with handshake.
3. Deployment pipeline configuration automation — currently manual per stage.
4. Cross-workspace ID rebinding tooling — not needed; IDs resolved at creation time.
5. `fabric-cicd`-style publishing.
6. Custom MCP servers.
7. Multi-tenant support.
8. Custom state backends.