# Runbook 4 — Cross-workspace ID rebinding

| | |
| --- | --- |
| **Performed by** | Human decides and edits; agent detects and verifies |
| **Agent role** | Find references, classify them, verify what landed |
| **Verifiable via official MCP** | **Partially.** `get_item_definition` shows what is deployed. It cannot prove a reference resolves at runtime. |
| **Order** | After Git connection and connections, before deployment pipeline rules |
| **Applies to** | All three workspaces, and every promotion DEV → TST → PRD |

This is the runbook that decides whether a promotion works. Everything else can be correct and a
deployment will still fail here.

## Why this breaks

Fabric items frequently store **absolute identifiers**: workspace GUIDs, item GUIDs, connection IDs,
capacity IDs, storage paths, and item names. A deployment pipeline copies an item's definition into
the next stage. It does not rewrite those identifiers.

Three distinct failure shapes follow:

| Shape | Example | Result in TST |
| --- | --- | --- |
| **Absolute ID** | Pipeline activity points at workspace `a1b2…` / lakehouse `c3d4…` | Reads DEV data from TST |
| **Environment-specific name** | Notebook resolves `lh_bronze_dev` | Item not found |
| **Cross-workspace reference** | `data` item reads a `dateng` lakehouse | Works only if the same reference exists in TST |

The first is the dangerous one: it does not fail, it silently reads the wrong environment.

## Prerequisites

- [ ] Git connection established; items are present in DEV
- [ ] Connections created (runbook 3) — a rebinding decision is different from a missing connection
- [ ] The declared config lists which references are cross-workspace
- [ ] You know the TST and PRD workspace names, because those names affect the decision

## Step 1 — Detect (agent)

The agent does the detection. This is read-only and it is where an agent is genuinely faster than a
person.

### 1a. Scan the repo for absolute identifiers

Search the repo for GUIDs:

```
[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}
```

For each hit, record: file, line, the GUID, and what it appears to identify (workspace, item,
connection, capacity). A GUID in a `.platform` `logicalId` is expected and is **not** a rebinding
problem — it is the item's stable identity. A GUID inside a pipeline activity, notebook cell, mirroring
configuration, or dataflow query **is** a problem.

Classify every hit:

| Where the GUID sits | Rebinding problem? |
| --- | --- |
| `.platform` → `config.logicalId` | No — this is the item identity and must stay stable |
| `.platform` → `metadata` | No |
| Pipeline activity `typeProperties` | **Yes** |
| Notebook cell source | **Yes** |
| Mirrored database `mirroring.json` | **Yes** |
| Dataflow query / destination | **Yes** |
| Semantic model partition expression | **Yes** |
| Eventstream / KQL definition | **Yes** |

### 1b. Scan for environment-specific names

Search for the DEV workspace and item names that would not exist in TST:

```
\[DEV\]
_bronze_dev
_dw_dev
```

Any hit outside a documentation file is a candidate.

### 1c. Compare against the deployed definitions

```
list_items            per workspace
get_item_definition   for each item the scan flagged
```

Cross-check: a GUID in the repo should appear in the deployed definition, and vice versa. A GUID in
the tenant but not in the repo means someone edited it in the UI — that change will be lost or will
conflict on the next sync.

### 1d. Produce the reference table

| # | Item | Workspace | Reference | Kind | Target | Should point at |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `pl_ingest_bronze` | dateng | `a1b2…` | workspace ID | DEV DatEng | Same-stage DatEng |
| 2 | `pl_load_silver` | data | `c3d4…` | lakehouse ID | `lh_bronze` in DatEng | Same-stage `lh_bronze` |
| 3 | `nb_transform` | data | `lh_silver_dev` | item name | DEV lakehouse | Same-stage lakehouse |

## Step 2 — Decide (human)

For each reference, one of three decisions. Do not let the agent choose; it does not own the
environment design.

### Option A — Deployment rule (preferred)

Fabric deployment pipelines can override specific item properties per stage. If the reference is a
property a rule supports, a rule is the correct fix: no code change, no branch divergence, and the
override is visible in the pipeline configuration.

Use a rule when the value is a **supported, item-level property** and differs per stage.

### Option B — Parameterise (preferred when a rule is not available)

Replace the hard-coded value with something resolved at runtime:

| Mechanism | Use for |
| --- | --- |
| Fabric Variable Library | Environment-scoped values consumed by pipelines, notebooks, dataflows |
| Workspace-relative item reference | A pipeline activity that binds to an item in the same workspace |
| Dynamic resolution by name | Notebook code that resolves an item at run time instead of embedding an ID |

Parameterisation is more work up front and the only approach that survives a workspace being
recreated. Prefer it for anything long-lived.

### Option C — Accept and document

Sometimes a reference genuinely should point at the same target in every stage — a shared reference
lakehouse, for example. Record it explicitly in the declared config as `shared: true` so the next
person does not "fix" it.

### Decision table

| Reference kind | Recommended |
| --- | --- |
| Connection ID | Deployment rule if supported; otherwise separate connection per stage (runbook 3) |
| Workspace ID | Parameterise, or resolve dynamically |
| Item ID (lakehouse, warehouse) | Workspace-relative reference, or parameterise |
| Item name with environment suffix | Parameterise via Variable Library |
| Capacity ID | Rule, or accept and document |
| Storage path | Rule per stage |
| `.platform` `logicalId` | **Leave alone** — changing it creates a new item |

## Step 3 — Apply (human)

1. Edit the repo. Prefer parameterisation over per-stage edits; per-stage edits reintroduce the
   problem on the next environment.
2. Commit and push.
3. Update from Git in the affected workspace.
4. Verify with step 4.

Order matters: `dateng` first, then `data`, then `analytics`. A `data` fix that depends on a `dateng`
reference cannot be verified before `dateng` is correct.

## Step 4 — Verify

### Agent, read-only

```
get_item_definition   workspaceId, itemId
```

Re-run the GUID scan against the returned definitions, not against the repo. Confirm:

1. No DEV workspace GUID remains in a runtime position.
2. No environment-suffixed item name remains.
3. Cross-workspace references point at the intended workspace.

### What this does not prove

State it every time:

> A definition that no longer contains a DEV identifier is not proof that the reference resolves. That
> requires running the item in the target stage.

### Human, runtime

After promotion to TST:

| Check | Who |
| --- | --- |
| Run the pipeline | Human |
| Confirm the row count or output matches the TST source | Human |
| Refresh the semantic model and open the report | Human |
| Confirm no item reports "workspace not found" / "item not found" | Human |

## Failure modes

| Symptom | Cause |
| --- | --- |
| TST report shows DEV numbers | Workspace or item GUID still points at DEV |
| Item not found after promotion | Environment-suffixed name, or an item excluded from the deployment |
| Works in DEV, 403 in TST | Connection or credential not present in TST |
| Promotion succeeds, nothing runs | Item promoted but no rule applied and no parameter set |
| Next sync overwrites the fix | Fix applied in the UI, not in the repo |

## Known limitations

- **Runtime binding is unverifiable read-only.** This is the fundamental gap in runbook 4.
- **Deployment rules cover a finite set of properties.** If a property has no rule, parameterisation
  is the only option.
- **A GUID scan has false positives.** Item `logicalId` values are GUIDs and must not be touched.
  Always classify before editing.
- **No MCP tool lists deployment rules**, so the agent cannot confirm a rule exists — only that the
  deployed definition still contains, or no longer contains, a value.

## Rollback

Revert the commit and update from Git. If a promotion already happened, redeploy from the previous
known-good stage rather than editing the target workspace by hand — a hand edit will be overwritten
by the next deployment and will not be reproducible.
