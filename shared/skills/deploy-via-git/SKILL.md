---
name: deploy-via-git
description: The DEV deployment loop for a Fabric Git-integrated repo — commit to the repo, update the workspace from Git, confirm items landed, then promote through deployment pipelines to Test and Production. Use when someone asks to deploy, sync, publish, release, promote, or asks why a committed change is not showing in a workspace.
---

# Deploy via Git

DEV is deployed by Git integration. TST and PRD are deployed by deployment pipelines. These are two
different mechanisms with two different failure modes; do not describe one as the other.

## Part 1 — DEV via Git integration

### Step 1: the human commits

The agent may help edit files, review a diff, and confirm the change is committed and pushed. The
agent does not commit to a branch that Fabric syncs without the human asking.

Before the human pushes, check:

- Every changed item folder has a `.platform` file.
- No token, connection string, or client secret is in the diff.
- Item names and folder names match the declared config.
- No environment-specific GUID was introduced by hand. If one was, run
  `shared/runbooks/04-id-rebinding.md` instead of continuing.

### Step 2: the human updates from Git

**UI only.** In the workspace: *Workspace settings → Git integration → Update* (or the Source
control panel). The agent cannot trigger this.

This is the single most common point of confusion: a push to the repo changes nothing in Fabric until
Update from Git runs, and the sync can partially fail.

### Step 3: the agent verifies the effect

This is the only reliable read-only proof that a Git update worked.

```
list_items        workspace = <workspace id>
```

Compare against the repo folder:

- **Missing item** — the update did not include it, or the item failed to sync.
- **Extra item** — present in the workspace, absent from the repo. Usually an item created in the UI
  that will be deleted on the next full sync. Report it; do not delete it.
- **Type mismatch** — the folder says one type, the workspace says another. This is a rename or a
  hand-created replacement.

For a changed item, confirm the definition moved:

```
get_item_definition   workspace = <id>, item = <id>
```

Compare semantically. Definition parts are returned as inline base64 and are not byte-identical to
the repo file — whitespace, ordering and generated properties differ. Report *what changed*, not
*that bytes differ*.

Repeat per workspace in order: `dateng`, `data`, `analytics`. A `data` failure caused by a missing
`dateng` asset should be reported as a dependency failure, not a Git failure.

### Step 4: record what cannot be verified

Always state, after a DEV sync:

> Git connection state, branch, folder and last-sync status are UI-only. I verified the items that
> resulted from the sync, not the sync itself.

## Part 2 — TST and PRD via deployment pipelines

Promotion is a human action in the deployment pipeline UI. No MCP tool exposes pipelines, stages,
assignments, rules, or deploy results.

### Step 1: pre-promotion checks

Run these before the human deploys. Each is a real cause of a broken promotion.

1. **Item inventory matches between stages** — `list_items` in the source stage workspace. Anything
   in DEV that should not reach TST must be removed from the pipeline's item selection first.
2. **Environment-specific values are covered by a rule** — connection IDs, workspace IDs, lakehouse
   names, warehouse names, capacity-specific settings. If a value differs between stages and no rule
   covers it, the promoted item will point at DEV. See runbook 5.
3. **Data-plane items are not promoted blindly** — a MirroredDatabase or SQLDatabase may need its
   target connection to exist in the destination stage first. See runbook 3.
4. **Nothing depends on an item excluded from the deployment** — check the dependency order.

### Step 2: the human deploys

**UI only.** In the deployment pipeline: compare stages, then *Deploy*. Repeat TST → PRD only after
TST is verified.

### Step 3: verify in the destination stage

Run `list_items` against the destination workspace and compare with the source stage. Then:

- `get_item` for the promoted items — confirm they exist and have the expected type.
- `get_workspace` — confirm the destination workspace is still on the expected capacity.

What this does **not** prove: that bindings resolve, that rules applied correctly, or that the item
runs. Say so. A promoted pipeline that exists but points at a DEV lakehouse passes every check above.

### Step 4: runtime smoke test

The honest final step is a human running the thing: execute the pipeline, refresh the semantic model,
open the report. Record the result as human-confirmed, not agent-verified.

## Failure triage

| Symptom | Likely cause | Next action |
| --- | --- | --- |
| Committed change not in workspace | Update from Git not run, or sync failed | Human checks sync status in UI |
| Item missing after sync | Unsupported item type, or `.platform` invalid | `docs_item-definitions` for the item type |
| Item duplicated after sync | Item renamed in repo, not in workspace | Human resolves in UI; do not delete |
| Promoted item points at DEV | Deployment rule missing for that value | Runbook 5 |
| Promoted item fails to run | Connection not present in target stage | Runbook 3 |
| `data` items fail after `dateng` succeeds | Shortcut or reference not rebound | Runbook 4 |

## Reporting

Report per workspace, in dependency order:

| Workspace | Items in repo | Items in workspace | Definitions checked | Verdict |
| --- | --- | --- | --- | --- |

Verdict is one of: `Synced`, `Partial — see findings`, `Not synced`, `Unverified (UI-only)`.
Never write `Deployed` when the only evidence is a human's recollection.
