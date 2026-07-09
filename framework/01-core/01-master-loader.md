# Master Loader

Version: 1.0
Pack: 01-core
Status: Stable
Applies To: selective module loading

## Purpose

The Master Loader chooses the minimum useful UEEF module set for the current task. It is a selector, not a command to load every UEEF file.

## Always Loaded Before This Selector

- `framework/01-core/00-boot-loader.md`
- `framework/01-core/00-core-system.md`

## Selection Policy

- Select by task type, risk, stack, and files touched.
- Load module paths first; load full module content only when needed.
- Never load all UEEF files for normal coding tasks.
- Load the full framework only for UEEF audits, UEEF updates, UEEF rebuilds, or explicit full-framework requests.
- Keep runtime and final verification compact.

## Frontend UI Tasks

Load only:

- `framework/08-performance/01-frontend-performance.md`
- `framework/10-frontend/00-frontend-architecture.md`
- `framework/14-ui/00-ui-excellence.md`
- `framework/15-ux/00-ux-excellence.md`
- `framework/16-accessibility/00-accessibility-excellence.md`
- `framework/27-quality-gates/08-ui-gate.md`
- `framework/27-quality-gates/09-ux-gate.md`
- `framework/27-quality-gates/10-accessibility-gate.md`
- `framework/27-quality-gates/05-performance-gate.md`
- `framework/27-quality-gates/16-ueef-activation-gate.md`

Apply UI UX Pro Max when available. Do not load backend, database, enterprise, or unrelated technology packs unless the task touches them.

## Backend API Tasks

Load only:

- `framework/05-architecture/00-clean-architecture.md`
- `framework/07-security/00-security-by-default.md`
- `framework/08-performance/03-backend-performance.md`
- `framework/11-backend/00-backend-architecture.md`
- `framework/13-api/00-api-design.md`
- `framework/27-quality-gates/04-security-gate.md`
- `framework/27-quality-gates/05-performance-gate.md`
- `framework/27-quality-gates/07-api-gate.md`
- `framework/27-quality-gates/11-testing-gate.md`
- `framework/27-quality-gates/16-ueef-activation-gate.md`

Add database modules only when schema, query, persistence, migration, or transaction behavior is involved.

## Database Tasks

Load only database, security, performance, migration, testing, and activation gates relevant to the database change.

## Documentation Tasks

Load only:

- `framework/18-documentation/00-documentation-engineering.md`
- `framework/24-ai-review/00-ai-review-system.md` when review quality matters
- `framework/27-quality-gates/12-documentation-gate.md`
- `framework/27-quality-gates/16-ueef-activation-gate.md`

## UEEF Maintenance Tasks

For UEEF-specific audit, install, validation, runtime, or rebuild work, broader loading is allowed. Still prefer targeted packs first, then expand only as needed.

## Compact Verification Format

```text
UEEF: ACTIVE
Loaded: boot-loader, core-system
Selected: <count> modules
Gates: <count> gates
UIUX: YES/NO/NA
```

Do not repeat full module rules in the final response unless the user asks for them.
