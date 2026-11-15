# Runbook 3 â€” Connections per workspace

| | |
| --- | --- |
| **Performed by** | Human, in the Fabric portal |
| **Agent role** | Guides; awaits connection IDs; injects them into definitions at creation time |
| **Verifiable via official MCP** | **No.** Connections are not workspace items and no MCP tool exposes them. |
| **Order** | Before creating any item that binds a connection (pipelines, mirrored databases) |
| **Applies to** | All three workspaces, plus the TST and PRD stages |

## Why this is a manual step

A Fabric connection (cloud connection, gateway connection, or data source credential set) is a
tenant-level artifact. It is not a workspace item, so it does not appear in `list_items`, and no
Core MCP tool can create, read, or bind one.

In the MCP-driven model the agent does not need to rebind connection GUIDs in existing
definitions. Instead, it pauses at the handshake, the human creates the connection and returns
its ID, and the agent injects that ID into the definition **before** creating the item. This
eliminates the sync-time validation failures that occurred when connection GUIDs were
hard-coded.

## Prerequisites

- [ ] Target workspace exists with capacity assigned
- [ ] The credential or principal for each connection is available (Key Vault reference,
  service principal, managed identity, or user credential)
- [ ] Each connection is declared in `fabric/source-connections.yaml`

## Connection handshakes

### Handshake A â€” Source connection (before pipeline creation)

The source connection (e.g. Azure SQL to WideWorldImporters) must exist before any pipeline
that reads from it is created.

1. Human creates the connection in the portal (Settings â†’ Manage connections and gateways â†’
   New connection).
2. Human returns the connection ID to the agent.
3. Agent records it in the source-connection manifest and injects it into pipeline definitions
   at creation time.

### Handshake B â€” controlDB connection (after controlDB creation)

The controlDB SQL database must exist before a connection to it can be created.

1. Agent creates the `controlDB` SQLDatabase item.
2. Human creates a connection to controlDB's SQL analytics endpoint in the portal.
3. Human returns the connection ID to the agent.
4. Agent injects it into pipeline definitions before creating them.

5. **controlDB DDL** - after Handshake B, retrieve the real connection string via
   GET /v1/workspaces/{ws}/sqlDatabases/{sqlDatabaseId} (returns serverFqdn and
   databaseName). Apply dateng/controlDB-deploy.sql via sqlcmd with
   ActiveDirectoryAzCli auth. MCP execute_query hits the SQL analytics endpoint (system
   tables only) and cannot create tables (external policy blocks
   Microsoft.Sql/.../Tables/Create).

## Connection type decides what a pipeline can do

This is the single most expensive lesson from the AdventureWorks build. A connection whose
`connectionDetails.type` is `OneLakeSql` can read, and nothing else. Bind it into a Copy sink, a
`SqlServerStoredProcedure` activity, or a `Script` activity and the pipeline fails at runtime, not
at save time.

Measured against a Fabric SQL Database (probes run in a scratch workspace, one pipeline each):

| Activity shape | `OneLakeSql` connection | `SQL` connection |
| --- | --- | --- |
| `Lookup` with `sqlReaderQuery` | Works | Works |
| `Copy` source `AzureSqlSource` + `sqlReaderQuery` | Works | Works |
| `Copy` sink `AzureSqlSink` | **Fails** | Works |
| `SqlServerStoredProcedure` (`storedProcedureName` only) | **Fails** | Works |
| `SqlServerStoredProcedure` via `sqlReaderStoredProcedureName` | **Fails** | **Fails** |
| `Script` activity | **Fails** | Works |

Two specific errors seen: `"The datasource type OneLakeSql is invalid."` and
`"Required property 'sqlReaderQuery' is missing in payload."` (the latter is the stored-procedure
activity silently degrading to a query activity because the type cannot carry a proc name).

The fix is a second connection to the same TDS endpoint, created as type **SQL Server**, not
`OneLakeSql`. Activity shapes in the repo do not change: `AzureSqlSource`, `AzureSqlTable`,
`AzureSqlSink` and `SqlServerStoredProcedure` all work once the bound connection is `SQL`.

### Creating an `SQL` connection cannot be automated

`POST /v1/connections` against a Fabric SQL Database is rejected for every credential type
available to the agent:

| `credentialType` | Result |
| --- | --- |
| `Basic` | `"Azure Active Directory only authentication is enabled"` |
| `OAuth2` | `ConnectionDetailsTypeNotSupportedForOAuth2` |
| `WorkspaceIdentity` | `DMTS_UntrustedEndpointForWorkspaceIdentity` |
| `ServicePrincipal` | Requires a client secret the agent must not hold |

So the connection is a human portal action: **Manage connections and gateways** > New connection >
**SQL Server** > authentication **Microsoft Entra ID** > tick the gateway checkbox.

### The gateway checkbox is the one that matters

A pipeline Copy into a Fabric SQL Database needs `allowConnectionUsageInGateway = true`. The
"allow code-first artifacts / notebook access" checkbox is not the blocker. After the human creates
the connection, the agent can PATCH it with the caller's own identity:

```
PATCH /v1/connections/{connectionId}
{ "allowConnectionUsageInGateway": true,
  "credentialDetails": { "credentialType": "OAuth2",
                         "accessToken": "<token>",
                         "useCallerIdentity": true } }
```

### Fabric SQL Database physical database names

Every `SQLDatabase` item exposes two database names. The portal and the analytics endpoint use the
display name; TDS uses a GUID-suffixed physical name.

```
GET /v1/workspaces/{ws}/sqlDatabases/{id}
  -> properties.serverFqdn      <guid-suffix>.database.fabric.microsoft.com,1433
  -> properties.databaseName    controlDB-87e80af8-aa5d-45c2-99fd-069d2fef3f56
```

Pipelines and sqlcmd must use `databaseName`, never `controlDB`. The analytics endpoint
(`controlDB`) is read-only and returns system tables only.

## Verification

Connections are unverifiable via MCP. Confirm existence, binding, and credential validity in the
portal. Ask the human to record:

| Item | Value |
| --- | --- |
| Connection name | |
| Type | |
| Created / reused | |
| Bound to which items | |
| Credential tested successfully | yes / no / not tested |

## Failure modes

| Symptom | Cause | Fix |
| --- | --- | --- |
| `ConnectionNotAccessible` at item creation | Connection does not exist or datasource inaccessible to the binding user | Create the connection and grant the binding user access |
| `RequestValidationFailed` at item creation | Connection GUID does not resolve | Re-run with the correct connection ID |
| `"The datasource type OneLakeSql is invalid."` at run time | Activity type needs a write or proc capability the connection does not have | Recreate the connection as type **SQL Server** |
| `"Required property 'sqlReaderQuery' is missing in payload."` | `SqlServerStoredProcedure` bound to a non-SQL connection | Same fix: connection type must be `SQL` |
| `"User does not have access to the connection used in the Pipeline"` | Stale or unresolvable connection GUID in the definition | Re-inject the live connection ID and re-apply the definition |
| Copy activity fails although Lookup works | Gateway checkbox not ticked on the connection | PATCH `allowConnectionUsageInGateway = true` |
| Works for one person, not another | Connection uses a personal credential | Move to service principal or managed identity |
| Two items, one source, different results | Different connections bound to the same source | Consolidate onto one connection per environment |
