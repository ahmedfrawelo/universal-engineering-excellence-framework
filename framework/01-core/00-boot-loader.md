# Boot Loader

Version: 1.0
Pack: 01-core
Status: Stable
Applies To: every non-trivial engineering task

## Purpose

The Boot Loader is the only UEEF entrypoint that must be read before every non-trivial engineering task. Its job is to prove UEEF is active and decide the smallest useful module set. It must not load the full framework by default.

## Always Load

Only these modules are always loaded:

- `framework/01-core/00-boot-loader.md`
- `framework/01-core/00-core-system.md`

The Master Loader is consulted to select modules, but it must not expand into the full framework unless the task is specifically about auditing, updating, validating, or rebuilding UEEF.

## Token Efficiency Rule

UEEF must improve engineering quality without wasting context. Prefer references to module paths over copying full module content. Load a module's full text only when it is needed to make or verify the decision.

## Boot Sequence

1. Confirm UEEF runtime is active using the compact runtime check.
2. Read the user request and identify task type.
3. Consult `framework/01-core/01-master-loader.md` for module selection.
4. Select the minimum useful module set.
5. Select only relevant quality gates.
6. Proceed with project inspection and implementation.

## Full Framework Loading Is Allowed Only For

- UEEF audit, acceptance review, validation, rebuild, or installation tasks.
- Updating UEEF modules, indexes, scripts, or docs.
- Explicit user request to inspect the full framework.

## Compact Runtime Check

```text
UEEF: ACTIVE/INACTIVE
Runtime: <path>
Loaded: boot-loader, core-system
Selected: <module paths only>
Gates: <gate paths only>
UIUX: YES/NO/NA
Status: READY/BLOCKED
```

## Completion Rule

Final responses should include compact UEEF verification, not repeated framework rules.
