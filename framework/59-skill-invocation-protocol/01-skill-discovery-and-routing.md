# Skill Discovery and Routing

## Purpose

Skill discovery prevents the assistant from reinventing existing workflow knowledge or missing specialized tools already installed in the runtime.

## Required Discovery

- Check global Codex skills under the active skills directory.
- Check project-local skill folders such as `.codex/skills`, `.agents/skills`, `.claude/skills`, `.cursor/skills`, and documented project workflow folders.
- Check UEEF packs for the same task category.
- Prefer installed supported skills over external web instructions unless the user explicitly asks to install or study an external skill.
- For UI work, always include `ui-ux-pro-max` and `impeccable` when available.
- For an ambiguous visual request, add `design-brief` before implementation.
- For production frontend creation or material UI polish, add `frontend-design`.
- For motion, animation, transition, easing, or interaction polish, add `emil-design-eng`.
- For browser work, use the installed Chrome control skill and the UEEF browser session pack.

## Routing Order

1. Safety and platform constraints.
2. User-requested named skill.
3. Domain-specific skill.
4. UEEF task pack.
5. Verification and review skill.
6. General engineering fallback.

## Output Contract

Record:

```text
Skill candidates:
Selected skill chain:
Skipped skills and reason:
Skill protocol gate:
```
