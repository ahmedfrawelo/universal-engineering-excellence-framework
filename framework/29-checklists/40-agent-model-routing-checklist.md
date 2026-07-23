# Agent and Model Routing Checklist

- [ ] Route tier recorded.
- [ ] Visible pre-command route line recorded.
- [ ] Child agent identity and bounded ownership recorded when spawned.
- [ ] No-spawn reason is explicit: NO_INDEPENDENT_WORK, CRITICAL_PATH_ONLY, or TOOL_UNAVAILABLE.
- [ ] Risk floor checked.
- [ ] Model capability selected or inherited intentionally.
- [ ] Delegation benefit is positive.
- [ ] Critical path identified.
- [ ] Child tasks have disjoint ownership and bounded context.
- [ ] Fan-out is limited to independent work streams.
- [ ] Independent workstream count is recorded before parallel routing.
- [ ] Agent and named-model availability are verified from current tools.
- [ ] Failed or ambiguous work escalated.
- [ ] Completed agents closed.
- [ ] Verification matches the route and risk.
