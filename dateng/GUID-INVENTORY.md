# GUID inventory - `dateng/`

Every GUID in the 30 migrated items, classified, with what was done about it.

This is the runbook 4 artefact (`fabric/runbooks/04-id-rebinding.md`, step 1d) for this
repository. It records the classification so the next person does not re-derive it, and so a
reviewer can see that no environment identifier was silently deleted.

**Source of truth for this file:** a scan of `C:\Dev\fabric-accelerator\workspace` taken before
migration. 382 hits, 133 unique GUIDs. Re-run the scan after any change to confirm the numbers
still hold.

---

## 1. Summary

| # | Class | Unique GUIDs | What it is | Action |
| --- | --- | --- | --- | --- |
| 1 | Item identity | 30 | `.platform` `config.logicalId` | **Kept verbatim.** Never regenerate. |
| 2 | Environment scope | 8 | Workspace, capacity, tenant, layer item ids | **Parameterised** into the Variable Library |
| 3 | Item reference | 5 | Deployed item ids referenced from another item | **Left for rebind** - see section 5 |
| 4 | Connection | 4 | Fabric connection ids | **Declared** in the Variable Library, not wired - see section 6 |
| 5 | Internal identity | 84 | Dashboard widgets/pages/queries, Eventstream nodes, query tabs | **Kept.** Not environment-scoped. |
| 6 | Nil | 1 | `00000000-0000-0000-0000-000000000000` | **Kept.** Means "current workspace". |
| 7 | Comment only | 1 | A `.show operations(...)` id inside a KQL comment | **Kept.** Not executable configuration. |
| | **Total** | **133** | | |

After migration the folder holds 31 items: the 30 migrated items plus the new
`accelerator-config` Variable Library.

---

## 2. Item identity - 30 GUIDs, kept verbatim

These are the `.platform` `config.logicalId` values. Fabric uses them to match an item folder to
an item in a workspace. **Regenerating one makes Fabric treat the item as a new item**, producing
a duplicate and orphaning the original.

| Item | Type | logicalId |
| --- | --- | --- |
| `accelerator-config` | VariableLibrary | `bedb80f6-2c41-409c-8752-3fd2d2ef436b` |
| `CommonTransforms` | Notebook | `eb5dc1f8-354f-483d-a8d8-c6d0970b6925` |
| `controlDB` | SQLDatabase | `2aaee3b7-af3f-b51e-4fb0-70ea78d6902e` |
| `DeltaLakeFunctions` | Notebook | `4a445806-41bc-4b28-905c-600b2636fd18` |
| `dw_gold` | Warehouse | `78ea7881-8640-498f-afa2-e8c3da3dd653` |
| `eh_fabricAccelerator` | Eventhouse | `1b5f823d-da00-bbfb-4997-393c7bd80584` |
| `eh_fabricAccelerator` | KQLDatabase | `e3258eb8-0f5b-87e3-4a96-351472a1085d` |
| `eh_fabricAccelerator_queryset` | KQLQueryset | `df77615f-4496-ab3a-49b9-d16f6e5a1ba4` |
| `entra-functions` | Notebook | `1f958145-34e3-4cb8-971c-85006e72506e` |
| `EnvSettings` | Notebook | `eaa157da-233f-b49f-49f6-2133749cdd76` |
| `es_fabricEvents` | Eventstream | `0de27062-50c0-9252-4b03-1f47402cdae4` |
| `fabricEvents_queryset` | KQLQueryset | `4bcc6306-82e1-8e62-4ed4-6097397bbd80` |
| `fabricEventsDashboard` | KQLDashboard | `4188c196-f9b6-bb7f-417e-2b060dca28ab` |
| `Ingest ASQL Table` | DataPipeline | `7ea78b86-8d5e-4e2e-adc8-1138c278f6ab` |
| `Ingest MirrorDB Table` | DataPipeline | `8ce93ec6-1295-b4f7-48b3-f8d92900eb46` |
| `Ingest OneLake Lakehouse Table` | DataPipeline | `b55ad926-9c8d-9479-47c8-379359eac7b4` |
| `kdb_fabricEvents` | KQLDatabase | `b22b1edd-6292-97ea-4089-fe9314ea1177` |
| `L1Transform-Generic-Fabric` | Notebook | `e3432c41-c712-4d7b-8868-a94bcc540915` |
| `Level1 Transform` | DataPipeline | `b25d5ad7-288a-4426-83f3-170aff284708` |
| `Level2 Transform` | DataPipeline | `5a473c1e-fd95-4b0a-a4a0-33537c65a0d7` |
| `lh_bronze` | Lakehouse | `1355e38b-d635-45a7-9d21-8f02933bc81f` |
| `lh_silver` | Lakehouse | `eafa06a2-044f-4009-8ecf-8bf4f0b5d725` |
| `Master ELT ASQL` | DataPipeline | `938c7b42-4d41-48f2-a568-46c6e47efb47` |
| `Master ELT MirrorDB` | DataPipeline | `49dcca2d-a370-9e6e-4ac8-12b9f6fbd55e` |
| `Master Level1 Transform` | DataPipeline | `592635be-9979-40a3-8a91-0305b696cea2` |
| `Master Level2 Transform` | DataPipeline | `29ca711a-e20f-457c-a619-35b0310193ad` |
| `Optimize Delta Lake Tables` | Notebook | `0f67c976-8c4d-4122-8f11-c478d6545d65` |
| `Unit Test CommonTransforms` | Notebook | `75e2204d-eab9-45e9-9f00-842b0c325c1b` |
| `UnitTest_DeltaLakeFunctions` | Notebook | `c6a760eb-bf67-89c1-4bc4-5031d9f73416` |
| `WideWorldImporters-mirror` | MirroredDatabase | `815cb9a6-5c36-80dd-4089-e21470663ea8` |
| `wwi-elt-framework` | DataPipeline | `be7ff152-6e10-453e-be6d-7aeed4ed4b26` |

Note that `eh_fabricAccelerator` appears twice - once as an Eventhouse and once as a KQLDatabase.
They are separate items and hold separate logical ids.

### A warning about logicalId vs deployed item id

The logicalId is **not** the same value as the item id you see in the portal or in a REST
response. Both were found in the source repo:

| Item | logicalId (in `.platform`) | Deployed id (used in item definitions) |
| --- | --- | --- |
| `controlDB` | `2aaee3b7-af3f-b51e-4fb0-70ea78d6902e` | `78d6902e-70ea-4fb0-b51e-af3f2aaee3b7` |
| `lh_silver` | `eafa06a2-044f-4009-8ecf-8bf4f0b5d725` | `cc80a0ab-603d-4df9-bdfc-c35a7e8ab095` |
| `L1Transform-Generic-Fabric` | `e3432c41-c712-4d7b-8868-a94bcc540915` | `3e035f81-2c25-416b-9009-b7ba22e444ab` |

A naive byte-reversal or rotation does not map one to the other - this was tested against five
item pairs and no transform held. Treat them as two independent identifiers and classify by
**where the GUID sits**, never by assuming one derives from the other.

---

## 3. Environment scope - 8 GUIDs, parameterised

These are the values that differ between DEV, TST and PRD. They now live in the
`accelerator-config` Variable Library (`variables.json`), and the pipelines read them through
`libraryVariables` instead of carrying literals.

| GUID | What it is | Variable Library variable |
| --- | --- | --- |
| `8d8d00a7-0e8a-4e3b-8c0e-8dcafac7adec` | Workspace hosting all layers | `bronze_workspace_id`, `silver_workspace_id`, `gold_workspace_id` |
| `c6c5024f-de55-45ca-a79a-decbe16235e3` | Bronze lakehouse item id | `bronze_lakehouse_id` |
| `cc80a0ab-603d-4df9-bdfc-c35a7e8ab095` | Silver lakehouse item id | `silver_lakehouse_id` |
| `7e2bbf6b-43fb-498c-90e3-56199c8c3b5e` | Gold warehouse item id | `gold_warehouse_id` |
| `3e035f81-2c25-416b-9009-b7ba22e444ab` | L1 notebook item id (compute reference) | `l1_notebook_id` |
| `e4eb626a-4082-4143-983d-6fc9284b74cd` | Capacity id | `capacity_id` |
| `4e921ed2-9b1c-457c-a917-16ef468eb90a` | Tenant id | *not parameterised* - see section 5 |
| `582b9e24-0962-4fd0-aee5-647d9c200685` | Workspace id passed to `readLHTable` in a unit-test notebook | *not parameterised* - see section 5 |

The three workspace variables carry the same value because this accelerator deploys every layer
into one workspace. They are kept separate so that splitting the layers into separate workspaces
later is a value-set edit rather than a code change.

### Non-GUID environment literals

The scan for GUIDs misses values that are environment-specific without being GUIDs. These were
found and handled the same way:

| Literal | Where | Variable Library variable |
| --- | --- | --- |
| `2ipjetq4tn6elkixc3xundvzbi-u4ai3dmkby5u5daorxfpvr5n5q.datawarehouse.fabric.microsoft.com` | `GoldDWEndpoint` parameter default in four pipelines | `gold_sql_endpoint` |

The KQL cluster host `trd-q1p0ndrk3rrqy8fsdn.z0.kusto.fabric.microsoft.com` in
`kdb_fabricEvents.KQLDatabase/EmbeddedRealTimeQueryset.json` is **not** parameterised - see
section 5.

---

## 4. What was actually edited

Nine pipeline definitions and one notebook. Nothing else was modified.

| Item | Change |
| --- | --- |
| `Master ELT ASQL` | Added `libraryVariables` (7). Replaced 7 `@pipeline().parameters.*` reads with `@pipeline().libraryVariables.*`. Removed 7 hardcoded parameter defaults. |
| `Master ELT MirrorDB` | Same as above, 7 variables. |
| `Master Level1 Transform` | Added `libraryVariables` (2). Replaced 2 reads. Removed 2 defaults. |
| `Master Level2 Transform` | Added `libraryVariables` (3). Replaced 3 reads. Removed 3 defaults. |
| `wwi-elt-framework` | Replaced pipeline variable `NotebookID_L1Transform-Generic-Fabric` with `libraryVariables.l1_notebook_id`. Removed the variable declaration and its hardcoded default. |
| `Ingest ASQL Table` | Removed 2 hardcoded parameter defaults. Parameters kept - the orchestrator supplies them. |
| `Ingest MirrorDB Table` | Removed 2 hardcoded parameter defaults. |
| `Level1 Transform` | Removed 3 hardcoded parameter defaults. Removed the notebook activity's hardcoded `workspaceId` and `capacityId` so the activity inherits the pipeline's workspace and capacity. |
| `Level2 Transform` | Removed 3 hardcoded parameter defaults. |
| `EnvSettings` | Replaced three hardcoded workspace ids with `notebookutils.variableLibrary.getLibrary("accelerator-config")`. |

`Ingest OneLake Lakehouse Table` had no environment literals and was not edited.

### Why the parameter declarations were kept on the child pipelines

`Ingest ASQL Table`, `Ingest MirrorDB Table`, `Level1 Transform` and `Level2 Transform` are
invoked by the orchestrators, which pass values explicitly. Removing a parameter would make the
parent's pass-through fail with an unknown-parameter error, so the declaration stays and only the
DEV default is removed. The effect is that a child pipeline no longer carries a usable
environment value of its own - it must be given one.

### Why `workspaceId` and `capacityId` were removed rather than parameterised

Those two fields in a `TridentNotebook` activity are plain string properties, not expression
slots, so a `@pipeline().libraryVariables.*` value cannot be placed in them. Omitting them makes
the activity use the pipeline's own workspace and capacity, which is the portable form and the
same target this accelerator used. This is a behaviour change in the sense that it is now implicit
rather than pinned - confirm on the first TST run.

---

## 5. Left for rebind - 5 GUIDs and 3 literals

These are environment-scoped but have **no documented Variable Library consumer slot**. They
cannot be parameterised by editing the item definition. Handle them with a deployment pipeline
rule, or accept and document them.

| Reference | Where | Why it cannot be parameterised |
| --- | --- | --- |
| `workspaceId` (8 occurrences) | `es_fabricEvents.Eventstream/eventstream.json` | Eventstream is not a documented Variable Library consumer. |
| `itemId` (10 occurrences: `3e035f81…`, `02b37a75…`, `7e2bbf6b…`, `f6fbd55e…`, `c6c5024f…`, `dcbe357b…`, `cc80a0ab…`) | `es_fabricEvents.Eventstream/eventstream.json` | Same. These are the source items the stream watches. |
| `tenantId` (3 occurrences: `4e921ed2…`) | `es_fabricEvents.Eventstream/eventstream.json` | Same. The tenant is normally constant across stages, so accept and document. |
| `default_lakehouse` (`cc80a0ab…`, 3 notebooks) | `L1Transform-Generic-Fabric`, `Optimize Delta Lake Tables`, `UnitTest_DeltaLakeFunctions` notebook META | Notebook attachment metadata, not runtime code. Fabric normally rewrites it on deploy; verify in TST. |
| `default_lakehouse_workspace_id` (`8d8d00a7…`, 3 notebooks) | Same three notebooks | Same. |
| `databaseArtifactId` (`14ea1177-fe93-4089-97ea-6292b22b1edd`) | `fabricEventsDashboard.KQLDashboard/RealTimeDashboard.json` | KQLDashboard is not a documented Variable Library consumer. |
| `clusterUri` (`trd-q1p0ndrk3rrqy8fsdn.z0.kusto.fabric.microsoft.com`) | `kdb_fabricEvents.KQLDatabase/EmbeddedRealTimeQueryset.json` | KQLDatabase definition, no VL slot. Note the sibling querysets already carry an empty `clusterUri`, which is the portable form. |
| `workspaceName="FabricMDP"` (3 occurrences) | `UnitTest_DeltaLakeFunctions.Notebook/notebook-content.py` | A hardcoded workspace *name* in test code. The test targets a different workspace by design; leave it or skip the test in TST. |
| `582b9e24-0962-4fd0-aee5-647d9c200685` (6 occurrences) | `UnitTest_DeltaLakeFunctions.Notebook/notebook-content.py` | A workspace id argument to `readLHTable` in test code. Same reasoning. |

Note what is **not** in this list: `parentEventhouseItemId` in both
`KQLDatabase/DatabaseProperties.json` files already holds the Eventhouse **logicalId**
(`1b5f823d…`), and pipeline `referenceName` fields already hold pipeline **logicalIds**. Those are
already portable and were left alone. That is why the source repo is better than it first looked:
its author used logicalId for some references and deployed ids for others.

---

## 6. Connections - 4 GUIDs, declared but not wired

| GUID | Connection | Variable Library variable |
| --- | --- | --- |
| `78e8d795-a55c-412e-9b76-47ba404b4d51` | controlDB SQL database (34 occurrences across 9 pipelines) | `control_db_connection_id` |
| `e7e44202-0cc1-4947-8192-a97761f62679` | WideWorldImporters source SQL | `source_sql_connection_id` |
| `69dfd2df-8257-4218-8002-a4222dc3d1a6` | Ingest MirrorDB Table | `mirror_ingest_connection_id` |
| `a0a57e51-5032-4e46-b0f0-493c9d2f51c9` | MirroredDatabase source (AzureSqlDatabase) | `mirror_source_connection_id` |

A pipeline activity binds a connection through a plain `"connection": "<guid>"` string. That is
not an expression slot, so a Variable Library value cannot be substituted into it. The four values
are declared in the library anyway so they are visible in one place and reviewable in a pull
request, but the actual per-stage substitution has to come from a deployment pipeline rule or from
a connection created per stage (runbook 3).

`mirroring.json` holds the same shape (`"connection": "a0a57e51…"`) and has the same limitation.

---

## 7. Internal identity - 84 GUIDs, kept

| Where | Count | Examples |
| --- | --- | --- |
| `fabricEventsDashboard.KQLDashboard/RealTimeDashboard.json` - page, widget, query, parameter and data source ids | ~60 | `731f692f…` (page "Workspace"), `2505cb77…` (data source, referenced by every query) |
| `es_fabricEvents.Eventstream/eventstream.json` - node ids | ~20 | `090ffc27…`, `1f00e84d…` |
| `*KQLQueryset/RealTimeQueryset.json` and `kdb_fabricEvents/EmbeddedRealTimeQueryset.json` - query and tab ids | ~8 | `4133f2a7…`, `691d55f0…` |

These are internal to the item. They identify a widget on a dashboard page or a node in a stream
graph, not anything in the environment, and they must stay stable or the item's own internal
references break. They are listed here as a count rather than individually because there is no
decision to make about any of them.

The single nil GUID `00000000-0000-0000-0000-000000000000` appears four times in the dashboard as
`"workspace": "00000000-…"`, meaning "the workspace this dashboard lives in". Correct and portable.

---

## 8. Verification performed

Local, on this machine:

- All 31 `.platform` files parse and carry both `config.logicalId` and `metadata.type`.
- All 10 `pipeline-content.json` files parse as JSON.
- Every `@pipeline().libraryVariables.<name>` reference resolves to a `libraryVariables` entry in
  the same file: 20 bindings, 0 undefined, 0 unused.
- Every `libraryVariables` entry names `accelerator-config` and logicalId
  `bedb80f6-2c41-409c-8752-3fd2d2ef436b`: 0 mismatches.
- Every `variableName` exists in `variables.json`: 0 missing.
- No environment GUID or the `datawarehouse.fabric.microsoft.com` host remains in any
  `pipeline-content.json`.
- The 30 source logical ids are byte-identical to the source repo - none were regenerated.
- Source folder `C:\Dev\fabric-accelerator` was read only and is unmodified.

## 9. Verification NOT performed

This machine has no Azure CLI and no Fabric tenant access, so none of the following was done.
Do not treat this migration as proven until each line has been checked:

| Not verified | Why it matters |
| --- | --- |
| The `libraryVariables` block is accepted by Fabric when syncing from Git | The block shape follows the documented contract, but this repo was never pushed to a workspace. If Fabric rejects it, the pipeline will not load. |
| `libraryId` resolves to the Variable Library | `libraryId` was set to the Variable Library's **logicalId**. If Fabric expects the deployed item id there instead, the binding fails. This is the single highest-risk assumption in the migration. |
| Pipelines run and read the expected values | A definition with no DEV literal is not proof that the reference resolves. Run each orchestrator in DEV first. |
| Notebook activity behaves as before without `workspaceId`/`capacityId` | Both fields were removed. Confirm the notebook still runs on the intended capacity. |
| `notebookutils.variableLibrary.getLibrary` works in `EnvSettings` | Requires the library to be present in the same workspace and a value set to be active. |
| Fabric rewrites notebook `default_lakehouse` on deploy | If it does not, three notebooks still point at the source lakehouse. |
| Value set switching is possible | Only the `dev` value set ships. See section 10. |

---

## 10. Promoting to TST and PRD

Only a `dev` value set ships, deliberately. An empty `tst` value set would inherit every DEV
default and the environment would silently read DEV data - the exact failure runbook 4 warns
about. So the TST and PRD value sets have to be created after the target workspace exists, because
the item ids they need do not exist until then.

For each target environment:

1. Provision the workspace and sync `dateng/` into it from Git.
2. Read the deployed item ids from the target workspace (portal, or `list_items`).
3. Read the SQL analytics endpoint host from the gold warehouse's settings.
4. Add `valueSets/<stage>.json` with an override for **every** variable that differs - do not
   override only some, or the rest inherit DEV:

   ```json
   {
     "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/variableLibrary/definition/valueSet/1.0.0/schema.json",
     "name": "tst",
     "description": "Test. Every value differs from dev.",
     "variableOverrides": [
       { "name": "bronze_workspace_id", "value": "<tst workspace id>" },
       { "name": "silver_workspace_id", "value": "<tst workspace id>" },
       { "name": "gold_workspace_id", "value": "<tst workspace id>" },
       { "name": "bronze_lakehouse_id", "value": "<tst lh_bronze id>" },
       { "name": "silver_lakehouse_id", "value": "<tst lh_silver id>" },
       { "name": "gold_warehouse_id", "value": "<tst dw_gold id>" },
       { "name": "gold_sql_endpoint", "value": "<tst endpoint host>" },
       { "name": "l1_notebook_id", "value": "<tst notebook id>" },
       { "name": "capacity_id", "value": "<tst capacity id>" },
       { "name": "control_db_connection_id", "value": "<tst connection id>" },
       { "name": "source_sql_connection_id", "value": "<tst connection id>" },
       { "name": "mirror_source_connection_id", "value": "<tst connection id>" },
       { "name": "mirror_ingest_connection_id", "value": "<tst connection id>" }
     ]
   }
   ```

5. Add the name to `settings.json` `valueSetsOrder`.
6. Set the active value set in the target workspace. This is **item state**, not definition, so it
   does not travel through Git and does not appear in a diff:

   ```
   PATCH /v1/workspaces/{workspaceId}/variableLibraries/{libraryId}
   { "properties": { "activeValueSetName": "tst" } }
   ```

7. Re-check section 5. None of the rebind items are fixed by the value set.

Because the active value set is item state, deployment does not overwrite it. That is what makes
this approach survive a promotion - and it is also why it is invisible in a pull request, so
record the active value set per workspace in `fabric/declared-environment.yaml`.
