import fs from 'node:fs';
import path from 'node:path';
import {
  assistantMessageContains, commitWorkUnitInvocation, hookRoot, loadPolicy, newTurnState, passingToolResponse, preToolDeny, readTurnState,
  runtimePath, safeId, setSessionGoalState, stopBlock, updateTurnState, writeTurnState
} from './ueef-hook-common.mjs';

const inputText = (value) => typeof value === 'string' ? value : JSON.stringify(value ?? '');
const regex = (value, flags = 'iu') => new RegExp(String(value).replace(/^\(\?i\)/u, ''), flags);
const mutationLikely = (toolName, toolInput) => /(apply_patch|write|edit|delete|remove|move|rename)/iu.test(toolName) ||
  /(Set-Content|Add-Content|Out-File|Remove-Item|Move-Item|Rename-Item|Copy-Item|rm\s|mv\s|cp\s|del\s|erase\s|writeFile|appendFile|unlink|rename\s*\()/iu.test(toolInput);
const responseFailed = (response) => /(Exit code:\s*[1-9]|Script failed|"isError"\s*:\s*true|permissionDecision"?\s*:\s*"deny")/iu.test(response);
const containsJsonStringField = (text, name, value) => new RegExp(`"${String(name).replace(/[.*+?^${}()|[\]\\]/gu, '\\$&')}"\\s*:\\s*"${String(value).replace(/[.*+?^${}()|[\]\\]/gu, '\\$&')}"`, 'u').test(text);
const completionNegationPattern = /(?:\b(?:not|no|never|without|pending|requires?|before|until|cannot|can't|won't|do\s+not|did\s+not|isn't|wasn't)\b|(?:لا|لن|ليس|ليست|غير|بدون|قبل|حتى|يتطلب|يحتاج))/iu;

function isCompletionClaim(message, policy) {
  const claim = regex(policy.completionClaimPattern, 'giu');
  for (const line of String(message).split(/\r?\n/u)) {
    claim.lastIndex = 0;
    for (const match of line.matchAll(claim)) {
      const prefix = line.slice(0, match.index);
      if (/^\s*(?:Current-step percent|Overall percent|نسبة الخطوة الحالية|النسبة الكلية)\s*:/iu.test(line)) continue;
      if (completionNegationPattern.test(prefix)) continue;
      return true;
    }
  }
  return false;
}

function currentContext(routeCommand = '') {
  let version = 'UNKNOWN';
  const versionFile = path.join(runtimePath, 'VERSION.md');
  if (fs.existsSync(versionFile)) version = fs.readFileSync(versionFile, 'utf8').match(/\b\d+\.\d+\.\d+\b/)?.[0] || version;
  let context = `UEEF managed enforcement is active. Current runtime version: ${version}. Loader: ${path.join(runtimePath, 'UEEF-LOADER.md')}. Status: ${path.join(runtimePath, 'scripts', 'ueef-status.ps1')}. Re-read the current loader for this task; do not rely on the AGENTS snapshot alone.`;
  if (routeCommand) context += ` Before any local tool, publish the four localized route fields, then run exactly one route record command using: ${routeCommand}`;
  return context;
}

function onSessionStart() {
  return {continue:true,hookSpecificOutput:{hookEventName:'SessionStart',additionalContext:currentContext()}};
}

function quotePowerShell(value) { return `'${String(value).replaceAll("'", "''")}'`; }
function commandArgument(command, name) {
  const escaped = name.replace(/[.*+?^${}()|[\]\\]/gu, '\\$&');
  return String(command).match(new RegExp(`(?:^|\\s)${escaped}\\s+(?:"([^"]+)"|'([^']+)'|([^\\s]+))`, 'iu'))?.slice(1).find(Boolean) || null;
}
function shellCommandFromTool(toolName, event) {
  if (/(?:shell_command|bash|powershell|terminal)/iu.test(toolName)) {
    return String(event.tool_input?.command || event.tool_input?.cmd || '');
  }
  if (!/(?:^|[._])exec$/iu.test(toolName)) return '';
  const code = typeof event.tool_input === 'string'
    ? event.tool_input
    : String(event.tool_input?.code || event.tool_input?.input || '');
  const wrapper = code.match(/^\s*const\s+([A-Za-z_$][\w$]*)\s*=\s*await\s+tools\.shell_command\(\{\s*command\s*:\s*("(?:\\.|[^"\\])*")\s*,\s*workdir\s*:\s*"(?:\\.|[^"\\])*"\s*,\s*timeout_ms\s*:\s*\d+\s*\}\)\s*;\s*text\(\1\)\s*;?\s*$/u);
  if (!wrapper) return '';
  try { return JSON.parse(wrapper[2]); } catch { return ''; }
}
function hasUnquotedShellControl(command) {
  const text = String(command || '');
  let quote = null;
  for (let index = 0; index < text.length; index += 1) {
    const character = text[index];
    if (character === '\r' || character === '\n') return true;
    if (quote === "'") {
      if (character === "'" && text[index + 1] === "'") { index += 1; continue; }
      if (character === "'") quote = null;
      continue;
    }
    if (quote === '"') {
      if (character === '`' && index + 1 < text.length) { index += 1; continue; }
      if (character === '"') quote = null;
      continue;
    }
    if (character === "'" || character === '"') { quote = character; continue; }
    if (character === ';' || character === '|') return true;
    if (character === '&' && text[index + 1] === '&') return true;
  }
  return quote !== null;
}
function isIsolatedRouteRecorder(toolName, event, toolInput) {
  const command = shellCommandFromTool(toolName, event);
  if (!command || hasUnquotedShellControl(command)) return false;
  return /^\s*(?:&\s+)?(?:"[^"]+"|'[^']+'|\S+)\s+(?:"[^"]*record-ueef-route\.mjs"|'[^']*record-ueef-route\.mjs'|\S*record-ueef-route\.mjs)/iu.test(command) &&
    /--session-id\s+/iu.test(command) && /--turn-id\s+/iu.test(command) && /--work-unit-id\s+/iu.test(command) && /--tier\s+/iu.test(command) &&
    /record-ueef-route\.mjs/iu.test(toolInput);
}
function isIsolatedDirectDispatcher(toolName, event) {
  const command = shellCommandFromTool(toolName, event);
  if (!command || hasUnquotedShellControl(command)) return false;
  return /^\s*(?:&\s+)?(?:"[^"]+"|'[^']+'|\S+)\s+(?:"[^"]*codex-app-server-dispatch\.mjs"|'[^']*codex-app-server-dispatch\.mjs'|\S*codex-app-server-dispatch\.mjs)\b/iu.test(command);
}

function isEconomicalLeadRead(toolName, event, tier) {
  if (!['T0', 'T1'].includes(String(tier))) return false;
  if (/(?:^|[._])(?:read|list|get|view|find|search|status)/iu.test(String(toolName))) return true;
  const command = shellCommandFromTool(toolName, event);
  if (!command || hasUnquotedShellControl(command)) return false;
  return /^\s*(?:Get-Content|Get-ChildItem|Test-Path|Resolve-Path|rg\b|git\s+(?:status|log|diff|show|rev-list)\b|(?:&\s+)?(?:"[^"]*ueef-status\.ps1"|'[^']*ueef-status\.ps1'|\S*ueef-status\.ps1)(?:\s|$))/iu.test(command);
}

function onUserPromptSubmit(event) {
  const state = newTurnState(event.session_id, event.turn_id, event.prompt, event.cwd, event.model);
  writeTurnState(event.session_id, event.turn_id, state);
  const recorder = path.join(hookRoot, 'record-ueef-route.mjs');
  const command = `& ${quotePowerShell(process.execPath)} ${quotePowerShell(recorder)} --session-id ${quotePowerShell(state.sessionId)} --turn-id ${quotePowerShell(state.turnId)} --work-unit-id '<stable-work-unit-id>' --tier <T0|T1|T2|T3|T4> --intent '<intent>' --agent-route '<route>' --browser-reason '<reason>' --acceptance '<acceptance criteria>' --owner-paths '<owned paths>' --non-goals '<explicit non-goals>'`;
  return {continue:true,hookSpecificOutput:{hookEventName:'UserPromptSubmit',additionalContext:currentContext(command)}};
}

function onPreToolUse(event) {
  const state = readTurnState(event.session_id, event.turn_id);
  if (!state) return {};
  const toolName = String(event.tool_name || '');
  const toolInput = inputText(event.tool_input);
  const freeModeActive = state.freeMode?.active === true;
  if (isIsolatedRouteRecorder(toolName, event, toolInput)) return {};
  if (!freeModeActive && !state.route?.modelRouteVerified) return preToolDeny('UEEF dynamic model route is missing. Publish Intent, Tier, Agent route, Browser reason, model, and effort, then run the injected record-ueef-route.mjs command with a fresh host catalog before using local tools.');
  if (!freeModeActive && state.route.tokenEconomy?.specRequired === true && (state.validations.executionSpec !== true || !state.executionSpec?.digest)) return preToolDeny('T2+ execution requires the managed execution spec created by the validated route recorder.');
  if (!freeModeActive && !assistantMessageContains(event.transcript_path, state.route.routeLine)) return preToolDeny(`Publish this exact route before execution: ${state.route.routeLine}`);
  const directModelDispatch = /codex-app-server-dispatch\.mjs/iu.test(toolInput);
  const hostModelDispatch = /(send_message_to_thread|create_thread|spawn_agent)/iu.test(toolName);
  const goalLifecycleTool = /^(?:create_goal|update_goal)$/iu.test(toolName);
  const economicalLeadRead = isEconomicalLeadRead(toolName, event, state.route?.tier);
  if (/(create_thread|fork_thread)/iu.test(toolName) && state.authorizations?.newUserTask !== true) return preToolDeny('Creating a user-visible Codex task requires an explicit current-prompt request for a new task. Use ephemeral routed execution or an internal worker instead.');
  const workerDispatch = state.validations.modelDispatch === true && /(create_thread|spawn_agent)/iu.test(toolName);
  if (!freeModeActive && workerDispatch && Number(state.workerDispatchCount || 0) >= Number(state.route.tokenEconomy?.maxWorkerCount ?? 0)) return preToolDeny(`Worker dispatch exceeds the ${state.route.tokenEconomy?.maxWorkerCount ?? 0}-worker budget for ${state.route.tier}.`);
  if (!freeModeActive && state.validations.modelDispatch !== true && !directModelDispatch && !hostModelDispatch && !goalLifecycleTool && !economicalLeadRead) return preToolDeny('Execute the current validated model route before using mutation or non-read task tools. Goal lifecycle controls and T0/T1 allowlisted read-only intake remain available before dispatch.');
  if (!freeModeActive && state.validations.modelDispatch === true && state.route.actualLine && !assistantMessageContains(event.transcript_path, state.route.actualLine)) return preToolDeny(`Publish the verified actual sub-agent execution before continuing: ${state.route.actualLine}`);
  if (!freeModeActive && directModelDispatch) {
    if (!isIsolatedDirectDispatcher(toolName, event)) return preToolDeny('Direct App Server dispatch must be an isolated dispatcher command with no chained output fabrication.');
    const commandText = shellCommandFromTool(toolName, event);
    const routePath = commandArgument(commandText, '--route');
    if (!routePath || !fs.existsSync(routePath)) return preToolDeny('Direct App Server dispatch requires the current managed route artifact.');
    let dispatchRoute;
    try { dispatchRoute = JSON.parse(fs.readFileSync(routePath, 'utf8')); } catch { return preToolDeny('Direct App Server dispatch route is unreadable.'); }
    if (dispatchRoute.routeDigest !== state.route.routeDigest || dispatchRoute.executionSpec?.digest !== state.executionSpec?.digest || dispatchRoute.catalogDigest !== state.route.catalogDigest || dispatchRoute.preferredModel !== state.route.preferredModel || dispatchRoute.hostReasoning !== state.route.hostReasoning ||
        (dispatchRoute.fallbackModel || null) !== (state.route.fallbackModel || null) || (dispatchRoute.fallbackHostReasoning || null) !== (state.route.fallbackHostReasoning || null)) {
      return preToolDeny('Direct App Server dispatch route does not match the current validated work-unit route.');
    }
  }
  const policy = loadPolicy();
  const mutation = mutationLikely(toolName, toolInput);
  if (!freeModeActive && hostModelDispatch) {
    const dispatchedModel = String(event.tool_input?.model || '');
    const dispatchedReasoning = String(event.tool_input?.thinking || event.tool_input?.reasoning_effort || '');
    if (!dispatchedModel || !dispatchedReasoning) return preToolDeny('Model-aware dispatch requires explicit model and reasoning from the current validated UEEF route.');
    if (dispatchedModel !== state.route.preferredModel || dispatchedReasoning !== state.route.hostReasoning) return preToolDeny(`Dispatch does not match validated work-unit route ${state.route.preferredModel}/${state.route.hostReasoning}.`);
  }
  for (const fragment of policy.protectedPathFragments) {
    if (mutation && toolInput.toLowerCase().includes(String(fragment).toLowerCase())) return preToolDeny(`UEEF protected enforcement path mutation denied: ${fragment}`);
  }
  if (!freeModeActive && state.frontendLikely === true && mutation && state.validations.frontendRouting !== true) return preToolDeny('Frontend mutation requires a passing select-frontend-route.mjs result before editing.');
  for (const pattern of policy.prohibitedBrowserToolPatterns) if (regex(pattern).test(toolName)) return preToolDeny(`Prohibited browser surface denied by UEEF: ${toolName}`);
  for (const pattern of policy.prohibitedBrowserInputPatterns) if (regex(pattern).test(toolInput)) return preToolDeny('Prohibited browser/window/profile/context path denied by UEEF.');
  if (policy.browserInputPatterns.some((pattern) => regex(pattern).test(toolInput)) && state.validations.browserPreflight !== true) return preToolDeny('Browser control requires a passing UEEF browser preflight before Chrome binding calls.');
  const patchMutation = /apply_patch/iu.test(toolName) || /tools\.apply_patch\s*\(/u.test(toolInput);
  const patchText = /apply_patch/iu.test(toolName)
    ? String(event.tool_input?.command || event.tool_input?.patch || toolInput)
    : toolInput;
  for (const rule of policy.destructiveCommands) {
    if (patchMutation) {
      const fileRemoval = rule.id === 'delete' && /^\s*\*{3}\s+Delete\s+File:/imu.test(patchText);
      if (fileRemoval && state.authorizations?.[rule.authorization] !== true) return preToolDeny(`Command denied without explicit current-prompt authorization: ${rule.id}`);
      continue;
    }
    if (regex(rule.pattern).test(toolInput) && state.authorizations?.[rule.authorization] !== true) return preToolDeny(`Command denied without explicit current-prompt authorization: ${rule.id}`);
  }
  if (toolName === 'update_goal') {
    const status = String(event.tool_input?.status || '');
    if (status === 'complete' && (state.validations.completionAudit !== true || state.validations.goalLifecycleComplete !== true)) return preToolDeny('Goal completion denied until completion audit and COMPLETE lifecycle validation both pass.');
    if (status === 'complete' && state.route?.tier === 'T4' && state.validations.freshReview !== true) return preToolDeny('T4 goal completion denied until the agent automatically runs the selected fresh-context review lane and fresh-review evidence passes in the current turn. Do not ask the user for a separate reviewer trigger.');
    if (status === 'blocked' && state.validations.goalLifecycleBlocked !== true) return preToolDeny('Goal BLOCKED transition denied until BLOCKED lifecycle validation passes.');
  }
  return {};
}

function onPostToolUse(event) {
  if (!readTurnState(event.session_id, event.turn_id)) return {};
  const toolName = String(event.tool_name || '');
  const toolInput = inputText(event.tool_input);
  const response = inputText(event.tool_response);
  const passed = passingToolResponse(event.tool_response);
  const mutation = mutationLikely(toolName, toolInput);
  const goalCreated = toolName === 'create_goal' && /"status"\s*:\s*"active"/iu.test(response);
  if (goalCreated) setSessionGoalState(event.session_id, true);
  updateTurnState(event.session_id, event.turn_id, (state) => {
    const modelDispatchWasAlreadyVerified = state.validations.modelDispatch === true;
    state.toolsUsed = Number(state.toolsUsed || 0) + 1;
    if (goalCreated) state.goalTask = true;
    if (mutation && !responseFailed(response)) state.frontendMutation = state.frontendLikely === true;
    const frontendPolicy = loadPolicy().frontendEnforcement || {};
    if (regex(frontendPolicy.routeCommandPattern || 'select-frontend-route\\.mjs').test(toolInput) && !responseFailed(response) && /"applies"\s*:\s*true/iu.test(response)) state.validations.frontendRouting = true;
    if (regex(frontendPolicy.evidenceCommandPattern || 'validate-frontend-execution-evidence\\.mjs').test(toolInput) && !responseFailed(response) && /FRONTEND_EXECUTION_EVIDENCE:\s*PASS/iu.test(response)) state.validations.frontendExecutionEvidence = true;
    if (!passed) return;
    if (/ueef-status\.ps1/iu.test(toolInput) && /Overall:\s*ACTIVE/iu.test(response) && /Runtime drift:\s*PASS/iu.test(response) && /Runtime source revision:\s*PASS/iu.test(response)) state.validations.runtime = true;
    if (/validate-task-evidence\.ps1/iu.test(toolInput) && /(\bstatus\s*[:=]\s*PASS|"status"\s*:\s*"PASS")/iu.test(response)) state.validations.taskEvidence = true;
    if (/validate-fresh-review-evidence\.ps1/iu.test(toolInput) && /FRESH_REVIEW_EVIDENCE:\s*PASS/iu.test(response)) state.validations.freshReview = true;
    if (/validate-completion-audit\.ps1/iu.test(toolInput) && /(\bstatus\s*[:=]\s*PASS|"status"\s*:\s*"PASS")/iu.test(response)) state.validations.completionAudit = true;
    if (/validate-goal-lifecycle\.ps1/iu.test(toolInput) && /GoalStatus\s+COMPLETE/iu.test(toolInput) && /CompleteAllowed\s*:\s*True/iu.test(response)) state.validations.goalLifecycleComplete = true;
    if (/validate-goal-lifecycle\.ps1/iu.test(toolInput) && /GoalStatus\s+BLOCKED/iu.test(toolInput) && /BlockedAllowed\s*:\s*True/iu.test(response)) state.validations.goalLifecycleBlocked = true;
    if (/get-ueef-task-preflight\.ps1/iu.test(toolInput) && /(browserGate.{0,80}(PASS|READY)|READY_WITH_FALLBACK)/isu.test(response)) state.validations.browserPreflight = true;
    if (/(user\.openTabs|claimTab|tab\.playwright)/iu.test(toolInput) && !/(error|failed|denied)/iu.test(response)) state.validations.browserVerified = true;
    const passingTestCommandPattern = frontendPolicy.passingTestCommandPattern || '(?:test-|validate-framework|ueef-audit|invoke-full-assurance)';
    if (regex(passingTestCommandPattern).test(toolInput) && /(PASS|passed|Exit code:\s*0)/iu.test(response)) state.validations.tests = true;
    if (/sync-runtime\.ps1/iu.test(toolInput) && /runtime synced/iu.test(response)) state.validations.runtimeSync = true;
    if (/git\s+push\b/iu.test(toolInput) && /(Exit code:\s*0|->)/iu.test(response)) state.validations.push = true;
    if (/(publish-github-release|gh\s+release\s+create)/iu.test(toolInput) && /(Exit code:\s*0|release)/iu.test(response)) state.validations.release = true;
    if (toolName === 'update_goal' && event.tool_input?.status === 'complete' && /"status"\s*:\s*"complete"/iu.test(response)) state.validations.goalComplete = true;
    if (toolName === 'update_goal' && event.tool_input?.status === 'blocked' && /"status"\s*:\s*"blocked"/iu.test(response)) state.validations.goalBlocked = true;
    if (/(send_message_to_thread|create_thread|spawn_agent)/iu.test(toolName) && state.route?.modelRouteVerified === true) {
      const dispatchedModel = String(event.tool_input?.model || '');
      const dispatchedReasoning = String(event.tool_input?.thinking || event.tool_input?.reasoning_effort || '');
      const exactHostReceipt = containsJsonStringField(response, 'provider', 'codex-app-server:turn/start') &&
        /"threadId"\s*:\s*"[^"]+"/iu.test(response) && /"turnId"\s*:\s*"[^"]+"/iu.test(response) &&
        containsJsonStringField(response, 'executionVerificationSource', 'codex-app-server:thread/start+thread/settings/updated+model/rerouted') &&
        /"providerModelFallbackAllowed"\s*:\s*false/iu.test(response) &&
        containsJsonStringField(response, 'actualModel', dispatchedModel) &&
        containsJsonStringField(response, 'actualHostReasoning', dispatchedReasoning) &&
        containsJsonStringField(response, 'routeDigest', state.route.routeDigest) &&
        /"executionVerified"\s*:\s*true/iu.test(response) && /"result"\s*:\s*"SUCCESS"/iu.test(response);
      if (dispatchedModel === state.route.preferredModel && dispatchedReasoning === state.route.hostReasoning && !responseFailed(response) && exactHostReceipt) {
        // A successful tool call is not execution evidence by itself.  The
        // host response must carry the exact digest-bound actual pair.
        state.validations.modelDispatch = true;
        state.route.actualModel = dispatchedModel;
        state.route.actualHostReasoning = dispatchedReasoning;
        state.route.actualVerificationSource = 'host-model-dispatch-receipt';
        state.route.actualLine = `Model execution: ${state.route.workUnitId} | ${dispatchedModel} / ${dispatchedReasoning} (verified: host-dispatch-receipt)`;
        if (!state.route.invocationCommitted) state.route.invocationCommitted = commitWorkUnitInvocation(event.session_id, state.route.workUnitId, state.route.invocationIndex) || state.route.invocationCommitted === true;
      }
    }
    if (modelDispatchWasAlreadyVerified && /(create_thread|spawn_agent)/iu.test(toolName) && !responseFailed(response)) {
      state.workerDispatchCount = Number(state.workerDispatchCount || 0) + 1;
    }
    if (/codex-app-server-dispatch\.mjs/iu.test(toolInput) && state.route?.modelRouteVerified === true && !responseFailed(response)) {
      const primaryPair = containsJsonStringField(response, 'actualModel', state.route.preferredModel) && containsJsonStringField(response, 'actualHostReasoning', state.route.hostReasoning);
      const fallbackPair = Boolean(state.route.fallbackModel && state.route.fallbackHostReasoning) &&
        containsJsonStringField(response, 'actualModel', state.route.fallbackModel) && containsJsonStringField(response, 'actualHostReasoning', state.route.fallbackHostReasoning) &&
        /"capacityFallbackUsed"\s*:\s*true/iu.test(response) && /"attemptIndex"\s*:\s*0[\s\S]*?"result"\s*:\s*"CAPACITY"/iu.test(response);
      const exactReceipt = containsJsonStringField(response, 'provider', 'codex-app-server:turn/start') &&
        containsJsonStringField(response, 'routeDigest', state.route.routeDigest) && (primaryPair || fallbackPair) &&
        /"threadId"\s*:\s*"[^"]+"/iu.test(response) && /"turnId"\s*:\s*"[^"]+"/iu.test(response) &&
        containsJsonStringField(response, 'executionVerificationSource', 'codex-app-server:thread/start+thread/settings/updated+model/rerouted') &&
        /"providerModelFallbackAllowed"\s*:\s*false/iu.test(response) && /"executionVerified"\s*:\s*true/iu.test(response) && /"result"\s*:\s*"SUCCESS"/iu.test(response);
      if (exactReceipt) {
        const actualModel = primaryPair ? state.route.preferredModel : state.route.fallbackModel;
        const actualHostReasoning = primaryPair ? state.route.hostReasoning : state.route.fallbackHostReasoning;
        state.validations.modelDispatch = true;
        state.route.actualModel = actualModel;
        state.route.actualHostReasoning = actualHostReasoning;
        state.route.actualVerificationSource = 'codex-app-server';
        state.route.actualLine = `Model execution: ${state.route.workUnitId} | ${actualModel} / ${actualHostReasoning} (verified: codex-app-server)`;
        if (!state.route.invocationCommitted) state.route.invocationCommitted = commitWorkUnitInvocation(event.session_id, state.route.workUnitId, state.route.invocationIndex) || state.route.invocationCommitted === true;
      }
    }
  });
  if (passed && toolName === 'update_goal' && ['complete','blocked'].includes(event.tool_input?.status)) setSessionGoalState(event.session_id, false);
  return {};
}

function onStop(event) {
  const state = readTurnState(event.session_id, event.turn_id);
  if (!state) return {continue:true};
  const message = String(event.last_assistant_message || '');
  const policy = loadPolicy();
  const freeModeActive = state.freeMode?.active === true;
  const completionClaim = isCompletionClaim(message, policy);
  if (!freeModeActive && state.frontendLikely === true && Number(state.toolsUsed || 0) > 0 && state.validations.frontendRouting !== true) return stopBlock('Frontend work requires passing frontend route evidence before the turn can end.');
  if (state.frontendMutation === true) {
    if (state.validations.tests !== true) return stopBlock('Frontend mutation requires current passing test evidence.');
    if (state.validations.frontendExecutionEvidence !== true) return stopBlock('Frontend mutation requires a passing validate-frontend-execution-evidence.mjs artifact.');
    const uiux = message.match(/^\s*UIUX\s*:\s*(.+)$/imu)?.[1]?.trim() || '';
    if (!uiux || /^(?:NA|N\/A|NO|NONE)$/iu.test(uiux)) return stopBlock('Frontend mutation requires a substantive UIUX verification label; NA is not allowed.');
  }
  // Final verification is a completion contract. Enforcing it on ordinary
  // conversational replies exposes internal workflow guidance as an error.
  if (!freeModeActive && completionClaim && (state.engineeringLikely === true || Number(state.toolsUsed || 0) > 0)) {
    const missing = policy.requiredFinalLabels.filter((label) => !new RegExp(`^\\s*${label.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\s*:`, 'imu').test(message));
    if (missing.length) return stopBlock(`UEEF final verification is missing labels: ${missing.join(', ')}`);
    if (state.route?.modelRouteVerified && (!message.includes(state.route.preferredModel) || !message.includes(state.route.displayReasoning || state.route.hostReasoning))) return stopBlock('UEEF Selected must report the current work-unit model and host-provided reasoning display from the validated route.');
    if (state.validations.modelDispatch === true && state.route?.actualModel && (!message.includes(state.route.actualModel) || !message.includes(state.route.actualHostReasoning))) return stopBlock('UEEF Selected must report the verified actual sub-agent model and reasoning effort.');
  }
  if (!freeModeActive && completionClaim) {
    if (['T2','T3','T4'].includes(state.route?.tier) && (state.validations.executionSpec !== true || !state.executionSpec?.digest)) return stopBlock('T2+ completion requires the managed execution spec bound to the current route.');
    if (state.route?.modelRouteVerified === true && state.validations.modelDispatch !== true) return stopBlock('Completion claim requires a successful host model dispatch matching the validated work-unit route.');
    if (['T2','T3','T4'].includes(state.route?.tier) && state.validations.taskEvidence !== true) return stopBlock('T2+ completion requires passing task evidence in the current turn.');
    if (state.route?.tier === 'T4' && state.validations.freshReview !== true) return stopBlock('T4 completion requires the agent to automatically run the selected fresh-context review lane and pass fresh-review evidence in the current turn. Do not ask the user for a separate reviewer trigger.');
    if (state.validations.completionAudit !== true) return stopBlock('Completion claim requires a passing schema-version-2 completion audit in the current turn.');
    if (state.goalTask === true && (state.validations.goalLifecycleComplete !== true || state.validations.goalComplete !== true)) return stopBlock('Goal completion requires passing COMPLETE lifecycle validation and a successful update_goal complete transition.');
    if (regex(policy.postCompletionQuestionPattern).test(message)) return stopBlock('Remove the post-completion follow-up question; stop after the evidenced bounded goal is complete.');
  }
  if (/(browser (verified|pass)|تم التحقق من المتصفح)/iu.test(message) && state.validations.browserVerified !== true) return stopBlock('Browser verification claim lacks current claimed-tab evidence.');
  if (/(\bpushed\b|^\s*Push\s*:\s*(PASS|YES|DONE)|تم الرفع)/imu.test(message) && state.validations.push !== true) return stopBlock('Push claim lacks a passing current-turn Git push result.');
  if (/(\breleased\b|^\s*Release\s*:\s*(PASS|YES|DONE)|تم النشر)/imu.test(message) && state.validations.release !== true) return stopBlock('Release claim lacks a passing current-turn publication result.');
  return {continue:true};
}

const raw = fs.readFileSync(0, 'utf8');
if (!raw.trim()) { process.stdout.write('{}\n'); process.exit(0); }
const event = JSON.parse(raw.replace(/^\uFEFF/u, ''));
let result = {};
if (event.hook_event_name === 'SessionStart') result = onSessionStart(event);
else if (event.hook_event_name === 'UserPromptSubmit') result = onUserPromptSubmit(event);
else if (event.hook_event_name === 'PreToolUse') result = onPreToolUse(event);
else if (event.hook_event_name === 'PostToolUse') result = onPostToolUse(event);
else if (event.hook_event_name === 'Stop') result = onStop(event);
process.stdout.write(`${JSON.stringify(result)}\n`);
