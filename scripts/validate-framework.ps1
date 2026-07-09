$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$required = @("README.md","INSTALL.md","VERSION.md","framework/MASTER_INDEX.md","scripts/install-codex.ps1","scripts/install-codex.sh","scripts/install-cursor.ps1","scripts/install-cursor.sh","scripts/install-generic.ps1","scripts/install-generic.sh")
$missing = @()
foreach ($r in $required) {
  if (!(Test-Path (Join-Path $Root $r))) { $missing += $r }
}
if ($missing.Count -gt 0) { throw "Missing required files: $($missing -join ', ')" }
$md = Get-ChildItem -Path $Root -Filter *.md -Recurse
$empty = $md | Where-Object { $_.Length -eq 0 }
if ($empty) { throw "Empty Markdown files: $($empty.FullName -join ', ')" }
$bad = Select-String -Path ($md.FullName) -Pattern "TODO|FIXME|lorem ipsum|TBD" -CaseSensitive:$false -ErrorAction SilentlyContinue
if ($bad) { throw "Disallowed weak markers found: $($bad[0].Path):$($bad[0].LineNumber)" }
$index = Get-Content (Join-Path $Root "framework/MASTER_INDEX.md") -Raw
if ($index -notmatch "Core Constitution" -or $index -notmatch "React Pack" -or $index -notmatch "Quality Gates") { throw "Master index does not link expected modules" }
$scriptRequired = Get-ChildItem (Join-Path $Root "scripts") | Where-Object { $_.Name -match "install|validate|update" }
if ($scriptRequired.Count -lt 10) { throw "Installer/update/validation script set is incomplete" }
Write-Host "UEEF validation passed"
Write-Host "Markdown file count: $($md.Count)"
Write-Host "Total file count: $((Get-ChildItem -Path $Root -File -Recurse).Count)"
