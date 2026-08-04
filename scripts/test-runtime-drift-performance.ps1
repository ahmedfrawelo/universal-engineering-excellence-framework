$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'scripts\runtime-file-policy.ps1')
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('ueef-runtime-drift-' + [guid]::NewGuid().ToString('N'))
try {
  $source = Join-Path $sandbox 'source'
  $runtime = Join-Path $sandbox 'runtime'
  New-Item -ItemType Directory -Path (Join-Path $source 'scripts'), (Join-Path $source 'framework'), $runtime -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $source 'scripts\sample.ps1') -Value 'alpha' -NoNewline -Encoding ascii
  Set-Content -LiteralPath (Join-Path $source 'framework\sample.md') -Value '# sample' -Encoding utf8
  Set-Content -LiteralPath (Join-Path $source 'VERSION.md') -Value 'version: 0.0.0' -Encoding utf8
  git -C $source init -q
  git -C $source config user.email 'ueef-test@example.invalid'
  git -C $source config user.name 'UEEF Test'
  git -C $source add -- scripts framework VERSION.md
  git -C $source commit -qm baseline
  Copy-UeefReleaseFiles -SourcePath $source -DestinationPath $runtime
  $loader = Join-Path $runtime 'UEEF-LOADER.md'
  Set-Content -LiteralPath $loader -Encoding utf8 -Value "Agent and model routing:`nenvironment-bootstrap`nLoaded: boot-loader, core-system"
  $loaderHash = (Get-FileHash -LiteralPath $loader -Algorithm SHA256).Hash

  $watch = [Diagnostics.Stopwatch]::StartNew()
  $clean = @(Get-UeefRuntimeDriftMismatches -SourcePath $source -RuntimePath $runtime -ExpectedLoaderHash $loaderHash)
  $watch.Stop()
  if ($clean.Count) { throw "Clean runtime reported drift: $($clean -join ', ')" }
  if ($watch.ElapsedMilliseconds -gt 2500) { throw "Small runtime drift verification exceeded 2500 ms: $($watch.ElapsedMilliseconds) ms" }
  $before = Get-UeefRuntimeContentSignature -SourcePath $source -RuntimePath $runtime -ExpectedLoaderHash $loaderHash

  $runtimeSample = Join-Path $runtime 'scripts\sample.ps1'
  $timestamp = (Get-Item -LiteralPath $runtimeSample).LastWriteTimeUtc
  Set-Content -LiteralPath $runtimeSample -Value 'omega' -NoNewline -Encoding ascii
  (Get-Item -LiteralPath $runtimeSample).LastWriteTimeUtc = $timestamp
  $after = Get-UeefRuntimeContentSignature -SourcePath $source -RuntimePath $runtime -ExpectedLoaderHash $loaderHash
  if ($after -ceq $before) { throw 'Content signature missed a same-length runtime mutation with restored timestamp.' }
  $drift = @(Get-UeefRuntimeDriftMismatches -SourcePath $source -RuntimePath $runtime -ExpectedLoaderHash $loaderHash)
  if ($drift -notcontains 'Different: scripts/sample.ps1') { throw "Runtime content mutation was not detected: $($drift -join ', ')" }
} finally {
  if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
Write-Output 'Runtime drift performance and content-signature tests passed'
