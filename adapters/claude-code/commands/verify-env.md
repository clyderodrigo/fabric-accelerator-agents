---
description: Read-only health check of a Fabric environment against its declared configuration
---

Delegate to the `verifier` subagent, or if subagents are unavailable, follow the
`verify-environment` skill directly with read-only tools only.

Scope: $ARGUMENTS

If no scope was given, check all three workspaces in order: `dateng`, `data`, `analytics`.

Requirements:

1. State the tenant and the workspaces being checked.
2. Name the tool behind every claim.
3. Include an `UNVERIFIED` section covering Git connection state, connections, and deployment
   pipelines. This section is mandatory even when there is nothing else to report.
4. Make no changes. If you find a problem, report it and stop.
