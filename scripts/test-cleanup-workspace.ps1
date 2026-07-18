$ErrorActionPreference = 'Stop'

$cleanupPs = Join-Path $PSScriptRoot 'cleanup-workspace.ps1'
$cleanupSh = Join-Path $PSScriptRoot 'cleanup-workspace.sh'
$bashPath = if (Test-Path 'C:\Program Files\Git\bin\bash.exe') { 'C:\Program Files\Git\bin\bash.exe' } else { $null }
$sandboxRoot = Join-Path ([IO.Path]::GetTempPath()) ("ueef-cleanup-test-" + [guid]::NewGuid().ToString('N'))

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function Assert-PowerShellRejected([string]$Root, [string]$ExpectedMessage) {
  try {
    & $cleanupPs -Root $Root | Out-Null
  } catch {
    Assert-True ($_.Exception.Message -like "*$ExpectedMessage*") "Unexpected rejection for '$Root': $($_.Exception.Message)"
    return
  }
  throw "PowerShell cleanup accepted unsafe root '$Root'."
}

function Invoke-Bash([string]$Root, [bool]$Apply = $false) {
  if (-not $bashPath) { return $null }
  $previousApply = $env:CLEANUP_APPLY
  $previousErrorAction = $ErrorActionPreference
  try {
    $env:CLEANUP_APPLY = if ($Apply) { '1' } else { '0' }
    $ErrorActionPreference = 'Continue'
    $output = & $bashPath $cleanupSh.Replace('\','/') $Root.Replace('\','/') 2>&1 | Out-String
    return @{ ExitCode = $LASTEXITCODE; Output = $output }
  } finally {
    $ErrorActionPreference = $previousErrorAction
    if ($null -eq $previousApply) { Remove-Item Env:CLEANUP_APPLY -ErrorAction SilentlyContinue } else { $env:CLEANUP_APPLY = $previousApply }
  }
}

function New-OldFile([string]$Path, [string]$Contents = 'fixture') {
  New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
  [IO.File]::WriteAllText($Path, $Contents)
  (Get-Item -LiteralPath $Path).LastWriteTime = (Get-Date).AddDays(-30)
}

try {
  New-Item -ItemType Directory -Path $sandboxRoot | Out-Null

  Assert-PowerShellRejected ([IO.Path]::GetPathRoot($sandboxRoot)) 'filesystem root'
  Assert-PowerShellRejected ([Environment]::GetFolderPath('UserProfile')) 'user home'

  $unmarked = Join-Path $sandboxRoot 'unmarked'
  New-Item -ItemType Directory -Path $unmarked | Out-Null
  Assert-PowerShellRejected $unmarked 'repository marker'

  $manifestRepo = Join-Path $sandboxRoot 'manifest-repo'
  New-Item -ItemType Directory -Path $manifestRepo | Out-Null
  [IO.File]::WriteAllText((Join-Path $manifestRepo 'package.json'), '{}')
  $manifestTemp = Join-Path $manifestRepo 'stale.tmp'
  New-OldFile $manifestTemp
  & $cleanupPs -Root $manifestRepo -Apply | Out-Null
  Assert-True (-not (Test-Path -LiteralPath $manifestTemp)) 'PowerShell cleanup did not accept a recognized manifest repository.'

  $gitRepo = Join-Path $sandboxRoot 'git-repo'
  New-Item -ItemType Directory -Path $gitRepo | Out-Null
  git -C $gitRepo init -q
  $tracked = Join-Path $gitRepo 'tracked.tmp'
  $untracked = Join-Path $gitRepo 'untracked.tmp'
  New-OldFile $tracked 'tracked'
  New-OldFile $untracked 'untracked'
  git -C $gitRepo add tracked.tmp
  git -C $gitRepo -c user.name=UEEF -c user.email=ueef@example.invalid commit -qm 'test fixture'

  $dryRun = & $cleanupPs -Root $gitRepo 6>&1 | Out-String
  Assert-True (Test-Path -LiteralPath $untracked) 'PowerShell dry run deleted an artifact.'
  Assert-True ($dryRun -like '*Dry run only*') 'PowerShell dry run output changed unexpectedly.'

  & $cleanupPs -Root $gitRepo -Apply | Out-Null
  Assert-True (Test-Path -LiteralPath $tracked) 'PowerShell cleanup deleted a tracked artifact.'
  Assert-True (-not (Test-Path -LiteralPath $untracked)) 'PowerShell cleanup did not delete an eligible artifact.'

  $caseRepo = Join-Path $sandboxRoot 'case-repo'
  New-Item -ItemType Directory -Path (Join-Path $caseRepo 'SRC') -Force | Out-Null
  [IO.File]::WriteAllText((Join-Path $caseRepo 'package.json'), '{}')
  $protectedTemp = Join-Path $caseRepo 'SRC\protected.tmp'
  New-OldFile $protectedTemp
  & $cleanupPs -Root $caseRepo -Apply | Out-Null
  Assert-True (Test-Path -LiteralPath $protectedTemp) 'PowerShell protected-path comparison was not case-insensitive.'

  $linkRepo = Join-Path $sandboxRoot 'link-repo'
  $outside = Join-Path $sandboxRoot 'outside'
  New-Item -ItemType Directory -Path $linkRepo, $outside | Out-Null
  [IO.File]::WriteAllText((Join-Path $linkRepo 'package.json'), '{}')
  $sentinel = Join-Path $outside 'sentinel.tmp'
  New-OldFile $sentinel
  $link = Join-Path $linkRepo 'build'
  New-Item -ItemType Junction -Path $link -Target $outside | Out-Null
  & $cleanupPs -Root $linkRepo -Apply | Out-Null
  Assert-True (Test-Path -LiteralPath $sentinel) 'PowerShell cleanup followed a reparse point outside the repository.'
  Assert-True (Test-Path -LiteralPath $link) 'PowerShell cleanup removed an unsafe reparse-point candidate.'

  $nestedLinkRepo = Join-Path $sandboxRoot 'nested-link-repo'
  $nestedLinkParent = Join-Path $nestedLinkRepo 'reports'
  New-Item -ItemType Directory -Path $nestedLinkParent -Force | Out-Null
  [IO.File]::WriteAllText((Join-Path $nestedLinkRepo 'package.json'), '{}')
  $nestedLink = Join-Path $nestedLinkParent 'escape'
  New-Item -ItemType Junction -Path $nestedLink -Target $outside | Out-Null
  & $cleanupPs -Root $nestedLinkRepo -Apply | Out-Null
  Assert-True (Test-Path -LiteralPath $sentinel) 'PowerShell recursive discovery followed a nested reparse-point escape.'

  $linkedMarkerRepo = Join-Path $sandboxRoot 'linked-marker-repo'
  $markerTarget = Join-Path $sandboxRoot 'marker-target'
  New-Item -ItemType Directory -Path $linkedMarkerRepo, $markerTarget | Out-Null
  New-Item -ItemType Junction -Path (Join-Path $linkedMarkerRepo '.git') -Target $markerTarget | Out-Null
  Assert-PowerShellRejected $linkedMarkerRepo 'repository marker'

  $rootLink = Join-Path $sandboxRoot 'root-link'
  New-Item -ItemType Junction -Path $rootLink -Target $manifestRepo | Out-Null
  Assert-PowerShellRejected $rootLink 'reparse point'

  if ($bashPath) {
    $bashFilesystemRoot = Invoke-Bash ([IO.Path]::GetPathRoot($sandboxRoot))
    Assert-True ($bashFilesystemRoot.ExitCode -ne 0 -and $bashFilesystemRoot.Output -like '*filesystem root*') 'Shell cleanup accepted a filesystem root.'
    $bashHome = Invoke-Bash ([Environment]::GetFolderPath('UserProfile'))
    Assert-True ($bashHome.ExitCode -ne 0 -and $bashHome.Output -like '*user home*') 'Shell cleanup accepted the user home.'

    $bashUnmarked = Invoke-Bash $unmarked
    Assert-True ($bashUnmarked.ExitCode -ne 0 -and $bashUnmarked.Output -like '*repository marker*') 'Shell cleanup accepted an unmarked directory.'

    $bashRepo = Join-Path $sandboxRoot 'bash-repo'
    New-Item -ItemType Directory -Path $bashRepo | Out-Null
    [IO.File]::WriteAllText((Join-Path $bashRepo 'package.json'), '{}')
    $bashTemp = Join-Path $bashRepo 'old.tmp'
    New-OldFile $bashTemp
    $bashDryRun = Invoke-Bash $bashRepo
    Assert-True ($bashDryRun.ExitCode -eq 0 -and (Test-Path -LiteralPath $bashTemp)) 'Shell dry run failed or deleted an artifact.'
    $bashApply = Invoke-Bash $bashRepo $true
    Assert-True ($bashApply.ExitCode -eq 0 -and -not (Test-Path -LiteralPath $bashTemp)) 'Shell cleanup did not delete an eligible artifact.'

    $bashGitRepo = Join-Path $sandboxRoot 'bash-git-repo'
    New-Item -ItemType Directory -Path $bashGitRepo | Out-Null
    git -C $bashGitRepo init -q
    $bashTracked = Join-Path $bashGitRepo 'tracked.tmp'
    $bashUntracked = Join-Path $bashGitRepo 'untracked.tmp'
    New-OldFile $bashTracked 'tracked'
    New-OldFile $bashUntracked 'untracked'
    git -C $bashGitRepo add tracked.tmp
    git -C $bashGitRepo -c user.name=UEEF -c user.email=ueef@example.invalid commit -qm 'test fixture'
    $bashGitApply = Invoke-Bash $bashGitRepo $true
    Assert-True ($bashGitApply.ExitCode -eq 0) 'Shell cleanup failed for a Git repository.'
    Assert-True (Test-Path -LiteralPath $bashTracked) 'Shell cleanup deleted a tracked artifact.'
    Assert-True (-not (Test-Path -LiteralPath $bashUntracked)) 'Shell cleanup did not delete an eligible untracked artifact.'

    $bashLinkRepo = Join-Path $sandboxRoot 'bash-link-repo'
    New-Item -ItemType Directory -Path $bashLinkRepo | Out-Null
    [IO.File]::WriteAllText((Join-Path $bashLinkRepo 'package.json'), '{}')
    $bashLink = Join-Path $bashLinkRepo 'build'
    New-Item -ItemType Junction -Path $bashLink -Target $outside | Out-Null
    $bashLinkApply = Invoke-Bash $bashLinkRepo $true
    Assert-True ($bashLinkApply.ExitCode -eq 0) 'Shell cleanup failed while skipping an unsafe link.'
    Assert-True ((Test-Path -LiteralPath $sentinel) -and (Test-Path -LiteralPath $bashLink)) 'Shell cleanup followed or removed an unsafe link.'

    $shellTests = & $bashPath (Join-Path $PSScriptRoot 'test-cleanup-workspace.sh').Replace('\','/') 2>&1 | Out-String
    Assert-True ($LASTEXITCODE -eq 0 -and $shellTests -like '*Shell workspace cleanup tests passed*') 'Standalone shell cleanup tests failed.'
  } else {
    Write-Host 'Shell cleanup tests skipped: Git Bash unavailable'
  }

  Write-Host 'Workspace cleanup tests passed'
} finally {
  if (Test-Path -LiteralPath $sandboxRoot) { Remove-Item -LiteralPath $sandboxRoot -Recurse -Force }
}
