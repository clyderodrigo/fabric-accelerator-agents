# Runbook 3 — Connections per workspace

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

### Handshake A — Source connection (before pipeline creation)

The source connection (e.g. Azure SQL to WideWorldImporters) must exist before any pipeline
that reads from it is created.

1. Human creates the connection in the portal (Settings → Manage connections and gateways →
   New connection).
2. Human returns the connection ID to the agent.
3. Agent records it in the source-connection manifest and injects it into pipeline definitions
   at creation time.

### Handshake B — controlDB connection (after controlDB creation)

The controlDB SQL database must exist before a connection to it can be created.

1. Agent creates the `controlDB` SQLDatabase item.
2. Human creates a connection to controlDB's SQL analytics endpoint in the portal.
3. Human returns the connection ID to the agent.
4. Agent injects it into pipeline definitions before creating them.

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
| Works for one person, not another | Connection uses a personal credential | Move to service principal or managed identity |
| Two items, one source, different results | Different connections bound to the same source | Consolidate onto one connection per environment |