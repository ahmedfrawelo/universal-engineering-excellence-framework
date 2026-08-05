# MCP Detection

Version: 1.4.0
Status: Enforced

## Purpose

Detects available MCP servers and requires only task-relevant servers.

## Required Practice

- Recognize Chrome DevTools, Context7, Playwright, Figma, and Node REPL when exposed.
- Inventory personal/system skills, plugin manifests, plugin-owned `SKILL.md` entrypoints, explicit plugin config, and remote-install markers separately. A cache manifest proves cached installation only. A valid remote-install marker proves installation and registration for that Codex home, but it does not prove enablement, connection health, session selection, or callability.
- Treat `config/preferred-capabilities.json` as the unified preference contract. Its skills manifest is installable missing-only; runtime-managed MCPs and bundled plugins are repaired through the Codex runtime; remote plugins require explicit platform installation. Never route plugin or MCP payloads through the user-skill installer.
- Run `scripts/reconcile-preferred-capabilities.ps1` for current state, or add `-Install` to install missing user skills while reporting non-skill actions without silently changing platform registration.
- For Chrome tasks, require the installed Chrome plugin plus Node REPL browser-client path. Do not route to directly exposed Playwright, Chrome DevTools, or in-app-browser MCPs as substitutes.
- Do not require every MCP for every task.
- Classify every dependency as Mandatory, Recommended, or Optional.
- Emit Environment Ready, Profiles Loaded, Mandatory Dependencies, Recommended Dependencies, Optional Dependencies, Missing Items, Installation Performed, and Validation Result.

## Evidence

- [ ] Current command, path, version, skill, MCP, or runtime evidence is recorded.
- [ ] Profile selection is traceable to task or repository evidence.
- [ ] READY/BLOCKED/WARN matches the dependency policy.

## Failure Conditions

- Mandatory gaps are ignored or hidden.
- The checker claims readiness without current evidence.
- Installed remote plugins or plugin-owned skills are omitted while the report appears complete.
- A fixed universal tool list blocks unrelated work.

## Related Modules

- framework/01-core/01-master-loader.md
- framework/03-runtime/00-runtime-sequence.md
- framework/18-runtime-operations/01-environment-bootstrap/10-dependency-levels.md
