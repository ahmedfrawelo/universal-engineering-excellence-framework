# Universal Engineering Excellence Framework

Universal Engineering Excellence Framework (UEEF) is an installable engineering operating system for AI coding assistants. Tested adapters are available for Codex, Cursor, and a generic AGENTS-compatible target; see `config/assistant-adapters.json` for the executable compatibility matrix. The current release is 2.25.10; it finalizes the native repository-intelligence engine placement, complete project file-tree graph coverage, and clean runtime handoff metadata.

## Why UEEF Exists

AI coding assistants can generate code quickly, but professional engineering requires consistent architecture, security, performance, testing, documentation, maintainability, and product judgment. UEEF turns those expectations into reusable Markdown modules, checklists, templates, installers, validation scripts, and runtime rules. Connector-created browser windows and automation profiles are never valid substitutes for the user's existing Chrome tab; browser work is blocked only when that user-owned tab cannot be proven after the required recovery and same-tab failover flow.

## Who Should Use It

- Engineers who want AI assistants to inspect before editing.
- Teams that need repeatable quality gates across projects.
- Maintainers who want global assistant rules with safe backup behavior.
- Enterprise teams that need governance, scorecards, review systems, and production readiness.

## What Problem It Solves

UEEF prevents shallow completion, duplicated code, duplicated UI, feature-local copies of shared behavior, random files, unowned standalone files, oversized mixed-responsibility files, weak security, unverified changes, inconsistent naming, architecture drift, and vague final reports.

## How AI Coding Assistants Use It

Assistants load the core framework, inspect the project, detect stack and architecture, detect tools and skills, load only relevant modules, produce a plan, edit safely, run quality gates, and finish with evidence.

## Global Installation

Use the scripts in scripts/ to install UEEF for Codex, Cursor, or generic AI agents. Installers ask before overwriting, back up existing rules, copy the framework, and create a global loader.

## Quick Install

```powershell
.\scripts\install-codex.ps1
.\scripts\install-cursor.ps1
.\scripts\install-generic.ps1
```

```sh
./scripts/install-codex.sh
./scripts/install-cursor.sh
./scripts/install-generic.sh
```

## Folder Structure

- `framework/`: stable numbered packs plus `framework/_domains/` as the physical fast-navigation layer. Start with `framework/_domains/README.md`, then use `framework/MASTER_INDEX.md` for exact file lookup.
- `scripts/`: owned automation for install, status, repository intelligence, evidence, generation, validation, runtime sync, release, and tests.
- `docs/`: architecture, usage, installation, governance, release notes, third-party attribution, and specifications.
- `examples/`: assistant and project usage examples for supported and guidance-only adapters.
- `config/`: routing, enforcement, adapter, and runtime policy configuration.
- `engines/`: embedded local engines used by UEEF, including repository intelligence.
- `tools/`: validation, generation, and maintenance support areas.
- `assets/`: display metadata and assets such as the UEEF skill icon.

The numbered framework packs are intentionally kept as stable runtime paths. The actual navigation organization lives under `framework/_domains/`; `framework/DOMAIN_MAP.md` is the compatibility entrypoint that points there.

## Versioning Strategy

UEEF follows Semantic Versioning. The current release is 2.25.10. See [VERSION.md](VERSION.md) for version policy and release history, [CHANGELOG.md](CHANGELOG.md) for the summary, and [docs/releases](docs/releases/) for individual release notes.

## Security Philosophy

UEEF requires security by default, backend authorization, safe secret handling, secure file uploads, dependency review, secure logging, and honest disclosure of validation limits.

## Unix capability scope

Unix preflight verifies `SOURCE_VALIDATED` or `ACTIVE_RUNTIME` before authorizing execution, while reporting `UNSUPPORTED_ON_UNIX` only for capability health and callable probes. It does not claim Windows capability-health parity.

## Preferred skills

`config/preferred-skills.json` is the source of truth for optional user-installed skills, their task triggers, pinned repositories, and install evidence. `config/preferred-capabilities.json` adds the preferred Codex plugins and MCPs without pretending that they share the skill install lifecycle. Run `scripts/reconcile-preferred-capabilities.ps1 -Install` to install missing skills and report any platform-managed plugin or runtime-managed MCP action. Runtime-managed system skills and plugin packages are never downloaded through the user-skill installer.

## Quality Philosophy

Quality means clear architecture, understandable code, minimal duplication, measurable verification, production readiness, accessibility, and maintainability under long-term ownership.

## Examples

Tested assistant adapters are Codex, Cursor, and the generic AGENTS-compatible target only. `examples/claude-code/` is an unverified guidance example, not a tested adapter, installer, or support claim. See examples/codex/, examples/cursor/, examples/claude-code/, and examples/generic-ai/ for assistant-loader guidance; see project examples for frontend, backend, fullstack, and enterprise usage.

## Contributing

Contributions must improve enforceable engineering behavior. Do not add placeholder files. Every new module must include practical rules, decision guidance, anti-patterns, quality gates, and success criteria.

## Runtime Activation Verification

UEEF includes a runtime activation layer. Before every non-trivial engineering task, the assistant must prove UEEF is active, keep `Loaded` limited to `boot-loader, core-system`, select relevant modules, check MCPs/tools/skills, apply UI UX Pro Max for UI work, and apply quality gates.

Run:

```powershell
.\scripts\ueef-status.ps1
```

See `docs/verify-ueef-is-active.md`.

## Project Context Map

Before broad work in an unfamiliar or large repository, run a bounded context map to identify manifests, shared owners, feature modules, design-system folders, tests, and generated outputs:

```powershell
.\scripts\project-context-map.ps1 -Path . -MaxItems 40
```

```sh
sh ./scripts/project-context-map.sh . 40
```

## Runtime Hardening

UEEF can be synchronized into Codex home as a self-contained runtime:

```powershell
.\scripts\sync-runtime.ps1 -CodexHome "D:\shared folder\codex-home" -Agent codex -BackupRoot "D:\shared folder\codex-home-backups"
& "D:\shared folder\codex-home\ueef\codex\scripts\ueef-status.ps1"
```

The managed runtime is active only when the installed status reports `Overall: ACTIVE`, `Runtime drift: PASS`, and `Runtime source revision: PASS`. A source checkout may report `SOURCE_VALIDATED`; that proves repository integrity but does not claim that Codex is using the installed runtime.

The active repository graph lives under `.ueef\repository-graph`. Check it with `.\scripts\repository-intelligence.ps1 -Command status -Root . -Json`, refresh it with `.\scripts\repository-intelligence.ps1 -Command build -Root . -Json`, and use bounded queries before broad repository work. Legacy graph-like outputs are not the canonical UEEF graph unless a task explicitly selects them.

## Product UI Standard

For frontend work, UEEF inspects the existing theme and component system before editing. New products define light, dark, and system modes; semantic tokens; responsive behavior; accessible interaction states; and one overlay contract. Packs 45-47 connect access-aware UI, component reuse, security, and performance to the same quality gate.

Design work also follows pack 48: search the project, design system, component registry, shared components, shared services, and pattern library before creating anything. Reuse is mandatory before extension or new creation, repeated capabilities belong in shared owners, and all visual values must map to governed tokens.

Frontend routing is proportional: `Quick` handles bounded changes in an existing owner, `Build` covers new or materially extended production surfaces, and `Audit` covers critique, redesign, and visual hardening. Design skills, skeleton modules, browser evidence, and visual-composition gates are selected only when their own triggers are part of the requested outcome.



