[CmdletBinding()]
param(
  [string]$Repository = '',
  [string]$Tag = '',
  [string]$Title = '',
  [string]$NotesFile = '',
  [ValidateRange(30,3600)][int]$CiTimeoutSeconds = 900,
  [ValidateRange(5,120)][int]$CiPollSeconds = 15,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content -LiteralPath (Join-Path $root 'release-manifest.json') -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($Tag)) { $Tag = 'v' + [string]$manifest.version }
if ([string]::IsNullOrWhiteSpace($Title)) { $Title = "Release $Tag" }
if ([string]::IsNullOrWhiteSpace($NotesFile)) { $NotesFile = Join-Path $root ([string]$manifest.releaseNotes) }
if ([string]::IsNullOrWhiteSpace($Repository)) {
  if (![string]::IsNullOrWhiteSpace([string]$manifest.repository)) {
    $Repository = [string]$manifest.repository
  } else {
    $remoteUrl = (git -C $root remote get-url origin) -join ''
    $match = [regex]::Match($remoteUrl, 'github\.com[:/](?<owner>[^/]+)/(?<repo>[^/.]+)(?:\.git)?$')
    if (!$match.Success) { throw "Could not infer GitHub repository from origin: $remoteUrl" }
    $Repository = "$($match.Groups['owner'].Value)/$($match.Groups['repo'].Value)"
  }
}

$notesPath = (Resolve-Path -LiteralPath $NotesFile).Path
$notes = [IO.File]::ReadAllText($notesPath)
if ([string]::IsNullOrWhiteSpace($notes)) { throw "Release notes file is empty: $notesPath" }

function Test-GhAuthenticated {
  $ghCommand = Get-Command gh -ErrorAction SilentlyContinue
  if (!$ghCommand) { return $false }
  $psi = [Diagnostics.ProcessStartInfo]::new($ghCommand.Source, 'auth status --hostname github.com')
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $process = [Diagnostics.Process]::Start($psi)
  $process.StandardOutput.ReadToEnd() | Out-Null
  $process.StandardError.ReadToEnd() | Out-Null
  $process.WaitForExit()
  return $process.ExitCode -eq 0
}

function Get-GhToken {
  $ghCommand = Get-Command gh -ErrorAction SilentlyContinue
  if (!$ghCommand) { return $null }
  $psi = [Diagnostics.ProcessStartInfo]::new($ghCommand.Source, 'auth token --hostname github.com')
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $process = [Diagnostics.Process]::Start($psi)
  $token = $process.StandardOutput.ReadToEnd().Trim()
  $process.StandardError.ReadToEnd() | Out-Null
  $process.WaitForExit()
  if ($process.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($token)) { return $null }
  return $token
}

function Get-GitCredentialManagerToken {
  $manager = (Get-Command git-credential-manager -ErrorAction SilentlyContinue).Source
  if ([string]::IsNullOrWhiteSpace($manager)) {
    $candidate = Join-Path $env:ProgramFiles 'Git\mingw64\bin\git-credential-manager.exe'
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { $manager = $candidate }
  }
  if ([string]::IsNullOrWhiteSpace($manager) -or !(Test-Path -LiteralPath $manager -PathType Leaf)) { return $null }

  $inputText = "protocol=https`nhost=github.com`n`n"
  $psi = [Diagnostics.ProcessStartInfo]::new($manager, 'get --no-ui')
  $psi.RedirectStandardInput = $true
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $process = [Diagnostics.Process]::Start($psi)
  $process.StandardInput.Write($inputText)
  $process.StandardInput.Close()
  $output = $process.StandardOutput.ReadToEnd()
  $process.StandardError.ReadToEnd() | Out-Null
  $process.WaitForExit()
  if ($process.ExitCode -ne 0) { return $null }
  $line = ($output -split "`r?`n") | Where-Object { $_ -like 'password=*' } | Select-Object -First 1
  if (!$line) { return $null }
  return ($line -replace '^password=', '')
}

function Publish-WithGitHubApi([string]$Token) {
  $body = [ordered]@{
    tag_name = $Tag
    target_commitish = 'main'
    name = $Title
    body = $notes
    draft = $false
    prerelease = $false
  } | ConvertTo-Json -Depth 5
  Invoke-RestMethod -Method Post -Uri "https://api.github.com/repos/$Repository/releases" -Headers @{
    Authorization = "Bearer $Token"
    Accept = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
    'User-Agent' = 'UEEF'
  } -ContentType 'application/json' -Body $body
}

function Wait-ForSuccessfulValidation([string]$Token) {
  $dirty = @(git -C $root status --porcelain)
  if ($LASTEXITCODE -ne 0) { throw 'Could not inspect the release worktree.' }
  if ($dirty.Count) { throw 'Refusing to publish from a dirty worktree.' }
  $head = (git -C $root rev-parse HEAD) -join ''
  if ($LASTEXITCODE -ne 0 -or $head -notmatch '^[0-9a-f]{40}$') { throw 'Could not resolve the release commit.' }
  $headers = @{
    Accept = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
    'User-Agent' = 'UEEF'
  }
  if (![string]::IsNullOrWhiteSpace($Token)) { $headers.Authorization = "Bearer $Token" }
  $deadline = [DateTimeOffset]::UtcNow.AddSeconds($CiTimeoutSeconds)
  do {
    $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/actions/runs?head_sha=$head&event=push&per_page=20" -Headers $headers
    $run = @($response.workflow_runs | Where-Object { $_.name -eq 'Validate UEEF' } | Sort-Object created_at -Descending | Select-Object -First 1)
    if ($run.Count -eq 1 -and [string]$run[0].status -eq 'completed') {
      if ([string]$run[0].conclusion -ne 'success') {
        throw "GitHub Actions validation failed for $head`: $($run[0].html_url)"
      }
      Write-Output "GitHub Actions validation passed for $head"
      return
    }
    if ([DateTimeOffset]::UtcNow -ge $deadline) {
      throw "Timed out waiting for GitHub Actions validation for $head."
    }
    Start-Sleep -Seconds $CiPollSeconds
  } while ($true)
}

if ($DryRun) {
  [pscustomobject]@{
    repository = $Repository
    tag = $Tag
    title = $Title
    notesFile = $notesPath
    ciCheckRequired = $true
    ciTimeoutSeconds = $CiTimeoutSeconds
    ghAuthenticated = Test-GhAuthenticated
    gitCredentialManagerAvailable = [bool](Get-GitCredentialManagerToken)
  }
  return
}

$ghAuthenticated = Test-GhAuthenticated
$token = if ($ghAuthenticated) { Get-GhToken } else { $null }
if ([string]::IsNullOrWhiteSpace($token)) { $token = Get-GitCredentialManagerToken }
try {
  Wait-ForSuccessfulValidation -Token $token

  if ($ghAuthenticated) {
    gh release create $Tag --repo $Repository --title $Title --notes-file $notesPath
    if ($LASTEXITCODE -ne 0) { throw "gh release create failed for $Tag." }
    Write-Output "GitHub release published with gh: https://github.com/$Repository/releases/tag/$Tag"
    return
  }

  if ([string]::IsNullOrWhiteSpace($token)) {
    throw 'No GitHub release credential is available. Run gh auth login, set GH_TOKEN, or sign in through Git Credential Manager.'
  }
  $release = Publish-WithGitHubApi -Token $token
  Write-Output "GitHub release published with Git Credential Manager: $($release.html_url)"
} finally {
  $token = $null
}
