# Documentation

Version: 1.0  
Pack: 18-documentation  
Status: Stable  
Applies To: tasks where documentation materially affects the outcome

## Purpose

This module establishes the enforceable **documentation** contract for accurate, discoverable, and maintainable engineering knowledge. It exists to turn that concern into explicit decisions, safeguards, and completion evidence.

## Apply When

- The request names documentation or changes behavior governed by it.
- Repository inspection finds an affected boundary, convention, artifact, or risk.
- A reviewer cannot prove the outcome without making the documentation decision explicit.

## Required Decisions

1. State the observable outcome and owner for documentation.
2. Document decisions, contracts, commands, and failure recovery next to their owners.
3. Record assumptions, rejected alternatives, and the condition that would require revisiting the decision.

## Documentation Placement Rules

- Put contributor workflow in `CONTRIBUTING.md`.
- Put user onboarding in `README.md`, `QUICK_START.md`, or `INSTALL.md` depending on audience.
- Put runtime/source/sync behavior in `docs/` beside existing runtime documentation.
- Put reusable task examples under `examples/`.
- Put enforceable domain contracts inside the owning `framework/<pack>/` file.
- Put generated or task-local proof under `.ueef/`; do not make generated evidence the authoritative source of policy.

## Documentation Quality Bar

Good UEEF documentation is executable by an agent:

1. It states when the guidance applies.
2. It names the owning file, script, module, or runtime boundary.
3. It gives exact commands where commands are expected.
4. It states what output or behavior proves success.
5. It states what remains out of scope or unsafe.

Avoid vague claims such as "make it better", "ensure quality", or "run tests" without naming the relevant check.

## Staleness Controls

- Prefer links to canonical files over duplicating long policy text.
- Mention version-sensitive facts only when they are checked in the current task.
- Keep source validation separate from installed runtime activation.
- Mark legacy/generated artifacts clearly so agents do not treat them as active owners.

## Mandatory Safeguards

- Remove stale instructions and avoid duplicating authoritative guidance.
- Reuse the repository's existing owner, pattern, and automation before adding a parallel mechanism.
- Keep failure behavior explicit, bounded, diagnosable, and recoverable in proportion to risk.

## Required Evidence

- Direct evidence that the documentation outcome works in the changed context.
- link, command, and example validation against the current implementation.
- A focused regression check for the nearest behavior that could be broken.

## Failure Conditions

- The documentation decision is implicit, ownerless, or contradicted by the implementation.
- Evidence demonstrates only intent, compilation, or a happy path when stronger proof is practical.
- Residual risk is hidden, unbounded, or handed off without an owner and trigger.
- Documentation adds a claim that cannot be verified from current source, command output, runtime status, or an explicitly named external source.

## Related Modules

- ../01-core/01-master-loader.md
- ../03-runtime/00-runtime-sequence.md
- ../27-quality-gates/00-quality-gate-system.md

## Completion Contract

Pass only when the decision, implementation, evidence, and remaining risk agree. Otherwise report the exact failed condition and required next action.
