# Project Modernization And Runtime Checklist

- [ ] Repository map, ownership boundaries, entrypoints, dynamic loading, generated code, and deployment paths inspected.
- [ ] Current behavior, architecture, security, performance, dependency, and operational baselines recorded.
- [ ] Refactor slices are reversible and protected by characterization or contract tests.
- [ ] Dead-code candidates check static, dynamic, reflective, configured, generated, job, plugin, and runtime consumers.
- [ ] Technology inventory covers packages, runtimes, frameworks, SDKs, databases, containers, CI, and deprecated APIs.
- [ ] Current and target versions, support status, breaking changes, migration, security, performance, and rollback documented.
- [ ] Major or high-risk upgrades wait for explicit user approval; safe compatible upgrades remain bounded and tested.
- [ ] Every non-trivial load boundary has an eager/lazy/preload/prefetch/defer decision and measured evidence.
- [ ] Lazy states reserve layout, remain accessible, recover from failure, and avoid waterfalls or duplicate chunks.
- [ ] Mutable remote state updates without page reload and preserves route, shell, focus, scroll, filters, selection, and edits.
- [ ] Realtime authorization, tenant isolation, ordering, deduplication, gaps, reconnect, backpressure, and burst load verified.
- [ ] Frontend and backend budgets compare baseline with final state.
- [ ] Rollout, rollback, telemetry, compatibility windows, and retirement criteria are explicit.
