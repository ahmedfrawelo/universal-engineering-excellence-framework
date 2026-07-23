[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidatePattern('^[a-z0-9][a-z0-9-]{1,62}$')][string]$Id,
  [string]$Root = (Get-Location).Path,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$specRoot = Join-Path $resolvedRoot (Join-Path '.ueef\specs' $Id)

if ((Test-Path -LiteralPath $specRoot) -and !$Force) {
  throw "Workflow already exists: $specRoot. Use -Force only to refresh missing files."
}
New-Item -ItemType Directory -Path $specRoot -Force | Out-Null

$files = [ordered]@{
  'constitution.md' = @'
# Constitution: {{TITLE}}

Status: DRAFT

## Principles

1. {{PRINCIPLE_1}}
2. {{PRINCIPLE_2}}

## Non-negotiable constraints

- {{CONSTRAINT}}
'@
  'spec.md' = @'
# Specification: {{TITLE}}

Status: DRAFT

## Outcome

{{OUTCOME}}

## In scope

- {{IN_SCOPE}}

## Out of scope

- {{OUT_OF_SCOPE}}

## Actors and scenarios

- {{ACTOR}}: {{SCENARIO}}

## Functional requirements

- REQ-001: {{REQUIREMENT}}

## Non-functional requirements

- NFR1: {{QUALITY_REQUIREMENT}}

## Acceptance criteria

- AC-001: {{MEASURABLE_ACCEPTANCE_CRITERION}}

## Risks, assumptions, and open questions

- {{RISK_OR_ASSUMPTION}}
'@
  'plan.md' = @'
# Technical Plan: {{TITLE}}

Status: DRAFT

## Requirement mapping

| Requirement | Decision | Owner | Verification |
| --- | --- | --- | --- |
| REQ-001 | {{DECISION}} | {{OWNER}} | {{VERIFICATION}} |

## Architecture and contracts

{{ARCHITECTURE}}

## Security, performance, and compatibility

{{NON_FUNCTIONAL_DESIGN}}

## Rollout and rollback

{{ROLLBACK_PLAN}}
'@
  'tasks.md' = @'
# Tasks: {{TITLE}}

Status: DRAFT

## Ordered work

- [ ] TASK-001 {{TASK}}
  - Requirements: REQ-001
  - Depends on: {{DEPENDENCY}}
  - Evidence: {{EVIDENCE}}
  - Done when: {{DONE_WHEN}}
'@
  'evidence.md' = @'
# Evidence: {{TITLE}}

Status: DRAFT

## Delivery record

| Acceptance criterion | Evidence command or review | Result | Recorded at |
| --- | --- | --- | --- |
| AC-001 | {{COMMAND_OR_REVIEW}} | {{PASS_OR_FAIL}} | {{UTC_TIMESTAMP}} |

## Residual risks and follow-up

- {{RESIDUAL_RISK}}
'@
}

foreach ($entry in $files.GetEnumerator()) {
  $path = Join-Path $specRoot $entry.Key
  if (!(Test-Path -LiteralPath $path)) {
    [IO.File]::WriteAllText($path, ($entry.Value.Trim() + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
  }
}

[pscustomobject]@{
  schemaVersion = 1
  workflowId = $Id
  path = $specRoot
  files = @($files.Keys)
  next = 'Replace {{PLACEHOLDERS}}, then run validate-spec-workflow.ps1.'
} | ConvertTo-Json -Depth 3
