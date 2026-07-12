# Final Response Format

Version: 1.0
Pack: 03-runtime
Status: Stable
Applies To: final responses

## Purpose

This module defines compact final UEEF verification. It prevents old verbose output and avoids claiming that selector modules were loaded as always-loaded runtime modules.

## Required Compact Format

```text
UEEF Verification
UEEF: ACTIVE / INACTIVE
Loaded: boot-loader, core-system
Selected: <task-specific module paths or compact count>
Gates: <task-specific gate paths or compact count>
Tools: <checked tools, compact>
Skills: <checked skills, compact>
UIUX: YES / NO / NA
Status: PASS / PARTIAL / ACTIVE / BLOCKED
```

## Strict Rules

- `Loaded` must only list always-loaded modules: `boot-loader, core-system`.
- The exact valid line is `Loaded: boot-loader, core-system`.
- Reading or using `UEEF-LOADER.md`, `AGENTS.md`, `master-loader`, `master-index`, `runtime-sequence`, or `activation-proof` does not make those files loaded modules.
- Do not list `master-loader`, `master-index`, `runtime-sequence`, or `activation proof` under `Loaded` for normal tasks.
- The Master Loader is a selector. If used, mention its output under `Selected`, not `Loaded`.
- Use module paths or compact counts under `Selected`.
- Keep quality gates under `Gates`.
- Keep UI UX Pro Max as `UIUX: YES`, `NO`, or `NA`.
- Do not repeat full framework rules in the final response.
- `BLOCKED` is valid only for an external or user-only impasse after no meaningful local work remains. Failed code, tests, save contracts, or verification gates use `ACTIVE` or `PARTIAL` while fixes continue.
- Never emit a final answer whose only outcome is "incomplete", "not completed", "no complete result", or equivalent while a goal remains active. Use commentary and continue execution.
- Goal-task finalization requires `GoalStatus: COMPLETE`, a valid external `BLOCKED`, or an explicit user request for status-only reporting.

## Bad Old Format

Do not use:

```text
Loaded: loader, core-system, master-loader, master-index
Loaded: boot-loader, core-system, master-loader
```

## Correct Example

```text
UEEF Verification
UEEF: ACTIVE
Loaded: boot-loader, core-system
Selected: framework/10-frontend/00-frontend-architecture.md, framework/14-ui/00-ui-excellence.md
Gates: activation, UI, UX, accessibility, performance
Tools: shell, test runner
Skills: UI UX Pro Max checked
UIUX: YES
Status: PASS
```
