---
description: Compare the repo's declared Fabric configuration against live tenant state
---

Delegate to the `drift-checker` subagent, or if subagents are unavailable, follow the `drift-check`
skill directly with read-only tools only.

Scope: $ARGUMENTS

If no scope was given, check all three workspaces.

Requirements:

1. Two sources: `fabric/declared-environment.yaml` for platform state, and the repo tree's
   `.platform` files for item inventory.
2. Classify every difference as `MISSING_IN_TENANT`, `EXTRA_IN_TENANT`, `MISMATCH`, or
   `UNVERIFIABLE`. One class per finding.
3. Include the mandatory `UNVERIFIABLE` block for Git state, connections, and deployment pipelines.
4. Do not remediate anything. No creates, deletes, role changes, or definition updates.
5. End with exactly one recommended next action.
