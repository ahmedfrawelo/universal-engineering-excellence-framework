# Application Evolution And Runtime Performance Specification

## Outcome

Every project task must preserve a fast, current, maintainable application: remote state reconciles without page reload when freshness matters; applicable code and resources load lazily without waterfalls; frontend and backend performance are measured; legacy code is refactored through behavior-preserving stages; and technology currency is inspected before substantial work.

## Requirements

1. Live updates patch or invalidate the smallest authorized scope and preserve route, shell, filters, selection, focus, scroll, and unsaved work.
2. Full page reload is prohibited for ordinary data reconciliation. It is allowed only for an unrecoverable bootstrap, incompatible deployed client, or security boundary change with an explicit reason.
3. Every route, feature, component, asset, query, integration, and background capability receives a lazy/eager decision based on criticality, dependency graph, UX, security, and measured cost.
4. Lazy loading must avoid request waterfalls, duplicate chunks, layout shift, inaccessible loading states, and hidden cold-start work on the first request.
5. Frontend and backend changes define measurable latency, rendering, query, payload, memory, concurrency, cache, and burst budgets where applicable.
6. Legacy refactoring starts with a repository map, behavior baseline, dependency graph, ownership boundaries, dead-code evidence, and risk classification.
7. Refactoring proceeds in reversible slices with characterization tests, compatibility seams, migration notes, telemetry, rollback, and consumer verification.
8. Dead code is removed only after static references, dynamic loading, reflection, configuration, routes, jobs, plugins, generated code, and production telemetry are checked.
9. Project inspection identifies manifests, lockfiles, runtimes, frameworks, SDKs, compilers, databases, infrastructure images, deprecated APIs, and end-of-life technology.
10. Safe compatible upgrades may be applied with tests. Major, runtime, schema, security-sensitive, or operationally risky upgrades require an impact report and explicit user decision before mutation.
11. Upgrade recommendations include current and target versions, support status, breaking changes, migration path, security impact, performance impact, rollback, owner, and verification commands.
12. Completion requires current source evidence, applicable automated checks, realistic runtime evidence, and no known regression hidden behind a successful build.

## Traceability

- Runtime freshness and performance: packs 47 and 56.
- Legacy refactoring and technology currency: pack 61.
- Security and zero regression: packs 49 and 55.
- Quality enforcement: gate 34, checklist 43, template 30, and cross-platform contract tests.
