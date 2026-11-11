---
name: drift-check
description: Compare declared configuration and repo definitions against live tenant state. Use when asked to check for drift, compare repo to tenant, or audit an environment. Read-only.
---

# Drift check

Read-only comparison of declared state, repo definitions, and live tenant state.

## Ground rules

- Read-only tools only.
- Never present a UI-only check as confirmed.

## Steps

1. **Confirm tenant and workspace.** `list_workspaces`, `get_workspace`.

2. **Compare declared config.** Read `fabric/declared-environment.yaml` and compare workspace
   names, capacity, roles against `get_workspace` and `list_workspace_roles`.

3. **Compare item inventory.** `list_items` per workspace against the repo folders. Report items
   in the tenant but not the repo, and items in the repo but not the tenant.

4. **Compare definitions.** `get_item_definition` for each item against the repo definition.
   Report semantic differences, especially environment-scoped values that still hold source
   tenant values.

5. **Check connections.** Connections are unverifiable via MCP. Report them as unverified with
   the reason.

6. **Check deployment pipelines.** Entirely unverifiable via MCP. Report as unverified.

7. **Report.** Produce a drift table: item, property, declared value, tenant value, status.

## What cannot be detected

- Git sync state (UI only).
- Connection existence or binding (UI only).
- Deployment pipeline configuration (UI only).
- Whether a definition difference is intentional or accidental (human decision).