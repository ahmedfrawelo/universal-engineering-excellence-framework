$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$requiredRoot = @("README.md","INSTALL.md","QUICK_START.md","VERSION.md","CHANGELOG.md","LICENSE","CONTRIBUTING.md","CODE_OF_CONDUCT.md","SECURITY.md","ROADMAP.md","BUILD_PROGRESS.md")
$missing = @()
foreach ($f in $requiredRoot) { if (!(Test-Path (Join-Path $Root $f))) { $missing += $f } }
$requiredDirs = @("framework","scripts","docs","examples","tools")
foreach ($d in $requiredDirs) { if (!(Test-Path (Join-Path $Root $d))) { $missing += $d } }
$packs = Get-ChildItem (Join-Path $Root "framework") -Directory
foreach ($p in $packs) {
  if (!(Test-Path (Join-Path $p.FullName "README.md"))) { $missing += "$($p.Name)/README.md" }
  if (!(Test-Path (Join-Path $p.FullName "INDEX.md"))) { $missing += "$($p.Name)/INDEX.md" }
}
if ($missing.Count) { throw "Missing required items: $($missing -join ', ')" }
$md = Get-ChildItem $Root -Filter *.md -Recurse
if ($md.Count -lt 160) { throw "Markdown count below minimum: $($md.Count)" }
$empty = $md | Where-Object { $_.Length -eq 0 }
if ($empty) { throw "Empty Markdown files: $($empty.FullName -join ', ')" }
$weak = Select-String -Path $md.FullName -Pattern 'TODO only|lorem ipsum|placeholder only|TBD only' -CaseSensitive:$false -ErrorAction SilentlyContinue
if ($weak) { throw "Placeholder-like marker found: $($weak[0].Path):$($weak[0].LineNumber)" }
$scriptNames = @("install-codex.ps1","install-codex.sh","install-cursor.ps1","install-cursor.sh","install-generic.ps1","install-generic.sh","validate-framework.ps1","validate-framework.sh","backup-existing-rules.ps1","backup-existing-rules.sh","detect-agent.ps1","detect-agent.sh")
foreach ($s in $scriptNames) { if (!(Test-Path (Join-Path $Root "scripts/$s"))) { throw "Missing script $s" } }
$master = Join-Path $Root "framework/MASTER_INDEX.md"
if (!(Test-Path $master)) { throw "Missing framework/MASTER_INDEX.md" }
$masterText = Get-Content $master -Raw
if ($masterText -notmatch "00-foundation" -or $masterText -notmatch "27-quality-gates" -or $masterText -notmatch "38-templates") { throw "Master index missing expected pack references" }
Write-Host "UEEF validation passed"
Write-Host "Markdown file count: $($md.Count)"
Write-Host "Framework pack count: $($packs.Count)"
Write-Host "Total file count: $((Get-ChildItem $Root -File -Recurse).Count)"
