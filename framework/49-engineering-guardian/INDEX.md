# Engineering Guardian Index

Version: 1.3.0  
Status: Enforced  
Applies to: every engineering task and release decision

## Purpose

Routes quality protection from zero regression and contract safety through monitors, automatic improvement, self-criticism, final review, health, and maintenance.

## Guardian Rules

- Start with 00 and 01 for every task.
- Select monitors for affected layers and systems.
- Finish with 20, 21, 24, and 25.

## Required Evidence

Before completion, compare the affected behavior with its baseline. Inspect the architecture, security boundary, performance path, design system, accessibility behavior, tests, documentation, and developer experience that the change touches. A regression must stop the task, be fixed or explicitly accepted by an accountable owner, and have a recorded follow-up. Never hide a quality decrease behind a green build.

- [ ] Every numbered module is present and discoverable.
- [ ] The pack is referenced by Core, Loader, Runtime, review, quality, and validation systems.

## Failure Conditions

- A known regression is left unresolved without an explicit, time-bounded risk decision.
- A task increases duplication, complexity, technical debt, security exposure, accessibility debt, or performance cost silently.
- Review claims improvement without a before-and-after baseline or direct evidence.

## Completion Rule

This module passes only when the change leaves the affected project area equal or better across applicable engineering dimensions, with residual risk visible and owned.

## Related Packs

- framework/24-ai-review
- framework/27-quality-gates
- framework/28-scorecards
- framework/48-design-governance
- framework/47-theme-responsive-interaction-security-performance
