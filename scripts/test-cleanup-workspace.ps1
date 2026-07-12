$ErrorActionPreference = 'Stop'
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ("ueef-cleanup-test-" + [guid]::NewGuid().ToString('N'))
try {
  New-Item -ItemType Directory -Path $sandbox | Out-Null
  git -C $sandbox init -q
  $tracked = Join-Path $sandbox 'tracked.tmp'
  $untracked = Join-Path $sandbox 'untracked.tmp'
  [IO.File]::WriteAllText($tracked, 'tracked')
  [IO.File]::WriteAllText($untracked, 'untracked')
  git -C $sandbox add tracked.tmp
  git -C $sandbox -c user.name=UEEF -c user.email=ueef@example.invalid commit -qm 'test fixture'
  (Get-Item $tracked).LastWriteTime = (Get-Date).AddDays(-30)
  (Get-Item $untracked).LastWriteTime = (Get-Date).AddDays(-30)
  $bashPath = if (Test-Path 'C:\Program Files\Git\bin\bash.exe') { 'C:\Program Files\Git\bin\bash.exe' } else { '' }
  if (!$bashPath) { Write-Host 'Cleanup test skipped: Git Bash unavailable'; exit 0 }
  $env:CLEANUP_APPLY = '1'; $env:CLEANUP_OLDER_THAN_DAYS = '14'
  & $bashPath (Join-Path $PSScriptRoot 'cleanup-workspace.sh').Replace('\','/') $sandbox.Replace('\','/') | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Unix cleanup failed.' }
  if (!(Test-Path -LiteralPath $tracked)) { throw 'Unix cleanup deleted a tracked artifact.' }
  if (Test-Path -LiteralPath $untracked) { throw 'Unix cleanup did not delete an eligible untracked artifact.' }
  Write-Host 'Workspace cleanup tests passed'
} finally {
  Remove-Item Env:CLEANUP_APPLY -ErrorAction SilentlyContinue
  Remove-Item Env:CLEANUP_OLDER_THAN_DAYS -ErrorAction SilentlyContinue
  if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
