# UEEF Status Check

Version: 1.0
Pack: 01-core
Status: Stable
Applies To: preflight, validation, final review

## Purpose

The UEEF status check is the repeatable runtime test that determines whether UEEF is installed, loadable, and ready for use.

## Required Command

Prefer the local repository script:

`powershell
.\scripts\ueef-status.ps1
`

On Unix-like systems:

`ash
./scripts/ueef-status.sh
`

## Required Checks

- Repository path exists.
- Global UEEF path exists or is reported as missing.
- Required root files exist.
- Core system, master loader, and master index exist.
- Runtime activation proof exists.
- Activation quality gate exists.
- Quality gates folder exists.
- Markdown file count is reported.
- Version is reported.
- Global loader exists or a required action is shown.
- Managed requirements and all hook payload hashes pass for a Codex managed runtime.
- Validation script exists.

## Interpretation

- Overall: ACTIVE means the managed runtime is installed and may be used for engineering work.
- `Managed enforcement: PASS` means Codex lifecycle hooks are installed and match active-state hashes; it does not claim that an already-open pre-install turn was retroactively intercepted.
- Overall: SOURCE_VALIDATED means only that a source checkout passes repository validation; it must not be presented as runtime activation.
- Overall: INACTIVE or SOURCE_INVALID means the assistant must not pretend UEEF is active.
- Global loader: UNKNOWN means the repository is present but a global AI rules path was not verified.

## Required Response Behavior

If the status check is inactive, respond with:

`	ext
UEEF: INACTIVE
Reason:
Required action:
`

If active, include the runtime check block and continue with module selection.
