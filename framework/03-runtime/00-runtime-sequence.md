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
4. Record the autonomy boundary: ordinary scoped work proceeds automatically; platform and high-impact confirmations remain explicit.
5. If the request expands, revise the plan and continue implementation. Treat release readiness as a separate decision.
6. Use `framework/01-core/01-master-loader.md` only to select relevant modules.
7. Load the minimum useful module set for the task.
8. Evaluate named, installed, project-local, and UEEF skill candidates; select the minimal skill chain.
9. Inspect the project and current implementation path.
10. Plan edits for non-trivial work.
11. Apply selected quality gates before final response.
12. Return compact UEEF verification.

## Compact Runtime Check

```text
UEEF: ACTIVE/INACTIVE
Runtime: <path>
Loaded: boot-loader, core-system
Selected Modules: <paths or count>
Quality Gates: <paths or count>
UI UX Pro Max: YES/NO/NA
RuntimeStatus: READY/BLOCKED
DeliveryStatus: IN_PROGRESS/PASS/PARTIAL
GoalStatus: ACTIVE/BLOCKED/COMPLETE
```

Do not edit project files only when `RuntimeStatus` is `BLOCKED`. A partial verification, failed implementation gate, regression, or incomplete delivery keeps `GoalStatus: ACTIVE` and permits continued fixes.

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
Design engineering skill route:
Specialist motion skills checked:
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

## Engineering Guardian Preflight

Every non-trivial task must also record:

```text
Affected baseline recorded:
Regression monitors selected:
Security and performance blockers checked:
Design and accessibility impact checked:
Architecture and dependency impact checked:
Automatic improvement opportunities reviewed:
Self-criticism completed:
Final Guardian Gate:
```

## Environment Bootstrap Preflight

Environment Bootstrap runs before project inspection and emits:

```text
Environment Ready:
Profiles Loaded:
Mandatory Dependencies:
Recommended Dependencies:
Optional Dependencies:
Missing Items:
Installation Performed:
Validation Result:
```

`READY` is valid only when all selected Mandatory dependencies pass. A Mandatory failure is `BLOCKED`; a Recommended failure is `READY_WITH_WARNINGS`; Optional gaps remain non-blocking.

## Browser Session Preflight

For browser tasks, implementation must not begin until the assistant records:

```text
User-owned browser/profile verified:
Extension/tab-claim authorization granted:
Exact user.openTabs() object claimed:
Existing window state preserved:
Target tab and domain verified:
Control provenance: EXISTING_EXTENSION_TAB / BLOCKED
Control channel: READY / THREAD_CONTROL_CHANNEL_DEGRADED
Verification evidence: LOCAL / VERIFIED_HANDOFF / PENDING
Separate automation surface created: NO / BLOCKED
Banner classification: ABSENT / VERIFIED_EXISTING_TAB / UNVERIFIED_BLOCKED
Signed-in state verified when required:
Browser session gate: PASS / PARTIAL_VISUAL_GATE / BLOCKED
```

For data-backed UI tasks, also record:

```text
Skeleton system selected:
Existing loading pattern searched:
Skeleton reused or updated:
State matrix defined:
Skeleton parity verified:
Layout shift checked:
Skeleton gate: PASS / BLOCKED
```

For design intelligence tasks, also record:

```text
Design source of truth identified:
Design extraction run:
Fonts and assets classified:
Colors and theme mappings classified:
Icons and stroke system classified:
Typography and sizing classified:
Missing roles and recommendations documented:
Design intelligence gate: PASS / BLOCKED
```

For broad audit or release work, also record:

```text
Continuous assurance audit run:
Security hygiene checked:
Generated artifacts checked:
Script syntax checked:
Release/runtime parity checked:
Residual risks recorded:
Continuous assurance gate: PASS / BLOCKED
```

For data-grid or data-platform work, also record:

```text
Existing table baseline inspected:
Query contract defined:
Server capabilities allowlisted:
Pagination/filter/sort/aggregate semantics verified:
Backend/API/database contract verified:
Performance budget verified:
    Realtime/refresh contract verified:
    Live refresh no-reload proof verified:
    Realtime security and burst-performance proof verified:
    Advanced grid capabilities verified:
    Production data delivery controls verified:
    Data grid platform gate: PASS / BLOCKED
    Shell baseline extracted:
    Navigation/header contracts verified:
    Shell motion/responsive/accessibility verified:
    Shell visual/performance gate: PASS / BLOCKED
    First-viewport composition reviewed:
    Density and responsive composition verified:
    Visual evidence gate: PASS / BLOCKED
```

Cookies, passwords, local storage, tokens, and profile stores must never be inspected.

## Agent and Model Routing Preflight

For skill, workflow, and UEEF-runtime work, also record:

```text
Skill candidates:
Selected skill chain:
Skipped skills and reason:
Red flags checked:
Skill protocol gate:
```

Every task records:

```text
Task complexity score:
Risk floor:
Agent route tier:
Model capability class:
Model override or inherited:
Agent topology:
Delegation benefit verified:
Independent workstreams:
Agent capability available:
Named model availability verified:
Context packet bounded:
Escalation triggers active:
Independent verification required:
Agent model routing gate: PASS / BLOCKED
```

Routing is mandatory; child-agent spawning is conditional. The lead agent is the correct single-agent topology when delegation would increase tokens or latency.
