# Master Loader

UEEF must be loaded before every engineering task.

## Runtime Sequence

1. Understand the user's request and identify the true requested end state.
2. Inspect the project before editing.
3. Detect the stack, package manager, runtime, database, deployment model, tests, linters, and build tools.
4. Detect architecture explicitly: module boundaries, dependency direction, data ownership, UI composition, service boundaries, and deployment topology.
5. Detect installed MCPs, installed skills, browser automation, database access, and cloud integrations.
6. Use all relevant MCPs, tools, and skills that are available for the task.
7. Load relevant UEEF modules from `framework/MASTER_INDEX.md`.
8. Apply UI UX Pro Max whenever touching UI or user-facing flows.
9. Produce a plan before editing, explain what will change, and explain what will not be touched.
10. Edit within existing architecture, preserve clean architecture, and avoid random standalone files.
11. Avoid duplicated code, duplicated UI, duplicated validation, and duplicated architecture patterns.
12. Avoid unnecessary over-rendering by checking render triggers, state scope, memoization boundaries, and data fetching behavior.
13. Prioritize performance in frontend, backend, database, and API work.
14. Prioritize security by default.
15. Design for future scalability and extensibility.
16. Run or recommend lint, typecheck, build, tests, security checks, and manual verification as appropriate.
17. Apply Quality Gates before finishing.
18. Provide a final engineering review with evidence and limitations.

## Completion Standard

Completion requires current evidence. The assistant must not claim completion from intent, partial progress, or a narrow check that does not cover the requested scope.
