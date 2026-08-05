# Engineering Health Scorecard

Version: 1.3.0

Score applicable dimensions from 0 to 4: 0 missing, 1 degraded, 2 partial, 3 complete with evidence, 4 protected by regression automation.

| Dimension | Evidence |
|---|---|
| Architecture | Boundaries, dependency direction, complexity, folder consistency |
| Security | Authentication, authorization, secrets, injection, abuse, tenant isolation, audit |
| Performance | Rendering, API, database, bundle, network, memory, cache, large data |
| Product quality | UI, UX, accessibility, theme, responsive, design consistency |
| Reliability | Errors, retries, idempotency, observability, recovery, rollback |
| Maintainability | Naming, typing, duplication, debt, ownership, future-proofing |
| Delivery | Tests, documentation, developer experience, release readiness |

Every applicable dimension must score at least 3 and total at least 80 percent. Any critical security, accessibility, production, contract, or performance regression forces FAIL regardless of average.
