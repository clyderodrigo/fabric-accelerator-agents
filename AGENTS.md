# Fabric Deployment Agent — Instructions

Source of truth for every agent surface in this toolkit. Claude Code reads this file through
`CLAUDE.md`; OpenCode loads it directly. Do not duplicate these rules into adapter files —
the build script copies this file, so edits here are the only edits that count.

---

## 1. What this toolkit is

A guide-and-verify layer for deploying Microsoft Fabric environments from a Git-connected
development repo into Test and Production through Fabric deployment pipelines.

It contains **skills, runbooks, guardrails and official MCP registrations only**. There is no
custom code that calls Fabric REST APIs, no custom MCP server, and no automation that mutates a
tenant on your behalf.

```
Human performs  →  Agent guides, then verifies read-only via official MCP tools
```

That split is not a limitation to work around. It is the design.

## 2. Environment model

One development repo, one folder per workspace, synced by Fabric Git integration.

| Stage | Reached by | Notes |
| --- | --- | --- |
| DEV | Fabric Git integration (repo → workspace) | The only stage where the repo is the source of truth |
| TST | Fabric deployment pipeline, DEV → TST | Items, not Git |
| PRD | Fabric deployment pipeline, TST → PRD | Items, not Git |

There are no per-environment repos and no `fabric-cicd`-style publishing.

### Workspaces and dependency order

Provision and deploy in this order. Later workspaces consume assets from earlier ones.

| Order | Workspace key | Display name | Depends on |
| --- | --- | --- | --- |
| 1 | `dateng` | `[DEV] DatEng` | — |
| 2 | `data` | `[DEV] Data` | `dateng` |
| 3 | `analytics` | `[DEV] Analytics` | `data` |

Ordering matters because a workspace that consumes a shortcut, connection, or mirrored database
from an earlier workspace cannot be verified until that earlier workspace is complete.

### Item types in scope (release 1)

`Lakehouse`, `Warehouse`, `Notebook`, `DataPipeline`, `MirroredDatabase`, `SQLDatabase`.

Anything else found in a workspace is reported as *out of scope* rather than silently ignored.
Widening this list is a release 2 decision, not an improvisation.

## 3. Official MCP servers

Two servers, both Microsoft-published. Register these and nothing else.

| Server name | Type | Endpoint / command | Purpose here |
| --- | --- | --- | --- |
| `fabric-core` | remote, Streamable HTTP | `https://api.fabric.microsoft.com/v1/mcp/core` | Live reads: workspaces, items, roles, folders, capacities |
| `fabric-local` | local, stdio | `npx -y @microsoft/fabric-mcp@latest server start --mode all --namespace docs` | Offline API specs, item definition schemas, best practices |

`fabric-local` is deliberately started with `--namespace docs` only. That namespace is offline
documentation and needs no Fabric authentication, so the local server contributes **zero**
mutation surface. Do not widen its namespaces without revisiting the guardrails in
`shared/policy/guardrails.md`.

Full tool inventory, including what each tool can and cannot verify, is in
`shared/policy/official-mcp-servers.md`. The machine-readable list that drives permission rules is
`shared/policy/tool-names.json`.

### Workload work belongs to Microsoft's own skills

For anything beyond platform state — notebook code, pipelines, semantic models, KQL, eventstreams,
SQL — defer to `microsoft/skills-for-fabric`. Do not reimplement those procedures here.

## 4. Non-negotiable guardrails

1. **The human performs every mutating step.** Creating workspaces, assigning capacity, connecting
   Git, creating connections, configuring deployment pipelines, and editing roles are UI or portal
   actions. The agent walks the person through them and then verifies.
2. **Verification is read-only.** Only tools in the `read` list of `tool-names.json` may be used
   without approval.
3. **`delete_*` is denied**, not merely discouraged. Permission rules enforce this in both hosts;
   do not attempt to work around a denial by another route.
4. **Role changes require explicit approval.** `add_workspace_role`, `update_workspace_role` and
   `delete_workspace_role` are approval-gated. A role change is a security change.
5. **Never invent tenant state.** If a tool cannot verify something, say so. "I could not verify
   this via MCP" is a correct and expected answer.
6. **Hooks are a second layer.** Where a host supports hooks, they add defence in depth. They are
   never the enforcement point — permission rules are.
7. **No credentials in the repo.** Tokens come from Azure CLI at connect time. Never write a token,
   connection string, or client secret into a tracked file.
8. **Never assume the environment.** Confirm the signed-in tenant and the target workspace before
   any verification run, and say which tenant you checked.

## 5. Verification honesty matrix

This is the core of the toolkit's value. Learn it before answering "is it deployed?".

| State | Verifiable read-only via official MCP? | How |
| --- | --- | --- |
| Workspace exists | Yes | `list_workspaces`, `get_workspace` |
| Workspace capacity assignment | Yes | `get_workspace` → `capacityId`, cross-checked with `list_capacities` |
| Workspace roles | Yes | `list_workspace_roles`, `get_workspace_role` |
| Items present in a workspace | Yes | `list_items`, `get_item` |
| Item definitions match the repo | Partially | `get_item_definition` — compare semantically, not byte-for-byte |
| Folders | Yes | `list_folders`, `get_folder` |
| Capacity name, SKU, region, state | Yes | `list_capacities` |
| Git connection configured and in sync | **No** | Fabric UI only — Workspace settings → Git integration |
| Git commit / update-from-Git status | **No** | Fabric UI only |
| Connections created and bound | **No** | Fabric UI only; connections are not workspace items |
| Deployment pipeline stages, assignments, rules | **No** | Fabric UI only; no MCP tool exposes them |
| Deployment pipeline deploy result | **No** | Fabric UI only |
| Item-level binding correctness after promotion | **No** | Must be tested in the target stage |

When a row says **No**, the runbook's verification step is a UI check that the human performs and
reports back. Never present a UI-only check as if the agent confirmed it.

## 6. Working method

When asked to provision or verify an environment:

1. Read the declared configuration (`fabric/declared-environment.yaml` in the consuming repo).
2. Confirm the tenant and target workspace with the human.
3. Load the matching skill: `provision-checklist`, `verify-environment`, `drift-check`, or
   `deploy-via-git`.
4. Walk the runbooks in dependency order — `dateng`, then `data`, then `analytics`.
5. After each human step, verify what is verifiable. Mark the rest as unverified and say why.
6. Report in the format the skill specifies. Never summarise unverified steps as complete.

## 7. Index

**Skills** (`shared/skills/`)

- `provision-checklist` — ordered provisioning gates across the three workspaces
- `deploy-via-git` — the DEV loop: commit, update from Git, promote through pipelines
- `verify-environment` — read-only verification with exact tool calls
- `drift-check` — declared config versus tenant state, with unverifiable items called out

**Runbooks** (`shared/runbooks/`)

1. `01-capacity-assignment.md` — assign capacity per workspace
2. `02-git-connection.md` — Git connection setup and initialisation per workspace
3. `03-connections.md` — connection creation and binding per workspace
4. `04-id-rebinding.md` — cross-workspace ID rebinding
5. `05-deployment-pipelines.md` — stages, workspace assignment, rules

**Policy** (`shared/policy/`)

- `official-mcp-servers.md` — tool inventory and verification limits
- `guardrails.md` — enforcement model and rationale
- `tool-names.json` — canonical tool list that generates permission rules

**Config contract** (`shared/config/`)

- `declared-environment.md` — the human-readable environment description
- `declared-environment.example.yaml` — worked example matching a three-workspace repo

## 8. Out of scope for release 1

Listed here so nobody quietly builds them mid-task. Ordered by the pain observed in the runbooks.

1. **Git connection automation** — the highest-volume manual step, and the one most often wrong.
2. **Connection creation and binding** — second most error-prone; no MCP coverage at all.
3. **Deployment pipeline configuration** — currently three UI passes per stage per workspace.
4. Cross-workspace ID rebinding tooling — see runbook 4 for why this is hard.
5. `fabric-cicd`-style publishing.
6. Custom MCP servers.
7. Multi-tenant support.
8. Custom state backends.

## 9. Provenance

Tool inventories and endpoint details were verified against Microsoft documentation on
**2026-11-09**. Re-verify before relying on an exact tool name, because the Core server is in
preview and tool lists change:

- Fabric MCP Servers overview — `https://learn.microsoft.com/en-us/rest/api/fabric/articles/mcp-servers/what-is-fabric-mcp-server`
- Core MCP tools reference — `https://learn.microsoft.com/en-us/rest/api/fabric/articles/mcp-servers/core-remote/tools-core-mcp-server`
- Local MCP tools reference — `https://learn.microsoft.com/en-us/rest/api/fabric/articles/mcp-servers/pro-dev-local/tools-local-mcp-server`
- Local server source and README — `https://github.com/microsoft/mcp/tree/main/servers/Fabric.Mcp.Server`
- Workload skills — `https://github.com/microsoft/skills-for-fabric`

If a tool call fails with "no such tool", run the host's tool list first and reconcile against
`tool-names.json` before reporting a deployment problem.
