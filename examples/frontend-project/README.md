# Frontend Project Example

This example shows the minimum UEEF workflow for a frontend change such as a route, page, component, loading state, data table, form, shell, or visual interaction.

## Scenario

User request:

```text
Make the project dashboard load faster and keep the layout stable.
```

## Route

- Intent: frontend performance and UX behavior.
- Tier: T2 for a bounded existing surface; T3 if shared components, shell routing, authentication flow, or visual design system behavior changes.
- Agent route: lead agent only unless a separate review lane has clear independent value.
- Browser: use the allowed Chrome path only when live DOM, interaction, or visual proof is required.

## Relevant modules

Load only modules that affect the task:

- `framework/08-performance/00-performance-philosophy.md`
- `framework/10-frontend/01-frontend-task-modes.md`
- `framework/14-ui/00-ui-system.md`
- `framework/15-ux/00-ux-system.md`
- `framework/16-accessibility/00-accessibility-system.md`
- `framework/17-testing/00-testing-and-qa.md`

## Implementation checklist

1. Inspect `git status --short` and preserve unrelated work.
2. Find the route owner, component owner, data-loading owner, shared UI primitives, and existing tests.
3. Decide whether SSR, SSG, streaming, prefetch, lazy load, defer, memoization, or virtualization is relevant. Record why skipped options were skipped.
4. Measure the constrained path: route load time, network waterfall, bundle/chunk size, long tasks, layout shift, or interaction latency.
5. Fix the bottleneck without breaking accessibility, focus, keyboard flow, reduced motion, RTL/LTR, or loading/error states.
6. Verify with unit/component tests and browser evidence when the task requires visual or interaction proof.

## Evidence example

```powershell
.\scripts\new-task-evidence.ps1 -TaskId dashboard-load-performance -Tier T2 -SelectedDomain performance,uiux,accessibility,testing -OutputPath .\.ueef\evidence\dashboard-load-performance.json
.\scripts\validate-task-evidence.ps1 -Tier T2 -SelectedDomain performance,uiux,accessibility,testing -EvidencePath .\.ueef\evidence\dashboard-load-performance.json
```

The evidence must include:

- baseline and post-change measurement with units;
- before/after user-visible behavior;
- browser or screenshot proof when visual correctness matters;
- test commands and exit codes.

## Completion rule

Do not claim complete because the component renders. Completion requires the requested user-visible behavior, performance constraint, and nearest regression risks to be verified.
