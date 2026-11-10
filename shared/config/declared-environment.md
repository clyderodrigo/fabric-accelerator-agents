# Declared environment configuration

The contract between the repo and the tenant. A human-readable description of the intended
workspaces, capacity, roles, Git mappings, connections and pipeline stages.

**Location:** `fabric/declared-environment.yaml` in the consuming repo.

**Consumed by:** the `provision-checklist`, `verify-environment` and `drift-check` skills.

## Design rule: do not declare items here

Item inventory is read from the repo tree, not from this file. Every item folder carries a
`.platform` file with `metadata.type` and `metadata.displayName`, which is authoritative by
construction.

A hand-maintained item list in this file drifts from the actual `.platform` files within a week, and
then drift-check reports drift against a stale baseline. If both sources exist and disagree, that
disagreement is itself a finding.

What this file declares is the state that **cannot** be inferred from the repo:

- capacity identity and assignment
- workspace roles
- Git mapping per workspace
- connections
- deployment pipeline stages and rules
- cross-workspace references that are deliberately shared

## Schema

```yaml
version: 1

tenant:
  name: contoso                     # display name, for humans
  id: ""                            # optional; leave empty rather than guessing

capacity:
  displayName: FabricCapacity01
  id: ""                            # optional; resolved via list_capacities when empty
  sku: F2
  region: westeurope

workspaces:
  - key: dateng                     # stable key used by skills and runbooks
    displayName: "[DEV] DatEng"
    stage: dev                      # dev | tst | prd
    capacity: FabricCapacity01      # displayName of the capacity above
    roles:
      - principal: "group:data-platform-engineers@contoso.com"
        role: Admin                 # Admin | Member | Contributor | Viewer
    git:
      provider: azure-devops        # azure-devops | github
      organization: contoso
      project: fabric
      repository: fabric-accelerator
      branch: main
      directory: /workspace/dateng
    dependsOn: []
    notes: ""

  - key: data
    displayName: "[DEV] Data"
    stage: dev
    capacity: FabricCapacity01
    roles: []
    git:
      provider: azure-devops
      organization: contoso
      project: fabric
      repository: fabric-accelerator
      branch: main
      directory: /workspace/data
    dependsOn: [dateng]

  - key: analytics
    displayName: "[DEV] Analytics"
    stage: dev
    capacity: FabricCapacity01
    roles: []
    git:
      provider: azure-devops
      organization: contoso
      project: fabric
      repository: fabric-accelerator
      branch: main
      directory: /workspace/analytics
    dependsOn: [data]

connections:
  - name: sql-dev
    type: Sql
    scope: workspace                # workspace | tenant
    usedBy:
      - workspace: data
        item: pl_load_silver
    declared: true

crossWorkspaceReferences:
  - from: { workspace: data, item: pl_load_silver }
    to:   { workspace: dateng, item: lh_bronze }
    kind: lakehouse                 # lakehouse | warehouse | mirroredDatabase | connection
    resolution: same-stage          # same-stage | shared | parameterised
    notes: "Must resolve to the TST lakehouse after promotion"

deploymentPipelines:
  - name: dateng-pipeline
    stages: [DEV, TST, PRD]
    workspaces:
      DEV: "[DEV] DatEng"
      TST: "[TST] DatEng"
      PRD: "[PRD] DatEng"
    rules:
      - item: pl_ingest_bronze
        property: connection
        values:
          TST: sql-tst
          PRD: sql-prd
```

## Field notes

### `capacity`

`id` is optional. When empty, skills resolve it from `list_capacities` using `displayName`. Populate
it only if you have copied it from the portal — never invent a GUID.

`sku` and `region` are asserted values. `verify-environment` compares them against `list_capacities`
and reports a mismatch.

### `workspaces[].roles`

Principals are written as `group:<email>`, `user:<upn>`, or `spn:<appId>`. The prefix matters: the
comparison against `list_workspace_roles` needs to know what kind of principal to expect.

Do not list the identity that runs the checks. It will appear in the tenant's role list and is not a
declared requirement.

### `workspaces[].git`

All three workspaces normally share one repository and differ by `directory`. That is the expected
shape for a single dev repo with a folder per workspace.

Git state is **unverifiable** via MCP. These fields exist so drift-check can print what the human
should confirm, not so the agent can check them.

### `workspaces[].dependsOn`

Drives ordering in `provision-checklist`. `data` depends on `dateng`; `analytics` depends on `data`.

### `connections`

Connections are **unverifiable** via MCP. `usedBy` exists so runbook 3 can build the binding table
without rediscovering it from item definitions.

`scope: tenant` means the connection is shared across workspaces and is a stronger candidate for a
deployment rule than for duplication per stage.

### `crossWorkspaceReferences`

The output of runbook 4, recorded so the next person does not re-derive it.

| `resolution` | Meaning |
| --- | --- |
| `same-stage` | Should point at the equivalent item in the destination stage. Needs a rule or parameterisation. |
| `shared` | Deliberately points at one fixed target in every stage. Documented so nobody "fixes" it. |
| `parameterised` | Resolved at runtime through a Variable Library or equivalent. |

### `deploymentPipelines`

Entirely **unverifiable** via MCP. Declared so that runbook 5's configuration is reviewable in a pull
request instead of living only in the portal.

`rules[].values` is keyed by stage, and each rule belongs to the **receiving** stage.

## Validation rules

A declared config is invalid if:

- A `workspaces[].key` is duplicated.
- A `workspaces[].capacity` names a capacity not in `capacity`.
- A `dependsOn` entry names an unknown key.
- A dependency cycle exists.
- `deploymentPipelines[].workspaces` names a workspace not in `workspaces`.
- A `crossWorkspaceReferences[].to` names a workspace that appears later in dependency order.

Report invalid config as a blocking finding. Do not guess the intent.

## Example

See `declared-environment.example.yaml`.
