---
name: provision-checklist
description: Ordered, gated checklist for provisioning the DEV workspaces and promoting them to Test and Production via MCP-driven deployment. Use when someone asks to provision an environment, start a new workspace, stand up DEV, or asks what still needs doing before a first deployment. Covers capacity, connections, MCP-driven item creation, and deployment pipelines, in dependency order.
---

# Provision checklist

Walks a human through provisioning. The agent creates items via MCP under approval; the human
supplies connections, capacity, and approvals. Order is fixed: `dateng` → `data` → `analytics`.

## Ground rules

- The human performs every step marked **UI** and approves every write. The agent verifies
  afterwards where a tool exists.
- Order is fixed: `dateng` → `data` → `analytics`. Do not parallelise across workspaces.
- A gate is not passed until its verification line is answered. "Looks fine" is not an answer.
- Where verification is impossible via MCP, say so and record who confirmed it.
- MCP-driven and Git-sync deployment must not be mixed in one workspace.

## Before starting

Confirm with the human, and write the answers into the response:

1. Tenant name and tenant ID being provisioned.
2. Capacity display name and SKU available to that tenant.
3. Source connections: type and endpoint for each source.
4. The three workspace display names.
5. That the signed-in identity can create workspaces and assign capacity.

Then check that the declared configuration exists:

- `fabric/declared-environment.yaml` in the consuming repo.
- `fabric/source-connections.yaml` with source connection IDs (or handshakes accepted).
- One repo folder per item type collection, each containing `.platform` files for its items.

If the declared config is missing, stop and point at `shared/config/declared-environment.md`. Do not
infer the environment from the repo tree alone.

## Stage 1 — Workspaces exist

| Step | Who | Action |
| --- | --- | --- |
| 1.1 | Agent (approved) | `create_workspace` for `[DEV] DatEng` with capacity ID |
| 1.2 | Agent (approved) | `create_workspace` for `[DEV] Data` |
| 1.3 | Agent (approved) | `create_workspace` for `[DEV] Analytics` |

**Verify** — `list_workspaces`, then `get_workspace` for each. Confirm display name, capacity ID,
and that `id` is stable.

## Stage 2 — Capacity assigned

Capacity is assigned at workspace creation time via `create_workspace(capacityId)`. If a workspace
was created without a capacity, it cannot be reassigned via MCP — recreate it.

**Verify** — `get_workspace` per workspace: `capacityId` must be non-null and equal for all three.
Then `list_capacities` and confirm that ID's display name, SKU, region and state.

## Stage 3 — Roles

**Verify first, then decide.** Run `list_workspace_roles` for each workspace and compare to the
`roles` block in the declared config. Report mismatches; do not fix them.

Role changes are approval-gated. If the human asks the agent to make one, that is a deliberate
exception, not part of this checklist.

## Stage 4 — Source connections

Runbook: `shared/runbooks/03-connections.md`

| Step | Who | Action |
| --- | --- | --- |
| 4.1 | UI | Create each source connection named in `source-connections.yaml` |
| 4.2 | Human | Return connection IDs to the agent |
| 4.3 | Agent | Record them in the manifest |

**Verify** — not possible via MCP. Connections are not workspace items. Record the human's
confirmation of connection name, type, and which items will use them.

## Stage 5 — MCP-driven deployment

Runbook: `shared/runbooks/06-mcp-deployment.md`

| Step | Who | Action |
| --- | --- | --- |
| 5.1 | Agent (approved) | Create core items: Lakehouses → Warehouse → SQLDatabase → Notebooks → VariableLibrary |
| 5.2 | UI | Create controlDB connection (handshake B) |
| 5.3 | Human | Return controlDB connection ID |
| 5.4 | Agent (approved) | Create DataPipelines with injected IDs |
| 5.5 | Agent (approved) | Create MirroredDatabase (optional) |

**Verify** — `list_items` + `get_item_definition` per item. Confirm types, display names, and
that definitions contain injected (not source) IDs.

## Stage 6 — Deployment pipelines

Runbook: `shared/runbooks/05-deployment-pipelines.md`

| Step | Who | Action |
| --- | --- | --- |
| 6.1 | UI | Create the pipeline with DEV, TST, PRD stages |
| 6.2 | UI | Assign each workspace to its stage |
| 6.3 | UI | Configure deployment rules for environment-specific values |
| 6.4 | UI | Deploy DEV → TST, then TST → PRD |

**Verify** — not possible via MCP. No tool exposes deployment pipelines, stages, assignments,
rules, or deployment results. Record the human's confirmation per stage.

## Completion report

Produce this table. Do not collapse rows.

| Gate | Status | Evidence | Verified by |
| --- | --- | --- | --- |
| Workspaces exist | Verified / Unverified / Failed | tool + key values | agent |
| Capacity assigned | — | `capacityId` per workspace | agent |
| Roles match declared | — | diff summary | agent |
| Source connections | Unverified (UI-only) | human confirmation | human |
| Items created via MCP | — | item counts per workspace | agent |
| Item definitions match repo | — | definitions read | agent |
| controlDB connection | Unverified (UI-only) | human confirmation | human |
| Deployment pipeline | Unverified (UI-only) | human confirmation | human |

Close with the single most likely next failure, chosen from what is still unverified.