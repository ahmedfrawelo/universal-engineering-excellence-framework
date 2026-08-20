$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$sandbox = Join-Path ([IO.Path]::GetTempPath()) "ueef-runtime-metadata-$([guid]::NewGuid().ToString('N'))"
try {
  $source = Join-Path $sandbox 'source'
  $runtime = Join-Path $sandbox 'runtime'
  New-Item -ItemType Directory -Path $source, $runtime -Force | Out-Null
  $sourceFile = Join-Path $source 'README.md'
  $runtimeFile = Join-Path $runtime 'README.md'
  Set-Content -LiteralPath $sourceFile -Value 'AAAA' -NoNewline -Encoding ascii
  Set-Content -LiteralPath $runtimeFile -Value 'AAAA' -NoNewline -Encoding ascii
  $node = Get-Command node -ErrorAction Stop
  $helper = Join-Path $root 'scripts\runtime-metadata-signature.mjs'
  $before = ('README.md' | & $node.Source $helper $source $runtime '')
  $originalWriteTime = (Get-Item -LiteralPath $runtimeFile).LastWriteTimeUtc
  Start-Sleep -Milliseconds 20
  Set-Content -LiteralPath $runtimeFile -Value 'BBBB' -NoNewline -Encoding ascii
  (Get-Item -LiteralPath $runtimeFile).LastWriteTimeUtc = $originalWriteTime
  $after = ('README.md' | & $node.Source $helper $source $runtime '')
  if ($before -eq $after) { throw 'Runtime metadata signature missed a same-size edit with restored LastWriteTime.' }
  Write-Output 'Runtime metadata signature tests passed'
} finally {
  if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
