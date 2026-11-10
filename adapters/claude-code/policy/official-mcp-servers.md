# Official MCP servers — inventory and verification limits

Verified against Microsoft documentation on 2026-11-09. Both servers are Microsoft-published and
are the only MCP servers this toolkit registers.

---

## 1. Fabric Core MCP Server (remote)

| Property | Value |
| --- | --- |
| Endpoint | `https://api.fabric.microsoft.com/v1/mcp/core` |
| Transport | Streamable HTTP |
| Auth | OAuth 2.0 bearer token, Microsoft Entra ID |
| Scope | `https://api.fabric.microsoft.com/.default` |
| Installation | None — remote endpoint |
| Status | Preview. Tool list can change. |

Operations run with the signed-in identity's Fabric RBAC. Fabric audit logs record supported
operations against that identity.

### Tool inventory (43 tools)

**Read-only — safe without approval**

| Tool | Use |
| --- | --- |
| `search_catalog` | Find items across workspaces when the workspace is unknown |
| `list_workspaces` | Enumerate workspaces the identity can see; filter by role |
| `get_workspace` | One workspace's metadata, including `capacityId`, domain, identity, endpoints |
| `list_workspace_roles` | All role assignments for a workspace |
| `get_workspace_role` | One role assignment |
| `list_items` | Items in a workspace or folder, with optional type filter |
| `get_item` | One item's metadata — no data, no definition |
| `get_item_definition` | Typed definition parts for one item |
| `list_folders` | Logical workspace folders |
| `get_folder` | One folder's metadata and parent |
| `list_capacities` | Accessible capacities: ID, display name, SKU, region, state |
| `get_operation_state` | Long-running operation state |
| `get_operation_result` | Completed operation result |
| `get_knowledge` | Guidelines and best practices for item types |
| `onelake_list_shortcuts` | Shortcuts on an item |
| `onelake_get_shortcut` | One shortcut's properties and target |
| `onelake_list_data_access_roles` | Data access roles on an item |
| `onelake_get_settings` | Workspace OneLake settings |

**Write — approval required**

`create_workspace`, `update_workspace`, `add_workspace_role`, `update_workspace_role`,
`create_item`, `update_item`, `update_item_definition`, `create_folder`, `update_folder`,
`move_folder`, `bulk_move_items`, `onelake_create_shortcut`,
`onelake_create_shortcuts_in_bulk`, `onelake_create_or_update_single_data_access_role`,
`onelake_create_or_update_data_access_roles`, `onelake_modify_default_tier`,
`onelake_modify_diagnostics`, `onelake_modify_immutability_policy`,
`onelake_reset_shortcut_cache`

**Delete — denied**

`delete_workspace`, `delete_workspace_role`, `delete_item`, `delete_folder`,
`onelake_delete_shortcut`, `onelake_delete_data_access_role`

### What this server cannot do

This is the important part. The following have **no corresponding Core MCP tool**:

| Missing capability | Consequence |
| --- | --- |
| Assign a workspace to a capacity | `update_workspace` changes name and description only. Capacity assignment is a UI/portal action, verified afterwards through `get_workspace`. |
| Read or set Git connection state | No tool. Sync status, branch, folder and connection health are UI-only. |
| Create, read or bind connections | Connections are not workspace items and no tool exposes them. |
| Read or configure deployment pipelines | No tool. Stages, workspace assignment and rules are UI-only. |
| Read deployment operation results | No tool. |
| Read item data | Only metadata and definitions. Use workload servers for data. |

`get_workspace` returns `capacityId` when a workspace is assigned. That is the single read-only hook
available for capacity verification, and it is why runbook 1 is verifiable while runbooks 2, 3 and 5
are not.

### Pagination and result handling

- HTTP 200 can still contain `result.isError: true`. Check both.
- A list result can return JSON in one `text` block followed by a diagnostic block. Parse the data
  block; do not concatenate blocks into one JSON document.
- When a continuation token is returned, the first page is not the complete inventory.

---

## 2. Fabric MCP Server (local)

| Property | Value |
| --- | --- |
| Package | `@microsoft/fabric-mcp` (npm, MIT) |
| Launch | `npx -y @microsoft/fabric-mcp@latest server start --mode all --namespace docs` |
| Transport | stdio |
| Auth | None for the `docs` namespace — documentation is bundled |
| Runtime | Node.js 22 LTS or later |

### Why `--namespace docs` only

The server exposes five areas: `core`, `jobs`, `docs`, `onelake`, `datafactory`. Four of them reach
live Fabric. This toolkit starts only `docs`, which is offline API specification, item definition
schema and best-practice content.

Result: the local server cannot mutate anything, so it needs no permission rules beyond an allow for
`docs_*`. That is a smaller attack surface than trying to enumerate every write tool it might
someday ship.

### Tools in the `docs` namespace

| Tool | Use |
| --- | --- |
| `docs_list-item-types` | Item types with public API specifications |
| `docs_item-api-spec` | Full OpenAPI specification for one item type |
| `docs_platform-api-spec` | Platform-level OpenAPI specification |
| `docs_item-definitions` | JSON schema / definition documentation for an item type |
| `docs_best-practices` | Pagination, throttling, retry, auth guidance |
| `docs_api-examples` | Example request and response payloads |

Use these to answer "what does a valid Lakehouse definition look like" without guessing, and to
check whether an item's committed definition is structurally plausible.

### If someone widens the namespaces

Starting the local server without `--namespace docs` exposes `core_create-item`,
`core_assign-workspace-to-capacity`, `core_delete-item`, `onelake_delete-file` and similar. If that
is ever needed, add matching deny and ask rules to both adapters first, then update
`policy/tool-names.json`. Do not widen first and patch rules later.

---

## 3. Workload-specific work

Do not reimplement workload procedures. `microsoft/skills-for-fabric` already covers:

`spark-cli`, `sqldw-cli`, `sqldb-cli`, `eventhouse-cli`, `eventstream-cli`, `activator-cli`,
`dataflows-cli`, `semantic-model-authoring`, `powerbi-report-cli`, `search-consumption-cli`,
`onelake-catalog-cli`, `git-integration-operations-cli`, `deployment-pipelines-authoring-cli`,
`variable-library-cli`.

Two of those are directly relevant when a runbook hits its limit:

- `git-integration-operations-cli` — the Git integration lifecycle through the Fabric CLI
- `deployment-pipelines-authoring-cli` — deployment pipeline authoring through the REST API

They are **not** registered as MCP servers and this toolkit does not invoke them. They are named so
that when a human asks "can this be automated", the answer points at the existing skill rather than
at a new script.

---

## 4. Authentication reality per host

Both hosts need an Entra ID access token for `https://api.fabric.microsoft.com`. Microsoft's own
skills repository uses an Azure CLI token helper rather than OAuth dynamic client registration,
because Entra ID is not a reliable DCR authorization server for this endpoint.

### Claude Code

`.mcp.json` uses `headersHelper`, a command that writes a JSON object of headers to stdout:

- Claude Code runs it on each connect and on reconnect, and re-runs it once after a 401 or 403.
- 10-second limit. Output must be `{"Authorization":"Bearer <token>"}`.
- For plugin-supplied servers, credential-looking environment variables are stripped from the
  helper's environment. The helper must therefore read the token from Azure CLI's own on-disk
  state, not from an environment variable.
- If the project folder is not trusted, the helper does not run and only static headers apply.

### OpenCode

OpenCode has no `headersHelper`. Remote servers take static `headers`, with `{env:NAME}` and
`{file:path}` substitution:

```jsonc
"headers": { "Authorization": "Bearer {env:FABRIC_MCP_TOKEN}" }
```

Set the variable before launching OpenCode:

```powershell
$env:FABRIC_MCP_TOKEN = az account get-access-token `
  --resource https://api.fabric.microsoft.com `
  --query accessToken -o tsv
```

Entra access tokens are short-lived (typically under 90 minutes). A long OpenCode session will
eventually fail with 401 and needs a restart with a fresh token. That is a known release 1
limitation; the release 2 fix is a token-refresh wrapper, not a different MCP server.

Do not put a literal token in `opencode.json`, and do not commit a file containing one.
