# Universal Engineering Excellence Framework

## What UEEF Is

UEEF is a reusable Engineering Operating System for AI coding assistants. It gives Codex, Cursor, Claude Code, Gemini CLI, Windsurf, Cline, Roo Code, Aider, and future agents a shared set of enforceable engineering rules.

## Who It Is For

- Engineers who want AI assistants to inspect projects before editing.
- Teams that need consistent code quality, architecture, testing, security, performance, and documentation behavior.
- Maintainers who want global rules that can be installed once and reused across repositories.

## Why It Exists

AI assistants can move fast, but speed without operating rules creates duplicated code, inconsistent UI, weak verification, and shallow completion claims. UEEF turns expert review habits into reusable loading instructions, checklists, decision graphs, templates, and technology packs.

## Install

Windows PowerShell:

```powershell
.\scripts\install-codex.ps1
.\scripts\install-cursor.ps1
.\scripts\install-generic.ps1
```

Unix shell:

```sh
./scripts/install-codex.sh
./scripts/install-cursor.sh
./scripts/install-generic.sh
```

Each installer asks before overwriting existing global rules, creates a timestamped backup, copies the framework, and writes a global loader file.

## Update

Run `.\scripts\update.ps1` on Windows or `./scripts/update.sh` on Unix from a cloned repository. The update scripts prefer `git pull` when the repository is a Git checkout and then refresh the global framework copy.

## Use With Codex

Install the Codex loader, then instruct Codex to load the global UEEF loader before engineering work. The loader requires project inspection, stack detection, tool and skill detection, a plan before editing, quality gates, and a final engineering review.

## Use With Cursor

Install the Cursor loader to global rules. Cursor should load UEEF before code generation, refactoring, UI work, and review. The Cursor example in `examples/cursor/` shows a practical rule file.

## Use With Other AI Agents

Use the generic installer and copy the loader text into the agent's global instruction mechanism. The framework is Markdown-first so it can be consumed by agents that support filesystem-based rules, project memories, or prompt imports.

## Folder Structure

- `framework/`: enforceable modules, technology packs, templates, decision graphs, and checklists.
- `scripts/`: installers, updater scripts, and validators.
- `examples/`: agent-specific loader examples.
- `docs/`: architecture, usage, installation, pack creation, and versioning documentation.

## Versioning

UEEF follows semantic versioning. Version `1.0.0` is the Enterprise Edition baseline. Patch releases fix guidance, minor releases add compatible modules, and major releases may reorganize contracts.

## Contribution Rules

Contributions must improve practical engineering behavior, include meaningful documentation, avoid empty outlines, and pass the validation scripts. New modules must include purpose, required behavior, inspection protocol, quality gates, and review questions.

## Safety And Security Philosophy

UEEF never asks users to commit credentials. Installers back up existing global rules before writing. Agents are instructed to preserve user work, avoid destructive commands without explicit approval, inspect security-sensitive paths carefully, and disclose verification limits.
