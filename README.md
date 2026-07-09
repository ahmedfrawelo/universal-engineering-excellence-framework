# Universal Engineering Excellence Framework

Universal Engineering Excellence Framework (UEEF) is an installable engineering operating system for AI coding assistants. It gives Codex, Cursor, Claude Code, Gemini CLI, Windsurf, Cline, Roo Code, Aider, and future agents a shared professional framework for project inspection, planning, implementation, review, validation, and final reporting.

## Why UEEF Exists

AI coding assistants can generate code quickly, but professional engineering requires consistent architecture, security, performance, testing, documentation, maintainability, and product judgment. UEEF turns those expectations into reusable Markdown modules, checklists, templates, installers, validation scripts, and runtime rules.

## Who Should Use It

- Engineers who want AI assistants to inspect before editing.
- Teams that need repeatable quality gates across projects.
- Maintainers who want global assistant rules with safe backup behavior.
- Enterprise teams that need governance, scorecards, review systems, and production readiness.

## What Problem It Solves

UEEF prevents shallow completion, duplicated code, duplicated UI, random files, weak security, unverified changes, inconsistent naming, architecture drift, and vague final reports.

## How AI Coding Assistants Use It

Assistants load the core framework, inspect the project, detect stack and architecture, detect tools and skills, load only relevant modules, produce a plan, edit safely, run quality gates, and finish with evidence.

## Global Installation

Use the scripts in scripts/ to install UEEF for Codex, Cursor, or generic AI agents. Installers ask before overwriting, back up existing rules, copy the framework, and create a global loader.

## Quick Install

`powershell
.\scripts\install-codex.ps1
.\scripts\install-cursor.ps1
.\scripts\install-generic.ps1
`

`sh
./scripts/install-codex.sh
./scripts/install-cursor.sh
./scripts/install-generic.sh
`

## Folder Structure

- ramework/: sequential engineering packs from foundation through future expansion.
- scripts/: installers, backup helpers, agent detection, update, and validation scripts.
- docs/: architecture, usage, installation, governance, and contribution documentation.
- examples/: assistant and project usage examples.
- 	ools/: validation, generation, and maintenance support areas.

## Versioning Strategy

UEEF uses semantic versioning. Version 1.0.0 is the Enterprise Edition core. Version 1.1 should refine existing packs. Version 2.0 may expand intelligence packs, memory systems, and machine-readable metadata.

## Security Philosophy

UEEF requires security by default, backend authorization, safe secret handling, secure file uploads, dependency review, secure logging, and honest disclosure of validation limits.

## Quality Philosophy

Quality means clear architecture, understandable code, minimal duplication, measurable verification, production readiness, accessibility, and maintainability under long-term ownership.

## Examples

See examples/codex/, examples/cursor/, examples/claude-code/, and examples/generic-ai/ for assistant loaders. See project examples for frontend, backend, fullstack, and enterprise usage.

## Contributing

Contributions must improve enforceable engineering behavior. Do not add placeholder files. Every new module must include practical rules, decision guidance, anti-patterns, quality gates, and success criteria.

## Runtime Activation Verification

UEEF includes a runtime activation layer. Before every non-trivial engineering task, the assistant must prove UEEF is active, list loaded core modules, select relevant modules, check MCPs/tools/skills, apply UI UX Pro Max for UI work, and apply quality gates.

Run:

`powershell
.\scripts\ueef-status.ps1
`

See docs/verify-ueef-is-active.md.

## Runtime Hardening

UEEF can be synchronized into Codex home as a self-contained runtime:

```powershell
.\scripts\sync-runtime.ps1
.\scripts\check-runtime-drift.ps1
.\scripts\write-active-state.ps1
```

The runtime is active only when `scripts\ueef-status.ps1` reports `Overall: ACTIVE`.
