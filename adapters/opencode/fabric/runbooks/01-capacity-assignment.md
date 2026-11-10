# Runbook 1 — Capacity assignment per workspace

| | |
| --- | --- |
| **Performed by** | Human, in the Fabric portal |
| **Agent role** | Guides the steps, then verifies read-only |
| **Verifiable via official MCP** | **Yes** — `get_workspace` and `list_capacities` |
| **Order** | After workspaces exist, before Git connection |
| **Applies to** | `[DEV] DatEng`, `[DEV] Data`, `[DEV] Analytics` |

## Why this is a manual step

The Core MCP Server has no tool that assigns a workspace to a capacity. `update_workspace` changes
the display name and description only. Assignment is a portal action.

Verification, however, *is* possible, because `get_workspace` returns the assigned `capacityId`. That
makes this the best-covered of the five runbooks.

## Prerequisites

- [ ] All three workspaces exist
- [ ] The signed-in identity is a Fabric Administrator, or holds a role on the capacity that permits
      assignment
- [ ] A Fabric capacity exists in the target tenant and region, in an active state
- [ ] The capacity SKU is large enough for the intended workload — see the cost-estimation skill
      before choosing
- [ ] The capacity is not already fully allocated to unrelated workspaces

## Steps

### 1. Confirm the target capacity

In the portal: **Admin portal → Capacity settings**, or **Manage capacities** in the Fabric hub.

Record:

| Field | Value |
| --- | --- |
| Capacity display name | |
| Capacity ID | |
| SKU | |
| Region | |
| State | |

Cross-check with the agent: run `list_capacities` and confirm the capacity appears with the same
name, SKU, region and state. If it does not appear, the identity is not an administrator or
contributor on that capacity — resolve that before continuing.

### 2. Assign `[DEV] DatEng`

**Workspace settings → License info / Capacity → Edit** → select the capacity → **Apply**.

### 3. Assign `[DEV] Data`

Same path. Use the same capacity.

### 4. Assign `[DEV] Analytics`

Same path. Use the same capacity.

## Verification

Agent, read-only:

```
get_workspace      workspaceId = <dateng id>
get_workspace      workspaceId = <data id>
get_workspace      workspaceId = <analytics id>
list_capacities
```

Pass criteria:

1. `capacityId` is non-null on all three workspaces.
2. All three `capacityId` values are identical.
3. That ID appears in `list_capacities`.
4. The capacity's `state` is healthy and its `sku` matches the declared config.
5. If `list_capacities` returned a `continuationToken`, page through before concluding.

Failure meanings:

| Observation | Meaning |
| --- | --- |
| `capacityId` null | Assignment did not apply, or was reverted |
| Different `capacityId` per workspace | Wrong capacity on at least one workspace |
| ID not in `list_capacities` | Capacity exists but identity cannot see it, or it was deleted |
| Capacity state not healthy | Assignment will not behave; escalate before continuing |

## Notes and failure modes

- **Trial or free capacity**: assignment may be blocked by tenant settings rather than by permissions.
  The error appears in the portal, not in the MCP response.
- **Assignment is asynchronous.** `capacityId` can be present while the workspace is still migrating.
  If items misbehave immediately after assignment, re-check after a few minutes rather than
  reassigning.
- **Moving a workspace between capacities later** moves its OneLake data and can incur charges.
  Treat a capacity change as a change window, not a fix for a performance complaint.
- **Do not assign TST or PRD workspaces to the DEV capacity** to "test" a deployment. Stage
  isolation is the point of having separate capacities.

## Rollback

Reassignment is reversible from the same portal screen: assign the workspace back to the previous
capacity. Verify with `get_workspace` again. There is no MCP-based rollback, and there is no
agent-side undo.
