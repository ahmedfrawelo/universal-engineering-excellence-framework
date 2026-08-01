$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$reporter = Join-Path $root 'scripts\get-architecture-report.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) ("ueef-architecture-" + [guid]::NewGuid().ToString('N'))
try {
  New-Item -ItemType Directory -Path (Join-Path $temp 'src\domain'),(Join-Path $temp 'src\ui'),(Join-Path $temp 'docs\adr') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $temp 'src\ui\view.ts') -Value 'export const view = true;' -Encoding utf8
  Set-Content -LiteralPath (Join-Path $temp 'src\domain\model.ts') -Value "import { view } from '../ui/view';" -Encoding utf8
  Set-Content -LiteralPath (Join-Path $temp 'src\ui\screen.ts') -Value "import { model } from '../domain/model';" -Encoding utf8
  Set-Content -LiteralPath (Join-Path $temp 'src\ui\public.ts') -Value 'export const api = true;' -Encoding utf8
  $policy = [ordered]@{
    schemaVersion=1
    sourceExtensions=@('.ts')
    ignoredSegments=@('.git','node_modules')
    owners=@(
      [ordered]@{id='domain';paths=@('src/domain/')},
      [ordered]@{id='ui';paths=@('src/ui/')},
      [ordered]@{id='docs';paths=@('docs/')}
    )
    allowedDependencies=[ordered]@{domain=@('domain');ui=@('ui','domain');docs=@('domain','ui','docs')}
    publicBoundaryPatterns=@('src/ui/public.ts')
    adrPatterns=@('docs/adr/*.md')
    requireAdrForPublicBoundaryChange=$true
  }
  $policyPath = Join-Path $temp 'architecture-policy.json'
  $policy | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $policyPath -Encoding utf8

  $forbidden = & $reporter -Root $temp -PolicyPath $policyPath -ChangedFile 'src/domain/model.ts' -Json | ConvertFrom-Json
  if ($forbidden.status -ne 'FAIL' -or 'FORBIDDEN_DEPENDENCY' -notin @($forbidden.violations.code)) { throw 'Forbidden dependency was not detected.' }
  $pass = & $reporter -Root $temp -PolicyPath $policyPath -ChangedFile 'src/ui/screen.ts' -Json | ConvertFrom-Json
  if ($pass.status -ne 'PASS') { throw 'Allowed dependency did not pass.' }
  $adrMissing = & $reporter -Root $temp -PolicyPath $policyPath -ChangedFile 'src/ui/public.ts' -Json | ConvertFrom-Json
  if ('ADR_REQUIRED' -notin @($adrMissing.violations.code)) { throw 'Public boundary change did not require an ADR.' }
  Set-Content -LiteralPath (Join-Path $temp 'docs\adr\0001-public-api.md') -Value '# ADR' -Encoding utf8
  $adrPass = & $reporter -Root $temp -PolicyPath $policyPath -ChangedFile @('src/ui/public.ts','docs/adr/0001-public-api.md') -Json | ConvertFrom-Json
  if ($adrPass.status -ne 'PASS') { throw 'Public boundary plus ADR did not pass.' }
  $unconfigured = & $reporter -Root $temp -ChangedFile 'src/ui/screen.ts' -Json | ConvertFrom-Json
  if ($unconfigured.status -ne 'NOT_CONFIGURED') { throw 'Missing project policy must not claim PASS.' }
  Write-Output 'Architecture report tests passed.'
} finally {
  if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
