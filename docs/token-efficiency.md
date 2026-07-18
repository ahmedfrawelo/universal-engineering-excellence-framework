# Token Efficiency Policy

## Purpose

UEEF must improve engineering quality without wasting context. The framework should guide decisions, not consume the conversation with unnecessary module content.

## Policy

1. Only the Boot Loader and Core System are always loaded.
2. The Master Loader selects only modules relevant to the current task.
3. Never load all UEEF files unless the task is about auditing, updating, validating, installing, or rebuilding UEEF.
4. For normal coding tasks, load the minimum useful module set.
5. For frontend UI tasks, load only frontend, UI, UX, accessibility, performance, and relevant quality gates.
6. For backend API tasks, load only architecture, backend, API, security, performance, database if needed, and relevant quality gates.
7. For documentation tasks, load only documentation and review modules.
8. Runtime verification output must be compact.
9. Final UEEF verification output must be compact.
10. Avoid repeating full framework rules in every response.
11. Use references to module paths instead of copying full module content unless needed.
12. Prefer targeted module inspection over full-framework reading.

## New Loading Behavior

Always load:

- `framework/01-core/00-boot-loader.md`
- `framework/01-core/00-core-system.md`

Then select task modules through:

- `framework/01-core/01-master-loader.md`

## Frontend Example

Selected modules:

- `framework/08-performance/00-performance-philosophy.md`
- `framework/10-frontend/00-frontend-engineering.md`
- `framework/14-ui/00-ui-system.md`
- `framework/15-ux/00-ux-system.md`
- `framework/16-accessibility/00-accessibility-system.md`
- `framework/27-quality-gates/ui-gate.md`
- `framework/27-quality-gates/ux-gate.md`
- `framework/27-quality-gates/accessibility-gate.md`
- `framework/27-quality-gates/performance-gate.md`
- `framework/27-quality-gates/16-ueef-activation-gate.md`

## Backend API Example

Selected modules:

- `framework/05-architecture/00-clean-architecture.md`
- `framework/07-security/00-security-by-default.md`
- `framework/08-performance/00-performance-philosophy.md`
- `framework/11-backend/00-backend-engineering.md`
- `framework/13-api/00-api-engineering.md`
- `framework/27-quality-gates/security-gate.md`
- `framework/27-quality-gates/performance-gate.md`
- `framework/27-quality-gates/api-gate.md`
- `framework/27-quality-gates/testing-gate.md`
- `framework/27-quality-gates/16-ueef-activation-gate.md`

## How This Reduces Token Usage

- Avoids reading hundreds of Markdown files for normal tasks.
- Keeps preflight to a small constant-size boot step.
- Selects only task-relevant modules.
- Uses paths as references instead of pasting full module text.
- Keeps final verification compact.
- Reserves full-framework loading for UEEF-specific maintenance or audits.
