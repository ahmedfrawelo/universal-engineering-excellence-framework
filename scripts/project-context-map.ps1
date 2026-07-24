param(
  [string]$Path = (Get-Location).Path,
  [int]$MaxItems = 40
)
$ErrorActionPreference = "Stop"

if (!(Test-Path -LiteralPath $Path)) { throw "Path not found: $Path" }
if ($MaxItems -lt 1) { throw "MaxItems must be at least 1." }
$Root = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path).Path)

function Get-RelPath {
  param([string]$FullName)
  $relative = $FullName.Substring($Root.TrimEnd('\').Length).TrimStart('\','/')
  if (!$relative) { return "." }
  return $relative -replace '\\','/'
}

function Write-Section {
  param([string]$Title, [object[]]$Items)
  Write-Output ""
  Write-Output "${Title}:"
  if (!$Items -or $Items.Count -eq 0) {
    Write-Output "- none detected"
    return
  }
  $Items | Select-Object -First $MaxItems | ForEach-Object { Write-Output "- $_" }
  if ($Items.Count -gt $MaxItems) { Write-Output "- ... truncated: $($Items.Count - $MaxItems) more" }
}

$MetadataSkipDirs = @(".git")
$GeneratedSkipDirs = @("node_modules","dist","build","out","coverage",".next",".angular","bin","obj")
$AllFiles = New-Object System.Collections.Generic.List[object]
$AllDirs = New-Object System.Collections.Generic.List[object]
$queue = New-Object System.Collections.Generic.Queue[string]
$queue.Enqueue($Root)
while ($queue.Count -gt 0) {
  $current = $queue.Dequeue()
  foreach ($item in Get-ChildItem -LiteralPath $current -Force -ErrorAction SilentlyContinue) {
    if ($item.PSIsContainer) {
      if ($MetadataSkipDirs -contains $item.Name) { continue }
      $AllDirs.Add($item) | Out-Null
      if ($GeneratedSkipDirs -contains $item.Name) { continue }
      $queue.Enqueue($item.FullName)
    } else {
      $AllFiles.Add($item) | Out-Null
    }
  }
}

function Find-FilesByName {
  param([string[]]$Names)
  $AllFiles |
    Where-Object { $Names -contains $_.Name } |
    ForEach-Object { Get-RelPath $_.FullName }
}

function Find-DirsByName {
  param([string[]]$Names)
  $AllDirs |
    Where-Object { $Names -contains $_.Name } |
    ForEach-Object { Get-RelPath $_.FullName }
}

function Find-FilesByPattern {
  param([string[]]$Patterns)
  foreach ($pattern in $Patterns) {
    $AllFiles | Where-Object { $_.Name -like $pattern } | ForEach-Object { Get-RelPath $_.FullName }
  }
}

$manifests = Find-FilesByName @(
  "release-manifest.json","package.json","pnpm-workspace.yaml","pnpm-lock.yaml","yarn.lock","package-lock.json","angular.json",
  "vite.config.ts","vite.config.js","next.config.js","next.config.mjs","tsconfig.json",
  "Dockerfile","docker-compose.yml","docker-compose.yaml","global.json","hosting.json","pyproject.toml","requirements.txt",
  "Pipfile","poetry.lock","Cargo.toml","Cargo.lock","go.mod","go.sum","pom.xml","build.gradle","build.gradle.kts"
) + (Find-FilesByPattern @("*.sln","*.csproj","*.fsproj","*.vbproj","*.xcodeproj"))
$sharedDirs = Find-DirsByName @("shared","common","lib","libs","library","components","ui","design-system","services","api","clients","validators","schemas","stores","state","hooks","utils")
$featureDirs = Find-DirsByName @("src","app","apps","features","framework","modules","packages","pages","routes","domains","cmd","internal","plugins","scripts")
$designDirs = Find-DirsByName @("tokens","theme","themes","styles","scss","css","icons","assets")
$testDirs = Find-DirsByName @("test","tests","e2e","spec","specs","__tests__","playwright","cypress")
$testFiles = Find-FilesByPattern @("test-*","*.test.*","*.spec.*","*_test.*","*Tests.*")
$ciDirs = Find-DirsByName @(".github",".gitlab","ci","deploy","deployment","infra","infrastructure","terraform","k8s","helm")
$generatedDirs = Find-DirsByName @("dist","build","out","coverage",".next",".angular","node_modules","bin","obj","logs","screenshots","artifacts")

Write-Output "Project Context Map"
Write-Output "Root: $Root"
Write-Output "Generated: $(Get-Date -Format s)"
Write-Section "Manifests" @($manifests | Sort-Object -Unique)
Write-Section "Shared candidates" @($sharedDirs | Sort-Object -Unique)
Write-Section "Feature/module candidates" @($featureDirs | Sort-Object -Unique)
Write-Section "Design system candidates" @($designDirs | Sort-Object -Unique)
Write-Section "Test candidates" (@($testDirs) + @($testFiles) | Sort-Object -Unique)
Write-Section "CI/deployment candidates" @($ciDirs | Sort-Object -Unique)
Write-Section "Generated/output candidates" @($generatedDirs | Sort-Object -Unique)
