param(
  [string]$InstallRoot = "$HOME\.ueef",
  [string]$Agent = "generic"
)
$ErrorActionPreference = "Stop"
$Source = Split-Path -Parent $PSScriptRoot
$Framework = Join-Path $Source "framework"
if (!(Test-Path $Framework)) { throw "Cannot find framework directory at $Framework" }
$Target = Join-Path $InstallRoot $Agent
$Backup = Join-Path $InstallRoot ("backups\" + $Agent + "-" + (Get-Date -Format "yyyyMMddHHmmss"))
if (Test-Path $Target) {
  $answer = Read-Host "Existing UEEF installation found at $Target. Back it up and replace it? (y/N)"
  if ($answer -notin @("y","Y","yes","YES")) { Write-Host "Install cancelled."; exit 1 }
  New-Item -ItemType Directory -Path $Backup -Force | Out-Null
  Copy-Item -LiteralPath $Target -Destination $Backup -Recurse -Force
}
New-Item -ItemType Directory -Path $Target -Force | Out-Null
Copy-Item -LiteralPath $Framework -Destination $Target -Recurse -Force
$Loader = Join-Path $Target "UEEF-LOADER.md"
@"
# UEEF Loader For $Agent

Load UEEF before every engineering task.

1. Read framework/MASTER_INDEX.md.
2. Inspect the project first.
3. Detect stack, architecture, MCPs, tools, and skills.
4. Use all relevant tools and skills.
5. Apply UI UX Pro Max for UI work.
6. Plan before editing.
7. Avoid duplicated code, duplicated UI, and random standalone files.
8. Prioritize security, performance, scalability, and clean architecture.
9. Run quality gates.
10. Provide a final engineering review with evidence.
"@ | Set-Content -LiteralPath $Loader -Encoding utf8
Write-Host "UEEF installed for $Agent at $Target"
Write-Host "Loader: $Loader"
