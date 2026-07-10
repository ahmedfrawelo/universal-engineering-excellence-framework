# Runtime Sequence

Version: 1.0
Pack: 03-runtime
Status: Stable
Applies To: runtime execution

## Purpose

The runtime sequence defines how UEEF is applied without wasting context. It prioritizes activation proof, selective loading, targeted inspection, and compact verification.

## Sequence

1. Load `framework/01-core/00-boot-loader.md`.
2. Load `framework/01-core/00-core-system.md`.
3. Confirm UEEF runtime is active.
4. Use `framework/01-core/01-master-loader.md` only to select relevant modules.
5. Load the minimum useful module set for the task.
6. Inspect the project and current implementation path.
7. Plan edits for non-trivial work.
8. Apply selected quality gates before final response.
9. Return compact UEEF verification.

## Compact Runtime Check

```text
UEEF: ACTIVE/INACTIVE
Runtime: <path>
Loaded: boot-loader, core-system
Selected Modules: <paths or count>
Quality Gates: <paths or count>
UI UX Pro Max: YES/NO/NA
Status: READY/BLOCKED
```

If status is `BLOCKED`, do not edit project files.

## Loading Rules

- Normal coding task: load only relevant modules.
- Frontend UI task: frontend, UI, UX, accessibility, performance, and relevant quality gates.
- Backend API task: architecture, backend, API, security, performance, database only if needed, and relevant quality gates.
- Documentation task: documentation and review modules only.
- UEEF maintenance task: full framework loading is allowed only when the task requires it.

## Final Verification

Use compact final verification:

```text
UEEF: ACTIVE
Loaded: boot-loader, core-system
Selected: <task-specific modules>
Gates: <task-specific gates>
UIUX: YES/NO/NA
```

Avoid repeating full framework rules in every response.

## UI Preflight Evidence

For UI work, implementation must not begin until the assistant records:

```text
Existing theme inspected:
Light theme available:
Dark theme available:
System theme available:
Theme tokens found:
Radius tokens found:
Responsive system found:
Overlay system found:
Existing dropdown/panel behavior inspected:
Security modules selected:
Performance modules selected:
UI UX Pro Max checked:
```

The final user-facing verification still uses only the compact required labels. The detailed evidence belongs in the plan, task record, tests, or review artifacts, not in the `Loaded` line.

## Design Governance Preflight

For design-system or UI work, also record:

```text
Existing project UI searched:
Design-system source found:
Component registry searched:
Shared components searched:
Shared services searched:
Pattern library searched:
Reuse or extension decision:
Token families identified:
Icon family identified:
Typography roles identified:
Design governance modules selected:
```
