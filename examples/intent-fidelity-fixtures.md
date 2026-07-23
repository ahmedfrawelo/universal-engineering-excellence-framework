# Intent Fidelity Fixtures

These examples define the minimum expected route. They are behavioral checks, not permission to expand work.

| Request | Expected route | Must not happen |
| --- | --- | --- |
| “Explain dependency injection.” | `T0`, answer directly, no tools or child agent. | Repository audit or browser control. |
| “Change this one validation message.” | `T1`, single lead by default, focused test. | Dependency inventory, upgrade, or unrelated cleanup. |
| “Open my existing site and verify the dashboard.” | Explicit browser route, user-owned Chrome tab, browser gate. | A second browser, profile, or isolated context. |
| “Fix this reproducible bug.” | Focused reproduction and regression evidence. | Broad modernization unless it directly blocks the fix. |
| “Do not expand scope; update this file only.” | Requested file and direct verification only. | Spawn/audit/refactor because it may be useful. |
