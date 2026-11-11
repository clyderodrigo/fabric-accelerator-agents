# Runbook 6 — MCP-driven deployment

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

1. **Workspace** — `create_workspace(displayName, capacityId)` → `workspaceId`.
2. **Folders** — `create_folder` for logical grouping (optional).
3. **Lakehouses** — `create_item(type=Lakehouse, definition)` → `lakehouseId`.
4. **Warehouse** — `create_item(type=Warehouse, definition)` → `warehouseId`.
5. **SQLDatabase** — `create_item(type=SQLDatabase, definition)` → `sqlDatabaseId`.
   - ⏸ **Handshake B** — human creates a connection to controlDB's SQL analytics endpoint and
     returns the connection ID.
6. **Notebooks** — `create_item(type=Notebook, definition)` → `notebookId`.
7. **VariableLibrary** — `create_item(type=VariableLibrary, definition)` with item IDs injected
   → `variableLibraryId`.
8. **DataPipelines** — `create_item(type=DataPipeline, definition)` with:
   - connection IDs from the source manifest and handshake B
   - item IDs from steps 3-7
   - child pipeline `referenceName` values rewritten to deployed IDs
   - `libraryVariables.libraryId` rewritten to the deployed VariableLibrary ID
9. **MirroredDatabase** (optional) — `create_item(type=MirroredDatabase, definition)` with the
   source connection ID injected.
10. **Verify** — `list_items` + `get_item_definition` per item.

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

## Verification

After deployment, verify per item:

```
list_items            per workspace
get_item_definition   for each item created
```

Confirm item types, display names, and that definitions contain the injected (not source) IDs.
State clearly which checks are agent-verifiable and which remain UI-only.