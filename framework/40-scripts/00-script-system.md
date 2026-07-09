# Scripts

Version: 1.0  
Pack: 40-scripts  
Status: Stable  
Applies To: Engineering teams, AI coding assistants, and maintainers

## Purpose

Scripts provides the minimum enforceable operating guidance for this pack so the pack is not only a folder label. It defines how an assistant should reason, what it must protect, and what evidence should exist before completion.

## When To Use This Module

Use this module when project inspection shows that the task touches the pack responsibility, when a user request names this concern, or when risk analysis indicates the concern could affect quality, maintainability, security, performance, user experience, or production readiness.

## Core Principles

- Load this pack only when relevant to the task.
- Prefer project evidence over generic assumptions.
- Respect existing architecture, naming, design system, tests, and delivery workflow.
- Optimize for long-term clarity and safe change.
- Keep guidance technology-neutral unless the pack is technology-specific.

## Mandatory Rules

- Inspect related files before proposing changes.
- Avoid duplicate implementations, duplicate documentation, and duplicate UI.
- Do not create unowned standalone files.
- Preserve secrets, credentials, and user data.
- Make limitations explicit when verification cannot be completed.

## Decision Guidance

1. Identify the user outcome this pack supports.
2. Identify the existing project pattern for this responsibility.
3. Compare the simplest safe option with the most scalable option.
4. Choose the option that satisfies the requested end state without avoidable technical debt.
5. Validate with the strongest practical evidence.

## Anti-Patterns

- Treating the pack as optional when the task clearly touches it.
- Applying technology-specific advice to an unrelated stack.
- Adding abstractions without reducing real complexity.
- Completing work without checking the relevant quality gate.

## Review Checklist

- The pack was loaded for a real reason.
- Existing conventions were inspected.
- The chosen approach has a clear owner and location.
- Verification matches the risk level.
- The final response states evidence and residual limitations.

## Quality Gate

The module passes when the assistant can show that the relevant concern was inspected, the resulting work is maintainable, and completion is backed by direct evidence rather than intent.

## Related Modules

- ../01-core/01-master-loader.md
- ../03-runtime/00-runtime-sequence.md
- ../27-quality-gates/00-quality-gate-system.md

## Success Criteria

- The pack is actionable during real engineering work.
- The assistant can select or skip the pack intentionally.
- No placeholder guidance remains.
- The outcome improves engineering quality without expanding scope recklessly.
