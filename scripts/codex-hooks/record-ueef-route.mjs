import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { hookRoot, peekWorkUnitInvocation, readTurnState, safeId, sha256Text, stateRoot, updateTurnState } from './ueef-hook-common.mjs';

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
if (has('--use-current-model') && stateBefore.authorizations?.useCurrentModel !== true) throw new Error('Current-model constraint was not explicitly authorized by the current prompt.');
if (has('--allow-model-constraint-override') && stateBefore.authorizations?.allowModelConstraintOverride !== true) throw new Error('Model-constraint override was not explicitly authorized by the current prompt.');
if (has('--allow-exceed') && stateBefore.authorizations?.allowAboveHigh !== true) throw new Error('Above-high reasoning was not explicitly authorized by the current prompt.');

const localResolver = path.join(hookRoot, 'resolve-model-route.mjs');
const resolver = fs.existsSync(localResolver) ? localResolver : path.join(hookRoot, '..', 'resolve-model-route.mjs');
const localPolicy = path.join(hookRoot, 'model-routing-policy.json');
const policy = fs.existsSync(localPolicy) ? localPolicy : path.join(hookRoot, '..', '..', 'config', 'model-routing-policy.json');
const invocationIndex = peekWorkUnitInvocation(sessionId, workUnitId);
const resolverArgs = [resolver, '--tier', tier, '--policy', policy];
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

const modelRoute = JSON.parse(execFileSync(process.execPath, resolverArgs, { encoding: 'utf8', timeout: 20_000 }));
const effectiveReasoning = modelRoute.displayReasoning || modelRoute.hostReasoning || modelRoute.reasoning || null;
const testRoute = modelRoute.testCatalogAllowed === true && has('--allow-test-catalog');
if ((!testRoute && (modelRoute.accountCatalogVerified !== true || modelRoute.catalogFresh !== true || modelRoute.catalogContractValid !== true)) || !modelRoute.preferredModel || !modelRoute.hostReasoning) {
  throw new Error(`Model route is unresolved or not backed by a fresh validated host catalog: ${modelRoute.modelAvailability}`);
}
const routeDigest = sha256Text(JSON.stringify({
  tier,
  workUnitId,
  invocationIndex: modelRoute.invocationIndex,
  preferredModel: modelRoute.preferredModel,
  hostReasoning: modelRoute.hostReasoning,
  fallbackModel: modelRoute.fallbackModel || null,
  fallbackHostReasoning: modelRoute.fallbackHostReasoning || null,
  tokenEconomy: modelRoute.tokenEconomy,
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
