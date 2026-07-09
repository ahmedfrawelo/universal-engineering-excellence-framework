# UEEF Required Preflight

Version: 1.0
Pack: 01-core
Status: Stable
Applies To: every non-trivial engineering task

## Mandatory Rule

Before every non-trivial engineering task, the AI must run a compact UEEF Preflight Check. The AI must not start implementation until it can produce `UEEF: ACTIVE` with evidence.

## Always Loaded

Only these are always loaded:

- `framework/01-core/00-boot-loader.md`
- `framework/01-core/00-core-system.md`

## Selector Rule

Use `framework/01-core/01-master-loader.md` only to select relevant modules. Do not report it as loaded unless the task specifically required reading the full selector content.

## Compact Runtime Check

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
