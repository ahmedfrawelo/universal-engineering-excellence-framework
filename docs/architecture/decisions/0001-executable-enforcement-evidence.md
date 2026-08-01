# ADR 0001: Executable enforcement evidence

Status: Accepted
Date: 2026-08-01

## Context

UEEF quality gates described strong completion contracts, but a generic PASS record could still be based on placeholders, qualitative claims, omitted domains, or unverifiable narrative evidence. Architecture and file-placement rules also lacked project-configurable executable checks.

## Decision

Use `config/enforcement-registry.json` as the quality-gate-to-domain contract. T2+ tasks generate a complete artifact with `scripts/new-task-evidence.ps1` and validate it with `scripts/validate-task-evidence.ps1`.

Architecture work also requires the file-organization domain. Project boundaries are declared in `.ueef/architecture-policy.json`, with the repository policy serving as UEEF's own configuration. Architecture and file-organization reports must return PASS; missing policy, warnings, or manual narrative cannot be promoted automatically.

Evidence provenance is typed: commands and tests record time and exit code, reviews identify a reviewer, and file artifacts provide a matching SHA-256. Performance records include numeric baseline, remeasurement, and budget values with units.

## Consequences

- Completion claims become reproducible and fail closed when evidence is missing.
- Projects selecting Architecture must define ownership and dependency direction explicitly.
- Public-boundary changes require an ADR change according to the configured policy.
- Existing T0/T1 work remains lightweight and does not require a task-evidence artifact.

## Rejected alternatives

- Keep checklist-only enforcement: rejected because it cannot distinguish verified execution from confident prose.
- Infer arbitrary project architecture without policy: rejected because it would produce false positives and false PASS results.
- Require every gate for every task: rejected because it violates proportional routing.

## Amendment: authorized loopback browser recovery

Browser recovery may expose a loopback-only Chrome DevTools endpoint as `AUTHORIZED_LOOPBACK_LAST_RESORT`, but only after every configured same-tab control stage has recorded failure evidence and the user explicitly authorizes the emergency path. A readiness probe must return `READY_LAST_RESORT`; incomplete stage evidence returns `PRIOR_STAGES_INCOMPLETE`. The adapter may attach only to the same existing page target and cannot launch Chrome, create a profile/context, bind outside loopback, or inspect cookies, storage, passwords, history, or profile files. Stricter host, plugin, and installed-skill rules retain precedence.
