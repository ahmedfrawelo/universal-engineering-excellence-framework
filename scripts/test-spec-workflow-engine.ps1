$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('ueef-spec-engine-' + [guid]::NewGuid().ToString('N'))
try {
  $python = Get-Command python -ErrorAction Stop
  $packageRoot = Join-Path $root 'engines\spec-workflow\ueef'
  $previousPythonPath = $env:PYTHONPATH
  $previousBytecode = $env:PYTHONDONTWRITEBYTECODE
  try {
    $env:PYTHONPATH = if ($previousPythonPath) { $packageRoot + [IO.Path]::PathSeparator + $previousPythonPath } else { $packageRoot }
    $env:PYTHONDONTWRITEBYTECODE = '1'
    & $python.Source -m unittest discover -s (Join-Path $root 'engines\spec-workflow\tests') -t (Join-Path $root 'engines\spec-workflow')
    if ($LASTEXITCODE -ne 0) { throw 'Spec workflow engine unit tests failed.' }
  } finally {
    $env:PYTHONPATH = $previousPythonPath
    $env:PYTHONDONTWRITEBYTECODE = $previousBytecode
  }
  New-Item -ItemType Directory -Path $sandbox | Out-Null
  $created = & (Join-Path $root 'scripts\new-spec-workflow.ps1') -Id 'engine-demo' -Root $sandbox | ConvertFrom-Json
  $graph = Join-Path $created.path 'task-graph.json'
  $state = Join-Path $created.path 'execution-state.json'
  $engine = Join-Path $root 'scripts\invoke-spec-workflow-engine.ps1'

  $upstream = & $engine upstream-status | ConvertFrom-Json
  if (!$upstream.valid -or $upstream.release -ne 'v0.16.1') { throw 'Upstream snapshot verification failed.' }

  $initialized = & $engine init --graph $graph --state $state | ConvertFrom-Json
  if ($initialized.status -ne 'READY' -or $initialized.revision -ne 0) { throw 'Engine did not initialize a READY graph.' }

  $wave = & $engine schedule --graph $graph --state $state --adapter codex | ConvertFrom-Json
  if ($wave.wave.Count -ne 1 -or $wave.wave[0].taskId -ne 'TASK-001' -or $wave.team.scaleAction -ne 'GROW') { throw 'Engine did not schedule the expected first wave.' }
  if ($wave.dispatchContracts[0].adapter -ne 'codex') { throw 'Codex dispatch contract was not emitted.' }

  $released = & $engine transition --graph $graph --state $state --task TASK-001 --action release --error 'simulated dispatch failure' --expected-revision 1 | ConvertFrom-Json
  if ($released.tasks.'TASK-001'.status -ne 'READY') { throw 'Engine did not release a failed dispatch reservation.' }
  $retryWave = & $engine schedule --graph $graph --state $state --adapter codex | ConvertFrom-Json
  if ($retryWave.wave.Count -ne 1 -or $retryWave.persistedRevision -ne 3) { throw 'Engine did not reserve a replacement dispatch wave.' }

  $started = & $engine transition --graph $graph --state $state --task TASK-001 --action start --worker worker-1 --expected-revision 3 | ConvertFrom-Json
  if ($started.tasks.'TASK-001'.status -ne 'RUNNING') { throw 'Engine did not record RUNNING.' }
  $completed = & $engine transition --graph $graph --state $state --task TASK-001 --action complete --evidence 'integration test passed' --tokens 250 --expected-revision 4 | ConvertFrom-Json
  if ($completed.status -ne 'DONE' -or $completed.tokensConsumed -ne 250) { throw 'Engine did not record evidence-backed completion.' }

  $finalWave = & $engine schedule --graph $graph --state $state --adapter codex | ConvertFrom-Json
  if ($finalWave.wave.Count -ne 0 -or $finalWave.team.scaleAction -ne 'SHRINK') { throw 'Engine did not shrink the team after convergence.' }
  Write-Host 'Spec workflow engine integration tests passed'
} finally {
  if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
