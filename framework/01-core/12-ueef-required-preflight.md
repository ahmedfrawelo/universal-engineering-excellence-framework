# UEEF Required Preflight

Version: 1.0
Pack: 01-core
Status: Stable
Applies To: every non-trivial engineering task

## Mandatory Rule

Before every non-trivial engineering task, the AI must run a compact UEEF Preflight Check. The AI must not start implementation until it can produce `UEEF: ACTIVE` with evidence.

For an existing chat, the preflight is refreshed at the beginning of every user turn. A prior turn's loaded state, tool choice, browser choice, or activation result is stale until the current loader and runtime status are checked again.

## Always Loaded

Only these are always loaded:

- `framework/01-core/00-boot-loader.md`
- `framework/01-core/00-core-system.md`

## Selector Rule

Use `framework/01-core/01-master-loader.md` only to select relevant modules. Never report it as loaded.

Reading a file is not the same as loading it as an always-loaded runtime module. `UEEF-LOADER.md`, `AGENTS.md`, `master-loader`, `master-index`, `runtime-sequence`, and `activation-proof` must never appear in `Loaded`.

## Compact Runtime Check

For non-trivial work, `scripts/get-ueef-task-preflight.ps1` is the optional single entrypoint for the Pack 58 route, proportional capability profile, workflow decisions, and conditional health evidence. It is read-only and advisory: activation remains mandatory, and selected capabilities are never claimed callable without task-time verification.

```text
UEEF: ACTIVE / INACTIVE
Loaded: boot-loader, core-system
Selected: <task-specific modules>
Gates: <task-specific gates>
UIUX: YES / NO / NA
Status: READY / BLOCKED
```

If UEEF cannot be verified, report:

```text
UEEF: INACTIVE
Reason:
Required action:
```

If status is `BLOCKED`, do not edit project files.

## Final Response Rule

Use the compact final format from `framework/03-runtime/10-final-response-format.md`. Never use the old verbose loaded-modules format.

Invalid examples:

```text
Loaded: loader, core-system, master-loader, master-index
Loaded: boot-loader, core-system, master-loader
```
