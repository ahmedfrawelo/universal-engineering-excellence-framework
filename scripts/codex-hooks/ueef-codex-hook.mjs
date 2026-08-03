import fs from 'node:fs';
import path from 'node:path';
import {
  hookRoot, loadPolicy, newTurnState, passingToolResponse, preToolDeny, readTurnState,
  runtimePath, safeId, setSessionGoalState, stopBlock, updateTurnState, writeTurnState
} from './ueef-hook-common.mjs';

const inputText = (value) => typeof value === 'string' ? value : JSON.stringify(value ?? '');
const regex = (value, flags = 'iu') => new RegExp(String(value).replace(/^\(\?i\)/u, ''), flags);

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

function onUserPromptSubmit(event) {
  const state = newTurnState(event.session_id, event.turn_id, event.prompt, event.cwd);
  writeTurnState(event.session_id, event.turn_id, state);
  const recorder = path.join(hookRoot, 'record-ueef-route.mjs');
  const command = `& ${quotePowerShell(process.execPath)} ${quotePowerShell(recorder)} --session-id ${quotePowerShell(state.sessionId)} --turn-id ${quotePowerShell(state.turnId)} --tier <T0|T1|T2|T3|T4> --intent '<intent>' --agent-route '<route>' --browser-reason '<reason>'`;
  return {continue:true,hookSpecificOutput:{hookEventName:'UserPromptSubmit',additionalContext:currentContext(command)}};
}

function onPreToolUse(event) {
  const state = readTurnState(event.session_id, event.turn_id);
  if (!state) return {};
  const toolName = String(event.tool_name || '');
  const toolInput = inputText(event.tool_input);
  if (/record-ueef-route\.mjs/iu.test(toolInput) && /--session-id/iu.test(toolInput) && /--turn-id/iu.test(toolInput) && /--tier/iu.test(toolInput)) return {};
  if (!state.route) return preToolDeny('UEEF route is missing. Publish Intent, Tier, Agent route, and Browser reason, then run the injected record-ueef-route.mjs command before using local tools.');
  const policy = loadPolicy();
  const mutationLikely = /(apply_patch|write|edit|delete|remove|move|rename)/iu.test(toolName) ||
    /(Set-Content|Add-Content|Out-File|Remove-Item|Move-Item|Rename-Item|Copy-Item|rm\s|mv\s|cp\s|del\s|erase\s|writeFile|appendFile|unlink|rename\s*\()/iu.test(toolInput);
  for (const fragment of policy.protectedPathFragments) {
    if (mutationLikely && toolInput.toLowerCase().includes(String(fragment).toLowerCase())) return preToolDeny(`UEEF protected enforcement path mutation denied: ${fragment}`);
  }
  for (const pattern of policy.prohibitedBrowserToolPatterns) if (regex(pattern).test(toolName)) return preToolDeny(`Prohibited browser surface denied by UEEF: ${toolName}`);
  for (const pattern of policy.prohibitedBrowserInputPatterns) if (regex(pattern).test(toolInput)) return preToolDeny('Prohibited browser/window/profile/context path denied by UEEF.');
  if (policy.browserInputPatterns.some((pattern) => regex(pattern).test(toolInput)) && state.validations.browserPreflight !== true) return preToolDeny('Browser control requires a passing UEEF browser preflight before Chrome binding calls.');
  for (const rule of policy.destructiveCommands) {
    if (regex(rule.pattern).test(toolInput) && state.authorizations?.[rule.authorization] !== true) return preToolDeny(`Command denied without explicit current-prompt authorization: ${rule.id}`);
  }
  if (toolName === 'update_goal') {
    const status = String(event.tool_input?.status || '');
    if (status === 'complete' && (state.validations.completionAudit !== true || state.validations.goalLifecycleComplete !== true)) return preToolDeny('Goal completion denied until completion audit and COMPLETE lifecycle validation both pass.');
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
  const goalCreated = toolName === 'create_goal' && /"status"\s*:\s*"active"/iu.test(response);
  if (goalCreated) setSessionGoalState(event.session_id, true);
  updateTurnState(event.session_id, event.turn_id, (state) => {
    state.toolsUsed = Number(state.toolsUsed || 0) + 1;
    if (goalCreated) state.goalTask = true;
    if (!passed) return;
    if (/ueef-status\.ps1/iu.test(toolInput) && /Overall:\s*ACTIVE/iu.test(response) && /Runtime drift:\s*PASS/iu.test(response) && /Runtime source revision:\s*PASS/iu.test(response)) state.validations.runtime = true;
    if (/validate-task-evidence\.ps1/iu.test(toolInput) && /(\bstatus\s*[:=]\s*PASS|"status"\s*:\s*"PASS")/iu.test(response)) state.validations.taskEvidence = true;
    if (/validate-completion-audit\.ps1/iu.test(toolInput) && /(\bstatus\s*[:=]\s*PASS|"status"\s*:\s*"PASS")/iu.test(response)) state.validations.completionAudit = true;
    if (/validate-goal-lifecycle\.ps1/iu.test(toolInput) && /GoalStatus\s+COMPLETE/iu.test(toolInput) && /CompleteAllowed\s*:\s*True/iu.test(response)) state.validations.goalLifecycleComplete = true;
    if (/validate-goal-lifecycle\.ps1/iu.test(toolInput) && /GoalStatus\s+BLOCKED/iu.test(toolInput) && /BlockedAllowed\s*:\s*True/iu.test(response)) state.validations.goalLifecycleBlocked = true;
    if (/get-ueef-task-preflight\.ps1/iu.test(toolInput) && /(browserGate.{0,80}(PASS|READY)|READY_WITH_FALLBACK)/isu.test(response)) state.validations.browserPreflight = true;
    if (/(user\.openTabs|claimTab|tab\.playwright)/iu.test(toolInput) && !/(error|failed|denied)/iu.test(response)) state.validations.browserVerified = true;
    if (/(test-|validate-framework|ueef-audit|invoke-full-assurance)/iu.test(toolInput) && /(PASS|passed|Exit code:\s*0)/iu.test(response)) state.validations.tests = true;
    if (/sync-runtime\.ps1/iu.test(toolInput) && /runtime synced/iu.test(response)) state.validations.runtimeSync = true;
    if (/git\s+push\b/iu.test(toolInput) && /(Exit code:\s*0|->)/iu.test(response)) state.validations.push = true;
    if (/(publish-github-release|gh\s+release\s+create)/iu.test(toolInput) && /(Exit code:\s*0|release)/iu.test(response)) state.validations.release = true;
    if (toolName === 'update_goal' && event.tool_input?.status === 'complete' && /"status"\s*:\s*"complete"/iu.test(response)) state.validations.goalComplete = true;
    if (toolName === 'update_goal' && event.tool_input?.status === 'blocked' && /"status"\s*:\s*"blocked"/iu.test(response)) state.validations.goalBlocked = true;
  });
  if (passed && toolName === 'update_goal' && ['complete','blocked'].includes(event.tool_input?.status)) setSessionGoalState(event.session_id, false);
  return {};
}

function onStop(event) {
  const state = readTurnState(event.session_id, event.turn_id);
  if (!state) return {continue:true};
  const message = String(event.last_assistant_message || '');
  const policy = loadPolicy();
  if (state.engineeringLikely === true || Number(state.toolsUsed || 0) > 0) {
    const missing = policy.requiredFinalLabels.filter((label) => !new RegExp(`^\\s*${label.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\s*:`, 'imu').test(message));
    if (missing.length) return stopBlock(`UEEF final verification is missing labels: ${missing.join(', ')}`);
  }
  const completionClaim = regex(policy.completionClaimPattern).test(message);
  if (state.goalTask === true && !completionClaim) {
    const missingProgress = policy.requiredProgressConcepts.filter((pattern) => !new RegExp(`^\\s*(?:${pattern})\\s*:`, 'imu').test(message));
    if (missingProgress.length) return stopBlock('Active long-goal update is missing understanding, phase, current step, both percentages, new evidence, current action, or next gate.');
  }
  if (completionClaim) {
    if (['T2','T3','T4'].includes(state.route?.tier) && state.validations.taskEvidence !== true) return stopBlock('T2+ completion requires passing task evidence in the current turn.');
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
const event = JSON.parse(raw);
let result = {};
if (event.hook_event_name === 'SessionStart') result = onSessionStart(event);
else if (event.hook_event_name === 'UserPromptSubmit') result = onUserPromptSubmit(event);
else if (event.hook_event_name === 'PreToolUse') result = onPreToolUse(event);
else if (event.hook_event_name === 'PostToolUse') result = onPostToolUse(event);
else if (event.hook_event_name === 'Stop') result = onStop(event);
process.stdout.write(`${JSON.stringify(result)}\n`);
