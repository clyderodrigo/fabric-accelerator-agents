---
name: drift-check
description: Read-only comparison of a repo's declared environment configuration against live tenant state via official MCP tools, classifying every difference as missing, extra, mismatched, or unverifiable. Use when someone asks about drift, asks whether the tenant matches the repo, wants a compliance or posture check, or asks what changed outside Git.
---

# Drift check

Answers one question: **where does the tenant differ from what the repo declares, and which parts
can I not answer at all?**

Read-only. Never remediate during a drift check.

## Two sources, deliberately

| Source | What it provides |
| --- | --- |
| `fabric/declared-environment.yaml` | Platform state: capacity, roles, Git mapping, connections, pipeline stages |
| The repo tree (`.platform` files) | Item inventory, per workspace folder |

Item inventory is **not** duplicated in the YAML. It is read from the repo, because a hand-maintained
item list drifts from the actual `.platform` files within a week. If the two disagree, that is itself
a finding.

## Procedure

### 1. Load and normalise

Read the declared config. Resolve:

- workspace key → display name → live workspace `id` (via `list_workspaces`)
- capacity display name → capacity `id` (via `list_capacities`, paging on `continuationToken`)
- repo folder → workspace key

If a workspace name in the config has no live match, record `MISSING_WORKSPACE` and continue. Do not
abort the whole check on one missing workspace — the remaining findings are still useful.

### 2. Collect tenant state

Per workspace:

```
get_workspace         → capacityId, displayName, domainId
list_workspace_roles  → principal + role
list_items            → item name + type
list_folders          → folder names, if the config declares folders
```

Collect `list_capacities` once, paged.

### 3. Collect repo state

For each workspace folder, walk item folders and read each `.platform`:

- `metadata.type` → item type
- `metadata.displayName` → item name
- folder name → the Git path

Ignore non-item directories. Ignore `ipynb/` duplicates if the repo carries both; state which path
you treated as authoritative.

### 4. Compare and classify

Every difference gets exactly one class:

| Class | Meaning |
| --- | --- |
| `MISSING_IN_TENANT` | Declared in repo, absent from workspace |
| `EXTRA_IN_TENANT` | Present in workspace, absent from repo |
| `MISMATCH` | Present in both, different value (capacity, role, type, name) |
| `UNVERIFIABLE` | Cannot be checked with an official MCP tool |

`EXTRA_IN_TENANT` is not automatically a defect — it may be an item awaiting removal, or one created
outside the repo. Report it as drift and let the human classify it. Never delete it.

### 5. The unverifiable block

Always present. These are the states with no MCP coverage:

| Declared state | Class | Note |
| --- | --- | --- |
| Git provider, repository, branch, folder | `UNVERIFIABLE` | UI-only |
| Git sync status / last commit | `UNVERIFIABLE` | UI-only |
| Connections (existence, type, binding) | `UNVERIFIABLE` | Not workspace items |
| Deployment pipeline stages and workspace assignment | `UNVERIFIABLE` | No MCP tool |
| Deployment rules | `UNVERIFIABLE` | No MCP tool |
| Item-level binding after promotion | `UNVERIFIABLE` | Runtime behaviour |

Do not mark these `OK` because nothing contradicted them. Silence is not evidence.

### 6. Definition-level drift

For items where the definition matters — pipelines with cross-workspace references, mirrored
databases, SQL databases — compare:

```
get_item_definition   workspaceId, itemId
```

against the committed `.platform` and content files. Report semantic differences only:

- A GUID that appears in the tenant definition and not in the repo.
- A workspace or lakehouse name in the tenant definition that differs from the declared config.
- A connection reference present in the tenant and absent from the repo.

Base64 payload differences alone are not drift. Whitespace and property ordering are not drift.

## Output format

```
DRIFT REPORT
Environment: <tenant> / <capacity>
Compared: fabric/declared-environment.yaml + repo tree
Checked at: <timestamp>

SUMMARY
  workspaces:  3 declared, 3 found
  items:       31 declared, 29 found, 2 extra
  capacity:    3 of 3 assigned correctly
  roles:       1 mismatch

FINDINGS
  [MISSING_IN_TENANT]  dateng / Lakehouse / lh_silver
  [EXTRA_IN_TENANT]    data / Notebook / nb_scratch_adhoc
  [MISMATCH]           analytics / capacityId  expected <cap-a>  actual <cap-b>
  [MISMATCH]           data / role  group:bi@contoso.com  declared Viewer  actual Contributor

UNVERIFIABLE
  Git connection state
  Connections and bindings
  Deployment pipeline configuration
  Item runtime bindings

RECOMMENDED NEXT ACTION
  <one item, chosen because it blocks a deployment or is a security difference>
```

Order findings by severity: `MISMATCH` on roles or capacity first, then `MISSING_IN_TENANT`, then
`EXTRA_IN_TENANT`, then definition-level notes. A role mismatch is a security finding and outranks a
missing notebook.

## Rules

- One class per finding. No "probably fine".
- Never remediate. No creates, no deletes, no role changes, no definition updates.
- Never infer Git state from the presence of items. A workspace can have items with Git disconnected.
- If `list_capacities` or `list_items` returns a continuation token, page through before declaring
  something missing.
- If the declared config and the repo tree disagree on items, report both and say which you treated
  as authoritative.
- Finish with exactly one recommended next action, not a list of ten.
