# Autonomy and Confirmation Policy

UEEF agents operate autonomously for ordinary work that the user has placed in scope.

## Proceed Without Agent Confirmation

- Inspect repository files, source code, configuration, logs, and local project state.
- Edit scoped project files, run formatters, builds, type checks, tests, linters, and local development commands.
- Create focused implementation artifacts, update project documentation, and run non-destructive diagnostics.
- Use the normal engineering steps required to complete a user-requested change rather than stopping for routine approval.
- Start, reuse, inspect, and stop scoped local development services as required for implementation and verification. Reuse an existing healthy service before starting another process.

## Local Command Prompts

- The agent must not ask the user whether it should run normal project commands or local development services.
- A command prompt shown by Codex is a platform safety confirmation for the process itself, not an agent decision or a UEEF question.
- When a platform command prompt appears, report the exact service or command being started only if the user asks. Do not misrepresent it as a task blocker.
- Never create duplicate long-running services just to avoid a command prompt; inspect and reuse the existing service when possible.

## Platform and High-Impact Boundaries

- Platform-level approval prompts cannot be bypassed by repository files or agent instructions. When the platform offers a persistent approval option, the user chooses it directly.
- Ask before sending external messages, publishing/deploying, purchases, account or permission changes, accepting browser permission dialogs, destructive data operations, or actions outside the stated scope.
- Never ask a redundant question when the user has already given precise approval for the same action in the current task.

## User-Facing Behavior

Do not narrate routine approval requests. Proceed and report evidence after completion. When a platform or high-impact confirmation is required, name the exact action and why it cannot be completed without that confirmation.
