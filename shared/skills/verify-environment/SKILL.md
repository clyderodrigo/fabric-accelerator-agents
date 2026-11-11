---
name: verify-environment
description: Read-only verification of a deployed Fabric environment against the declared configuration and repo definitions. Use when asked to verify, check, audit, or confirm a deployment, or after a deployment run. Never mutates tenant state.
---

# Verify environment

Read-only verification. The agent never mutates state during this skill.

## Ground rules

- Read-only tools only. No writes, no deletes, no role changes.
- Never present a UI-only check as confirmed. State plainly what could not be verified and why.
- Confirm the tenant and target workspace before starting.

## Steps

1. **Confirm tenant and workspace.** `list_workspaces`, then `get_workspace` for the target.
   Record the workspace ID, capacity ID, and region.

2. **Verify capacity.** `list_capacities` and confirm the workspace's `capacityId` matches the
   declared capacity display name, SKU, and region.

3. **Verify roles.** `list_workspace_roles` and compare against the declared config. Report
   mismatches; do not fix them.

4. **Verify items.** `list_items` per workspace. Compare item names and types against the repo
   folders. Report missing or extra items.

5. **Verify definitions.** `get_item_definition` for each item. Compare semantically against the
   repo definition. Confirm that environment-scoped values (workspace IDs, item IDs, connection
   IDs) contain the deployed values, not source values.

6. **Verify folders.** `list_folders`, `get_folder` against the declared structure.

7. **Report.** Produce the verification matrix from `shared/policy/official-mcp-servers.md`.

## What cannot be verified

- Connections exist or are bound (portal only).
- Deployment pipeline stages, assignments, rules, or results (portal only).
- Runtime binding correctness (must run the item).
- Whether a promoted item reads the correct environment's data (must test in target stage).

State each of these as unverified with the reason, not as complete.