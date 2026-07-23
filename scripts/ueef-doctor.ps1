[CmdletBinding()]
param(
  [string]$SourcePath = '',
  [string]$RuntimePath = $(if ($env:CODEX_HOME) { Join-Path $env:CODEX_HOME 'ueef\codex' } else { 'E:\shared folder\codex-home\ueef\codex' }),
  [switch]$Json
)
$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $PSCommandPath
if ([string]::IsNullOrWhiteSpace($SourcePath)) { $SourcePath = Split-Path -Parent $scriptRoot }
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourcePath).Path)
$runtimeExists = Test-Path -LiteralPath $RuntimePath -PathType Container
$loaderPath = Join-Path $RuntimePath 'UEEF-LOADER.md'
$terms = @('Scope wins', 'stop when done', 'T1 defaults to single-agent', 'economical default')
$missing = if ($runtimeExists -and (Test-Path -LiteralPath $loaderPath)) { @($terms | Where-Object { (Get-Content -LiteralPath $loaderPath -Raw) -notmatch [regex]::Escape($_) }) } else { @($terms) }
$drift = if ($runtimeExists -and (Test-Path -LiteralPath (Join-Path $source 'scripts\check-runtime-drift.ps1'))) { & (Join-Path $source 'scripts\check-runtime-drift.ps1') -SourcePath $source -RuntimePath $RuntimePath 2>&1 | Out-String } else { 'Runtime not installed; drift check skipped.' }
$result = [ordered]@{ runtimeInstalled=$runtimeExists; intentTermsPresent=($missing.Count -eq 0); missingIntentTerms=$missing; drift=$drift.Trim(); recommendation=if($runtimeExists -and $missing.Count -eq 0 -and $drift -match 'Overall: SYNCED'){'Runtime is current.'}else{'Run scripts/sync-runtime.ps1 from the source repository after validating the release.'} }
if ($Json) { $result | ConvertTo-Json -Depth 3 } else { $result | Format-List }
