# Fabric deployment accelerator — agents

A guide-and-verify layer for deploying Microsoft Fabric environments from a Git-connected
development repo into Test and Production through Fabric deployment pipelines.

It contains **skills, runbooks, guardrails and official MCP registrations only**. There is no custom
code that calls Fabric REST APIs, no custom MCP server, and nothing that mutates a tenant on your
behalf.

```
Human performs  →  Agent guides, then verifies read-only via official MCP tools
```

That split is the design, not a limitation. It exists because the operations that break Fabric
deployments — capacity assignment, Git connection, connections, cross-workspace rebinding, deployment
pipeline rules — have **no** MCP coverage at all. Pretending otherwise is how a deployment gets
declared "done" while pointing at the wrong environment.

## Two adapters, one source

| Path | What it is |
| --- | --- |
| `shared/` | The only hand-edited copy of every skill, runbook, agent, command and policy document |
| `adapters/claude-code/` | A Claude Code plugin, generated from `shared/` |
| `adapters/opencode/` | An OpenCode project configuration, generated from `shared/` |
| `scripts/build.ps1` | Generates both adapters; the only place host differences are encoded |
| `AGENTS.md` | Source-of-truth instructions; `CLAUDE.md` imports it |

Nothing under `adapters/` is edited by hand. Change `shared/`, run the build, commit both.

## Requirements

| Requirement | Why |
| --- | --- |
| Azure CLI, signed in | `az login --allow-no-subscriptions`. Mints the MCP access token. |
| Node.js 22 LTS or later | Runs the local Fabric MCP server and the Claude token helper. |
| A Fabric identity that can see the target workspaces | Every MCP call runs as that identity, under its Fabric RBAC. |
| Windows PowerShell 5.1 or later | Only to rebuild the adapters. Consumers do not need it. |

## Install

Each adapter has its own install steps, including the token setup for that host:

- **Claude Code** — [`adapters/claude-code/README.md`](adapters/claude-code/README.md)
- **OpenCode** — [`adapters/opencode/README.md`](adapters/opencode/README.md)

Both installs need one thing from this repo that is not code: copy the `fabric/` folder into your
deploying repository. It holds the runbooks and the declared-environment contract that the skills
read.

```powershell
Copy-Item -Recurse ./adapters/claude-code/fabric ./fabric
Copy-Item ./fabric/declared-environment.example.yaml ./fabric/declared-environment.yaml
```

Then fill in `fabric/declared-environment.yaml`. Its schema is `fabric/declared-environment.md`.

## Try it

| Command | What it does |
| --- | --- |
| `/provision-check` | Walks the provisioning gates in dependency order |
| `/verify-env` | Read-only health check against the declared configuration |
| `/drift-check` | Declared configuration versus live tenant state |

Or ask directly: *"Verify the [DEV] DatEng workspace against fabric/declared-environment.yaml."*

Workspace order is fixed: `dateng` → `data` → `analytics`. Later workspaces consume assets from
earlier ones, so a `data` failure caused by a missing `dateng` asset is reported as a dependency
failure, not a Git failure.

## What can and cannot be verified

This is the part worth reading before trusting any output.

| State | Read-only via official MCP? | How |
| --- | --- | --- |
| Workspace exists | Yes | `list_workspaces`, `get_workspace` |
| Capacity assignment | Yes | `get_workspace` → `capacityId`, cross-checked with `list_capacities` |
| Workspace roles | Yes | `list_workspace_roles` |
| Items and folders | Yes | `list_items`, `list_folders` |
| Item definitions | Partially | `get_item_definition` — compare semantically, never byte-for-byte |
| Git connection and sync status | **No** | Fabric portal only |
| Connections and their bindings | **No** | Connections are not workspace items |
| Deployment pipeline stages, rules, results | **No** | No MCP tool exposes deployment pipelines |
| Runtime binding after promotion | **No** | Requires running the item |

When a row says **No**, the verification step is a portal check the human performs and reports back.
The toolkit never presents that as agent-verified. The full matrix, with the exact tool names, is in
`AGENTS.md`.

## Guardrails

Enforced by the host, not requested in a prompt.

| Control | Behaviour |
| --- | --- |
| `delete_*` tools | **Denied** in both hosts. In Claude Code the deny removes them from the model's context entirely. |
| Role changes | **Approval required**. A role change is a security change. |
| Every other write | **Approval required**. |
| Read-only tools | Allowed. |
| `verifier`, `drift-checker` | Subagents with read-only tool allowlists. They cannot write, delete, or run shell. |
| Hooks | A second layer only. Permission rules are the enforcement point. |

Rule syntax differs between the hosts and is **not** interchangeable — Claude Code uses
`mcp__plugin_<plugin>_<server>__<tool>` with deny/ask/allow arrays where the first match wins;
OpenCode uses `<server>_<tool>` with an ordered array where the **last** match wins. Both rule sets
are generated from `shared/policy/tool-names.json` so nobody hand-translates them. The differences
are documented in `shared/policy/guardrails.md`.

## Official MCP servers

Only two, both Microsoft-published.

| Server | Type | Endpoint / command |
| --- | --- | --- |
| `fabric-core` | remote, Streamable HTTP | `https://api.fabric.microsoft.com/v1/mcp/core` |
| `fabric-local` | local, stdio | `npx -y @microsoft/fabric-mcp@latest server start --mode all --namespace docs` |

`fabric-local` is started with `--namespace docs` only. That namespace is offline API documentation
and needs no Fabric authentication, so the local server contributes **zero** mutation surface. Full
inventory and per-host auth details: `shared/policy/official-mcp-servers.md`.

Workload work — notebook code, pipelines, semantic models, KQL, eventstreams, SQL — is **not**
reimplemented here. Use `microsoft/skills-for-fabric` for that.

## Rebuilding

```powershell
powershell -NoProfile -File ./scripts/build.ps1
```

The script regenerates both adapters, re-parses every emitted JSON file, and asserts that each
`delete_*` deny and each read allow survived generation. It also runs `claude plugin validate` when
the Claude CLI is on `PATH`; pass `-SkipValidate` to skip it.

`-PluginName` changes the Claude Code plugin name, which changes **every** generated MCP tool name.
Only change it before the first install, then re-copy the settings template.

Because `adapters/` is committed, CI can prove the output is current by rebuilding and checking that
`git diff` is empty.

## Worked example: `dateng/`

[`dateng/`](dateng/README.md) is a real, complete example: 30 items from the accelerator, flattened
into the shape Fabric Git integration expects, with environment identifiers moved into an
`accelerator-config` Variable Library. [`fabric/`](fabric/declared-environment.yaml) beside it is
the matching declared environment.

Use it to see what the skills are checking against, or copy the pattern for another repository.
[`dateng/GUID-INVENTORY.md`](dateng/GUID-INVENTORY.md) is the runbook 4 artefact for it: all 133
GUIDs classified, what was changed and why, and what could not be verified without tenant access.
[`dateng/OPEN-ISSUES.md`](dateng/OPEN-ISSUES.md) is the review checklist: every unproven assumption,
needed decision and known gap, with a severity and a way to check each.

Two things to know before pointing a workspace at it:

- It was migrated on a machine with no Fabric tenant, so the sync has not been proven. Read
  [`dateng/OPEN-ISSUES.md`](dateng/OPEN-ISSUES.md) first - F1 and F2 need checking on the first sync,
  and F3 is a plain defect.
- It includes Real-Time Intelligence items and a Variable Library, which are outside the release 1
  item set below. `drift-check` will report those as *out of scope*. That is expected, not a
  failure.

## Release 1 scope

In scope: `Lakehouse`, `Warehouse`, `Notebook`, `DataPipeline`, `MirroredDatabase`, `SQLDatabase`.
Anything else found in a workspace is reported as *out of scope*, not silently ignored.

Deliberately out of scope, ordered by the pain observed in the runbooks:

1. **Git connection automation** — the highest-volume manual step and the one most often wrong.
2. **Connection creation and binding** — second most error-prone, with no MCP coverage at all.
3. **Deployment pipeline configuration** — currently three UI passes per stage per workspace.
4. Cross-workspace ID rebinding tooling.
5. `fabric-cicd`-style publishing.
6. Custom MCP servers.
7. Multi-tenant support.
8. Custom state backends.

When someone asks "can this be automated", the honest answer points at Microsoft's own
`git-integration-operations-cli` and `deployment-pipelines-authoring-cli` skills, not at a new
script in this repo.

## Provenance

Tool inventories and endpoint details were verified against Microsoft documentation on
**2026-11-09**. The Core MCP Server is in preview and its tool list can change; re-verify before
relying on an exact tool name.

- Fabric MCP Servers overview — <https://learn.microsoft.com/en-us/rest/api/fabric/articles/mcp-servers/what-is-fabric-mcp-server>
- Core MCP tools reference — <https://learn.microsoft.com/en-us/rest/api/fabric/articles/mcp-servers/core-remote/tools-core-mcp-server>
- Local MCP tools reference — <https://learn.microsoft.com/en-us/rest/api/fabric/articles/mcp-servers/pro-dev-local/tools-local-mcp-server>
- Claude Code permissions — <https://code.claude.com/docs/en/permissions>
- Claude Code plugin MCP tool names — <https://code.claude.com/docs/en/mcp>
- OpenCode permissions — <https://opencode.ai/docs/permissions/>
- OpenCode MCP servers — <https://opencode.ai/docs/mcp-servers/>
- Workload skills — <https://github.com/microsoft/skills-for-fabric>

If a tool call fails with "no such tool", list the host's tools first and reconcile against
`shared/policy/tool-names.json` before reporting a deployment problem.
