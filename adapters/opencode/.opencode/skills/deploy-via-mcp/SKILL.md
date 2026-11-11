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
4. **Handshake B** — pause. Human creates a connection to controlDB's SQL analytics endpoint
   and returns the connection ID. Do not proceed without it.
5. **Create DataPipelines** — for each pipeline in the source-connection manifest's matched
   pattern, inject workspace/item/connection IDs into the definition, then `create_item`.
6. **Create MirroredDatabase** (optional) — inject the source connection ID.
7. **Verify** — `list_items` + `get_item_definition` per item. Report which checks are
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