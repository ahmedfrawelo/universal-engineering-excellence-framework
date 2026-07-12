# Agent and Model Routing Gate

Pass when every applicable item is true:

- Task complexity and risk were classified from current evidence.
- The selected model meets the capability and risk floor.
- The topology is the smallest one with a positive delegation benefit.
- Parallel topology is backed by at least two independently owned workstreams.
- Named model overrides were verified as available; unavailable overrides fall back to capability-only routing.
- Child ownership and context packets are bounded and non-overlapping.
- Critical-path work remains with the lead.
- Escalation and fallback rules were honored.
- Agents were closed after integration.
- Verification strength matches risk and independent review exists for T4.
- The route schema is current, its reasoning ceiling is `medium`, and no emitted reasoning value exceeds that ceiling.
- T2-T4 agent use is evidenced when a bounded independent stream exists; otherwise a valid single-agent reason is recorded.

Any critical risk without an explicit floor, or any security, production, migration, or destructive task below its forced floor, is `BLOCKED`.
