$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $root 'scripts\managed-enforcement.ps1'
$hookSource = Join-Path $root 'scripts\codex-hooks\ueef-codex-hook.mjs'
$recorderSource = Join-Path $root 'scripts\codex-hooks\record-ueef-route.mjs'
$policySource = Join-Path $root 'config\codex-enforcement-policy.json'
foreach ($required in @($installer, $hookSource, $recorderSource, $policySource)) {
  if (!(Test-Path -LiteralPath $required -PathType Leaf)) { throw "Managed enforcement dependency missing: $required" }
}

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
  $process.StandardInput.Write($json)
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
  $hook = Join-Path $install.hooksPath 'ueef-codex-hook.mjs'
  $recorder = Join-Path $install.hooksPath 'record-ueef-route.mjs'
  $nodePath = [string]$install.nodePath
  foreach ($path in @($hook,$recorder,(Join-Path $install.hooksPath 'ueef-hook-common.mjs'),(Join-Path $install.hooksPath 'codex-enforcement-policy.json'),$nodePath)) {
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Managed hook payload missing: $path" }
  }

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
  $base = @{session_id=$session;turn_id=$turn;cwd=$root;model='test-model';permission_mode='default';transcript_path=$null}
  $sessionResult = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='SessionStart';source='resume'})
  $sessionContext = [string]$sessionResult.hookSpecificOutput.additionalContext
  if ($sessionContext -notmatch 'UEEF' -or $sessionContext -notmatch 'UEEF-LOADER.md') { throw 'SessionStart did not inject current UEEF context.' }

  $promptText = '/goal implement mandatory enforcement then push and release'
  $promptResult = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='UserPromptSubmit';prompt=$promptText})
  if ([string]$promptResult.hookSpecificOutput.additionalContext -notmatch 'record-ueef-route.mjs') { throw 'UserPromptSubmit did not inject the route command.' }
  $stateRoot = Join-Path $runtimeRoot 'hook-state'
  $persistedState = (Get-ChildItem -LiteralPath $stateRoot -Filter '*.json' -File | Select-Object -First 1)
  if (!$persistedState) { throw 'UserPromptSubmit did not create turn state.' }
  if ([IO.File]::ReadAllText($persistedState.FullName, [Text.Encoding]::UTF8).Contains($promptText)) { throw 'Hook state persisted the raw user prompt.' }

  $unroutedEdit = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='apply_patch';tool_use_id='tool-1';tool_input=@{command='*** Begin Patch'}})
  Assert-Denied $unroutedEdit 'Unrouted edit'
  $routeCommand = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='shell_command';tool_use_id='tool-1b';tool_input=@{command="node record-ueef-route.mjs --session-id $session --turn-id $turn --tier T4"}})
  if ([string]$routeCommand.hookSpecificOutput.permissionDecision -eq 'deny') { throw 'Route recorder was denied through the current shell tool name.' }

  & $nodePath $recorder --session-id $session --turn-id $turn --tier T4 --intent 'mandatory enforcement' --agent-route 'single primary agent' --browser-reason 'not required' | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Node route recorder failed.' }
  $routedEdit = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='apply_patch';tool_use_id='tool-2';tool_input=@{command='*** Begin Patch'}})
  if ([string]$routedEdit.hookSpecificOutput.permissionDecision -eq 'deny') { throw 'Routed ordinary edit was denied.' }

  $protectedEdit = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='Bash';tool_use_id='tool-3';tool_input=@{command="Set-Content '$requirementsPath' 'tamper'"}})
  Assert-Denied $protectedEdit 'Protected requirements mutation'
  $protectedRead = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='shell_command';tool_use_id='tool-3b';tool_input=@{command="Get-Content '$requirementsPath'"}})
  if ([string]$protectedRead.hookSpecificOutput.permissionDecision -eq 'deny') { throw 'Read-only protected-path inspection was denied.' }
  $browserTool = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='mcp__browser__open';tool_use_id='tool-4';tool_input=@{url='https://example.com'}})
  Assert-Denied $browserTool 'In-app browser tool'
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
  & $nodePath $recorder --session-id $session --turn-id $turn2 --tier T2 --intent 'inspection' --agent-route 'single primary agent' --browser-reason 'not required' | Out-Null
  $unauthorizedPush = Invoke-Hook $nodePath $hook ($base2 + @{hook_event_name='PreToolUse';tool_name='Bash';tool_use_id='tool-5';tool_input=@{command='git push origin main'}})
  Assert-Denied $unauthorizedPush 'Unauthorized push'
  Assert-Denied (Invoke-Hook $nodePath $hook ($base2 + @{hook_event_name='PreToolUse';tool_name='Bash';tool_use_id='tool-5b';tool_input=@{command="Remove-Item 'scoped' -Recurse"}})) 'Unauthorized delete'
  Assert-Denied (Invoke-Hook $nodePath $hook ($base2 + @{hook_event_name='PreToolUse';tool_name='Bash';tool_use_id='tool-5c';tool_input=@{command='git reset --hard HEAD'}})) 'Unauthorized reset'

  $session2 = 'session-created-goal'
  $goalTurn = 'turn-goal-create'
  $goalBase = @{session_id=$session2;turn_id=$goalTurn;cwd=$root;model='test-model';permission_mode='default';transcript_path=$null}
  Invoke-Hook $nodePath $hook ($goalBase + @{hook_event_name='UserPromptSubmit';prompt='inspect the repository'}) | Out-Null
  & $nodePath $recorder --session-id $session2 --turn-id $goalTurn --tier T2 --intent 'inspection' --agent-route 'single primary agent' --browser-reason 'not required' | Out-Null
  Invoke-Hook $nodePath $hook ($goalBase + @{hook_event_name='PostToolUse';tool_name='create_goal';tool_use_id='tool-goal';tool_input=@{objective='finish inspection'};tool_response='{"goal":{"status":"active"}}'}) | Out-Null
  $goalTurn2 = 'turn-goal-followup'
  $goalBase2 = $goalBase.Clone(); $goalBase2.turn_id=$goalTurn2
  Invoke-Hook $nodePath $hook ($goalBase2 + @{hook_event_name='UserPromptSubmit';prompt='continue'}) | Out-Null
  $createdGoalState = Get-Content -LiteralPath (Get-ChildItem -LiteralPath $stateRoot -Filter '*.turn-goal-followup.json' -File | Select-Object -First 1).FullName -Raw | ConvertFrom-Json
  if ($createdGoalState.goalTask -ne $true) { throw 'Goal created through create_goal did not persist to the next prompt.' }

  $authorizedPush = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PreToolUse';tool_name='Bash';tool_use_id='tool-6';tool_input=@{command='git push origin main'}})
  if ([string]$authorizedPush.hookSpecificOutput.permissionDecision -eq 'deny') { throw 'Explicitly authorized push was denied.' }

  $turn3 = 'turn-3'
  $base3 = $base.Clone(); $base3.turn_id=$turn3
  Invoke-Hook $nodePath $hook ($base3 + @{hook_event_name='UserPromptSubmit';prompt='delete the scoped fixture and reset its temporary test repository'}) | Out-Null
  & $nodePath $recorder --session-id $session --turn-id $turn3 --tier T2 --intent 'authorized destructive fixture' --agent-route 'single primary agent' --browser-reason 'not required' | Out-Null
  $authorizedDelete = Invoke-Hook $nodePath $hook ($base3 + @{hook_event_name='PreToolUse';tool_name='Bash';tool_use_id='tool-6b';tool_input=@{command="Remove-Item 'scoped' -Recurse"}})
  if ([string]$authorizedDelete.hookSpecificOutput.permissionDecision -eq 'deny') { throw 'Explicitly authorized delete was denied.' }
  $authorizedReset = Invoke-Hook $nodePath $hook ($base3 + @{hook_event_name='PreToolUse';tool_name='Bash';tool_use_id='tool-6c';tool_input=@{command='git reset --hard HEAD'}})
  if ([string]$authorizedReset.hookSpecificOutput.permissionDecision -eq 'deny') { throw 'Explicitly authorized reset was denied.' }

  $postEvidence = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PostToolUse';tool_name='Bash';tool_use_id='tool-7';tool_input=@{command='.\scripts\validate-task-evidence.ps1 -Tier T4 -EvidencePath .\.ueef\evidence\x.json'};tool_response="Exit code: 0`nstatus : PASS`ntaskId : x"})
  if ([string]$postEvidence.decision -eq 'block') { throw 'Passing task evidence was rejected.' }
  $missingLabels = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='Stop';stop_hook_active=$false;last_assistant_message='Implementation is still active.'})
  Assert-StopBlocked $missingLabels 'Final response without UEEF labels'

  $progressMissing = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='Stop';stop_hook_active=$false;last_assistant_message="UEEF: ACTIVE`nLoaded: boot-loader, core-system`nSelected: runtime`nGates: T4`nTools: PowerShell`nSkills: none`nUIUX: NA`nStatus: ACTIVE"})
  Assert-StopBlocked $progressMissing 'Long goal response without progress fields'

  $completionWithoutAudit = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='Stop';stop_hook_active=$false;last_assistant_message="Goal COMPLETE.`nUnderstanding: done`nPhase: review`nCurrent step: closure`nCurrent-step percent: 100%`nOverall percent: 100%`nNew evidence: tests`nCurrent action: close`nNext gate: none`nUEEF: ACTIVE`nLoaded: boot-loader, core-system`nSelected: runtime`nGates: T4`nTools: PowerShell`nSkills: none`nUIUX: NA`nStatus: COMPLETE"})
  Assert-StopBlocked $completionWithoutAudit 'Completion without completion audit'

  Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PostToolUse';tool_name='Bash';tool_use_id='tool-8';tool_input=@{command='.\scripts\validate-completion-audit.ps1 -Path .\.ueef\completion-audit\x.json'};tool_response="Exit code: 0`nstatus : PASS`ntaskId : x"}) | Out-Null
  Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PostToolUse';tool_name='Bash';tool_use_id='tool-9';tool_input=@{command='.\scripts\validate-goal-lifecycle.ps1 -GoalStatus COMPLETE -CompletionAuditPath .\.ueef\completion-audit\x.json'};tool_response="Exit code: 0`nGoalStatus : COMPLETE`nCompleteAllowed : True`nCompletionAuditPassed : True"}) | Out-Null
  Invoke-Hook $nodePath $hook ($base + @{hook_event_name='PostToolUse';tool_name='update_goal';tool_use_id='tool-10';tool_input=@{status='complete'};tool_response='{"goal":{"status":"complete"}}'}) | Out-Null
  $completeMessage = "Goal COMPLETE.`nUnderstanding: done`nPhase: review`nCurrent step: closure`nCurrent-step percent: 100%`nOverall percent: 100%`nNew evidence: all gates pass`nCurrent action: stop`nNext gate: none`nUEEF: ACTIVE`nLoaded: boot-loader, core-system`nSelected: runtime`nGates: T4 PASS`nTools: PowerShell`nSkills: none`nUIUX: NA`nStatus: COMPLETE"
  $completeStop = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='Stop';stop_hook_active=$false;last_assistant_message=$completeMessage})
  if ($completeStop.continue -eq $false -or [string]$completeStop.decision -eq 'block') { throw 'Fully evidenced completion was blocked.' }
  $followupStop = Invoke-Hook $nodePath $hook ($base + @{hook_event_name='Stop';stop_hook_active=$false;last_assistant_message=($completeMessage + "`nDo you want anything else?")})
  Assert-StopBlocked $followupStop 'Post-completion follow-up question'

  Write-Output 'Managed enforcement tests passed'
} finally {
  if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
