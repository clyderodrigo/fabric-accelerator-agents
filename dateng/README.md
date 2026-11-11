# `dateng/` - definition library for the DatEng workspace

Item definitions deployed by the agent through the `fabric-core` MCP server. Each immediate
child is an item folder named `<displayName>.<ItemType>` carrying a `.platform` file.

No Git sync. No connections required at sync time — connections are supplied by the human and
injected into definitions at creation time (runbook 06).

Items here are the source of truth for the agent's `create_item` payloads.