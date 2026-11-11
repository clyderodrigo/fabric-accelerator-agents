# Guardrails — enforcement model and rationale

This toolkit enforces a strict split between what the agent can do on its own and what requires a
human. The model changed with the introduction of the `fabric-core` write tools: the agent may now
create and mutate Fabric items, but only under explicit approval and within the limits below.

## Three tiers

| Tier | Tools | Rule |
| --- | --- | --- |
| Read | `read` list in `tool-names.json` | Allowed without approval. Verification and discovery. |
| Write | `write` list in `tool-names.json` | Approval-gated. Agent proposes payload, human approves, then executes. |
| Delete | `delete` list in `tool-names.json` | Denied. Never attempted, never worked around. |

Role-change tools (`add_workspace_role`, `update_workspace_role`, `delete_workspace_role`) are
write tools that additionally require an explicit security-change acknowledgement.

## What the agent may do

- Read tenant state: workspaces, items, definitions, folders, capacities, roles.
- Create workspaces, items, folders, shortcuts, data access roles — after approval.
- Update item metadata and definitions — after approval.
- Move items between folders — after approval.
- Assign workspace roles — after explicit security-change acknowledgement.

## What the agent must never do

- Call any `delete_*` tool. Denied in both hosts; not a suggestion.
- Invent tenant state. If a tool cannot verify something, say "I could not verify this via MCP."
- Write credentials, tokens, or connection strings into tracked files.
- Mix MCP-driven and Git-sync deployment in one workspace. API-created items receive a nil
  logicalId and are not identity-compatible with Git-synced items.
- Execute a write without explicit approval.
- Assume the environment. Confirm tenant and target workspace before any deployment run.

## Deployment modes

Two modes exist. They must not be mixed in one workspace.

| Mode | Mechanism | When to use |
| --- | --- | --- |
| MCP-driven | Agent creates items via `fabric-core` write tools, using repo definitions as the payload library | Default for new workspaces. Full control of IDs, handshakes, and ordering. |
| Git-sync | Fabric Git integration syncs a folder into a workspace | Abandoned for this toolkit. Items created this way carry real logicalIds and are not
  interchangeable with MCP-created items. |

## Connections

Connections are tenant-level artifacts with no MCP tool. They are supplied by the human and
consumed by the agent at creation time. The agent never creates, reads, or binds a connection.
The handshake procedure is in runbook 06.

## Hooks are a second layer

Where a host supports hooks, they add defence in depth. They are never the enforcement point —
permission rules are.

## Rationale

The MCP server is Microsoft-published and its tool list is the boundary. Writes are gated
because item creation is a tenant mutation. Deletes are denied because there is no recovery
path from an agent mistake. Connections and deployment pipelines have no MCP surface at all,
so they remain human steps with agent guidance.