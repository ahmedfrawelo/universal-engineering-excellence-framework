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
- Validation script exists.

## Interpretation

- Overall: ACTIVE means UEEF may be used for engineering work.
- Overall: INACTIVE means the assistant must not pretend UEEF is active.
- Global loader: UNKNOWN means the repository is present but a global AI rules path was not verified.

## Required Response Behavior

If the status check is inactive, respond with:

`	ext
UEEF Active: NO
Reason:
Required action:
`

If active, include the runtime check block and continue with module selection.
