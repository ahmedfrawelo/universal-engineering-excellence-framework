$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Push-Location $Root
try {
  if (Test-Path ".git") { git pull --ff-only }
  Write-Host "Repository refreshed. Run the installer for each assistant you use."
} finally {
  Pop-Location
}
