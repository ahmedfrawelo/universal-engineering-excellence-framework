$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$broken = [System.Collections.Generic.List[string]]::new()
Get-ChildItem -LiteralPath $root -Recurse -Filter *.md -File | Where-Object { $_.FullName -notmatch '\.git[\\/]' } | ForEach-Object {
  $file = $_
  $content = Get-Content -LiteralPath $file.FullName -Raw
  foreach ($match in [regex]::Matches($content, '\[[^\]]+\]\(([^)]+)\)')) {
    $target = $match.Groups[1].Value.Trim('<','>')
    if ($target -match '^(https?://|mailto:|#)') { continue }
    $target = $target.Split('#')[0]
    if (!$target) { continue }
    try { $resolved = [IO.Path]::GetFullPath((Join-Path $file.DirectoryName $target)) }
    catch { $broken.Add("$($file.FullName) -> $target"); continue }
    if (!(Test-Path -LiteralPath $resolved)) { $broken.Add("$($file.FullName) -> $target") }
  }
}
if ($broken.Count) { throw "Broken Markdown links: $($broken -join '; ')" }
Write-Host 'Documentation link tests passed'
