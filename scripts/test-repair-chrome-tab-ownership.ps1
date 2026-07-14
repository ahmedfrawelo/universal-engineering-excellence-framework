$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $PSScriptRoot 'repair-chrome-tab-ownership.ps1'
$scriptText = Get-Content -LiteralPath $scriptPath -Raw

foreach ($term in @("Name='extension-host.exe'", 'chrome-extension://hehggadaopoacecdllhhajmbjkdcmajg/', 'Stop-Process -Id', '[switch]$DryRun')) {
  if ($scriptText -notmatch [regex]::Escape($term)) { throw "Ownership recovery safety term missing: $term" }
}
if ($scriptText -match '\bexit\b') { throw 'Ownership recovery must return to the caller instead of terminating the task shell.' }

$result = & $scriptPath -DryRun
if (@($result | Where-Object { $_.Status -in @('DryRun', 'NoExtensionHostFound') }).Count -ne 1) {
  throw 'Ownership recovery dry run returned an invalid status.'
}
Write-Host 'Chrome tab ownership recovery tests passed'
