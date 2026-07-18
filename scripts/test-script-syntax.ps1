param([switch]$SkipShell)
$ErrorActionPreference = 'Stop'
Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' -File | ForEach-Object {
  $tokens = $null; $errors = $null
  [Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors) | Out-Null
  if ($errors.Count) { throw "PowerShell parse errors in $($_.Name): $($errors[0].Message)" }
}
Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.mjs' -File | ForEach-Object {
  & node --check $_.FullName | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Node syntax check failed for $($_.Name)." }
}
if (!$SkipShell) {
  $bash = if (Test-Path 'C:\Program Files\Git\bin\bash.exe') { 'C:\Program Files\Git\bin\bash.exe' } else { (Get-Command bash -ErrorAction SilentlyContinue).Source }
  if ($bash) {
    foreach ($script in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.sh' -File) {
      & $bash -n $script.FullName.Replace('\','/')
      if ($LASTEXITCODE -ne 0) { throw "Shell syntax check failed for $($script.Name)." }
    }
  }
}
Write-Host 'Cross-platform script syntax tests passed'
