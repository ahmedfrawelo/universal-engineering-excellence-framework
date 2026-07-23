# Agent and Model Orchestration

Runtime routing for every task through a complexity, risk, and delegation-benefit decision. The pack selects the least expensive capable model and the smallest useful agent topology without lowering verification quality.

Every task is routed. A trivial task may remain on the main agent because it is already an agent and spawning a child would add token and latency overhead.

`T1` defaults to a single agent unless independent work has a concrete benefit. `medium` is the economical reasoning default, not a hard ceiling: recorded high-ambiguity `T3/T4` routes may use a platform-supported higher level.
