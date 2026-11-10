---
name: verify-environment
description: Read-only verification of a Fabric environment against its declared configuration — workspaces, capacity, roles, items, folders — using official MCP tools only. Use when someone asks whether an environment is set up correctly, asks for a health check, asks what is deployed, or wants proof that a provisioning step worked.
---

# Verify environment

Read-only. This skill never mutates anything. If a check fails, report it; do not fix it.

## Before the first call

State, in the response:

1. The tenant you are checking (from `az account show`, or ask the human).
2. The workspace set: `dateng`, `data`, `analytics`.
3. The config file you are comparing against.

If the identity cannot see a workspace, that is a finding. Do not silently substitute another
account or another tenant.

## Checks, in order

### Check 1 — Workspaces exist

```
list_workspaces
```

Then, per workspace:

```
get_workspace   workspaceId = <id>
```

Record: `id`, `displayName`, `capacityId`, `domainId`, `type`.

Fail if a declared workspace is absent. Report the count of workspaces visible to the identity, so a
permissions problem is distinguishable from a missing workspace.

### Check 2 — Capacity assignment

```
get_workspace      per workspace → capacityId
list_capacities    → id, displayName, sku, region, state
```

All three workspaces must report the same non-null `capacityId`, and that ID must appear in
`list_capacities` with the expected SKU and a healthy state.

`list_capacities` returns one page. If a `continuationToken` comes back, page through before
concluding a capacity is missing.

This is the one runbook-1 gate that is genuinely verifiable read-only.

### Check 3 — Roles

```
list_workspace_roles   per workspace
```

Compare to the `roles` block in the declared config. Report:

- **Missing** principal or role.
- **Extra** principal not in the declared config.
- **Role drift** — same principal, different role.

Do not change roles. A role difference is reported as a finding.

### Check 4 — Items

```
list_items   per workspace
```

Build a per-type inventory. Compare against the repo folders:

- Items in scope: `Lakehouse`, `Warehouse`, `Notebook`, `DataPipeline`, `MirroredDatabase`,
  `SQLDatabase`.
- Anything else: list under **out of scope** with its type. Do not silently drop it.

Then spot-check definitions on the items that carry cross-workspace references:

```
get_item_definition   workspaceId, itemId
```

Use `docs_item-definitions` from `fabric-local` to judge whether a definition is structurally
plausible for its type.

### Check 5 — Folders

```
list_folders   per workspace
get_folder     when a parent relationship matters
```

Only if the declared config uses folders. Absence of folders is not a failure when none are declared.

### Check 6 — What cannot be checked

Always produce this section. It is not optional, and it is not filler.

| State | Why it cannot be verified |
| --- | --- |
| Git connection and sync status | No Core MCP tool exposes Git integration |
| Connections and their bindings | Connections are not workspace items |
| Deployment pipeline stages, assignments, rules | No MCP tool exposes deployment pipelines |
| Deployment results | No MCP tool exposes deployment operations |
| Runtime behaviour of a promoted item | Requires executing the item |

## Output format

```
Environment: <tenant> / <capacity name> / <three workspaces>
Compared against: fabric/declared-environment.yaml
Checked at: <timestamp>

FINDINGS
  [FAIL]  analytics: capacityId is null — workspace not assigned to a capacity
  [WARN]  data: principal group:bi-developers@contoso.com has Contributor, declared Viewer
  [INFO]  dateng: 14 items, all in scope

UNVERIFIED (UI-only)
  Git connection state — confirm in Workspace settings → Git integration
  Connections — confirm each declared connection exists and is bound
  Deployment pipeline — confirm stage assignment and rules

VERDICT: <one sentence>
```

Severity: `FAIL` breaks the declared intent. `WARN` differs but may be intentional. `INFO` is
informational. Never use `FAIL` for something you could not check — that is `UNVERIFIED`.

## Rules

- Every claim carries the tool that produced it.
- Every unverified row is named. A report with no `UNVERIFIED` section is wrong.
- No mutations, no "while I was there" fixes, no role changes to make a check pass.
- If a tool errors, report the error verbatim and continue with the remaining checks.
