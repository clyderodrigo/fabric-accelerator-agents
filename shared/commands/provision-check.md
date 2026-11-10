---
description: Walk the provisioning checklist for the DEV workspaces in dependency order
---

Load the `provision-checklist` skill and walk it for this repository.

Target: $ARGUMENTS

If no target was given, ask which workspaces to cover before starting, and default to all three in
order: `dateng`, then `data`, then `analytics`.

Rules for this run:

1. Read `fabric/declared-environment.yaml` first. If it is missing, stop and point at
   `shared/config/declared-environment.md`.
2. Confirm the tenant with the human before the first MCP call.
3. For every gate, state whether it is agent-verified or human-confirmed. Never blur the two.
4. Do not perform mutating steps. Where a step is UI-only, give the exact screen path and ask the
   human to report the result.
5. End with the completion table from the skill, with every row filled in — including the
   `Unverified` ones.
