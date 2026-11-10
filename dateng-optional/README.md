# `dateng-optional/` - connection-gated items (NOT part of the default sync)

These items are **in scope by type** (`MirroredDatabase`) but are **not portable on their own**:
they reference an external data source through a Fabric connection, and that connection plus the
source database must exist in the target tenant before the item can be created.

They are deliberately **not** in `dateng/`. Fabric Git sync validates a `MirroredDatabase`'s source
connection at item create/update time, so a workspace that syncs `dateng/` without the prerequisite
connection fails with `ConnectionNotAccessible` and the item is left in a broken state. Keeping
these items out of the default folder means a clean first sync on alien soil.

## Contents

| Folder | Item type | External prerequisite |
| --- | --- | --- |
| `WideWorldImporters-mirror.MirroredDatabase/` | MirroredDatabase | An Azure SQL database (WideWorldImporters or equivalent) reachable by the binding user, plus a Fabric connection of type `AzureSqlDatabase` bound to it |

## How to enable the MirrorDB flow

Only do this after the core `dateng/` workspace is synced and verified.

1. Provision the source database.
   - Create or restore an Azure SQL database containing the WideWorldImporters tables
     (`Application.*`, `Purchasing.*`, `Sales.*` as listed in `mirroring.json`).
   - Grant the binding user (the identity that performs Git sync / runs the mirror) read access
     to that database. Creating the database alone is not enough - `ConnectionNotAccessible` is
     raised when the binding user cannot read the datasource.
2. Create the Fabric connection.
   - Portal: Settings -> Manage connections and gateways -> New connection -> Azure SQL Database.
   - Enter the server/database endpoint and credentials (prefer a service principal or managed
     identity over a personal account).
   - Record the connection id. Either edit `mirroring.json` by hand, or add the pair to
     `fabric/connection-rebind.json` and run
     `pwsh ./scripts/rebind-connections.ps1 -MappingFile ./fabric/connection-rebind.json`
     before syncing.
3. Copy this folder's item folders into the workspace's Git folder (the same level as the
   `dateng/` items) so Fabric sees them as direct children:
   ```
   <repo>/<workspace-folder>/WideWorldImporters-mirror.MirroredDatabase/
   ```
4. Update from Git. The mirror item should now create successfully.
5. Bind the connection in the mirror item's mirroring configuration if it was not already
   resolved by the definition.
6. Only then run `Ingest MirrorDB Table` and `Master ELT MirrorDB` - both pipelines reference
   this mirror by name and the `mirror_ingest_connection_id` connection.

## What is NOT in this folder

The two MirrorDB pipelines (`Ingest MirrorDB Table`, `Master ELT MirrorDB`) stay in `dateng/`
because they are normal pipeline items and sync without validating their connection. They are
inert until the mirror item and the `mirror_ingest_connection_id` connection exist; running
them before that will fail at runtime, not at sync time. That failure is expected and is not a
sync defect.

## Verification

- `get_item_definition` on the mirror item shows the new connection id in `mirroring.json`.
- The mirror reports healthy replication in the Fabric UI.
- `Ingest MirrorDB Table` runs and lands rows in the bronze lakehouse.

Connections are unverifiable via MCP. Confirm existence, binding and credential validity in the
portal (runbook 3).
