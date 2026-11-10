---
name: provision-checklist
description: Ordered, gated checklist for provisioning the DEV workspaces and promoting them to Test and Production. Use when someone asks to provision an environment, start a new workspace, stand up DEV, or asks what still needs doing before a first deployment. Covers capacity, Git connection, connections, ID rebinding and deployment pipelines, in dependency order.
---

# Provision checklist

Walks a human through provisioning. The agent does not perform the mutating steps; it sequences
them, states what to check, and verifies what is verifiable.

## Ground rules

- The human performs every step marked **UI**. The agent verifies afterwards where a tool exists.
- Order is fixed: `dateng` → `data` → `analytics`. Do not parallelise across workspaces.
- A gate is not passed until its verification line is answered. "Looks fine" is not an answer.
- Where verification is impossible via MCP, say so and record who confirmed it.

## Before starting

Confirm with the human, and write the answers into the response:

1. Tenant name and tenant ID being provisioned.
2. Capacity display name and SKU available to that tenant.
3. Git provider (Azure DevOps or GitHub), organisation/project, repository, branch.
4. The three workspace display names.
5. That the signed-in identity is a Fabric Administrator, or can create workspaces and assign
   capacity.

Then check that the declared configuration exists:

- `fabric/declared-environment.yaml` in the consuming repo.
- One repo folder per workspace, each containing `.platform` files for its items.

If the declared config is missing, stop and point at `fabric/declared-environment.md`. Do not
infer the environment from the repo tree alone.

## Stage 1 — Workspaces exist

| Step | Who | Action |
| --- | --- | --- |
| 1.1 | UI | Create `[DEV] DatEng` |
| 1.2 | UI | Create `[DEV] Data` |
| 1.3 | UI | Create `[DEV] Analytics` |

Workspace creation is available through `create_workspace`, but this checklist does not use it:
workspace creation is a capacity decision with naming and domain implications, and the human owns
it.

**Verify** — `list_workspaces`, then `get_workspace` for each. Confirm display name and that `id` is
stable. If a workspace is missing from `list_workspaces`, the identity lacks visibility, not
necessarily that the workspace is absent — say which.

## Stage 2 — Capacity assigned

Runbook: `fabric/runbooks/01-capacity-assignment.md`

| Step | Who | Action |
| --- | --- | --- |
| 2.1 | UI | Assign `[DEV] DatEng` to the capacity |
| 2.2 | UI | Assign `[DEV] Data` |
| 2.3 | UI | Assign `[DEV] Analytics` |

**Verify** — `get_workspace` per workspace: `capacityId` must be non-null and equal for all three.
Then `list_capacities` and confirm that ID's display name, SKU, region and state. A workspace with a
`capacityId` pointing at a capacity in a failed state is not provisioned.

## Stage 3 — Roles

**Verify first, then decide.** Run `list_workspace_roles` for each workspace and compare to the
`roles` block in the declared config. Report mismatches; do not fix them.

Role changes are approval-gated. If the human asks the agent to make one, that is a deliberate
exception, not part of this checklist.

## Stage 4 — Git connection

Runbook: `fabric/runbooks/02-git-connection.md`

| Step | Who | Action |
| --- | --- | --- |
| 4.1 | UI | Connect `[DEV] DatEng` to its repo folder and branch |
| 4.2 | UI | Initialise / update from Git |
| 4.3 | UI | Repeat for `[DEV] Data` |
| 4.4 | UI | Repeat for `[DEV] Analytics` |

**Verify** — not possible via MCP. Git connection state, branch, folder and sync status are UI-only.
Record the human's confirmation of: provider, repository, branch, folder, last sync time, and whether
any item failed to sync.

**Then verify the effect**, which *is* possible: `list_items` per workspace and compare item names and
types against the repo folders. A Git connection that reports success but produced no items is a
failed connection.

## Stage 5 — Connections

Runbook: `fabric/runbooks/03-connections.md`

| Step | Who | Action |
| --- | --- | --- |
| 5.1 | UI | Create each connection named in the declared config |
| 5.2 | UI | Bind each connection to the items that reference it |

**Verify** — not possible via MCP. Connections are not workspace items. Record the human's
confirmation of connection name, type, and which items were bound.

Indirect signal: `get_item_definition` on a bound item can show a connection reference in its
definition. That confirms a reference exists, not that it resolves.

## Stage 6 — Cross-workspace rebinding

Runbook: `fabric/runbooks/04-id-rebinding.md`

This is where most first deployments break. Run it before any pipeline configuration.

| Step | Who | Action |
| --- | --- | --- |
| 6.1 | Agent | Read item definitions via `get_item_definition` and list every hard-coded GUID or item name |
| 6.2 | Human | Decide, per reference, whether it should point at the same workspace or a target-stage item |
| 6.3 | Human | Apply fixes in the repo, commit, update from Git |
| 6.4 | UI | Re-sync the affected workspace |

**Verify** — partially. `get_item_definition` confirms what is in the tenant now. It cannot confirm
that a reference resolves at runtime. State that explicitly.

## Stage 7 — Deployment pipelines

Runbook: `fabric/runbooks/05-deployment-pipelines.md`

| Step | Who | Action |
| --- | --- | --- |
| 7.1 | UI | Create the pipeline with DEV, TST, PRD stages |
| 7.2 | UI | Assign each workspace to its stage |
| 7.3 | UI | Configure deployment rules for environment-specific values |
| 7.4 | UI | Deploy DEV → TST, then TST → PRD |

**Verify** — not possible via MCP. No tool exposes deployment pipelines, stages, assignments, rules,
or deployment results. Record the human's confirmation per stage, plus any item that failed to deploy.

## Completion report

Produce this table. Do not collapse rows.

| Gate | Status | Evidence | Verified by |
| --- | --- | --- | --- |
| Workspaces exist | Verified / Unverified / Failed | tool + key values | agent / human |
| Capacity assigned | … | `capacityId` per workspace | agent |
| Roles match declared | … | diff summary | agent |
| Git connected | Unverified (UI-only) | human confirmation | human |
| Items present after sync | … | item counts per workspace | agent |
| Connections bound | Unverified (UI-only) | human confirmation | human |
| Cross-workspace references | Partially verified | definitions read, runtime untested | agent + human |
| Deployment pipeline | Unverified (UI-only) | human confirmation | human |

Close with the single most likely next failure, chosen from what is still unverified.
