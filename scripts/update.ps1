$Root = Split-Path -Parent $PSScriptRoot
git -C $Root pull --ff-only
Write-Host "Repository updated. Re-run installer for each agent."
