param([switch]$SkipShell)
$ErrorActionPreference = 'Stop'
Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' -File | ForEach-Object {
  $bytes = [IO.File]::ReadAllBytes($_.FullName)
  $hasUnicodeBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) -or
    ($bytes.Length -ge 2 -and (($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) -or ($bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF)))
  $hasNonAscii = $false
  foreach ($byte in $bytes) {
    if ($byte -gt 0x7F) { $hasNonAscii = $true; break }
  }
  if ($hasNonAscii -and !$hasUnicodeBom) {
    throw "PowerShell 5.1 encoding risk in $($_.Name): non-ASCII source requires a Unicode BOM or an ASCII-safe encoding."
  }
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
