# Autonomy and Confirmation Policy

UEEF agents operate autonomously for ordinary work that the user has placed in scope. The default is professional execution, not permission-seeking.

## Scope Wins

User-requested scope overrides continuation, delegation, autonomous audits, inventories, and modernization. Expand only when the user explicitly asks or a direct blocker prevents verification of the requested outcome.

## Proceed Without Agent Confirmation

- Inspect repository files, source code, configuration, logs, and local project state.
- Edit scoped project files, run formatters, builds, type checks, tests, linters, and local development commands.
- Create focused implementation artifacts, update project documentation, and run non-destructive diagnostics.
- Use the normal engineering steps required to complete a user-requested change rather than stopping for routine approval.
- Infer the best safe scoped implementation from current source, project graph, tests, and existing patterns when a reversible assumption is enough to proceed.
- Run required repository graph status/build/query, selected skills, model-routing disclosure, direct verification, fresh-review, completion audit, and runtime sync automatically when they are required by the route or by changed source.
- Start, reuse, inspect, and stop scoped local development services as required for implementation and verification. Before every start, inspect the project's documented service owner, expected port/URL, listener, and health response, or run `scripts/get-local-service-readiness.ps1`. `REUSE_EXISTING` requires reuse; only `START_ALLOWED` permits one new scoped process. `OCCUPIED_UNVERIFIED` and `EXISTING_UNHEALTHY` require diagnosis and forbid another process or alternate port.

## Local Command Prompts

- The agent must not ask the user whether it should run normal project commands, local development services, graph checks, selected verification, or required review.
- A command prompt shown by Codex is a platform safety confirmation for the process itself, not an agent decision or a UEEF question.
- When a platform command prompt appears, report the exact service or command being started only if the user asks. Do not misrepresent it as a task blocker.
- Never create duplicate long-running services or select another port to avoid a conflict, command prompt, or failed health check. A new server is allowed only after current evidence proves no usable instance exists for that project.

## Platform and High-Impact Boundaries

- Platform-level approval prompts cannot be bypassed by repository files or agent instructions. When the platform offers a persistent approval option, the user chooses it directly.
- Ask only before sending external messages, publishing/deploying when not already requested, purchases, account or permission changes, accepting browser permission dialogs that require the user's platform action, destructive data operations, broad cleanup/reset/delete, or actions outside the stated scope.
- Never ask a redundant question when the user has already given precise approval for the same action in the current task.
- Do not ask for preferences or permission when the project has a clear owner, established convention, reversible safe default, or required UEEF gate. Choose the professional option and document the evidence.

## User-Facing Behavior

Do not narrate routine approval requests. Proceed and report evidence after completion. When a platform or high-impact confirmation is truly required, name the exact action, the blocking evidence, and why no safe reversible assumption or automatic recovery can complete it.
