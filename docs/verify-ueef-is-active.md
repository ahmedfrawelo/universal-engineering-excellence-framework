# Verify UEEF Is Active

## Purpose

This document explains how to prove UEEF is installed globally, loadable, and actively used before engineering work starts.

## 1. Verify UEEF Is Installed

From the repository root, run:

`powershell
.\scripts\ueef-status.ps1
`

Expected active result:

`	ext
Installed: YES
Global loader: PASS
Overall: ACTIVE
`

## 2. Verify UEEF Is Global

UEEF is global when a configured global path, normally $HOME\.ueef, contains at least one UEEF-LOADER.md file. The loader must instruct the assistant to load UEEF core, run the runtime check, select modules, check tools and skills, apply UI UX Pro Max for UI work, and apply quality gates.

## 3. Run Status Scripts

Windows:

`powershell
.\scripts\ueef-status.ps1
`

Unix-like systems:

`ash
./scripts/ueef-status.sh
`

## 4. Valid Runtime Check

## UEEF Runtime Check

UEEF Active: YES / NO

Global UEEF Path:
...

UEEF Version:
...

Core Loaded:
- framework/01-core/00-core-system.md
- framework/01-core/01-master-loader.md
- framework/01-core/02-master-index.md

Relevant Modules Selected:
- ...

MCPs Checked:
- ...

Skills Checked:
- ...

UI UX Pro Max:
Required: YES / NO
Available: YES / NO / UNKNOWN
Applied: YES / NO / NOT APPLICABLE

Quality Gates Planned:
- ...

Status:
READY / BLOCKED

## 5. Detect Fake Activation

Activation is fake when the assistant says UEEF is active but does not provide a status result, global path, loaded core modules, selected relevant modules, MCP/tool/skill checks, UI UX Pro Max status, and quality gates.

## 6. If UEEF Is Inactive

Run one installer:

`powershell
.\scripts\install-codex.ps1
.\scripts\install-cursor.ps1
.\scripts\install-generic.ps1
`

Then rerun:

`powershell
.\scripts\ueef-status.ps1
`

## 7. Test With A New Empty Project

Ask the assistant to create a small project. Before editing, it must show UEEF Active: YES, load core modules, detect tools, select relevant modules, and plan quality gates.

## 8. Test With A Frontend Task

Ask for a UI layout or React component change. UI UX Pro Max must be required, available status must be reported, and UI, UX, accessibility, frontend, performance, and activation gates must be selected.

## 9. Test With A Backend Task

Ask for an API endpoint. The assistant must select architecture, backend, API, security, performance, testing, and activation gates.

## 10. Verify UI UX Pro Max

For UI work, the runtime check must say:

`	ext
UI UX Pro Max:
Required: YES
Available: YES / NO / UNKNOWN
Applied: YES
`

If UI UX Pro Max is not available, the assistant must report the limitation and still apply UEEF UI, UX, accessibility, and frontend modules.
