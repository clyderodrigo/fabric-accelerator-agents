# Runbook 3 — Connection creation and binding per workspace

| | |
| --- | --- |
| **Performed by** | Human, in the Fabric portal |
| **Agent role** | Guides, and reads item definitions to find references |
| **Verifiable via official MCP** | **No.** Connections are not workspace items and no MCP tool exposes them. |
| **Order** | After Git connection, before cross-workspace rebinding and pipeline configuration |
| **Applies to** | All three workspaces, plus the TST and PRD stages |

## Why this is a manual step

A Fabric connection (cloud connection, gateway connection, or data source credential set) is a
tenant-level artifact. It is not a workspace item, so it does not appear in `list_items`, and no Core
MCP tool can create, read, or bind one.

What the agent *can* do is read an item definition and show you a connection reference that exists in
the definition. That proves a reference is present. It does not prove the reference resolves.

## Prerequisites

- [ ] Git connection is established and items are present
- [ ] The credential or principal for each connection is available (Key Vault reference, service
      principal, managed identity, or user credential)
- [ ] The identity can create connections in the tenant, or can bind to an existing shared connection
- [ ] Gateway requirements are known for any on-premises source
- [ ] Each connection is declared in `fabric/declared-environment.yaml` under `connections:`

## Steps

### 1. Inventory the connections the items need

Before creating anything, find out what is actually required. The agent can help here.

```
list_items            per workspace
get_item_definition   for pipelines, mirrored databases, SQL databases, dataflows
```

Build a table of every distinct connection reference, and match each to the declared config:

| Connection name | Type | Used by (workspace / item) | Declared in config? |
| --- | --- | --- | --- |
| | | | |

An undeclared connection is a finding: either the config is incomplete or the item was built ad hoc.
Resolve that before creating credentials for it.

### 2. Create each connection

**Portal path:** Settings → **Manage connections and gateways** → **New connection** → choose the
source type → enter endpoint and credentials → **Create**.

Guidance that prevents most rework:

- **Name connections per environment.** A connection called `sql-prod` used by a DEV item is a
  production incident waiting for a deployment rule to be missed.
- **Prefer a service principal or managed identity** over a personal credential. A connection bound to
  a person's account breaks when that person leaves.
- **Store secrets in Key Vault** where the tenant supports it, and reference the secret rather than
  pasting a value.
- **Do not reuse a DEV connection in TST or PRD.** Deployment rules can rebind, but only if the target
  connection already exists in the target stage.

### 3. Bind each connection to its item

Binding is per item, in the item's own UI:

| Item type | Where binding happens |
| --- | --- |
| Data pipeline | Pipeline → activity → connection/settings |
| Mirrored database | Mirroring configuration → source connection |
| SQL database | Item settings → connection |
| Dataflow Gen2 | Dataflow → data destination / source settings |
| Semantic model | Settings → data source credentials |

### 4. Repeat per workspace

`dateng` first. A `data` item that reads from a `dateng` lakehouse may depend on a shortcut rather
than a connection — check runbook 4 before assuming a connection is missing.

## Verification

### What cannot be verified

State this plainly to the human:

> Connections are not workspace items and no MCP tool exposes them. I cannot confirm that a
> connection exists, that its credentials are valid, or that an item is bound to it. Please confirm
> the following in the portal.

Ask for, and record:

| Item | Value |
| --- | --- |
| Connection name | |
| Type | |
| Created / reused | |
| Bound to which items | |
| Credential tested successfully | yes / no / not tested |

### What the agent can verify

Only the presence of a reference inside an item definition:

```
get_item_definition   workspaceId, itemId
```

Report:

- The connection reference as it appears in the definition.
- Whether that reference looks like a GUID, a name, or a workspace-relative path.
- Whether the same reference appears in the declared config.

Say clearly: **a reference in a definition is not a working connection.**

### Indirect signals worth checking

- If an item definition contains a hard-coded server name or workspace GUID, runbook 4 applies.
- If two items in the same workspace reference different connections for the same source, one of them
  is probably wrong. Flag it.

## Failure modes

| Symptom | Cause | Fix |
| --- | --- | --- |
| Item fails on refresh with an auth error | Credential expired or wrong principal | Re-enter credentials on the connection |
| Works in DEV, fails in TST after promotion | Connection not created in TST | Create it in TST before deploying |
| Gateway error | Source is on-premises and no gateway is bound | Bind a gateway to the connection |
| Works for one person, not another | Connection uses a personal credential | Move to service principal or managed identity |
| Two items, one source, different results | Different connections bound to the same source | Consolidate onto one connection per environment |

## Rebinding connection GUIDs on a new tenant

The connection GUIDs shipped in item definitions (`"connection": "<guid>"`) are the source
tenant's. They are not expression slots, so they cannot be parameterised through the Variable
Library, and they are validated at sync time - a definition that points at a connection the
binding user cannot reach fails `Update from Git` with `RequestValidationFailed` /
`ConnectionNotAccessible` before the item is created.

Before syncing into a new tenant:

1. Create the four connections (runbook 3 steps 1-3) and record their ids.
2. Copy `fabric/connection-rebind.example.json` to `fabric/connection-rebind.json` and fill in the
   target ids.
3. Run `pwsh ./scripts/rebind-connections.ps1 -MappingFile ./fabric/connection-rebind.json`.
4. Commit or keep the rebind as a local transform, then `Update from Git`.

The script rewrites every occurrence in `dateng/`, `dateng-optional/` and `dateng-rti/` JSON
definitions. It never touches `.platform` files or logicalIds. It is a repo file edit, not a
tenant mutation.

## Known limitations

- **Zero MCP coverage.** Every claim in this runbook's verification section is human-confirmed.
- **Credential validity cannot be tested read-only.** A connection can exist and be bound while its
  secret is expired.
- **Binding is item-specific.** There is no single screen that shows "which items use this connection",
  so the inventory in step 1 is the only reliable map.

## Rollback

Delete or replace the connection in **Manage connections and gateways**, then rebind the affected
items. Deleting a connection that is still bound breaks those items — capture `list_items` and the
binding table first so the pre-change state is recorded.
