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
- Every non-trivial T1-T4 code change has visible pre-edit route evidence and at least one bounded child-agent record when tooling is callable.
- A code-changing task without a child passes only with explicit `TOOL_UNAVAILABLE`; `NO_INDEPENDENT_WORK` and `CRITICAL_PATH_ONLY` cannot excuse missing delegation for code changes.

Any critical risk without an explicit floor, or any security, production, migration, or destructive task below its forced floor, is `BLOCKED`.
