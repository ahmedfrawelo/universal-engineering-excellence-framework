import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { assertTurnOwner, commitReservedWorkUnitInvocation, hookRoot, peekWorkUnitInvocation, readTurnState, releaseWorkUnitInvocationReservation, reserveWorkUnitInvocation, safeId, sha256Text, stateRoot, updateTurnState } from './ueef-hook-common.mjs';

const args = process.argv.slice(2);
const value = (name) => {
  const index = args.indexOf(name);
  if (index < 0 || index + 1 >= args.length) throw new Error(`Missing ${name}.`);
  return args[index + 1];
};
const optional = (name) => {
  const index = args.indexOf(name);
  return index < 0 ? null : args[index + 1] || null;
};
const has = (name) => args.includes(name);

const sessionId = value('--session-id');
const turnId = value('--turn-id');
if (has('--print-binding')) {
  const state = readTurnState(sessionId, turnId);
  if (!state?.route?.modelRouteVerified || !state.executionSpec?.digest) throw new Error('No verified route binding exists for the requested UEEF turn.');
  assertTurnOwner(state, sessionId);
  process.stdout.write(`${JSON.stringify({
    schemaVersion: 1,
    workUnitId: state.route.workUnitId,
    tier: state.route.tier,
    routeBinding: {
      routeDigest: state.route.routeDigest,
      executionSpecDigest: state.executionSpec.digest
    }
  })}\n`);
  process.exit(0);
}
const executeRoute = optional('--execute-route');
if (executeRoute) {
  const routePath = path.resolve(executeRoute);
  const prompt = value('--prompt');
  if (!prompt.trim() || Buffer.byteLength(prompt, 'utf8') > 256 * 1024) throw new Error('--prompt must contain 1-262144 UTF-8 bytes.');
  const state = readTurnState(sessionId, turnId);
  if (!state?.route?.modelRouteVerified) throw new Error('No verified route exists for the requested UEEF turn.');
  assertTurnOwner(state, sessionId);
  if (path.resolve(state.route.routeOutput || '') !== routePath) throw new Error('Dispatch route path does not match the current UEEF turn route.');
  if (!fs.existsSync(routePath) || !fs.lstatSync(routePath).isFile() || fs.lstatSync(routePath).isSymbolicLink()) throw new Error('Dispatch route is missing or unsafe.');
  const route = JSON.parse(fs.readFileSync(routePath, 'utf8'));
  if (route.routeDigest !== state.route.routeDigest || route.executionSpec?.digest !== state.executionSpec?.digest) throw new Error('Dispatch route identity does not match the current UEEF turn.');
  const dispatcher = path.resolve(hookRoot, '..', 'codex', 'scripts', 'codex-app-server-dispatch.mjs');
  if (!fs.existsSync(dispatcher) || !fs.lstatSync(dispatcher).isFile() || fs.lstatSync(dispatcher).isSymbolicLink()) throw new Error('Trusted installed UEEF dispatcher is missing or unsafe.');
  const reservationNonce = crypto.randomBytes(16).toString('hex');
  if (!reserveWorkUnitInvocation(sessionId, state.route.workUnitId, state.route.invocationIndex, turnId, reservationNonce)) {
    throw new Error('UEEF work-unit invocation is already reserved or committed.');
  }
  try {
    updateTurnState(sessionId, turnId, (current) => {
      if (current.route?.routeDigest !== route.routeDigest || current.executionSpec?.digest !== route.executionSpec?.digest) throw new Error('UEEF turn route changed before dispatch reservation.');
      if (current.validations.modelDispatch === true || current.route.invocationCommitted === true) throw new Error('UEEF route execution replay denied.');
      if (current.dispatchReservation) throw new Error('UEEF route execution is already reserved by another process.');
      current.dispatchReservation = { schemaVersion: 1, nonce: reservationNonce, routeDigest: route.routeDigest, pid: process.pid, createdAtUtc: new Date().toISOString() };
    });
  } catch (error) {
    releaseWorkUnitInvocationReservation(sessionId, state.route.workUnitId, reservationNonce);
    throw error;
  }
  let committed = false;
  try {
    const raw = execFileSync(process.execPath, [dispatcher, '--route', routePath, '--prompt', prompt], { encoding: 'utf8', timeout: 10 * 60 * 1000, windowsHide: true });
    const receipt = JSON.parse(raw.trim().split(/\r?\n/u).at(-1));
    const primary = receipt.actualModel === route.preferredModel && receipt.actualHostReasoning === route.hostReasoning;
    const fallback = Boolean(route.fallbackModel && route.fallbackHostReasoning) && receipt.actualModel === route.fallbackModel && receipt.actualHostReasoning === route.fallbackHostReasoning && receipt.capacityFallbackUsed === true;
    const observedAt = Date.parse(receipt.completedAt || '');
    if (receipt.provider !== 'codex-app-server:turn/start' || receipt.routeDigest !== route.routeDigest || receipt.executionSpecDigest !== route.executionSpec?.digest ||
        !receipt.threadId || !receipt.turnId || receipt.executionVerificationSource !== 'codex-app-server:thread/start+thread/settings/updated+model/rerouted' ||
        receipt.providerModelFallbackAllowed !== false || receipt.executionVerified !== true || receipt.result !== 'SUCCESS' || (!primary && !fallback) ||
        !Number.isFinite(observedAt) || Math.abs(Date.now() - observedAt) > 10 * 60 * 1000) throw new Error('Dispatcher did not return an exact current verified route receipt.');
    updateTurnState(sessionId, turnId, (current) => {
      if (current.route?.routeDigest !== route.routeDigest || current.executionSpec?.digest !== route.executionSpec?.digest || current.dispatchReservation?.nonce !== reservationNonce) throw new Error('UEEF turn route or reservation changed during dispatch.');
      current.validations.modelDispatch = true;
      current.route.actualModel = receipt.actualModel;
      current.route.actualHostReasoning = receipt.actualHostReasoning;
      current.route.actualDisplayReasoning = primary ? (route.displayReasoning || route.hostReasoning) : (route.fallbackDisplayReasoning || route.fallbackHostReasoning);
      current.route.capacityFallbackUsed = fallback;
      current.route.actualVerificationSource = 'codex-app-server';
      current.route.actualLine = `Model execution: ${current.route.workUnitId} | ${receipt.actualModel} / ${current.route.actualDisplayReasoning} (host: ${receipt.actualHostReasoning}; verified: codex-app-server)`;
      delete current.dispatchReservation;
    });
    committed = commitReservedWorkUnitInvocation(sessionId, state.route.workUnitId, state.route.invocationIndex, reservationNonce);
    if (!committed) throw new Error('Verified route execution could not commit its reserved one-shot invocation.');
    updateTurnState(sessionId, turnId, (current) => { current.route.invocationCommitted = true; });
    process.stdout.write(`${JSON.stringify({ status: 'PASS', ...receipt })}\n`);
    process.exit(0);
  } finally {
    if (!committed) {
      releaseWorkUnitInvocationReservation(sessionId, state.route.workUnitId, reservationNonce);
      updateTurnState(sessionId, turnId, (current) => { if (current.dispatchReservation?.nonce === reservationNonce) delete current.dispatchReservation; });
    }
  }
}
const closureEvidence = optional('--validate-closure');
if (closureEvidence) {
  const taskEvidencePath = path.resolve(closureEvidence);
  const freshReviewPath = path.resolve(value('--fresh-review'));
  const completionAuditPath = path.resolve(value('--completion-audit'));
  const state = readTurnState(sessionId, turnId);
  if (!state?.validations?.modelDispatch || !['T3', 'T4'].includes(String(state.route?.tier))) throw new Error('Closure validation requires a verified T3/T4 host dispatch.');
  assertTurnOwner(state, sessionId);
  for (const file of [taskEvidencePath, freshReviewPath, completionAuditPath]) {
    if (!fs.existsSync(file) || !fs.lstatSync(file).isFile() || fs.lstatSync(file).isSymbolicLink()) throw new Error(`Closure evidence is missing or unsafe: ${file}`);
  }
  const taskEvidence = JSON.parse(fs.readFileSync(taskEvidencePath, 'utf8'));
  const freshReview = JSON.parse(fs.readFileSync(freshReviewPath, 'utf8'));
  const completionAudit = JSON.parse(fs.readFileSync(completionAuditPath, 'utf8'));
  const bindingMatches = (artifact) => artifact?.routeBinding?.routeDigest === state.route.routeDigest && artifact?.routeBinding?.executionSpecDigest === state.executionSpec?.digest;
  if (!taskEvidence.taskId || taskEvidence.taskId !== freshReview.taskId || taskEvidence.taskId !== completionAudit.taskId || state.route.workUnitId !== taskEvidence.taskId ||
      taskEvidence.tier !== state.route.tier || freshReview.tier !== state.route.tier || !bindingMatches(taskEvidence) || !bindingMatches(freshReview) || !bindingMatches(completionAudit)) {
    throw new Error('Closure artifacts do not bind the current UEEF task identity.');
  }
  const reportPaths = ['architecture', 'file-organization'].map((domain) => taskEvidence.domains?.[domain]?.fields?.automatedReport).filter(Boolean).map((file) => path.resolve(taskEvidence.repositoryRoot, file));
  const closureFiles = [taskEvidencePath, freshReviewPath, completionAuditPath, ...reportPaths];
  const hashesBefore = new Map();
  for (const file of closureFiles) {
    if (!fs.existsSync(file) || !fs.lstatSync(file).isFile() || fs.lstatSync(file).isSymbolicLink()) throw new Error(`Referenced closure evidence is missing or unsafe: ${file}`);
    hashesBefore.set(file, crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'));
  }
  const runtimeScripts = path.resolve(hookRoot, '..', 'codex', 'scripts');
  const powershell = process.env.SystemRoot ? path.join(process.env.SystemRoot, 'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe') : 'powershell.exe';
  const runPowerShell = (script, scriptArgs) => execFileSync(powershell, ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(runtimeScripts, script), ...scriptArgs], { encoding: 'utf8', timeout: 5 * 60 * 1000, windowsHide: true });
  const domains = Array.isArray(taskEvidence.selectedDomains) ? taskEvidence.selectedDomains.join(',') : '';
  const taskResult = runPowerShell('validate-task-evidence.ps1', ['-Tier', String(state.route.tier), '-SelectedDomain', domains, '-EvidencePath', taskEvidencePath, '-Json']);
  const freshResult = runPowerShell('validate-fresh-review-evidence.ps1', ['-Path', freshReviewPath, '-Json']);
  const auditResult = runPowerShell('validate-completion-audit.ps1', ['-Path', completionAuditPath, '-Json']);
  const runtimeResult = runPowerShell('ueef-status.ps1', []);
  if (!/"status"\s*:\s*"PASS"/iu.test(taskResult) || !/FRESH_REVIEW_EVIDENCE:\s*PASS/iu.test(freshResult) || !/"status"\s*:\s*"PASS"/iu.test(auditResult) ||
      !/Overall:\s*ACTIVE/iu.test(runtimeResult) || !/Runtime drift:\s*PASS/iu.test(runtimeResult) || !/Runtime source revision:\s*PASS/iu.test(runtimeResult)) {
    throw new Error('One or more managed closure validators did not pass.');
  }
  for (const [file, expected] of hashesBefore) {
    const actual = crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
    if (actual !== expected) throw new Error(`Closure evidence changed during validation: ${file}`);
  }
  updateTurnState(sessionId, turnId, (current) => {
    if (current.route?.routeDigest !== state.route.routeDigest || current.validations.modelDispatch !== true) throw new Error('UEEF turn route changed during closure validation.');
    current.validations.taskEvidence = true;
    current.validations.freshReview = true;
    current.validations.completionAudit = true;
    current.validations.goalLifecycleComplete = true;
    current.validations.runtime = true;
    current.validations.tests = true;
  });
  process.stdout.write(`${JSON.stringify({ status: 'PASS', taskId: taskEvidence.taskId, tier: state.route.tier, taskEvidence: 'PASS', freshReview: 'PASS', completionAudit: 'PASS', runtime: 'ACTIVE' })}\n`);
  process.exit(0);
}
const workUnitId = value('--work-unit-id');
const tier = value('--tier');
const intent = value('--intent');
const agentRoute = value('--agent-route');
const browserReason = value('--browser-reason');
const acceptance = optional('--acceptance');
const ownerPaths = optional('--owner-paths');
const nonGoals = optional('--non-goals');
const modelCatalog = optional('--model-catalog');
const routeOutput = optional('--route-output');
const specialistPurpose = optional('--specialist-purpose');
const catalogTimeoutMs = 10_000;
const catalogDiscoveryAttempts = 2;
const catalogDiscoveryLockWaitMs = 10_000;
const catalogProcessGraceMs = 3_000;
const catalogParentMarginMs = 2_000;
const resolverProcessGraceMs = 5_000;

if (!/^T[0-4]$/.test(tier)) throw new Error(`Invalid tier: ${tier}`);
for (const [name, item] of Object.entries({ workUnitId, intent, agentRoute, browserReason })) {
  if (!item || item.length > 500) throw new Error(`${name} must contain 1-500 characters.`);
}
if (modelCatalog && !fs.existsSync(modelCatalog)) throw new Error(`Test model catalog not found: ${modelCatalog}`);
if (has('--allow-test-catalog') && !modelCatalog) throw new Error('--allow-test-catalog requires --model-catalog.');
if (['T2', 'T3', 'T4'].includes(tier)) {
  for (const [name, item] of Object.entries({ acceptance, ownerPaths, nonGoals })) {
    if (!item || item.length > 1000) throw new Error(`${name} must contain 1-1000 characters for T2+ execution specs.`);
  }
}

const stateBefore = readTurnState(sessionId, turnId);
if (!stateBefore) throw new Error('No current UEEF turn state exists. Submit the prompt through the managed UserPromptSubmit hook first.');
assertTurnOwner(stateBefore, sessionId);
if (has('--use-current-model') && stateBefore.authorizations?.useCurrentModel !== true) throw new Error('Current-model constraint was not explicitly authorized by the current prompt.');
if (has('--allow-model-constraint-override') && stateBefore.authorizations?.allowModelConstraintOverride !== true) throw new Error('Model-constraint override was not explicitly authorized by the current prompt.');
if (has('--allow-exceed') && stateBefore.authorizations?.allowAboveHigh !== true) throw new Error('Above-high reasoning was not explicitly authorized by the current prompt.');

const localResolver = path.join(hookRoot, 'resolve-model-route.mjs');
const resolver = fs.existsSync(localResolver) ? localResolver : path.join(hookRoot, '..', 'resolve-model-route.mjs');
const localPolicy = path.join(hookRoot, 'model-routing-policy.json');
const policy = fs.existsSync(localPolicy) ? localPolicy : path.join(hookRoot, '..', '..', 'config', 'model-routing-policy.json');
const invocationIndex = peekWorkUnitInvocation(sessionId, workUnitId);
const resolverArgs = [resolver, '--tier', tier, '--policy', policy];
resolverArgs.push('--catalog-timeout-ms', String(catalogTimeoutMs));
resolverArgs.push('--work-unit-id', workUnitId);
resolverArgs.push('--invocation-index', String(invocationIndex));
if (modelCatalog) resolverArgs.push('--catalog', modelCatalog);
if (specialistPurpose) resolverArgs.push('--specialist-purpose', specialistPurpose);
if (has('--allow-test-catalog')) resolverArgs.push('--allow-test-catalog');
const currentModelFromAuth = stateBefore.pickerModel || null;
const autoUseCurrentModel = stateBefore.authorizations?.useCurrentModel === true;
const useCurrentModel = has('--use-current-model') || autoUseCurrentModel;
if (has('--allow-model-constraint-override') && useCurrentModel && stateBefore.authorizations?.allowModelConstraintOverride !== true) throw new Error('Model-constraint override was not explicitly authorized by the current prompt.');
if (has('--allow-exceed') && stateBefore.authorizations?.allowAboveHigh !== true) throw new Error('Above-high reasoning was not explicitly authorized by the current prompt.');

const currentModel = optional('--current-model') || currentModelFromAuth;
if (useCurrentModel && !currentModel) throw new Error('Current-model routing requires the current picker model from the hook event or --current-model.');
if (useCurrentModel) {
  resolverArgs.push('--use-current-model', '--current-model', currentModel);
}
const reasoningOverride = optional('--reasoning-override');
if (reasoningOverride) resolverArgs.push('--reasoning-override', reasoningOverride);
if (has('--allow-exceed') || stateBefore.authorizations?.allowAboveHigh === true) resolverArgs.push('--allow-exceed');
if (has('--allow-model-constraint-override') || stateBefore.authorizations?.allowModelConstraintOverride === true) resolverArgs.push('--allow-model-constraint-override');

if (!modelCatalog) process.stderr.write('UEEF route: discovering the current model catalog (bounded to 55 seconds).\n');
const modelRoute = JSON.parse(execFileSync(process.execPath, resolverArgs, {
  encoding: 'utf8',
  timeout: ((catalogDiscoveryLockWaitMs + catalogTimeoutMs + catalogProcessGraceMs + catalogParentMarginMs) * catalogDiscoveryAttempts) + resolverProcessGraceMs,
  windowsHide: true
}));
if (!modelCatalog) process.stderr.write('UEEF route: model catalog resolved; recording the route.\n');
const effectiveReasoning = modelRoute.displayReasoning || modelRoute.hostReasoning || modelRoute.reasoning || null;
const testRoute = modelRoute.testCatalogAllowed === true && has('--allow-test-catalog');
if ((!testRoute && (modelRoute.accountCatalogVerified !== true || modelRoute.catalogFresh !== true || modelRoute.catalogContractValid !== true)) || !modelRoute.preferredModel || !modelRoute.hostReasoning) {
  throw new Error(`Model route is unresolved or not backed by a fresh validated host catalog: ${modelRoute.modelAvailability}`);
}
const reviewIntent = /(?:review|audit|inspect|diagnos|report|analyse|analyze|راجع|افحص|شخص|تقرير)/iu.test(intent);
const implementationIntent = /(?:implement|fix|change|build|create|migrate|release|deploy|نفذ|اصلح|عدل|انش)/iu.test(intent);
const mode = reviewIntent && !implementationIntent ? 'REVIEW' : 'IMPLEMENTATION';
const spec = ['T3', 'T4'].includes(tier) ? 'FULL_REQUIRED' : modelRoute.tokenEconomy?.specRequired === true ? 'LIGHT' : 'NONE';
const specReason = spec === 'FULL_REQUIRED' ? 'FULL_SPEC_REQUIRED_BY_SCOPE_OR_RISK' : spec === 'LIGHT' ? 'EXECUTION_SPEC_REQUIRED' : 'TIER_DOES_NOT_REQUIRE_SPEC';
const userDelegationAuthorized = stateBefore.authorizations?.delegation === true;
const userSingleAgent = stateBefore.authorizations?.singleAgent === true && tier !== 'T4';
const policyVerifierAuthorized = tier === 'T4' && !userDelegationAuthorized;
const delegationAuthorized = userDelegationAuthorized || policyVerifierAuthorized;
const delegationAuthorizationSource = userDelegationAuthorized ? 'USER' : policyVerifierAuthorized ? 'PLATFORM_POLICY' : 'NONE';
const delegationScope = userDelegationAuthorized ? 'WORKERS' : policyVerifierAuthorized ? 'INDEPENDENT_VERIFIER' : 'NONE';
const team = userSingleAgent ? 'NONE' : Number(modelRoute.tokenEconomy?.maxWorkerCount || 0) > 0 && delegationAuthorized ? 'SPAWN' : Number(modelRoute.tokenEconomy?.maxWorkerCount || 0) > 0 ? 'AUTHORIZATION_REQUIRED' : 'NONE';
const teamReason = userSingleAgent ? 'USER_REQUESTED_SINGLE_AGENT' : userDelegationAuthorized ? 'USER_AUTHORIZED' : policyVerifierAuthorized ? 'MANDATORY_FRESH_REVIEW' : team === 'AUTHORIZATION_REQUIRED' ? 'AUTHORIZATION_REQUIRED' : 'NO_INDEPENDENT_WORK';
const decision = { mode, spec, specReason, team, teamReason, delegationAuthorized, delegationAuthorizationSource, delegationScope };
const routeDigest = sha256Text(JSON.stringify({
  tier,
  workUnitId,
  invocationIndex: modelRoute.invocationIndex,
  preferredModel: modelRoute.preferredModel,
  hostReasoning: modelRoute.hostReasoning,
  fallbackModel: modelRoute.fallbackModel || null,
  fallbackHostReasoning: modelRoute.fallbackHostReasoning || null,
  tokenEconomy: modelRoute.tokenEconomy,
  decision,
  catalogDigest: modelRoute.catalogDigest,
  catalogProvider: modelRoute.catalogProvider,
  catalogDiscoveredAt: modelRoute.catalogDiscoveredAt
}));
const executionSpec = {
  schemaVersion: 1,
  tier,
  workUnitId,
  promptSha256: stateBefore.promptSha256,
  outcome: intent,
  acceptanceCriteria: acceptance || 'Complete the bounded work unit and preserve current evidence requirements.',
  ownerPaths: ownerPaths || '(bounded by current task owner)',
  nonGoals: nonGoals || 'No scope outside the current bounded work unit.',
  tokenEconomy: modelRoute.tokenEconomy,
  requiredEvidence: ['current behavior evidence', 'risk-matched validation', 'completion audit before completion claim'],
  createdAtUtc: new Date().toISOString()
};
executionSpec.digest = sha256Text(JSON.stringify(executionSpec));
const managedRouteOutput = routeOutput
  ? path.resolve(routeOutput)
  : path.join(stateRoot, `${safeId(sessionId)}.${safeId(turnId)}.route.json`);
const routeRevision = Number(stateBefore.route?.routeRevision || 0) + 1;
const previousModel = stateBefore.route?.preferredModel || null;
const previousHostReasoning = stateBefore.route?.hostReasoning || null;
const routeHasMeaningfulChange = Boolean(stateBefore.route) && (
  stateBefore.route.workUnitId !== workUnitId ||
  stateBefore.route.invocationIndex !== modelRoute.invocationIndex ||
  stateBefore.route.preferredModel !== modelRoute.preferredModel ||
  stateBefore.route.hostReasoning !== modelRoute.hostReasoning
);

const routeChanged = routeHasMeaningfulChange && (
  stateBefore.route.workUnitId === workUnitId
    ? (stateBefore.route.invocationIndex !== modelRoute.invocationIndex || stateBefore.route.preferredModel !== modelRoute.preferredModel || stateBefore.route.hostReasoning !== modelRoute.hostReasoning)
    : true
);

updateTurnState(sessionId, turnId, (state) => {
  assertTurnOwner(state, sessionId);
  if (state.promptSha256 !== stateBefore.promptSha256) throw new Error('UEEF turn state changed while resolving the model route.');
  const previous = state.route;
  state.route = {
    tier,
    workUnitId,
    invocationIndex: modelRoute.invocationIndex,
    intent,
    agentRoute,
    browserReason,
    preferredModel: modelRoute.preferredModel,
    displayReasoning: effectiveReasoning,
    hostReasoning: modelRoute.hostReasoning,
    fallbackModel: modelRoute.fallbackModel || null,
    fallbackHostReasoning: modelRoute.fallbackHostReasoning || null,
    catalogDigest: modelRoute.catalogDigest,
    specialistPurpose: modelRoute.specialistPurpose || null,
    tokenEconomy: modelRoute.tokenEconomy,
    decision,
    eligibleSelectionPool: modelRoute.eligibleSelectionPool || [],
    distributionIndex: modelRoute.distributionIndex,
    catalogProvider: modelRoute.catalogProvider,
    catalogDiscoveredAt: modelRoute.catalogDiscoveredAt,
    routeDigest,
    routeOutput: managedRouteOutput,
    routeRevision,
    routeChanged,
    invocationCommitted: false,
    modelRouteVerified: true,
    recordedAtUtc: new Date().toISOString()
  };
  state.executionSpec = executionSpec;
  state.validations.executionSpec = true;
  state.validations.modelDispatch = false;
  delete state.dispatchReservation;
});

const routeLine = routeChanged
  ? `Model route changed: ${workUnitId} | ${previousModel || '(none)'} / ${previousHostReasoning || 'n/a'} -> ${modelRoute.preferredModel} / ${effectiveReasoning} (host: ${modelRoute.hostReasoning})`
  : `Model route: ${workUnitId} | ${modelRoute.preferredModel} / ${effectiveReasoning} (host: ${modelRoute.hostReasoning})`;

{
  fs.mkdirSync(path.dirname(managedRouteOutput), { recursive: true });
  fs.writeFileSync(managedRouteOutput, `${JSON.stringify({
    ...modelRoute,
    workUnitId,
    routeDigest,
    routeRevision,
    routeChanged,
    routeLine,
    decision,
    executionSpec
  }, null, 2)}\n`, { flag: routeOutput ? 'wx' : 'w' });
}

updateTurnState(sessionId, turnId, (state) => {
  if (state.route?.routeDigest === routeDigest) state.route.routeLine = routeLine;
});

process.stdout.write(`${JSON.stringify({
  status: 'PASS',
  tier,
  workUnitId,
  invocationIndex: modelRoute.invocationIndex,
  effortRotation: modelRoute.effortRotation,
  routeRevision,
  routeChanged,
  routeLine,
  decision,
  preferredModel: modelRoute.preferredModel,
  displayReasoning: effectiveReasoning,
  hostReasoning: modelRoute.hostReasoning,
  catalogProvider: modelRoute.catalogProvider,
  catalogDiscoveredAt: modelRoute.catalogDiscoveredAt,
  catalogModelCount: modelRoute.catalogModelCount,
  generalModelCount: modelRoute.generalModelCount,
  eligibleSelectionPool: modelRoute.eligibleSelectionPool,
  distributionIndex: modelRoute.distributionIndex,
  specialistPurpose: modelRoute.specialistPurpose,
  tokenEconomy: modelRoute.tokenEconomy,
  executionSpec,
  routeDigest,
  routeOutput: managedRouteOutput
})}\n`);
