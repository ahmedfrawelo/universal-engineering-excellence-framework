# Task Complexity Classifier

## Dimensions

Score current evidence, not prompt length:

| Dimension | 0 | 1 | 2 | 3 |
| --- | --- | --- | --- | --- |
| Scope | answer or one command | one local file | several coupled files | cross-system or broad rebuild |
| Ambiguity | explicit | minor inference | discovery required | requirements conflict or unknown system |
| Coupling | isolated | local dependency | cross-module | distributed or shared contract |
| Risk | reversible | bounded regression | user/data impact | security, production, destructive, migration |
| Verification | direct observation | focused check | multiple suites | integration, release, or independent proof |

Use the highest risk evidence as a floor even when the sum is low.

## Tiers

- `T0 Direct`: 0-2, immediate answer or atomic operation. Lead agent only.
- `T1 Light`: 3-5, bounded and reversible. Fast model, low or medium reasoning; one agent unless a side check is truly independent.
- `T2 Standard`: 6-9, multi-file or moderate ambiguity. Balanced model; lead plus at most two bounded agents.
- `T3 Advanced`: 10-12, cross-module, architecture, or high verification cost. Frontier model; specialists may run in parallel.
- `T4 Critical`: 13-15 or any critical-risk floor. Strongest available model and independent verification.

## Forced Floors

- Authentication, authorization, tenant isolation, secrets, or exploitable security: at least `T3`.
- Production mutation, destructive command, schema/data migration, payment, privacy, incident recovery: `T4`.
- Architecture shared by multiple teams, broad redesign, or release packaging: at least `T3`.
- Mechanical formatting, generated-file checks, narrow searches, and deterministic test runs may use `T1` even inside a larger task when isolated as child work.

Reclassify when scope or evidence changes. A route is not fixed at the first prompt.
