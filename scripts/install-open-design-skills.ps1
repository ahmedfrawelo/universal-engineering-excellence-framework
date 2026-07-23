param(
  [string]$CodexHome = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'resolve-codex-home.ps1')
if ([string]::IsNullOrWhiteSpace($CodexHome)) { $CodexHome = Resolve-CodexHome }
$openDesignRef = '034c3895d127743038c18c09a38eab9c7d6a7641'
$installer = Join-Path $CodexHome 'skills\.system\skill-installer\scripts\install-skill-from-github.py'
if (!(Test-Path -LiteralPath $installer)) { throw "Skill installer not found: $installer" }
$python = Get-Command python -ErrorAction SilentlyContinue
if (!$python) { throw 'Python is required to install Open Design skills.' }

$skillPaths = @('skills/design-brief', 'skills/frontend-design')
$missing = @($skillPaths | Where-Object {
  $name = Split-Path $_ -Leaf
  !(Test-Path -LiteralPath (Join-Path $CodexHome "skills\$name\SKILL.md"))
})
if (!$missing.Count) {
  Write-Output 'Open Design skills already installed'
  exit 0
}

& $python.Source $installer --repo nexu-io/open-design --ref $openDesignRef --path @missing --dest (Join-Path $CodexHome 'skills')
if ($LASTEXITCODE -ne 0) { throw "Open Design skill installation failed with exit code $LASTEXITCODE" }
Write-Output "Open Design skills installed: $($missing.Count) from $openDesignRef"
