# Runbook 5 — Deployment pipeline configuration

| | |
| --- | --- |
| **Performed by** | Human, in the Fabric deployment pipeline UI |
| **Agent role** | Pre-flight checks, and verification of the *resulting items* |
| **Verifiable via official MCP** | **No.** No MCP tool exposes pipelines, stages, assignments, rules or deploy results. |
| **Order** | Last. Runbooks 1–4 must be complete first. |
| **Applies to** | DEV → TST → PRD |

## Why this is a manual step

Deployment pipelines are a separate Fabric workload. The Core MCP Server exposes workspaces, items,
roles, folders and capacities — not pipelines. There is no tool to create a pipeline, assign a
workspace to a stage, add a rule, or read a deployment result.

`deployment-pipelines-authoring-cli` covers this through the REST API, but it is not an MCP server and
this toolkit does not invoke it.

## Model

```
DEV stage          TST stage          PRD stage
[DEV] DatEng  →    [TST] DatEng  →    [PRD] DatEng
[DEV] Data    →    [TST] Data   →     [PRD] Data
[DEV] Analytics →  [TST] Analytics →  [PRD] Analytics
```

Two viable shapes:

| Shape | Stages | Use when |
| --- | --- | --- |
| One pipeline per workspace | 3 pipelines × 3 stages | Workspaces are deployed independently |
| One pipeline, all workspaces selected per stage | 1 pipeline × 3 stages | The three workspaces always move together |

One pipeline per workspace is the safer default: a `data` failure does not block an unrelated
`analytics` hotfix. Choose one pipeline for everything only if the dependency chain genuinely requires
simultaneous promotion.

## Prerequisites

- [ ] Runbook 1 complete — every workspace assigned to the right capacity, in every stage
- [ ] Runbook 2 complete — DEV workspaces synced from Git
- [ ] Runbook 3 complete — connections exist in **every** stage that will receive items
- [ ] Runbook 4 complete — no unresolved absolute identifiers
- [ ] TST and PRD workspaces exist and are assigned to their own capacities
- [ ] The identity is an admin on the pipeline and on every workspace in it
- [ ] A deployment plan exists: which items are in scope, and which are DEV-only

## Steps

### 1. Create the pipeline

**Fabric hub → Deployment pipelines → New pipeline.** Name it after the workspace set, not after the
environment — the pipeline spans environments.

### 2. Name the stages

Rename the default stages to `DEV`, `TST`, `PRD`. If the tenant has fewer than three stages, add
stages before assigning anything.

### 3. Assign a workspace to each stage

Per stage: **Assign workspace** → select the stage's workspace → **Assign**.

| Stage | Workspace |
| --- | --- |
| DEV | `[DEV] DatEng` |
| TST | `[TST] DatEng` |
| PRD | `[PRD] DatEng` |

Repeat for the `data` and `analytics` pipelines.

A stage can hold only one workspace per pipeline. If the assignment is rejected, the workspace is
already assigned to another pipeline's same stage — that is a real constraint, not a bug.

### 4. Select the items in scope

In the DEV stage, use the item selection to include only what should be promoted.

Exclude:

- Scratch notebooks and ad hoc pipelines
- Items that exist only to support DEV debugging
- Items whose definitions still contain DEV identifiers (runbook 4)

Anything selected is copied to the next stage on every deployment. A scratch notebook in DEV becomes a
scratch notebook in PRD.

### 5. Configure deployment rules

This is where runbook 4's decisions become configuration. Rules are per item, per stage.

Typical rules:

| Item type | Property | DEV | TST | PRD |
| --- | --- | --- | --- | --- |
| Data pipeline | Connection | `sql-dev` | `sql-tst` | `sql-prd` |
| Data pipeline | Parameter default | dev path | tst path | prd path |
| Semantic model | Connection | dev | tst | prd |
| Mirrored database | Source connection | dev | tst | prd |
| Dataflow | Destination workspace / lakehouse | dev | tst | prd |

Rules are applied at deploy time, to the destination stage. A rule configured for TST does not apply
when deploying DEV → TST if it was set on the DEV stage — configure the rule on the **receiving**
stage.

If a property has no rule, go back to runbook 4 and parameterise it. Do not hand-edit the target
workspace: the next deployment overwrites it.

### 6. Deploy DEV → TST

Use **Compare** first. Review:

- Items added, updated, unchanged
- Items that will be deleted in the target
- Any item flagged as unsupported for deployment

Then **Deploy**. Wait for completion; do not start TST → PRD in parallel.

### 7. Verify TST before promoting to PRD

Agent, read-only:

```
list_items        workspaceId = <TST workspace id>
get_item          for each promoted item
get_workspace     confirm capacity is the TST capacity
```

Compare against the DEV inventory. Then the human runs the smoke test from runbook 4 step 4.

### 8. Deploy TST → PRD

Only after TST is verified. Repeat compare → deploy → verify.

## Verification

### What cannot be verified

| State | Why |
| --- | --- |
| Pipeline exists | No MCP tool |
| Stage names and order | No MCP tool |
| Workspace-to-stage assignment | No MCP tool |
| Item selection | No MCP tool |
| Deployment rules and their values | No MCP tool |
| Deployment result, per item | No MCP tool |
| Whether a rule actually applied | No MCP tool |

Record the human's confirmation for each. Never present a UI check as an agent verification.

### What the agent can verify

Only the destination stage's resulting state:

| Check | Tool |
| --- | --- |
| Items exist in TST/PRD | `list_items` |
| Item types are correct | `get_item` |
| Definitions no longer carry DEV identifiers | `get_item_definition` |
| Destination workspace still on its own capacity | `get_workspace` |

This confirms the *effect*. It does not confirm the pipeline configuration that produced it.

## Failure modes

| Symptom | Cause | Fix |
| --- | --- | --- |
| Stage assignment rejected | Workspace already assigned to another pipeline stage | Remove it there first |
| Item not deployed | Not selected, or type unsupported by deployment pipelines | Check item selection and type support |
| Item deployed but points at DEV | Rule missing, or configured on the wrong stage | Configure on the receiving stage |
| Deploy fails on a connection | Connection absent in the target stage | Runbook 3, in the target stage |
| Deploy succeeds, item errors at runtime | Credential, binding, or parameter unresolved | Runbook 3 / 4 |
| Target item deleted unexpectedly | Unselected items are removed on deploy | Compare before deploying; restore from the previous stage |
| Rule appears ignored | Property not rule-capable | Parameterise instead |

## Known limitations

- **No MCP coverage of the pipeline itself.** This is the largest verification gap in the toolkit.
- **Rules are stage-scoped and easy to misplace.** Always configure on the receiving stage.
- **Deployment can delete.** An item present in TST but not selected in DEV is removed. Compare first.
- **One workspace per stage per pipeline.** This constrains how pipelines are split.

## Rollback

Redeploy from the previous stage after reverting the source. Do not edit the target workspace by hand:
the change will be overwritten and will not be reproducible. If PRD is affected, follow the
organisation's change process — this runbook does not authorise a PRD rollback on its own.
