# Guardrails

MCP calls are bounded only by the signed-in identity's Fabric RBAC. The agent is not a sandbox.
Safety therefore has to be explicit, layered, and enforced by the host rather than requested in a
prompt.

---

## 1. The enforcement model

Three layers, in order of authority. Do not confuse them.

| Layer | Enforces? | Where it lives |
| --- | --- | --- |
| Permission rules | **Yes** — this is the enforcement point | `.claude/settings.json`, `opencode.json` |
| Subagent tool scoping | Yes, for subagent sessions | Agent frontmatter |
| Hooks / plugins | No — second layer only | Host hook config |

A hook that inspects tool calls is useful for logging and for catching patterns the rule engine
cannot express. It is not a substitute for a deny rule, because a hook can be disabled, can fail
open, and does not run in every host. Never describe a hook as the control that prevents deletion.

## 2. What is denied

`delete_*` tools are denied outright, in both hosts:

- `delete_workspace` — deletes a workspace **and every item in it**. Irreversible.
- `delete_item`
- `delete_folder`
- `delete_workspace_role`
- `onelake_delete_shortcut`
- `onelake_delete_data_access_role`

Deletion is a human, in-portal action with its own confirmation. If a deployment is wrong, the fix
is to correct the repo and re-sync, or to remove the item in the UI — not to ask an agent to delete
it.

In Claude Code, a tool-name glob deny removes the matching tools from the model's context entirely,
so the model cannot even attempt them. That is stronger than blocking at call time, and it is the
intended behaviour here.

## 3. What requires approval

**Role changes** — `add_workspace_role`, `update_workspace_role`, `delete_workspace_role`.
A role change is a security change. `delete_workspace_role` is additionally denied.

**Everything else that mutates** — workspace create/update, item create/update/definition,
folder create/update/move, `bulk_move_items`, shortcut creation, data-access-role upserts, OneLake
settings changes, shortcut cache reset.

Approval is per call. "Allow always" is available in OpenCode and should be used sparingly; a saved
broad approval does not override a configured deny.

## 4. Read-only subagents

`verifier` and `drift-checker` exist so that routine checks do not require write-capable context.

Both are scoped to read tools only:

- Claude Code: `tools:` lists built-in read tools plus one entry per read-only Fabric tool. Nothing
  else is available, so a write cannot be attempted.
- OpenCode: `permissions` deny `*` first, then allow back only `read`, `glob`, `grep`, `skill` and the
  read-only Fabric tools. Because the last match wins, the deny has to come first.

A subagent uses its own permissions, not a subset of the parent's. That is why the read allowlist is
written out rather than inherited.

## 5. Rule syntax differs between hosts

This was verified against current documentation. It does not work the same way in both tools, and
copying a rule from one to the other silently produces no protection.

| | Claude Code | OpenCode V2 |
| --- | --- | --- |
| Container | `permissions.deny` / `.ask` / `.allow` arrays | ordered `permissions` array of objects |
| MCP tool name | `mcp__plugin_<plugin>_<server>__<tool>` | `<server>_<tool>` |
| Example deny | `mcp__plugin_fabric-accelerator_fabric-core__delete_item` | `{ "action": "fabric-core_delete_item", "resource": "*", "effect": "deny" }` |
| Wildcard deny | `mcp__plugin_fabric-accelerator_fabric-core__delete_*` | `{ "action": "fabric-core_delete_*", "resource": "*", "effect": "deny" }` |
| Precedence | deny → ask → allow; first match wins | last matching rule wins |
| No match | normal tool prompt | `ask` |

Two naming details matter more than they look:

- **Claude Code** prefixes a plugin-bundled server with the plugin name. A server named
  `fabric-core` inside a plugin named `fabric-accelerator` produces
  `mcp__plugin_fabric-accelerator_fabric-core__list_workspaces`. Write a rule against
  `mcp__fabric-core__*` and it matches nothing. Hyphens survive; characters outside `A-Z`, `a-z`,
  `0-9`, `_` and `-` become `_`.
- **OpenCode** joins server and tool with a single underscore and keeps hyphens, so the action is
  `fabric-core_delete_item`. Characters outside letters, digits, `_` and `-` become `_`.

Both consequences below follow from those shapes:

1. **Claude Code**: a broad deny cannot be carved out by a narrower allow. Do not try.
2. **OpenCode**: ordering is inverted relative to intuition. Broad rules go first, specific rules
   last. Putting a read `allow` before a broad `ask` makes reads prompt, because the `ask` matches
   later.

`shared/policy/tool-names.json` is the single source for both. The build script emits the correct
shape per host so a human never hand-translates a rule.

## 6. Things the agent must never do

- Retry a denied tool through a different route, a different server, or a shell command.
- Treat a UI-only check as verified because the human said "it looked fine" without naming what
  they saw.
- Report a deployment as complete while any step is unverified. Use the honesty matrix in
  `AGENTS.md` and mark those rows explicitly.
- Write a token, connection string, client secret or signed URL into a tracked file.
- Widen `fabric-local` namespaces, or register a third MCP server, as a shortcut around a missing
  Core tool.
- Change a role assignment to make a verification pass.

## 7. Environment separation

DEV is where the repo is authoritative. TST and PRD are reached only through deployment pipelines.

Before any verification run, state the tenant and the workspace set you are checking. If the
signed-in identity cannot see a workspace, that is a finding — not a reason to try another account
silently.

Never verify a production workspace as a stand-in for a test one, and never promote to PRD as a way
to "check whether it works".
