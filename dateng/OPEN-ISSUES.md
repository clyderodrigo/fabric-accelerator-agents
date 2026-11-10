# Open issues and flags - `dateng/`

Everything about this migration that is **not proven**, **needs a decision**, or **will fail in a
way that is not obvious**. Written for the person connecting this folder to a workspace.

`GUID-INVENTORY.md` records what was *done*. This file records what is *still open*.

Severity means: how likely is this to cost you a debugging session if you skip it.

| ID | Severity | Area | Flag | Action needed |
| --- | --- | --- | --- | --- |
| [F1](#f1--libraryid-set-to-the-logicalid-high) | **High** | Variable Library | `libraryId` was set to the Variable Library's logicalId, not a deployed item id | Confirm on first sync |
| [F2](#f2--libraryvariables-block-never-seen-by-fabric-high) | **High** | Pipelines | The `libraryVariables` block has never been accepted by a real tenant | Confirm on first sync |
| [F3](#f3--entra-functions-references-a-notebook-that-does-not-exist-high) | **High** | Notebooks | `%run /common/keyvault-functions` has no matching item | **Decide** |
| [F4](#f4--no-runtime-verification-medium) | Medium | All | Nothing was run; no tenant access on the migration machine | Run in DEV |
| [F5](#f5--level1-transform-lost-its-pinned-workspaceid--capacityid-medium) | Medium | Pipeline | Notebook activity no longer pins workspace/capacity | Confirm first TST run |
| [F6](#f6--envsettings-variable-library-read-is-untested-medium) | Medium | Notebook | `notebookutils.variableLibrary` call never executed | Confirm first DEV run |
| [F7](#f7--only-a-dev-value-set-ships-medium-by-design) | Medium | Variable Library | No `tst`/`prd` value sets exist yet | Create after provisioning |
| [F8](#f8--references-that-still-carry-dev-identifiers-medium) | Medium | Mixed | Refs with no Variable Library consumer slot still hold DEV values | Rule or accept |
| [F9](#f9--connection-bindings-are-not-wired-to-the-library-medium) | Medium | Connections | Four connection ids declared but not substituted | Deployment rule |
| [F10](#f10--%run-name-mismatches-low) | Low | Notebooks | `%run` targets differ from item names | Leave unless it fails |
| [F11](#f11--drift-check-will-report-items-out-of-scope-low-expected) | Low | Tooling | RTI items and VariableLibrary are outside release 1 scope | Expect it |
| [F12](#f12--declared-environmentyaml-has-blank-values-low) | Low | Config | Workspace name, capacity SKU/region, Git details unset | Fill in from portal |

---

## F1 — `libraryId` set to the logicalId (High)

**What.** Every `libraryVariables` entry in the five rewired pipelines carries:

```json
"libraryId": "bedb80f6-2c41-409c-8752-3fd2d2ef436b"
```

That is the Variable Library's `.platform` `config.logicalId`. It is **not** the deployed item id
Fabric will assign when the library is created in a workspace.

**Why this choice.** This repository already resolves cross-item references by logicalId: pipeline
`referenceName` fields and `KQLDatabase.parentEventhouseItemId` both do it. Following the existing
convention was the least surprising option.

**Why it might be wrong.** If Fabric expects the deployed item id in `libraryId`, the binding fails
and the pipelines will not resolve their variables. This is the single highest-risk assumption in
the migration.

**How to check.** After the first **Update from Git**, open one rewired pipeline (e.g.
`Master ELT ASQL`) in the Fabric UI and look at its variable-library binding. If it resolves, the
assumption holds. If it shows unresolved, replace `libraryId` with the deployed item id and record
it - but note that would reintroduce a per-environment value, which is the thing this migration
removed.

**Do not** "fix" this pre-emptively. Guessing the other way is equally likely to be wrong.

---

## F2 — `libraryVariables` block never seen by Fabric (High)

**What.** The `libraryVariables` block shape in each pipeline follows the documented contract
(`libraryName`, `libraryId`, `variableName`, `type`, sibling to `activities`), and expressions read
`@pipeline().libraryVariables.<name>`.

**Why it might be wrong.** The shape came from documentation, not from a round trip. This folder has
never been pushed to a workspace, so no Fabric instance has parsed it.

**How to check.** The first sync either loads the pipelines or rejects them. If rejected, the error
names the offending property. Fall back to wiring the value at the activity level instead of the
pipeline level.

**Blast radius if wrong.** All 5 rewired pipelines. The other 5 pipelines and all non-pipeline items
are unaffected.

---

## F3 — `entra-functions` references a notebook that does not exist (High)

**What.** `entra-functions.Notebook/notebook-content.py` line 23:

```
%run /common/keyvault-functions {"kvLinkedService": "keyvault01"}
```

There is **no** `keyvault-functions` notebook in the 30 migrated items, and that line is the only
occurrence of the name anywhere in the source repository. It was never committed.

**Why it matters.** If that cell runs, it fails. Nothing in the migration created this - it is
pre-existing and was carried over verbatim.

**Decision required.** One of:

1. The notebook exists in the tenant but was never committed → the source repo is incomplete, and
   `dateng/` is missing an item. Add it and re-run the GUID scan.
2. It is dead code from a Synapse-era structure (`/common/` is a Synapse folder path) → remove or
   comment the cell.

Do not leave it undecided. It is the only flag here that is a plain defect rather than an
unverified assumption.

---

## F4 — No runtime verification (Medium)

**What.** The migration machine has no Azure CLI and no Fabric tenant access. Everything verified
was verified locally: JSON parses, references resolve to declarations, no environment literals
remain, logicalIds preserved.

**What that does not prove.** That any of it works. A definition with no DEV identifier in it is not
evidence that the reference resolves - that requires running the item.

**How to check.** Provision DEV first, sync, then run in this order:
`Master Level1 Transform` → `Master Level2 Transform` → `Master ELT ASQL` → `Master ELT MirrorDB` →
`wwi-elt-framework`. Confirm row counts against the source, not just green status.

---

## F5 — `Level1 Transform` lost its pinned `workspaceId` / `capacityId` (Medium)

**What.** The `TridentNotebook` activity had hardcoded `"workspaceId"` and `"capacityId"` string
properties. Both were removed, so the activity now inherits the pipeline's workspace and capacity.

**Why.** Those fields are plain strings, not expression slots - a `libraryVariables` value cannot go
into them. Omitting them is the portable form, and it resolves to the same target this accelerator
used (single workspace, single capacity).

**Residual risk.** The target is now implicit. If the notebook was deliberately pinned to a
different capacity, that intent is gone. Confirm on the first TST run that the notebook lands on the
expected capacity.

---

## F6 — `EnvSettings` Variable Library read is untested (Medium)

**What.** The three hardcoded workspace ids were replaced with:

```python
config = notebookutils.variableLibrary.getLibrary("accelerator-config")
bronzeWorkspaceId = config.bronze_workspace_id
```

**Why it might fail.** `notebookutils.variableLibrary` only reads libraries in the **same
workspace**, and only reads the **active value set**. Both conditions have to hold.

**How to check.** Run `EnvSettings` in DEV and confirm the three ids match `variables.json`
defaults. Then switch the active value set and confirm they change.

**Also.** Every downstream notebook that `%run`s `EnvSettings` now depends on the library being
present. A missing library breaks them at import time, not at the line that reads it.

---

## F7 — Only a `dev` value set ships (Medium, by design)

**What.** `valueSets/` contains `dev.json` only, and it overrides nothing - it inherits every
default from `variables.json`.

**Why.** An empty `tst` value set would inherit every DEV default and the environment would
silently read DEV data. That is the exact failure runbook 4 warns about: it does not error, it
returns wrong data. Shipping nothing is safer than shipping an inheriting set.

**Action.** Create `tst` and `prd` after the target workspace exists - the item ids they need do not
exist until then. `GUID-INVENTORY.md` section 10 has the procedure and a complete override payload.

**Do not** partially override. If you override `bronze_workspace_id` but not
`bronze_lakehouse_id`, you get a workspace from TST and a lakehouse from DEV.

---

## F8 — References that still carry DEV identifiers (Medium)

These are environment-scoped but have **no documented Variable Library consumer slot**, so they
could not be parameterised by editing the item definition. Full detail in `GUID-INVENTORY.md`
section 5.

| Reference | Where | Count |
| --- | --- | --- |
| `workspaceId` | `es_fabricEvents.Eventstream` | 8 |
| `itemId` | `es_fabricEvents.Eventstream` | 10 |
| `tenantId` | `es_fabricEvents.Eventstream` | 3 |
| `default_lakehouse`, `default_lakehouse_workspace_id` | 3 notebooks (META block) | 6 |
| `databaseArtifactId` | `fabricEventsDashboard.KQLDashboard` | 1 |
| `clusterUri` | `kdb_fabricEvents.KQLDatabase` | 2 |
| `workspaceName="FabricMDP"` | `UnitTest_DeltaLakeFunctions` | 3 |
| workspace id argument | `UnitTest_DeltaLakeFunctions` | 6 |

**What to do.** For each, either a deployment pipeline rule, or accept and document it. The
notebook META ones may be rewritten by Fabric on deploy - verify rather than assume. The two test
notebook references deliberately target a different workspace and are arguably correct as-is.

**What is already fine.** `parentEventhouseItemId` and pipeline `referenceName` hold **logicalIds**,
which are portable. They are not on this list and must not be touched.

---

## F9 — Connection bindings are not wired to the library (Medium)

**What.** Four connection ids are declared in `variables.json` (`control_db_connection_id`,
`source_sql_connection_id`, `mirror_source_connection_id`, `mirror_ingest_connection_id`), but the
pipelines still bind connections through plain `"connection": "<guid>"` strings.

**Why.** That field is not an expression slot, so a Variable Library value cannot be substituted
into it.

**Action.** Per-stage substitution has to come from a deployment pipeline rule, or from a
connection created per stage (runbook 3). The declared variables make the values reviewable but do
not by themselves change behaviour - do not mistake one for the other.

`WideWorldImporters-mirror.MirroredDatabase/mirroring.json` has the same limitation.

---

## F10 — `%run` name mismatches (Low)

| `%run` target | Actual item name | Difference |
| --- | --- | --- |
| `/commonTransforms` | `CommonTransforms` | Case, plus a `common/` path segment that does not exist |
| `/DeltaLakeFunctions` | `DeltaLakeFunctions ` | Trailing space in the displayName |

Both look like Synapse folder-path leftovers. Fabric may match case-insensitively and ignore the
path, in which case this is cosmetic. Unverified.

**Action.** Leave alone unless a notebook fails to import. If it does, fix the `%run` target rather
than renaming the item - renaming an item changes its identity.

---

## F11 — `drift-check` will report items out of scope (Low, expected)

**What.** `dateng/` contains `Eventhouse`, `KQLDatabase`, `KQLQueryset`, `KQLDashboard`,
`Eventstream` and `VariableLibrary`. Release 1's declared item set is `Lakehouse`, `Warehouse`,
`Notebook`, `DataPipeline`, `MirroredDatabase`, `SQLDatabase`.

**Consequence.** `drift-check` reports the RTI items and the Variable Library as *out of scope*.

**Action.** None. That is the tool behaving correctly. It is a signal to widen the scope list in
`AGENTS.md` if RTI becomes a supported target, not a defect in this folder.

---

## F12 — `declared-environment.yaml` has blank values (Low)

**What.** Workspace display name, capacity displayName/SKU/region, and all Git details are empty
rather than guessed.

**Action.** Fill them in from the portal. `capacity.id` is populated from an observed `capacityId`
in the source pipeline, not from the portal - confirm it.

`verify-environment` will report the blanks as missing assertions until they are filled. That is
intended: a blank is honest, an invented GUID is not.

---

## Not a flag - things that look wrong but are fine

| Looks like | Reality |
| --- | --- |
| 6 of 8 notebooks fail `ast.parse` | They use `%run` magics, which are not Python. Expected for Fabric notebook exports. Identical in the source. `ast.parse` is the wrong tool. |
| `00000000-0000-0000-0000-000000000000` in the dashboard | Means "the workspace this item lives in". Correct and portable. |
| ~84 GUIDs still present in dashboard, eventstream and queryset definitions | Widget, page, query, node and tab ids. Internal to the item, must stay stable. Not environment-scoped. |
| Two items both named `eh_fabricAccelerator` | One is an Eventhouse, one is a KQLDatabase. Separate items, separate logicalIds. |
| `xmla.json` contains `{{TDS_Endpoint}}` / `{{Dataset_Name}}` | Fabric template tokens, filled at deploy time. Pre-existing and correct. |
| The source repo already used logicalId for some references | Not an inconsistency to "fix" - it is why the migration was tractable. Do not convert them to deployed ids. |
