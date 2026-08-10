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
  $node = Get-Command node -ErrorAction Stop
  foreach ($bridge in @('invoke-spec-workflow-codex-host.mjs', 'invoke-spec-workflow-claude-host.mjs', 'invoke-spec-workflow-generic-host.mjs')) {
    & $node.Source --check (Join-Path $root "scripts\$bridge")
    if ($LASTEXITCODE -ne 0) { throw "Host bridge syntax check failed: $bridge" }
  }
  & $node.Source (Join-Path $root 'scripts\test-spec-workflow-host-receipt.mjs')
  if ($LASTEXITCODE -ne 0) { throw 'Host receipt parser tests failed.' }
  & $node.Source (Join-Path $root 'scripts\test-spec-workflow-generic-host.mjs')
  if ($LASTEXITCODE -ne 0) { throw 'Generic host bridge tests failed.' }
  & $node.Source (Join-Path $root 'scripts\test-host-route-inheritance.mjs')
  if ($LASTEXITCODE -ne 0) { throw 'Validated host route inheritance tests failed.' }
  & $node.Source (Join-Path $root 'scripts\test-spec-workflow-upstream.mjs')
  if ($LASTEXITCODE -ne 0) { throw 'Spec workflow upstream integrity tests failed.' }

  $engineHelp = (& $engine --help 2>&1 | Out-String)
  if ($engineHelp -match 'upstream-status|upstream-validate') {
    throw 'Production engine still exposes the retired Spec Kit runtime bridge.'
  }

  $initialized = & $engine init --graph $graph --state $state | ConvertFrom-Json
  if ($initialized.status -ne 'READY' -or $initialized.revision -ne 0) { throw 'Engine did not initialize a READY graph.' }
  $pauseState = Join-Path $created.path 'pause-state.json'
  & $engine init --graph $graph --state $pauseState | Out-Null
  $paused = & $engine pause --graph $graph --state $pauseState --reason 'integration pause' | ConvertFrom-Json
  if ($paused.status -ne 'PAUSED') { throw 'Engine did not persist operator pause.' }
  $pausedWave = & $engine schedule --graph $graph --state $pauseState | ConvertFrom-Json
  if ($pausedWave.wave.Count -ne 0) { throw 'Paused workflow scheduled new work.' }
  $resumed = & $engine resume --graph $graph --state $pauseState | ConvertFrom-Json
  if ($resumed.status -ne 'READY') { throw 'Engine did not resume operator pause.' }

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

  $receiptState = Join-Path $created.path 'receipt-state.json'
  $receiptResults = Join-Path $created.path 'host-results.json'
  & $engine init --graph $graph --state $receiptState | Out-Null
  $receiptWave = & $engine schedule --graph $graph --state $receiptState --adapter codex | ConvertFrom-Json
  $contract = $receiptWave.dispatchContracts[0]
  $acceptanceEvidence = @{}
  foreach ($criterion in @($contract.acceptance)) { $acceptanceEvidence[[string]$criterion] = 'host receipt integration test' }
  $receipt = @{schemaVersion=2;results=@(@{
    taskId=$contract.taskId;worker=$contract.worker;outcome='complete';evidence=($acceptanceEvidence | ConvertTo-Json -Compress);tokens=11
    workflowId=$contract.workflowId;executionId=$contract.executionId;graphDigest=$contract.graphDigest
    routeDigest=$contract.routeDigest;executionSpecDigest=$contract.executionSpecDigest
    attemptId=$contract.attemptId;leaseGeneration=$contract.leaseGeneration;fencingToken=$contract.fencingToken
  })} | ConvertTo-Json -Depth 5
  [IO.File]::WriteAllText($receiptResults, $receipt, [Text.UTF8Encoding]::new($false))
  $applied = & $engine apply-results --graph $graph --state $receiptState --adapter codex --results $receiptResults | ConvertFrom-Json
  if ($applied.appliedResultCount -ne 1) { throw 'Engine did not apply the reserved host receipt.' }
  if (!(Test-Path -LiteralPath ($receiptState + '.events.jsonl'))) { throw 'Engine did not write the persisted event log.' }
  & $node.Source (Join-Path $root 'scripts\test-spec-workflow-cycle.mjs')
  if ($LASTEXITCODE -ne 0) { throw 'Spec workflow host cycle test failed.' }
  Write-Host 'Spec workflow engine integration tests passed'
} finally {
  if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
