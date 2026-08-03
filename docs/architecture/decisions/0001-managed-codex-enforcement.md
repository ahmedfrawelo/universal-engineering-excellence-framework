# ADR 0001: Managed Codex lifecycle enforcement

Status: Accepted
Date: 2026-08-02

## Context

UEEF guidance was injected through `AGENTS.md` and validated by scripts, but Codex did not mechanically invoke those scripts before every local tool or final response. Runtime synchronization also could not refresh an already-open task's original AGENTS snapshot. The result was detectable policy drift without an enforcement boundary.

Official Codex lifecycle hooks provide `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, and `Stop`. Windows system `requirements.toml` can pin hooks on and register managed commands that users cannot disable through the ordinary hook browser.

## Decision

Codex runtime synchronization installs a UEEF-owned managed hook payload under the stable runtime root and a UEEF-owned system requirements file. The hooks:

- inject current runtime context at session and prompt boundaries;
- require a per-turn route record before supported local tools;
- deny protected paths, prohibited browser surfaces, and unauthorized destructive/publication commands;
- collect passing validator evidence from tool results;
- continue the turn when final labels, progress, evidence, completion audit, or goal closure proof is missing.

Managed requirements are written only when the file is absent or already carries the UEEF ownership marker. A foreign requirements file is rejected unchanged because structurally merging arbitrary TOML without an owning parser could weaken administrator policy.

## Consequences

- Critical UEEF rules become mechanical on official local hook paths instead of prompt-only.
- Existing user and plugin hooks continue to load because UEEF does not set `allow_managed_hooks_only`.
- Hosted tools and specialized paths that Codex excludes from hook coverage remain a documented platform boundary.
- An already-open turn is not retroactively intercepted; the next supported lifecycle reload applies the installed hooks.
- Runtime ACTIVE now requires exact managed requirements and hook hashes.

## Alternatives rejected

- Expanding AGENTS text: still advisory and still snapshot-bound.
- User-level `hooks.json`: requires mutable user trust and can be disabled.
- Modifying Codex binaries: unsupported, unsafe, and outside UEEF ownership.
- Silently merging a foreign system requirements file: risks invalid TOML or weakening higher-authority policy.
