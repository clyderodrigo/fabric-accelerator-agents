# Runbook 2 — Git connection setup and initialisation per workspace

| | |
| --- | --- |
| **Performed by** | Human, in the Fabric portal |
| **Agent role** | Guides the steps, verifies only the *result* |
| **Verifiable via official MCP** | **No, not directly.** Connection state, branch, folder and sync status are UI-only. The resulting items **are** verifiable. |
| **Order** | After capacity assignment, before connections |
| **Applies to** | `[DEV] DatEng`, `[DEV] Data`, `[DEV] Analytics` |

## Why this is a manual step

No Core MCP tool exposes Git integration. There is no tool to connect a workspace, choose a branch,
set a folder, read sync status, or trigger an update. The Fabric CLI skill
`git-integration-operations-cli` covers the lifecycle through the REST API, but it is not an MCP
server and this toolkit does not invoke it.

**Be explicit with the human:** the agent can confirm that items arrived. It cannot confirm that Git
is connected, which branch is bound, or whether the last sync succeeded.

## Model

One repository, one folder per workspace, three connections.

```
<repo root>
├── workspace/
│   ├── dateng/          → [DEV] DatEng
│   ├── data/            → [DEV] Data
│   └── analytics/       → [DEV] Analytics
```

If the repo currently has a single workspace root, moving to per-workspace folders is a
restructuring step. Do it in one commit, before connecting anything, so that all three connections
point at a stable layout.

## Prerequisites

- [ ] Workspaces exist and are assigned to a capacity
- [ ] Repo contains one folder per workspace, each with valid `.platform` files
- [ ] The signed-in identity can administer each workspace
- [ ] The identity can authorise the Git provider (Azure DevOps or GitHub) — this is a one-time
      consent per provider per user, and it is separate from Fabric permissions
- [ ] Branch protection on the target branch does not block Fabric's service identity
- [ ] `.gitignore` excludes local state, tokens and editor caches

## Steps — Azure DevOps

### 1. Connect `[DEV] DatEng`

1. Open the workspace → **Workspace settings** → **Git integration**.
2. Provider: **Azure DevOps**.
3. **Connect** and authorise. First time only: grant Fabric access to the Azure DevOps organisation.
4. Fill in:

| Field | Value |
| --- | --- |
| Organisation | |
| Project | |
| Repository | |
| Branch | `main` (or the declared branch) |
| Git folder | `/workspace/dateng` |

5. **Connect and sync**.

### 2. Connect `[DEV] Data`

Same, with Git folder `/workspace/data`.

### 3. Connect `[DEV] Analytics`

Same, with Git folder `/workspace/analytics`.

## Steps — GitHub

### 1. Connect `[DEV] DatEng`

1. Open the workspace → **Workspace settings** → **Git integration**.
2. Provider: **GitHub**.
3. **Connect** and authorise. First time only: install or authorise the Fabric GitHub app for the
   organisation, and grant access to the specific repository.
4. Fill in:

| Field | Value |
| --- | --- |
| GitHub account / organisation | |
| Repository | |
| Branch | `main` |
| Git folder | `/workspace/dateng` |

5. **Connect and sync**.

### 2. and 3.

Repeat for `/workspace/data` and `/workspace/analytics`.

## Initialisation decisions

When a folder already contains items in the repo, Fabric offers a choice on first sync:

| Situation | Choose | Why |
| --- | --- | --- |
| Repo folder has items, workspace is empty | **Sync from Git** (repo wins) | The repo is the source of truth in DEV |
| Workspace has items, repo folder is empty | **Commit to Git** (workspace wins) | Preserves existing work; review the commit afterwards |
| Both have items | Stop | Decide item by item. A blind sync deletes workspace items; a blind commit pollutes the repo. |

Never pick "workspace wins" for a folder that already has items from a previous environment. That is
how DEV-only content ends up in a branch that feeds production.

## Verification

### What the human must confirm

The agent cannot check any of this. Ask for each workspace and record the answer:

| Item | Value |
| --- | --- |
| Provider | Azure DevOps / GitHub |
| Organisation and project | |
| Repository | |
| Branch | |
| Git folder | |
| Sync outcome | Success / partial / failed |
| Items that failed to sync | |
| Last sync time | |

A "successful" sync that produced no items is a failed connection.

### What the agent can verify

```
list_items   workspaceId = <workspace id>
```

Compare item names and types against the repo folder. Then, for one representative item per type:

```
get_item      workspaceId, itemId
get_item_definition   workspaceId, itemId
```

Pass criteria:

1. Every in-scope item in the repo folder appears in the workspace with the same name and type.
2. No unexpected item appears that has no repo counterpart.
3. At least one definition per type is structurally plausible for that type — use
   `docs_item-definitions` from `fabric-local` to judge.

If `list_items` returns a continuation token, page through before concluding an item is missing.

## Failure modes

| Symptom | Cause | Fix |
| --- | --- | --- |
| Connection dialog rejects the repo | Fabric app not authorised for that repo, or identity lacks repo read | Re-authorise in the provider, then retry |
| Sync succeeds, zero items | Wrong Git folder, or branch has no items in that folder | Correct the folder path |
| Only some items sync | Unsupported item type, or an invalid `.platform` | `docs_item-definitions`; check the `.platform` shape |
| Item appears twice | Rename in repo without rename in workspace | Resolve in UI; do not delete the original |
| Sync fails on a notebook | Notebook format not accepted, or binary asset missing | Compare against a known-good notebook definition |
| Branch protection blocks sync | Service identity cannot push | Adjust branch policy, or use a dedicated integration branch |
| Workspace shows "conflicted" | Repo and workspace both changed the same item | Resolve per item in the Source control panel |

## Known limitations

- **No MCP verification of the connection itself.** Any claim that "Git is connected" must be
  attributed to the human.
- **Partial sync is silent in MCP terms.** `list_items` shows the gap but not the cause.
- **Disconnecting and reconnecting** can trigger a full sync that deletes workspace items absent from
  the repo. Treat it as a destructive operation and warn the human.

## Rollback

Disconnect Git integration in the same workspace settings screen. This does **not** delete items, but
a later reconnect may. Before disconnecting, capture `list_items` output so the pre-change state is
recorded.
