# `dateng/` - workspace items ready for Git integration

The 29 portable items of the Fabric accelerator, flattened and parameterised so the folder can be connected
to a Fabric workspace through Git integration.

Every immediate child is an item folder named `<displayName>.<ItemType>` and carries a `.platform`
file. That is the shape Fabric Git integration expects: the folder you point a workspace at must
have items as its direct children, not category folders.

```
dateng/
  accelerator-config.VariableLibrary/    <- new: environment-scoped values
  controlDB.SQLDatabase/
  dw_gold.Warehouse/
  lh_bronze.Lakehouse/
  lh_silver.Lakehouse/
  <8 notebooks>.Notebook/
  <10 pipelines>.DataPipeline/
```

Connection-gated items (currently the `WideWorldImporters-mirror` MirroredDatabase) live in the
sibling `dateng-optional/` folder, not here. They are deliberately excluded from the default sync
set because Fabric validates their source connection at item create/update time and fails with
`ConnectionNotAccessible` when the prerequisite connection or source database is missing. See
`dateng-optional/README.md`.

## What changed relative to the source

| Change | Why |
| --- | --- |
| Category folders dropped (`lakehouse/`, `pipeline/reusable/.../`, `rti/eventhouse/`) | Fabric syncs one folder per workspace; category nesting is one level too deep. |
| `accelerator-config` Variable Library added | Holds workspace, capacity, item-id, endpoint and connection values so they are not literals in item definitions. |
| Environment literals replaced with `libraryVariables` in 5 pipelines | Removes DEV identifiers from runtime positions. |
| Hardcoded parameter defaults removed from 4 child pipelines | A reusable child should not carry an environment value of its own. |
| `EnvSettings` reads workspace ids from the Variable Library | It was the one notebook that hardcoded them in code. |
| Notebook activity `workspaceId` / `capacityId` removed in `Level1 Transform` | Those fields are not expression slots; omitting them makes the activity inherit the pipeline's workspace and capacity. |

Every `.platform` `config.logicalId` was preserved byte-for-byte. Regenerating one would make
Fabric create a duplicate item instead of matching the existing one.

Full detail, including every GUID and what was done with it, is in
[GUID-INVENTORY.md](GUID-INVENTORY.md).

## Connect it

1. Copy the `fabric/` folder from this repository into the deploying repository, and fill in
   `fabric/declared-environment.yaml`.
2. In the Fabric workspace: **Workspace settings > Git integration**, choose the provider and
   repository, and set the folder to `dateng`.
3. **Update from Git** to pull the items in.

## Before you promote

Read [`OPEN-ISSUES.md`](OPEN-ISSUES.md) first. It lists every unproven assumption and needed
decision with a severity and a way to check each. Two are blocking on the first sync:

- **F1** - `libraryId` is set to the Variable Library's logicalId, not a deployed item id.
- **F2** - the `libraryVariables` block has never been parsed by a real tenant.

One is a plain defect: **F3**, `entra-functions` runs `%run /common/keyvault-functions`, and that
notebook does not exist.

Only a `dev` value set ships, on purpose - see **F7**. Create the `tst` and `prd` value sets after
the target workspace exists, and set the active value set per workspace;
`GUID-INVENTORY.md` section 10 has the procedure and the payload.

## Files in this folder

| File | Purpose |
| --- | --- |
| `README.md` | This file |
| `GUID-INVENTORY.md` | Classification of all 133 GUIDs, change log, verification record, promotion procedure |
| `OPEN-ISSUES.md` | Every unproven assumption, needed decision and known gap, with severity and how to check each |

All three are plain files, not folders, so Fabric Git integration ignores them. If your tenant
rejects a folder containing non-item files, move them one level up - the item folders are
unaffected.
