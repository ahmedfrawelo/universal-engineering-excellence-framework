param(
  [string]$CodexHome = ''
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'resolve-codex-home.ps1')
if ([string]::IsNullOrWhiteSpace($CodexHome)) { $CodexHome = Resolve-CodexHome }
$designSkillsRef = '6bf24434f7730ad169077756cf9c7cd7bd675fc6'

$installer = Join-Path $CodexHome 'skills\.system\skill-installer\scripts\install-skill-from-github.py'
if (!(Test-Path -LiteralPath $installer)) { throw "Skill installer not found: $installer" }
$python = Get-Command python -ErrorAction SilentlyContinue
if (!$python) { throw 'Python is required to install design engineering skills.' }

$skillPaths = @(
  'skills/animation-vocabulary',
  'skills/apple-design',
  'skills/emil-design-eng',
  'skills/improve-animations',
  'skills/review-animations'
)
$missing = @($skillPaths | Where-Object {
  $name = Split-Path $_ -Leaf
  !(Test-Path -LiteralPath (Join-Path $CodexHome "skills\$name\SKILL.md"))
})

if (!$missing.Count) {
  Write-Output 'Design engineering skills already installed'
  exit 0
}

& $python.Source $installer --repo emilkowalski/skills --ref $designSkillsRef --path @missing --dest (Join-Path $CodexHome 'skills')
if ($LASTEXITCODE -ne 0) { throw "Design skill installation failed with exit code $LASTEXITCODE" }
Write-Output "Design engineering skills installed: $($missing.Count) from $designSkillsRef"
