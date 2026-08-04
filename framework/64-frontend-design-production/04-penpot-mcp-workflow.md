# Penpot MCP Workflow

Penpot is preferred for new UEEF-controlled design-canvas work. An explicit supplied Figma artifact remains on Figma unless the user requests migration.

The preferred endpoint is `http://localhost:4401/mcp` under `mcp_servers.penpot`. Live use requires all of:

Penpot is disabled by default so ordinary Codex/UEEF startup never waits for an absent local bridge. For an explicitly selected Penpot task, start the local bridge, connect the Penpot plugin, then run `scripts/set-penpot-mcp-state.ps1 -State Enable`. The command refuses non-loopback endpoints and refuses activation while port 4401 is unreachable. After the task, `-State Disable` restores the fast default. `required = false` prevents an optional design tool from blocking Codex startup.

- the MCP entry is configured;
- the MCP endpoint is reachable;
- the Penpot plugin is connected to the bridge;
- the intended Penpot design file is selected;
- a task-relevant read or mutation succeeds.

If any item is missing, report Penpot as unavailable or pending and fall back to `DESIGN.md`, repository evidence, and rendered verification. Never claim that Penpot was used merely because it is listed in a manifest.
