$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$reporter = Join-Path $root 'scripts\get-file-organization-report.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) ("ueef-file-organization-" + [guid]::NewGuid().ToString('N'))
try {
  New-Item -ItemType Directory -Path (Join-Path $temp 'src\feature') -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $temp 'src\misc') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $temp 'src\feature\good.ts') -Value 'export const good = true;' -Encoding utf8
  Set-Content -LiteralPath (Join-Path $temp 'bad.ts') -Value 'export const bad = true;' -Encoding utf8
  Set-Content -LiteralPath (Join-Path $temp 'src\misc\dump.ts') -Value 'export const dump = true;' -Encoding utf8
  $failed = & $reporter -Root $temp -ChangedFile @('src/feature/good.ts','bad.ts','src/misc/dump.ts') -Json | ConvertFrom-Json
  if ($failed.status -ne 'FAIL' -or @($failed.violations).Count -ne 2) { throw 'File organization violations were not detected.' }
  $codes = @($failed.violations.code)
  if ('UNOWNED_ROOT_SOURCE' -notin $codes -or 'GENERIC_DUMP_FOLDER' -notin $codes) { throw 'Expected file organization violation codes are missing.' }
  $pass = & $reporter -Root $temp -ChangedFile 'src/feature/good.ts' -Json | ConvertFrom-Json
  if ($pass.status -ne 'PASS' -or @($pass.ownerMap).Count -ne 1 -or $pass.ownerMap[0].owner -ne 'src/feature') { throw 'Owned feature file did not pass organization review.' }
} finally {
  if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
Write-Output 'File organization report tests passed.'
