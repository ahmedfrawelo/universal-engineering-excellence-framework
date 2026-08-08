$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $root 'scripts\managed-enforcement.ps1'
$hookSource = Join-Path $root 'scripts\codex-hooks\ueef-codex-hook.mjs'
$recorderSource = Join-Path $root 'scripts\codex-hooks\record-ueef-route.mjs'
$policySource = Join-Path $root 'config\codex-enforcement-policy.json'
foreach ($required in @($installer, $hookSource, $recorderSource, $policySource)) {
  if (!(Test-Path -LiteralPath $required -PathType Leaf)) { throw "Managed enforcement dependency missing: $required" }
}
$policyText = [IO.File]::ReadAllText($policySource, [Text.Encoding]::UTF8)
function Decode-Utf8Base64([string]$Value) { return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Value)) }
foreach ($term in @('2KfZhNmB2YfZhQ==','2KfZhNmF2LHYrdmE2Kk=','2KfZhNmG2LPYqNipINin2YTZg9mE2YrYqQ==','2KfZhNmI2KfYrNmH2Kk=','2YfZhCDYqtix2YrYrw==') | ForEach-Object { Decode-Utf8Base64 $_ }) {
  if (!$policyText.Contains($term)) { throw "Managed enforcement policy lost Arabic term: $term" }
}
if ($policyText -match '[ØÙ�]') { throw 'Managed enforcement policy contains mojibake instead of Arabic UTF-8 text.' }

. $installer
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('ueef-managed-enforcement-' + [guid]::NewGuid().ToString('N'))

function Invoke-Hook {
  param([string]$NodePath, [string]$Script, [hashtable]$Event)
  $json = $Event | ConvertTo-Json -Depth 12 -Compress
  $start = [Diagnostics.ProcessStartInfo]::new()
  $start.FileName = $NodePath
  $start.Arguments = "`"$Script`""
  $start.UseShellExecute = $false
  $start.RedirectStandardInput = $true
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $start
  [void]$process.Start()
  $jsonBytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
  $process.StandardInput.BaseStream.Write($jsonBytes, 0, $jsonBytes.Length)
  $process.StandardInput.Close()
  $output = $process.StandardOutput.ReadToEnd()
  $errorText = $process.StandardError.ReadToEnd()
  $process.WaitForExit()
  if ($process.ExitCode -ne 0) { throw "Hook failed with exit code $($process.ExitCode): $errorText" }
  if ([string]::IsNullOrWhiteSpace($output)) { return [pscustomobject]@{} }
  return ($output | ConvertFrom-Json)
}

function Assert-Denied($Result, [string]$Context) {
  $decision = [string]$Result.hookSpecificOutput.permissionDecision
  if ($decision -ne 'deny' -and [string]$Result.decision -ne 'block') { throw "$Context was not denied." }
}

function Assert-StopBlocked($Result, [string]$Context) {
  if ([string]$Result.decision -ne 'block' -or [string]::IsNullOrWhiteSpace([string]$Result.reason)) { throw "$Context did not continue the turn." }
}

function Add-AssistantMessage {
  param([string]$Path,[string]$Text)
  $item = [ordered]@{
    type = 'response_item'
    payload = [ordered]@{
      type = 'message'
      role = 'assistant'
      phase = 'commentary'
      content = @([ordered]@{type='output_text';text=$Text})
    }
  }
  [IO.File]::AppendAllText($Path, (($item | ConvertTo-Json -Depth 8 -Compress) + "`n"), [Text.UTF8Encoding]::new($false))
}

function Record-UeefRoute {
  param([string]$NodePath,[string]$Recorder,[string]$Catalog,[string]$Session,[string]$Turn,[string]$Tier,[string]$Intent,[string]$WorkUnit,[string]$Transcript,[string]$BrowserReason='not required')
  $routeOutput = Join-Path ([IO.Path]::GetTempPath()) ("ueef-managed-route-" + [guid]::NewGuid().ToString('N') + '.json')
  $route = & $NodePath $Recorder --session-id $Session --turn-id $Turn --work-unit-id $WorkUnit --tier $Tier --intent $Intent --agent-route 'single primary agent' --browser-reason $BrowserReason --acceptance 'Requested behavior is implemented and verified' --owner-paths 'bounded test owner' --non-goals 'unrelated project behavior' --model-catalog $Catalog --allow-test-catalog --route-output $routeOutput | ConvertFrom-Json
  if ($LASTEXITCODE -ne 0) { throw "Node dynamic route recorder failed for $Session/$Turn." }
  if (!(Test-Path -LiteralPath $routeOutput -PathType Leaf)) { throw 'Dynamic route recorder did not create --route-output.' }
  $artifact = Get-Content -LiteralPath $routeOutput -Raw | ConvertFrom-Json
  if ($artifact.routeLine -cne $route.routeLine -or $artifact.routeDigest -cne $route.routeDigest) { throw 'Managed route artifact did not preserve route line and digest.' }
  if ($Tier -in @('T2','T3','T4') -and (!$artifact.executionSpec.digest -or !$artifact.tokenEconomy.specRequired)) { throw 'Managed route artifact did not bind the required T2+ execution spec and token economy contract.' }
  Remove-Item -LiteralPath $routeOutput -Force
  Add-AssistantMessage $Transcript $route.routeLine
  return $route
}

function Complete-HostDispatch {
  param([string]$NodePath,[string]$Hook,[string]$StateRoot,[hashtable]$Base,[string]$Session,[string]$Turn,[string]$Transcript)
  $statePath = (Get-ChildItem -LiteralPath $StateRoot -Filter "*.$Turn.json" -File | Select-Object -First 1).FullName
  $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
  Invoke-Hook $NodePath $Hook ($Base + @{hook_event_name='PostToolUse';tool_name='codex_app__send_message_to_thread';tool_use_id="dispatch-$Turn";tool_input=@{threadId='thread';model=$state.route.preferredModel;thinking=$state.route.hostReasoning};tool_response="Exit code: 0`n{`"threadId`":`"thread`"}"}) | Out-Null
  $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
  if ($state.validations.modelDispatch -eq $true) { throw 'A successful host tool call without an actual execution receipt was incorrectly accepted.' }
  $minimalReceipt = [ordered]@{routeDigest=$state.route.routeDigest;actualModel=$state.route.preferredModel;actualHostReasoning=$state.route.hostReasoning;executionVerified=$true;result='SUCCESS'} | ConvertTo-Json -Compress
  Invoke-Hook $NodePath $Hook ($Base + @{hook_event_name='PostToolUse';tool_name='codex_app__send_message_to_thread';tool_use_id="dispatch-minimal-$Turn";tool_input=@{threadId='thread';model=$state.route.preferredModel;thinking=$state.route.hostReasoning};tool_response=$minimalReceipt}) | Out-Null
  $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
  if ($state.validations.modelDispatch -eq $true) { throw 'Minimal host receipt without provider execution metadata was incorrectly accepted.' }
  $receipt = [ordered]@{provider='codex-app-server:turn/start';threadId='host-thread';turnId='host-turn';routeDigest=$state.route.routeDigest;actualModel=$state.route.preferredModel;actualHostReasoning=$state.route.hostReasoning;executionVerificationSource='codex-app-server:thread/start+thread/settings/updated+model/rerouted';providerModelFallbackAllowed=$false;executionVerified=$true;result='SUCCESS'} | ConvertTo-Json -Compress
  Invoke-Hook $NodePath $Hook ($Base + @{hook_event_name='PostToolUse';tool_name='codex_app__send_message_to_thread';tool_use_id="dispatch-receipt-$Turn";tool_input=@{threadId='thread';model=$state.route.preferredModel;thinking=$state.route.hostReasoning};tool_response=$receipt}) | Out-Null
  $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
  if ($state.validations.modelDispatch -ne $true -or $state.route.actualVerificationSource -ne 'host-model-dispatch-receipt') { throw 'Exact digest-bound host execution receipt was not accepted.' }
  Add-AssistantMessage $Transcript $state.route.actualLine
  return $state
}

try {
  $codexHome = Join-Path $sandbox 'codex-home'
  $runtimeRoot = Join-Path $codexHome 'ueef'
  $requirementsPath = Join-Path $sandbox 'system\requirements.toml'
  New-Item -ItemType Directory -Path $codexHome -Force | Out-Null
  $install = Install-UeefManagedEnforcement -RuntimePath $root -RuntimeRoot $runtimeRoot -RequirementsPath $requirementsPath
  if (!$install.requirementsPath -or !$install.hooksPath) { throw 'Installer did not return managed paths.' }
  $requirements = [IO.File]::ReadAllText($requirementsPath, [Text.Encoding]::UTF8)
  foreach ($term in @('# UEEF-MANAGED-REQUIREMENTS','hooks = true','SessionStart','UserPromptSubmit','PreToolUse','PostToolUse','Stop','windows_managed_dir')) {
    if (!$requirements.Contains($term)) { throw "Managed requirements missing: $term" }
  }
  if ($requirements -notmatch '(?m)^command_windows\s*=\s*''node\s+"[^"\r\n]+ueef-codex-hook\.mjs"''\s*$') {
    throw 'Managed requirements did not use the verified Windows command-hook form.'
  }
  $hook = Join-Path $install.hooksPath 'ueef-codex-hook.mjs'
  $recorder = Join-Path $install.hooksPath 'record-ueef-route.mjs'
  $nodePath = [string]$install.nodePath
  $liveHookTestSource = Get-Content -LiteralPath (Join-Path $root 'scripts\test-live-managed-hooks.mjs') -Raw
  if ($liveHookTestSource -match '--persist' -or $liveHookTestSource -notmatch 'ephemeral:\s*true') { throw 'Live managed-hook verification must always use an ephemeral App Server thread.' }
  foreach ($path in @($hook,$recorder,(Join-Path $install.hooksPath 'ueef-hook-common.mjs'),(Join-Path $install.hooksPath 'codex-enforcement-policy.json'),(Join-Path $install.hooksPath 'model-routing-policy.json'),(Join-Path $install.hooksPath 'resolve-model-route.mjs'),(Join-Path $install.hooksPath 'codex-app-server-models.mjs'),(Join-Path $install.hooksPath 'codex-app-server-client-lib.mjs'),$nodePath)) {
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Managed hook payload missing: $path" }
  }
  $modelCatalog = Join-Path $sandbox 'live-host-model-catalog.json'
  $catalogDocument = [ordered]@{
    schemaVersion = 1
    discoveredAt = (Get-Date).ToUniversalTime().ToString('o')
    provenance = [ordered]@{provider='test-fixture'}
    data = @([ordered]@{id='test-model';model='test-model';displayName='Test model';description='Frontier balanced fast test model';isDefault=$true;supportedReasoningEfforts=@([ordered]@{reasoningEffort='low';displayName='Low label'},[ordered]@{reasoningEffort='medium';displayName='Medium label'},[ordered]@{reasoningEffort='high';displayName='High label'})})
  }
  [IO.File]::WriteAllText($modelCatalog, ($catalogDocument | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))

  $foreignRequirements = Join-Path $sandbox 'foreign\requirements.toml'
  New-Item -ItemType Directory -Path (Split-Path -Parent $foreignRequirements) -Force | Out-Null
  [IO.File]::WriteAllText($foreignRequirements, "[features]`nhooks = false`n", [Text.UTF8Encoding]::new($false))
  $foreignBefore = [IO.File]::ReadAllText($foreignRequirements, [Text.Encoding]::UTF8)
  $foreignRejected = $false
  try { Install-UeefManagedEnforcement -RuntimePath $root -RuntimeRoot (Join-Path $sandbox 'foreign-runtime') -RequirementsPath $foreignRequirements | Out-Null }
  catch { $foreignRejected = $_.Exception.Message -like '*not UEEF-owned*' }
  if (!$foreignRejected -or [IO.File]::ReadAllText($foreignRequirements, [Text.Encoding]::UTF8) -cne $foreignBefore) { throw 'Foreign requirements were not rejected unchanged.' }

  $session = 'session-1'
  $turn = 'turn-1'
  $baseTranscript = Join-Path $sandbox 'session-1.jsonl'
  [IO.File]::WriteAllText($baseTranscript, '', [Text.UTF8Encoding]::new($false))
  $base = @{session_id=$session;turn_id=$turn;cwd=$root;model='test-model';permission_mode='default';transcript_path=$baseTranscript}
  $sessionResult = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='SessionStart';source='resume'})
  $sessionContext = [string]$sessionResult.hookSpecificOutput.additionalContext
  if ($sessionContext -notmatch 'UEEF' -or $sessionContext -notmatch 'UEEF-LOADER.md') { throw 'SessionStart did not inject current UEEF context.' }

  $promptText = '/goal implement mandatory enforcement then push and release'
  $promptResult = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='UserPromptSubmit';prompt=$promptText})
  if ([string]$promptResult.hookSpecificOutput.additionalContext -notmatch 'record-ueef-route.mjs' -or [string]$promptResult.hookSpecificOutput.additionalContext -notmatch '--acceptance' -or [string]$promptResult.hookSpecificOutput.additionalContext -notmatch '--owner-paths' -or [string]$promptResult.hookSpecificOutput.additionalContext -notmatch '--non-goals') { throw 'UserPromptSubmit did not inject the execution-spec-aware route command.' }
  $stateRoot = Join-Path $runtimeRoot 'hook-state'
  $persistedState = (Get-ChildItem -LiteralPath $stateRoot -Filter '*.json' -File | Select-Object -First 1)
  if (!$persistedState) { throw 'UserPromptSubmit did not create turn state.' }
  if ([IO.File]::ReadAllText($persistedState.FullName, [Text.Encoding]::UTF8).Contains($promptText)) { throw 'Hook state persisted the raw user prompt.' }

  $negatedSession = 'session-negated-authorizations'
  $negatedTurn = 'turn-negated-authorizations'
  $negatedTranscript = Join-Path $sandbox 'session-negated-authorizations.jsonl'
  [IO.File]::WriteAllText($negatedTranscript, '', [Text.UTF8Encoding]::new($false))
  $negatedBase = @{session_id=$negatedSession;turn_id=$negatedTurn;cwd=$root;model='test-model';permission_mode='default';transcript_path=$negatedTranscript}
  Invoke-Hook $nodePath $hook ($negatedBase + @{hook_event_name='UserPromptSubmit';prompt='Do not use the current model. Do not allow a model constraint override. Do not use xhigh.'}) | Out-Null
  $negatedState = Get-Content -LiteralPath (Get-ChildItem -LiteralPath $stateRoot -Filter '*.turn-negated-authorizations.json' -File | Select-Object -First 1).FullName -Raw | ConvertFrom-Json
  if ($negatedState.authorizations.useCurrentModel -or $negatedState.authorizations.allowModelConstraintOverride -or $negatedState.authorizations.allowAboveHigh) { throw 'Negated model-routing language was treated as authorization.' }

  $unroutedEdit = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='apply_patch';tool_use_id='tool-1';tool_input=@{command='*** Begin Patch'}})
  Assert-Denied $unroutedEdit 'Unrouted edit'
  $routeCommand = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='shell_command';tool_use_id='tool-1b';tool_input=@{command="node record-ueef-route.mjs --session-id $session --turn-id $turn --work-unit-id implementation --tier T4"}})
  if ([string]$routeCommand.hookSpecificOutput.permissionDecision -eq 'deny') { throw 'Route recorder was denied through the current shell tool name.' }
  $compoundRecorder = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='shell_command';tool_use_id='tool-1c';tool_input=@{command="node record-ueef-route.mjs --session-id $session --turn-id $turn --work-unit-id implementation --tier T4; git reset --hard HEAD"}})
  Assert-Denied $compoundRecorder 'Compound destructive command disguised as route recorder'

  $execRecorderCode = 'const r = await tools.shell_command({command:"node scripts/record-ueef-route.mjs --session-id session --turn-id turn --work-unit-id test --tier T0",workdir:"C:\\repo",timeout_ms:30000}); text(r);'
  $execRecorder = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='functions.exec';tool_use_id='tool-1d';tool_input=$execRecorderCode})
  if ([string]$execRecorder.hookSpecificOutput.permissionDecision -eq 'deny') { throw 'Isolated functions.exec route-recorder wrapper was denied.' }
  $execRecorderQuotedSemicolonCode = 'const r = await tools.shell_command({command:"node scripts/record-ueef-route.mjs --session-id session --turn-id turn --work-unit-id test --tier T0 --acceptance ''reviewed; verified'' --non-goals ''no reset; no delete''",workdir:"C:\\repo",timeout_ms:30000}); text(r);'
  $execRecorderQuotedSemicolon = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='functions.exec';tool_use_id='tool-1d-quoted-semicolon';tool_input=$execRecorderQuotedSemicolonCode})
  if ([string]$execRecorderQuotedSemicolon.hookSpecificOutput.permissionDecision -eq 'deny') { throw 'Quoted punctuation inside functions.exec route metadata was treated as a shell control operator.' }
  $execRecorderUnquotedSemicolonCode = 'const r = await tools.shell_command({command:"node scripts/record-ueef-route.mjs --session-id session --turn-id turn --work-unit-id test --tier T0; git status",workdir:"C:\\repo",timeout_ms:30000}); text(r);'
  $execRecorderUnquotedSemicolon = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='functions.exec';tool_use_id='tool-1d-unquoted-semicolon';tool_input=$execRecorderUnquotedSemicolonCode})
  Assert-Denied $execRecorderUnquotedSemicolon 'Unquoted shell control operator in functions.exec route-recorder wrapper'
  $execRecorderWithExtra = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='functions.exec';tool_use_id='tool-1e';tool_input=($execRecorderCode + ' tools.apply_patch("unexpected");')})
  Assert-Denied $execRecorderWithExtra 'functions.exec route-recorder wrapper with extra executable code'

  Record-UeefRoute $nodePath $recorder $modelCatalog $session $turn T4 'mandatory enforcement' 'implementation' $baseTranscript | Out-Null
  $executionSpecState = Get-Content -LiteralPath (Get-ChildItem -LiteralPath $stateRoot -Filter "*.$turn.json" -File | Select-Object -First 1).FullName -Raw | ConvertFrom-Json
  if ($executionSpecState.validations.executionSpec -ne $true -or !$executionSpecState.executionSpec.digest -or $executionSpecState.route.tokenEconomy.budgetMode -ne 'expanded') { throw 'T4 route did not persist a verified automatic execution spec and expanded token budget.' }
  $visibleTaskWithoutRequest = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='codex_app__create_thread';tool_use_id='visible-task-without-request';tool_input=@{model=$executionSpecState.route.preferredModel;thinking=$executionSpecState.route.hostReasoning;prompt='test'}})
  Assert-Denied $visibleTaskWithoutRequest 'User-visible task creation without an explicit request'
  $beforeDispatchEdit = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='apply_patch';tool_use_id='tool-2-before-dispatch';tool_input=@{command='*** Begin Patch'}})
  Assert-Denied $beforeDispatchEdit 'Routed edit before actual model dispatch'
  Complete-HostDispatch $nodePath $hook $stateRoot $base $session $turn $baseTranscript | Out-Null
  $routedEdit = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='apply_patch';tool_use_id='tool-2';tool_input=@{command='*** Begin Patch'}})
  if ([string]$routedEdit.hookSpecificOutput.permissionDecision -eq 'deny') { throw 'Routed and actually dispatched ordinary edit was denied.' }
  $documentedCommandPatch = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='apply_patch';tool_use_id='tool-2-documented-command';tool_input=@{command="*** Begin Patch`n*** Update File: docs/example.md`n@@`n+pickerModel = documented only`n+Remove-Item is documented only`n*** End Patch"}})
  if ([string]$documentedCommandPatch.hookSpecificOutput.permissionDecision -eq 'deny') { throw 'Command text documented inside a patch was treated as an executed destructive command.' }
  $fileRemovalPatch = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='apply_patch';tool_use_id='tool-2-file-removal';tool_input=@{command="*** Begin Patch`n*** Delete File: docs/example.md`n*** End Patch"}})
  Assert-Denied $fileRemovalPatch 'File removal patch without explicit authorization'
  $mainStatePath = (Get-ChildItem -LiteralPath $stateRoot -Filter "*.$turn.json" -File | Select-Object -First 1).FullName
  $mainState = Get-Content -LiteralPath $mainStatePath -Raw | ConvertFrom-Json
  for ($workerIndex = 0; $workerIndex -lt $mainState.route.tokenEconomy.maxWorkerCount; $workerIndex++) {
    $workerTool = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='spawn_agent';tool_use_id="worker-$workerIndex";tool_input=@{model=$mainState.route.preferredModel;thinking=$mainState.route.hostReasoning;message='bounded worker'}})
    if ([string]$workerTool.hookSpecificOutput.permissionDecision -eq 'deny') { throw "Worker $workerIndex was denied inside the T4 worker budget." }
    Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PostToolUse';tool_name='spawn_agent';tool_use_id="worker-$workerIndex";tool_input=@{model=$mainState.route.preferredModel;thinking=$mainState.route.hostReasoning;message='bounded worker'};tool_response='{"status":"complete"}'}) | Out-Null
  }
  $overBudgetWorker = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='spawn_agent';tool_use_id='worker-over-budget';tool_input=@{model=$mainState.route.preferredModel;thinking=$mainState.route.hostReasoning;message='extra worker'}})
  Assert-Denied $overBudgetWorker 'Worker dispatch above the route token budget'

  $routeSession = 'session-work-units'
  $routeTurn = 'turn-work-units'
  $routeTranscript = Join-Path $sandbox 'session-work-units.jsonl'
  [IO.File]::WriteAllText($routeTranscript, '', [Text.UTF8Encoding]::new($false))
  $routeBase = @{session_id=$routeSession;turn_id=$routeTurn;cwd=$root;model='picker-model';permission_mode='default';transcript_path=$routeTranscript}
  Invoke-Hook $nodePath $hook ($routeBase + @{hook_event_name='UserPromptSubmit';prompt='Implement the task with automatic routing'}) | Out-Null
  $firstRoute = & $nodePath $recorder --session-id $routeSession --turn-id $routeTurn --work-unit-id inspect --tier T0 --intent inspection --agent-route 'single primary agent' --browser-reason 'not required' --model-catalog $modelCatalog --allow-test-catalog | ConvertFrom-Json
  $secondRoute = & $nodePath $recorder --session-id $routeSession --turn-id $routeTurn --work-unit-id implementation --tier T2 --intent implementation --agent-route 'single primary agent' --browser-reason 'not required' --acceptance 'implementation verified' --owner-paths 'bounded owner' --non-goals 'unrelated work' --model-catalog $modelCatalog --allow-test-catalog | ConvertFrom-Json
  if (!(Test-Path -LiteralPath $secondRoute.routeOutput -PathType Leaf)) { throw 'Route recorder did not create its automatic protected route artifact.' }
  $automaticRouteArtifact = Get-Content -LiteralPath $secondRoute.routeOutput -Raw | ConvertFrom-Json
  if ($automaticRouteArtifact.executionSpec.digest -ne $secondRoute.executionSpec.digest -or $automaticRouteArtifact.tokenEconomy.maxWorkerCount -ne 1) { throw 'Automatic route artifact did not preserve the execution spec and token budget.' }
  if ($firstRoute.routeRevision -ne 1 -or $firstRoute.routeChanged -or $secondRoute.routeRevision -ne 2 -or !$secondRoute.routeChanged -or
      $secondRoute.routeLine -notmatch 'Model route changed' -or $secondRoute.routeLine -notmatch '->' -or
      $secondRoute.routeLine -notmatch [regex]::Escape([string]$firstRoute.preferredModel) -or
      $secondRoute.routeLine -notmatch [regex]::Escape([string]$secondRoute.preferredModel)) { throw 'Work-unit route revision/change/full-model-name contract failed.' }
  if ($secondRoute.displayReasoning -cne 'Low label' -or $secondRoute.routeLine -notmatch 'Low label') { throw 'Host-provided effort display label was not used in the visible route.' }
  $hiddenRoute = Invoke-Hook $nodePath $hook ($routeBase + @{hook_event_name='PreToolUse';tool_name='apply_patch';tool_use_id='route-hidden';tool_input=@{command='*** Begin Patch'}})
  Assert-Denied $hiddenRoute 'Execution before the changed route was shown to the user'
  Add-AssistantMessage $routeTranscript $secondRoute.routeLine
  $wrongDispatch = Invoke-Hook $nodePath $hook ($routeBase + @{hook_event_name='PreToolUse';tool_name='codex_app__send_message_to_thread';tool_use_id='route-dispatch-wrong';tool_input=@{threadId='thread';model='wrong-model';thinking='medium'}})
  Assert-Denied $wrongDispatch 'Dispatch that does not match the validated route'
  $matchedDispatch = Invoke-Hook $nodePath $hook ($routeBase + @{hook_event_name='PreToolUse';tool_name='codex_app__send_message_to_thread';tool_use_id='route-dispatch-match';tool_input=@{threadId='thread';model=$secondRoute.preferredModel;thinking=$secondRoute.hostReasoning}})
  if ([string]$matchedDispatch.hookSpecificOutput.permissionDecision -eq 'deny') { throw 'Route-matched model dispatch was denied.' }
  Invoke-Hook $nodePath $hook ($routeBase + @{hook_event_name='PostToolUse';tool_name='codex_app__send_message_to_thread';tool_use_id='route-dispatch-match';tool_input=@{threadId='thread';model=$secondRoute.preferredModel;thinking=$secondRoute.hostReasoning};tool_response="Exit code: 0`n{`"threadId`":`"thread`"}"}) | Out-Null
  $routeState = Get-Content -LiteralPath (Get-ChildItem -LiteralPath $stateRoot -Filter '*.turn-work-units.json' -File | Select-Object -First 1).FullName -Raw | ConvertFrom-Json
  if ($routeState.validations.modelDispatch -eq $true) { throw 'Host route-matched request without an actual receipt became completion evidence.' }
  $matchedReceipt = [ordered]@{provider='codex-app-server:turn/start';threadId='work-unit-thread';turnId='work-unit-turn';routeDigest=$routeState.route.routeDigest;actualModel=$secondRoute.preferredModel;actualHostReasoning=$secondRoute.hostReasoning;executionVerificationSource='codex-app-server:thread/start+thread/settings/updated+model/rerouted';providerModelFallbackAllowed=$false;executionVerified=$true;result='SUCCESS'} | ConvertTo-Json -Compress
  Invoke-Hook $nodePath $hook ($routeBase + @{hook_event_name='PostToolUse';tool_name='codex_app__send_message_to_thread';tool_use_id='route-dispatch-match-receipt';tool_input=@{threadId='thread';model=$secondRoute.preferredModel;thinking=$secondRoute.hostReasoning};tool_response=$matchedReceipt}) | Out-Null
  $routeState = Get-Content -LiteralPath (Get-ChildItem -LiteralPath $stateRoot -Filter '*.turn-work-units.json' -File | Select-Object -First 1).FullName -Raw | ConvertFrom-Json
  if ($routeState.validations.modelDispatch -ne $true) { throw 'Successful host route-matched dispatch did not become completion evidence.' }
  $beforeActualLine = Invoke-Hook $nodePath $hook ($routeBase + @{hook_event_name='PreToolUse';tool_name='apply_patch';tool_use_id='route-before-actual-line';tool_input=@{command='*** Begin Patch'}})
  Assert-Denied $beforeActualLine 'Execution before actual sub-agent model line was shown'
  Add-AssistantMessage $routeTranscript $routeState.route.actualLine

  $cycleSession = 'session-persisted-effort-cycle'
  $cycleTranscript = Join-Path $sandbox 'session-persisted-effort-cycle.jsonl'
  [IO.File]::WriteAllText($cycleTranscript, '', [Text.UTF8Encoding]::new($false))
  $cycleRoutes = @()
  foreach ($cycleTurn in @('cycle-turn-0','cycle-turn-1','cycle-turn-2')) {
    $cycleBase = @{session_id=$cycleSession;turn_id=$cycleTurn;cwd=$root;model='picker-model';permission_mode='default';transcript_path=$cycleTranscript}
    Invoke-Hook $nodePath $hook ($cycleBase + @{hook_event_name='UserPromptSubmit';prompt='Continue the same routed task'}) | Out-Null
    $cycleRoutes += Record-UeefRoute $nodePath $recorder $modelCatalog $cycleSession $cycleTurn T2 'continued task' 'same-work-unit' $cycleTranscript
    Complete-HostDispatch $nodePath $hook $stateRoot $cycleBase $cycleSession $cycleTurn $cycleTranscript | Out-Null
  }
  if (($cycleRoutes.hostReasoning -join ',') -ne 'low,medium,high' -or ($cycleRoutes.invocationIndex -join ',') -ne '0,1,2') { throw 'The same work unit did not persist low/medium/high effort rotation across turns.' }

  $directSession = 'session-direct-dispatch'
  $directTurn = 'turn-direct-dispatch'
  $directTranscript = Join-Path $sandbox 'session-direct-dispatch.jsonl'
  [IO.File]::WriteAllText($directTranscript, '', [Text.UTF8Encoding]::new($false))
  $directBase = @{session_id=$directSession;turn_id=$directTurn;cwd=$root;model='test-model';permission_mode='default';transcript_path=$directTranscript}
  Invoke-Hook $nodePath $hook ($directBase + @{hook_event_name='UserPromptSubmit';prompt='Run a routed work unit'}) | Out-Null
  Record-UeefRoute $nodePath $recorder $modelCatalog $directSession $directTurn T2 'direct dispatch' 'direct-work-unit' $directTranscript | Out-Null
  $directStatePath = (Get-ChildItem -LiteralPath $stateRoot -Filter '*.turn-direct-dispatch.json' -File | Select-Object -First 1).FullName
  $directState = Get-Content -LiteralPath $directStatePath -Raw | ConvertFrom-Json
  $directRoutePath = Join-Path $sandbox 'direct-route.json'
  [IO.File]::WriteAllText($directRoutePath, (@{routeDigest=$directState.route.routeDigest;executionSpec=$directState.executionSpec;tokenEconomy=$directState.route.tokenEconomy;catalogDigest=$directState.route.catalogDigest;preferredModel=$directState.route.preferredModel;hostReasoning=$directState.route.hostReasoning;fallbackModel=$directState.route.fallbackModel;fallbackHostReasoning=$directState.route.fallbackHostReasoning} | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
  $directCommand = "node scripts/codex-app-server-dispatch.mjs --route `"$directRoutePath`" --prompt test"
  $directPre = Invoke-Hook $nodePath $hook ($directBase + @{hook_event_name='PreToolUse';tool_name='shell_command';tool_use_id='direct-dispatch';tool_input=@{command=$directCommand}})
  if ([string]$directPre.hookSpecificOutput.permissionDecision -eq 'deny') { throw "Matching direct App Server dispatch was denied before execution: $($directPre.hookSpecificOutput.permissionDecisionReason)" }
  $directExecCode = "const r = await tools.shell_command({command:$($directCommand | ConvertTo-Json -Compress),workdir:$($root | ConvertTo-Json -Compress),timeout_ms:30000}); text(r);"
  $directExecPre = Invoke-Hook $nodePath $hook ($directBase + @{hook_event_name='PreToolUse';tool_name='functions.exec';tool_use_id='direct-dispatch-exec';tool_input=$directExecCode})
  if ([string]$directExecPre.hookSpecificOutput.permissionDecision -eq 'deny') { throw "Matching functions.exec App Server dispatcher wrapper was denied: $($directExecPre.hookSpecificOutput.permissionDecisionReason)" }
  $minimalReceipt = [ordered]@{routeDigest=$directState.route.routeDigest;actualModel=$directState.route.preferredModel;actualHostReasoning=$directState.route.hostReasoning;executionVerified=$true;result='SUCCESS'} | ConvertTo-Json
  Invoke-Hook $nodePath $hook ($directBase + @{hook_event_name='PostToolUse';tool_name='shell_command';tool_use_id='direct-dispatch-minimal';tool_input=@{command=$directCommand};tool_response="Exit code: 0`n$minimalReceipt"}) | Out-Null
  $directState = Get-Content -LiteralPath $directStatePath -Raw | ConvertFrom-Json
  if ($directState.validations.modelDispatch -eq $true) { throw 'Minimal caller-authored direct receipt was incorrectly accepted.' }
  $directReceipt = [ordered]@{provider='codex-app-server:turn/start';threadId='thread-direct';turnId='turn-direct';routeDigest=$directState.route.routeDigest;actualModel=$directState.route.preferredModel;actualHostReasoning=$directState.route.hostReasoning;executionVerified=$true;executionVerificationSource='codex-app-server:thread/start+thread/settings/updated+model/rerouted';providerModelFallbackAllowed=$false;result='SUCCESS';capacityFallbackUsed=$false} | ConvertTo-Json
  Invoke-Hook $nodePath $hook ($directBase + @{hook_event_name='PostToolUse';tool_name='shell_command';tool_use_id='direct-dispatch';tool_input=@{command=$directCommand};tool_response="Exit code: 0`n$directReceipt"}) | Out-Null
  $directState = Get-Content -LiteralPath $directStatePath -Raw | ConvertFrom-Json
  if ($directState.validations.modelDispatch -ne $true -or $directState.route.actualVerificationSource -ne 'codex-app-server' -or $directState.route.actualLine -notmatch [regex]::Escape([string]$directState.route.preferredModel)) { throw "Direct App Server receipt did not record the verified actual model line. Receipt=$directReceipt State=$($directState | ConvertTo-Json -Depth 8 -Compress)" }
  Assert-Denied (Invoke-Hook $nodePath $hook ($directBase + @{hook_event_name='PreToolUse';tool_name='apply_patch';tool_use_id='direct-before-line';tool_input=@{command='*** Begin Patch'}})) 'Task tool before verified actual model line'
  Add-AssistantMessage $directTranscript $directState.route.actualLine
  $directAfterLine = Invoke-Hook $nodePath $hook ($directBase + @{hook_event_name='PreToolUse';tool_name='apply_patch';tool_use_id='direct-after-line';tool_input=@{command='*** Begin Patch'}})
  if ([string]$directAfterLine.hookSpecificOutput.permissionDecision -eq 'deny') { throw 'Task tool remained denied after verified actual model line.' }

  $protectedEdit = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='Bash';tool_use_id='tool-3';tool_input=@{command="Set-Content '$requirementsPath' 'tamper'"}})
  Assert-Denied $protectedEdit 'Protected requirements mutation'
  $protectedRead = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='shell_command';tool_use_id='tool-3b';tool_input=@{command="Get-Content '$requirementsPath'"}})
  if ([string]$protectedRead.hookSpecificOutput.permissionDecision -eq 'deny') { throw 'Read-only protected-path inspection was denied.' }
  $browserTool = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='mcp__browser__open';tool_use_id='tool-4';tool_input=@{url='https://example.com'}})
  Assert-Denied $browserTool 'In-app browser tool'
  $playwrightTool = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='mcp__playwright__browser_navigate';tool_use_id='tool-4a';tool_input=@{url='https://example.com'}})
  Assert-Denied $playwrightTool 'Playwright MCP tool'
  $newContext = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='mcp__node_repl__js';tool_use_id='tool-4b';tool_input=@{code='browser.newContext()'}})
  Assert-Denied $newContext 'New browser context'
  $chromeBeforePreflight = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='mcp__node_repl__js';tool_use_id='tool-4c';tool_input=@{code='user.openTabs()'}})
  Assert-Denied $chromeBeforePreflight 'Chrome call before browser preflight'
  Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PostToolUse';tool_name='Bash';tool_use_id='tool-4d';tool_input=@{command='.\scripts\get-ueef-task-preflight.ps1 -Task browser -TaskTag browser'};tool_response="Exit code: 0`nstatus: READY_WITH_FALLBACK`nbrowserGate: PASS"}) | Out-Null
  $chromeAfterPreflight = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='mcp__node_repl__js';tool_use_id='tool-4e';tool_input=@{code='user.openTabs()'}})
  if ([string]$chromeAfterPreflight.hookSpecificOutput.permissionDecision -eq 'deny') { throw 'Chrome binding remained denied after browser preflight.' }

  $turn2 = 'turn-2'
  $base2 = $base.Clone(); $base2.turn_id=$turn2
  Invoke-Hook $nodePath $hook ($base2 + @{hook_event_name='UserPromptSubmit';prompt='inspect the repository'}) | Out-Null
  $turn2State = Get-Content -LiteralPath (Get-ChildItem -LiteralPath $stateRoot -Filter '*.turn-2.json' -File | Select-Object -First 1).FullName -Raw | ConvertFrom-Json
  if ($turn2State.goalTask -ne $true) { throw 'Active goal state did not carry across prompt updates in the same session.' }
  Record-UeefRoute $nodePath $recorder $modelCatalog $session $turn2 T2 'inspection' 'inspection' $baseTranscript | Out-Null
  $unauthorizedPush = Invoke-Hook $nodePath $hook ($base2 + @{hook_event_name='PreToolUse';tool_name='Bash';tool_use_id='tool-5';tool_input=@{command='git push origin main'}})
  Assert-Denied $unauthorizedPush 'Unauthorized push'
  Assert-Denied (Invoke-Hook $nodePath $hook ($base2 + @{hook_event_name='PreToolUse';tool_name='Bash';tool_use_id='tool-5b';tool_input=@{command="Remove-Item 'scoped' -Recurse"}})) 'Unauthorized delete'
  Assert-Denied (Invoke-Hook $nodePath $hook ($base2 + @{hook_event_name='PreToolUse';tool_name='Bash';tool_use_id='tool-5c';tool_input=@{command='git reset --hard HEAD'}})) 'Unauthorized reset'

  $frontendSession = 'session-frontend'
  $frontendTurn = 'turn-frontend'
  $frontendTranscript = Join-Path $sandbox 'session-frontend.jsonl'
  [IO.File]::WriteAllText($frontendTranscript, '', [Text.UTF8Encoding]::new($false))
  $frontendBase = @{session_id=$frontendSession;turn_id=$frontendTurn;cwd=$root;model='test-model';permission_mode='default';transcript_path=$frontendTranscript}
  Invoke-Hook $nodePath $hook ($frontendBase + @{hook_event_name='UserPromptSubmit';prompt='Implement a responsive frontend component'}) | Out-Null
  Record-UeefRoute $nodePath $recorder $modelCatalog $frontendSession $frontendTurn T2 'frontend component' 'frontend-implementation' $frontendTranscript 'not required until visual verification' | Out-Null
  Complete-HostDispatch $nodePath $hook $stateRoot $frontendBase $frontendSession $frontendTurn $frontendTranscript | Out-Null
  $frontendEarlyEdit = Invoke-Hook $nodePath $hook ($frontendBase + @{hook_event_name='PreToolUse';tool_name='apply_patch';tool_use_id='frontend-1';tool_input=@{command='*** Begin Patch'}})
  Assert-Denied $frontendEarlyEdit 'Frontend mutation before route'
  Invoke-Hook $nodePath $hook ($frontendBase + @{hook_event_name='PostToolUse';tool_name='shell_command';tool_use_id='frontend-2';tool_input=@{command='node scripts/select-frontend-route.mjs --task frontend'};tool_response='Exit code: 0 {"applies":true,"frontendMode":"Build"}'}) | Out-Null
  $frontendRoutedEdit = Invoke-Hook $nodePath $hook ($frontendBase + @{hook_event_name='PreToolUse';tool_name='apply_patch';tool_use_id='frontend-3';tool_input=@{command='*** Begin Patch'}})
  if ([string]$frontendRoutedEdit.hookSpecificOutput.permissionDecision -eq 'deny') { throw 'Frontend mutation remained denied after route evidence.' }
  Invoke-Hook $nodePath $hook ($frontendBase + @{hook_event_name='PostToolUse';tool_name='apply_patch';tool_use_id='frontend-3';tool_input=@{command='*** Begin Patch'};tool_response='{}'}) | Out-Null
  $frontendLabels = "UEEF: ACTIVE`nLoaded: boot-loader, core-system`nSelected: frontend; Model used: test-model / Low label (host: low)`nGates: focused`nTools: apply_patch`nSkills: frontend-ui-engineering`nUIUX: NA`nStatus: ACTIVE"
  $frontendUnverifiedStop = Invoke-Hook $nodePath $hook ($frontendBase + @{hook_event_name='Stop';stop_hook_active=$false;last_assistant_message=$frontendLabels})
  Assert-StopBlocked $frontendUnverifiedStop 'Frontend mutation without execution evidence'
  Invoke-Hook $nodePath $hook ($frontendBase + @{hook_event_name='PostToolUse';tool_name='shell_command';tool_use_id='frontend-4';tool_input=@{command='npm test'};tool_response='Exit code: 0 tests passed'}) | Out-Null
  Invoke-Hook $nodePath $hook ($frontendBase + @{hook_event_name='PostToolUse';tool_name='shell_command';tool_use_id='frontend-5';tool_input=@{command='node scripts/validate-frontend-execution-evidence.mjs --path evidence.json'};tool_response='Exit code: 0 FRONTEND_EXECUTION_EVIDENCE: PASS'}) | Out-Null
  $frontendVerifiedLabels = $frontendLabels -replace 'UIUX: NA','UIUX: responsive, accessibility, states, performance, tests, and rendered evidence PASS'
  $frontendVerifiedStop = Invoke-Hook $nodePath $hook ($frontendBase + @{hook_event_name='Stop';stop_hook_active=$false;last_assistant_message=$frontendVerifiedLabels})
  if ([string]$frontendVerifiedStop.decision -eq 'block') {
    $frontendState = Get-Content -LiteralPath (Get-ChildItem -LiteralPath $stateRoot -Filter '*.turn-frontend.json' -File | Select-Object -First 1).FullName -Raw
    throw "Verified frontend turn remained blocked: $($frontendVerifiedStop.reason) State: $frontendState"
  }

  $metaSession = 'session-frontend-meta'
  $metaTurn = 'turn-frontend-meta'
  $metaTranscript = Join-Path $sandbox 'session-frontend-meta.jsonl'
  [IO.File]::WriteAllText($metaTranscript, '', [Text.UTF8Encoding]::new($false))
  $metaBase = @{session_id=$metaSession;turn_id=$metaTurn;cwd=$root;model='test-model';permission_mode='default';transcript_path=$metaTranscript}
  Invoke-Hook $nodePath $hook ($metaBase + @{hook_event_name='UserPromptSubmit';prompt='Strengthen UEEF frontend enforcement rules'}) | Out-Null
  Record-UeefRoute $nodePath $recorder $modelCatalog $metaSession $metaTurn T2 'UEEF policy maintenance' 'meta-policy' $metaTranscript | Out-Null
  Complete-HostDispatch $nodePath $hook $stateRoot $metaBase $metaSession $metaTurn $metaTranscript | Out-Null
  $metaEdit = Invoke-Hook $nodePath $hook ($metaBase + @{hook_event_name='PreToolUse';tool_name='apply_patch';tool_use_id='frontend-meta-1';tool_input=@{command='*** Begin Patch'}})
  if ([string]$metaEdit.hookSpecificOutput.permissionDecision -eq 'deny') { throw 'UEEF frontend meta-policy maintenance was incorrectly routed as a consumer UI mutation.' }

  $ambientSession = 'session-ambient-ui-context'
  $ambientTurn = 'turn-ambient-ui-context'
  $ambientTranscript = Join-Path $sandbox 'session-ambient-ui-context.jsonl'
  [IO.File]::WriteAllText($ambientTranscript, '', [Text.UTF8Encoding]::new($false))
  $ambientBase = @{session_id=$ambientSession;turn_id=$ambientTurn;cwd=$root;model='test-model';permission_mode='default';transcript_path=$ambientTranscript}
  $ambientPrompt = '<in-app-browser-context source="ambient-ui-state">The user has the in-app browser open with a UI graph page.</in-app-browser-context>' + "`nCreate the repository handoff and push the project."
  Invoke-Hook $nodePath $hook ($ambientBase + @{hook_event_name='UserPromptSubmit';prompt=$ambientPrompt}) | Out-Null
  $ambientState = Get-Content -LiteralPath (Get-ChildItem -LiteralPath $stateRoot -Filter '*.turn-ambient-ui-context.json' -File | Select-Object -First 1).FullName -Raw | ConvertFrom-Json
  if ($ambientState.frontendLikely -eq $true) { throw 'Ambient in-app-browser UI state incorrectly selected frontend enforcement for a non-frontend user request.' }

  $session2 = 'session-created-goal'
  $goalTurn = 'turn-goal-create'
  $goalTranscript = Join-Path $sandbox 'session-created-goal.jsonl'
  [IO.File]::WriteAllText($goalTranscript, '', [Text.UTF8Encoding]::new($false))
  $goalBase = @{session_id=$session2;turn_id=$goalTurn;cwd=$root;model='test-model';permission_mode='default';transcript_path=$goalTranscript}
  Invoke-Hook $nodePath $hook ($goalBase + @{hook_event_name='UserPromptSubmit';prompt='inspect the repository'}) | Out-Null
  Record-UeefRoute $nodePath $recorder $modelCatalog $session2 $goalTurn T2 'inspection' 'goal-inspection' $goalTranscript | Out-Null
  Complete-HostDispatch $nodePath $hook $stateRoot $goalBase $session2 $goalTurn $goalTranscript | Out-Null
  Invoke-Hook $nodePath $hook ($goalBase + @{hook_event_name='PostToolUse';tool_name='create_goal';tool_use_id='tool-goal';tool_input=@{objective='finish inspection'};tool_response='{"goal":{"status":"active"}}'}) | Out-Null
  $goalTurn2 = 'turn-goal-followup'
  $goalBase2 = $goalBase.Clone(); $goalBase2.turn_id=$goalTurn2
  Invoke-Hook $nodePath $hook ($goalBase2 + @{hook_event_name='UserPromptSubmit';prompt='continue'}) | Out-Null
  $createdGoalState = Get-Content -LiteralPath (Get-ChildItem -LiteralPath $stateRoot -Filter '*.turn-goal-followup.json' -File | Select-Object -First 1).FullName -Raw | ConvertFrom-Json
  if ($createdGoalState.goalTask -ne $true) { throw 'Goal created through create_goal did not persist to the next prompt.' }

  $newTaskSession = 'session-explicit-new-task'
  $newTaskTurn = 'turn-explicit-new-task'
  $newTaskTranscript = Join-Path $sandbox 'session-explicit-new-task.jsonl'
  [IO.File]::WriteAllText($newTaskTranscript, '', [Text.UTF8Encoding]::new($false))
  $newTaskBase = @{session_id=$newTaskSession;turn_id=$newTaskTurn;cwd=$root;model='test-model';permission_mode='default';transcript_path=$newTaskTranscript}
  Invoke-Hook $nodePath $hook ($newTaskBase + @{hook_event_name='UserPromptSubmit';prompt='Create a new task for the separate requested work'}) | Out-Null
  Record-UeefRoute $nodePath $recorder $modelCatalog $newTaskSession $newTaskTurn T1 'explicit new task' 'explicit-new-task' $newTaskTranscript | Out-Null
  $newTaskState = Get-Content -LiteralPath (Get-ChildItem -LiteralPath $stateRoot -Filter '*.turn-explicit-new-task.json' -File | Select-Object -First 1).FullName -Raw | ConvertFrom-Json
  $t1LeadRead = Invoke-Hook $nodePath $hook ($newTaskBase + @{hook_event_name='PreToolUse';tool_name='shell_command';tool_use_id='t1-lead-read';tool_input=@{command='Get-Content .\docs\PROJECT-HANDOFF.md';workdir=$root;timeout_ms=10000}})
  if ([string]$t1LeadRead.hookSpecificOutput.permissionDecision -eq 'deny') { throw 'T1 lead-agent allowlisted read-only intake was denied before model dispatch.' }
  $t1RuntimeRead = Invoke-Hook $nodePath $hook ($newTaskBase + @{hook_event_name='PreToolUse';tool_name='shell_command';tool_use_id='t1-runtime-read';tool_input=@{command="& 'D:\shared folder\codex-home\ueef\codex\scripts\ueef-status.ps1'";workdir=$root;timeout_ms=10000}})
  if ([string]$t1RuntimeRead.hookSpecificOutput.permissionDecision -eq 'deny') { throw 'T1 quoted Windows runtime status read was denied before model dispatch.' }
  $t1LeadMutation = Invoke-Hook $nodePath $hook ($newTaskBase + @{hook_event_name='PreToolUse';tool_name='apply_patch';tool_use_id='t1-lead-mutation';tool_input=@{patch='*** Begin Patch'}})
  if ([string]$t1LeadMutation.hookSpecificOutput.permissionDecision -ne 'deny') { throw 'T1 lead-agent mutation was allowed before model dispatch.' }
  $explicitVisibleTask = Invoke-Hook $nodePath $hook ($newTaskBase + @{hook_event_name='PreToolUse';tool_name='codex_app__create_thread';tool_use_id='visible-task-explicit';tool_input=@{model=$newTaskState.route.preferredModel;thinking=$newTaskState.route.hostReasoning;prompt='requested task'}})
  if ([string]$explicitVisibleTask.hookSpecificOutput.permissionDecision -eq 'deny') { throw 'Explicitly requested user-visible task creation was denied.' }

  $arabicTaskPrompts = @(
    'سلم المشروع لشات جديد وعرفه كل حاجة',
    'افتح شات جديد بتاسك جديدة',
    'اعمل تاسك جديده في نفس المشروع',
    'حول المشروع لمهمة جديدة'
  )
  for ($arabicIndex = 0; $arabicIndex -lt $arabicTaskPrompts.Count; $arabicIndex++) {
    $arabicTurn = "turn-arabic-new-task-$arabicIndex"
    $arabicBase = $newTaskBase.Clone(); $arabicBase.turn_id = $arabicTurn
    Invoke-Hook $nodePath $hook ($arabicBase + @{hook_event_name='UserPromptSubmit';prompt=$arabicTaskPrompts[$arabicIndex]}) | Out-Null
    $arabicState = Get-Content -LiteralPath (Get-ChildItem -LiteralPath $stateRoot -Filter "*.$arabicTurn.json" -File | Select-Object -First 1).FullName -Raw | ConvertFrom-Json
    if ($arabicState.authorizations.newUserTask -ne $true) { throw "Arabic explicit new-task request was not recognized: $($arabicTaskPrompts[$arabicIndex])" }
  }
  $negativeArabicTurn = 'turn-arabic-new-task-negative'
  $negativeArabicBase = $newTaskBase.Clone(); $negativeArabicBase.turn_id = $negativeArabicTurn
  Invoke-Hook $nodePath $hook ($negativeArabicBase + @{hook_event_name='UserPromptSubmit';prompt='لا تفتح شات جديد ولا تعمل تاسك جديدة'}) | Out-Null
  $negativeArabicState = Get-Content -LiteralPath (Get-ChildItem -LiteralPath $stateRoot -Filter "*.$negativeArabicTurn.json" -File | Select-Object -First 1).FullName -Raw | ConvertFrom-Json
  if ($negativeArabicState.authorizations.newUserTask -eq $true) { throw 'Negated Arabic new-task request was incorrectly authorized.' }
  $nonNewArabicTurn = 'turn-arabic-task-quality-not-new'
  $nonNewArabicBase = $newTaskBase.Clone(); $nonNewArabicBase.turn_id = $nonNewArabicTurn
  Invoke-Hook $nodePath $hook ($nonNewArabicBase + @{hook_event_name='UserPromptSubmit';prompt='حول المشروع لمهمة جيدة'}) | Out-Null
  $nonNewArabicState = Get-Content -LiteralPath (Get-ChildItem -LiteralPath $stateRoot -Filter "*.$nonNewArabicTurn.json" -File | Select-Object -First 1).FullName -Raw | ConvertFrom-Json
  if ($nonNewArabicState.authorizations.newUserTask -eq $true) { throw 'Arabic task-quality wording without an explicit new-task request was incorrectly authorized.' }

  $authorizedPush = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='Bash';tool_use_id='tool-6';tool_input=@{command='git push origin main'}})
  if ([string]$authorizedPush.hookSpecificOutput.permissionDecision -eq 'deny') { throw 'Explicitly authorized push was denied.' }

  $turn3 = 'turn-3'
  $base3 = $base.Clone(); $base3.turn_id=$turn3
  Invoke-Hook $nodePath $hook ($base3 + @{hook_event_name='UserPromptSubmit';prompt='delete the scoped fixture and reset its temporary test repository'}) | Out-Null
  Record-UeefRoute $nodePath $recorder $modelCatalog $session $turn3 T2 'authorized destructive fixture' 'destructive-fixture' $baseTranscript | Out-Null
  Complete-HostDispatch $nodePath $hook $stateRoot $base3 $session $turn3 $baseTranscript | Out-Null
  $authorizedDelete = Invoke-Hook $nodePath $hook ($base3 + @{hook_event_name='PreToolUse';tool_name='Bash';tool_use_id='tool-6b';tool_input=@{command="Remove-Item 'scoped' -Recurse"}})
  if ([string]$authorizedDelete.hookSpecificOutput.permissionDecision -eq 'deny') { throw 'Explicitly authorized delete was denied.' }
  $authorizedReset = Invoke-Hook $nodePath $hook ($base3 + @{hook_event_name='PreToolUse';tool_name='Bash';tool_use_id='tool-6c';tool_input=@{command='git reset --hard HEAD'}})
  if ([string]$authorizedReset.hookSpecificOutput.permissionDecision -eq 'deny') { throw 'Explicitly authorized reset was denied.' }

  $postEvidence = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PostToolUse';tool_name='Bash';tool_use_id='tool-7';tool_input=@{command='.\scripts\validate-task-evidence.ps1 -Tier T4 -EvidencePath .\.ueef\evidence\x.json'};tool_response="Exit code: 0`nstatus : PASS`ntaskId : x"})
  if ([string]$postEvidence.decision -eq 'block') { throw 'Passing task evidence was rejected.' }
  $missingLabels = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='Stop';stop_hook_active=$false;last_assistant_message='Implementation is still active.'})
  Assert-StopBlocked $missingLabels 'Final response without UEEF labels'

  $progressMissing = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='Stop';stop_hook_active=$false;last_assistant_message="UEEF: ACTIVE`nLoaded: boot-loader, core-system`nSelected: runtime; Model used: test-model / Medium label (host: medium)`nGates: T4`nTools: PowerShell`nSkills: none`nUIUX: NA`nStatus: ACTIVE"})
  Assert-StopBlocked $progressMissing 'Long goal response without progress fields'

  $arabicProgress = (@(
    '2KfZhNmB2YfZhTog2YXYsdin2KzYudipINiq2LTYutmK2YQgVUVFRg==',
    '2KfZhNmF2LHYrdmE2Kk6INiq2K3ZgtmC',
    '2KfZhNiu2LfZiNipINin2YTYrdin2YTZitipOiDZgdit2LUg2KfZhNil2YbZgdin2LA=',
    '2YbYs9io2Kkg2KfZhNiu2LfZiNipINin2YTYrdin2YTZitipOiA3MCU=',
    '2KfZhNmG2LPYqNipINin2YTZg9mE2YrYqTogNjAl',
    '2KfZhNiv2YTZitmEINin2YTYrNiv2YrYrzogcm91dGUvc3RhdHVzIGNoZWNrcw==',
    '2KfZhNil2KzYsdin2KEg2KfZhNit2KfZhNmKOiDZhdiq2KfYqNi52Kkg2KfZhNiq2LTYrtmK2LU=',
    '2KfZhNio2YjYp9io2Kkg2KfZhNiq2KfZhNmK2Kk6IG1hbmFnZWQgZW5mb3JjZW1lbnQ='
  ) | ForEach-Object { Decode-Utf8Base64 $_ }) -join "`n"
  $arabicProgress += "`nUEEF: ACTIVE`nLoaded: boot-loader, core-system`nSelected: runtime; Model used: test-model / Medium label (host: medium)`nGates: T4`nTools: PowerShell`nSkills: none`nUIUX: NA`nStatus: ACTIVE"
  $arabicProgressStop = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='Stop';stop_hook_active=$false;last_assistant_message=$arabicProgress})
  if ($arabicProgressStop.continue -eq $false -or [string]$arabicProgressStop.decision -eq 'block') { throw "Arabic long-goal progress update was blocked: $($arabicProgressStop.reason)" }

  $completionWithoutAudit = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='Stop';stop_hook_active=$false;last_assistant_message="Goal COMPLETE.`nUnderstanding: done`nPhase: review`nCurrent step: closure`nCurrent-step percent: 100%`nOverall percent: 100%`nNew evidence: tests`nCurrent action: close`nNext gate: none`nUEEF: ACTIVE`nLoaded: boot-loader, core-system`nSelected: runtime; Model used: test-model / Medium label (host: medium)`nGates: T4`nTools: PowerShell`nSkills: none`nUIUX: NA`nStatus: COMPLETE"})
  Assert-StopBlocked $completionWithoutAudit 'Completion without completion audit'

  $negativeCompletionMention = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='Stop';stop_hook_active=$false;last_assistant_message="Understanding: explaining hook behavior`nPhase: diagnosis`nCurrent step: describe why the guard fired`nCurrent-step percent: 100%`nOverall percent: 50%`nNew evidence: stop-hook output`nCurrent action: no completion claim`nNext gate: implementation`nUEEF: ACTIVE`nLoaded: boot-loader, core-system`nSelected: runtime; Model used: test-model / Medium label (host: medium)`nGates: active`nTools: PowerShell`nSkills: none`nUIUX: NA`nStatus: ACTIVE - the goal is not COMPLETE and still requires an audit"})
  if ($negativeCompletionMention.continue -eq $false -or [string]$negativeCompletionMention.decision -eq 'block') { throw "A negated completion explanation was incorrectly blocked: $($negativeCompletionMention.reason)" }

  Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PostToolUse';tool_name='Bash';tool_use_id='tool-8';tool_input=@{command='.\scripts\validate-completion-audit.ps1 -Path .\.ueef\completion-audit\x.json'};tool_response="Exit code: 0`nstatus : PASS`ntaskId : x"}) | Out-Null
  Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PostToolUse';tool_name='Bash';tool_use_id='tool-9';tool_input=@{command='.\scripts\validate-goal-lifecycle.ps1 -GoalStatus COMPLETE -CompletionAuditPath .\.ueef\completion-audit\x.json'};tool_response="Exit code: 0`nGoalStatus : COMPLETE`nCompleteAllowed : True`nCompletionAuditPassed : True"}) | Out-Null
  $missingFreshReview = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='update_goal';tool_use_id='tool-9a';tool_input=@{status='complete'}})
  Assert-Denied $missingFreshReview 'T4 completion without fresh review evidence'
  Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PostToolUse';tool_name='Bash';tool_use_id='tool-9b';tool_input=@{command='.\scripts\validate-fresh-review-evidence.ps1 -Path .\.ueef\evidence\x.json'};tool_response="Exit code: 0`nFRESH_REVIEW_EVIDENCE: PASS"}) | Out-Null
  $freshReviewCompletion = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='update_goal';tool_use_id='tool-9c';tool_input=@{status='complete'}})
  if ([string]$freshReviewCompletion.hookSpecificOutput.permissionDecision -eq 'deny') { throw 'T4 completion remained denied after fresh review evidence.' }
  Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PostToolUse';tool_name='update_goal';tool_use_id='tool-10';tool_input=@{status='complete'};tool_response='{"goal":{"status":"complete"}}'}) | Out-Null
  $completeMessage = "Goal COMPLETE.`nUnderstanding: done`nPhase: review`nCurrent step: closure`nCurrent-step percent: 100%`nOverall percent: 100%`nNew evidence: all gates pass`nCurrent action: stop`nNext gate: none`nUEEF: ACTIVE`nLoaded: boot-loader, core-system`nSelected: runtime; Model used: test-model / Medium label (host: medium)`nGates: T4 PASS`nTools: PowerShell`nSkills: none`nUIUX: NA`nStatus: COMPLETE"
  $completeStop = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='Stop';stop_hook_active=$false;last_assistant_message=$completeMessage})
  if ($completeStop.continue -eq $false -or [string]$completeStop.decision -eq 'block') { throw 'Fully evidenced completion was blocked.' }
  $followupStop = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='Stop';stop_hook_active=$false;last_assistant_message=($completeMessage + "`nDo you want anything else?")})
  Assert-StopBlocked $followupStop 'Post-completion follow-up question'

  Write-Output 'Managed enforcement tests passed'
} finally {
  if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
