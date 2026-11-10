# `dateng-rti/` - Real-Time Intelligence items (out of scope for release 1)

These items were split out of `dateng/` because they are **out of scope for release 1** of the
accelerator (see `AGENTS.md` section 2 - item types in scope: `Lakehouse`, `Warehouse`,
`Notebook`, `DataPipeline`, `MirroredDatabase`, `SQLDatabase`). They are Real-Time Intelligence
items: `Eventhouse`, `KQLDatabase`, `KQLQueryset`, `KQLDashboard`, `Eventstream`.

They are kept here so they are not lost, but they must **not** be synced through the core
workspace's Git integration - Fabric's Git sync cannot resolve their environment-scoped
references (cluster URIs, database item ids, workspace ids) and fails with
`InvalidArtifactDefinitionFormat` / `invalid WorkspaceId <null>`.

Handle them separately, using the dedicated skills:

- `eventhouse-cli` for the Eventhouse and KQL databases
- `eventstream-cli` for the Eventstream
- KQL dashboards / querysets via the Real-Time Intelligence experience or their REST APIs

Connect `dateng-rti/` to a dedicated RTI workspace only after the core `dateng/` workspace is
synced and verified.