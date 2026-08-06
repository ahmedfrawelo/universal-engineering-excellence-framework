import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
const valueAfter = (flag) => { const i = args.indexOf(flag); return i === -1 ? null : args[i + 1] || null; };
const routePath = valueAfter('--route');
const dispatchPath = valueAfter('--dispatch-result');
const completionPath = valueAfter('--completion-result');
const outputPath = valueAfter('--output');
const primaryCapacityReceiptPath = valueAfter('--primary-capacity-receipt');
const allowTestRoute = args.includes('--allow-test-route');
if (!routePath || !dispatchPath || !outputPath) throw new Error('Provide --route, --dispatch-result, and --output.');

const readJson = (file) => JSON.parse(fs.readFileSync(file, 'utf8'));
const sha256File = (file) => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const sha256Object = (value) => crypto.createHash('sha256').update(JSON.stringify(value), 'utf8').digest('hex');
const route = readJson(routePath);
const catalogIdentity = (route.catalogCoverage || []).map((entry) => ({
  model: entry.model,
  hidden: entry.hidden,
  capabilityClass: entry.capabilityClass,
  supportedReasoningEfforts: entry.supportedReasoningEfforts,
  defaultReasoningEffort: entry.defaultReasoningEffort,
  upgrade: entry.upgrade
}));
const computedCatalogDigest = sha256Object(catalogIdentity);
if (!route.catalogDigest || route.catalogDigest !== computedCatalogDigest) throw new Error('Route catalog digest does not match canonical catalog coverage.');
const routeDisplayReasoning = route.displayReasoning || route.hostReasoning;
const dispatch = readJson(dispatchPath);
const trustedLiveRoute = route.accountCatalogVerified === true && route.catalogFresh === true && route.catalogContractValid === true;
const explicitTestRoute = allowTestRoute && route.testCatalogAllowed === true;
if ((!trustedLiveRoute && !explicitTestRoute) || !route.preferredModel || !route.hostReasoning) {
  throw new Error('A model execution receipt requires a fresh, contract-validated, account-verified live route.');
}

const routeIdentity = {
  tier: route.tier,
  invocationIndex: route.invocationIndex ?? 0,
  preferredModel: route.preferredModel,
  hostReasoning: route.hostReasoning,
  fallbackModel: route.fallbackModel || null,
  fallbackHostReasoning: route.fallbackHostReasoning || null,
  tokenEconomy: route.tokenEconomy || null,
  catalogDigest: route.catalogDigest || null,
  catalogProvider: route.catalogProvider,
  catalogDiscoveredAt: route.catalogDiscoveredAt
};
const computedRouteDigest = sha256Object({
  tier: route.tier,
  workUnitId: route.workUnitId || null,
  invocationIndex: route.invocationIndex ?? 0,
  preferredModel: route.preferredModel,
  hostReasoning: route.hostReasoning,
  fallbackModel: route.fallbackModel || null,
  fallbackHostReasoning: route.fallbackHostReasoning || null,
  tokenEconomy: route.tokenEconomy || null,
  catalogDigest: route.catalogDigest || null,
  catalogProvider: route.catalogProvider,
  catalogDiscoveredAt: route.catalogDiscoveredAt
});
const routeDigest = route.routeDigest || computedRouteDigest;
if (route.routeDigest && route.routeDigest !== computedRouteDigest) throw new Error('Managed route digest does not bind the complete primary and fallback route identity.');
const directAppServerReceipt = dispatch.provider === 'codex-app-server:turn/start';
const capacity = dispatch.result === 'CAPACITY' || dispatch.status === 'CAPACITY' || dispatch.errorCode === 'MODEL_CAPACITY';
if ((directAppServerReceipt || capacity) && !dispatch.routeDigest) throw new Error('Direct App Server and capacity evidence require the managed route digest.');
if (dispatch.routeDigest && dispatch.routeDigest !== routeDigest) throw new Error('Dispatch result does not match the managed route digest.');
let model;
let effort;
let result;
let completion = null;

if (capacity) {
  const attemptId = dispatch.attemptId || dispatch.requestId || dispatch.turnId;
  const errorMessage = String(dispatch.errorMessage || dispatch.message || '');
  if (!attemptId || !errorMessage.includes('Selected model is at capacity')) throw new Error('CAPACITY evidence requires a host attempt/request/turn id and the exact provider capacity signal.');
  model = dispatch.attemptedModel || dispatch.requestedModel || route.preferredModel;
  effort = dispatch.attemptedHostReasoning || dispatch.requestedHostReasoning || route.hostReasoning;
  result = 'CAPACITY';
  if (model !== route.preferredModel || effort !== route.hostReasoning) throw new Error('Capacity evidence must identify the selected primary model and effort.');
} else {
  if (!dispatch.threadId || typeof dispatch.threadId !== 'string') throw new Error('Non-capacity dispatch evidence requires the host threadId.');
  if (directAppServerReceipt) {
    if (dispatch.executionVerified !== true || dispatch.executionVerificationSource !== 'codex-app-server:thread/start+thread/settings/updated+model/rerouted' || dispatch.providerModelFallbackAllowed !== false || !dispatch.turnId) {
      throw new Error('Direct App Server evidence requires verified thread/start plus reroute tracking, a turn id, and disabled provider fallback.');
    }
    model = dispatch.actualModel;
    effort = dispatch.actualHostReasoning;
    result = dispatch.result;
  } else {
    if (!completionPath) throw new Error('Legacy host dispatch evidence requires --completion-result from Codex read_thread evidence.');
    completion = readJson(completionPath);
    if (completion.provider !== 'codex-app:read-thread' || completion.threadId !== dispatch.threadId || !completion.turnId) throw new Error('Completion evidence must be a matching Codex read_thread observation with threadId and turnId.');
    const observedAtMs = Date.parse(completion.observedAt || '');
    if (!Number.isFinite(observedAtMs) || Math.abs(Date.now() - observedAtMs) > 24 * 60 * 60 * 1000) throw new Error('Completion evidence requires a current observedAt timestamp.');
    model = completion.actualModel;
    effort = completion.actualHostReasoning;
    result = completion.result;
  }
  if (!['SUCCESS', 'UNSUPPORTED', 'FAILED'].includes(result)) throw new Error('Completion result must be SUCCESS, UNSUPPORTED, or FAILED.');
}

const permitted = new Map([[route.preferredModel, route.hostReasoning]]);
if (route.fallbackModel && route.fallbackHostReasoning) permitted.set(route.fallbackModel, route.fallbackHostReasoning);
if (permitted.get(model) !== effort) throw new Error('Observed host result does not match the selected route or its single declared fallback.');

let primaryCapacityReceipt = null;
if (model === route.fallbackModel && result === 'SUCCESS') {
  const aggregatedAttempts = Array.isArray(dispatch.attempts) ? dispatch.attempts : [];
  const aggregateProvesPrimaryCapacity = directAppServerReceipt && dispatch.capacityFallbackUsed === true &&
    aggregatedAttempts.some((attempt) => attempt.attemptIndex === 0 && attempt.model === route.preferredModel && attempt.hostReasoning === route.hostReasoning && attempt.result === 'CAPACITY') &&
    aggregatedAttempts.some((attempt) => attempt.attemptIndex === 1 && attempt.model === route.fallbackModel && attempt.hostReasoning === route.fallbackHostReasoning && attempt.result === 'SUCCESS');
  if (!aggregateProvesPrimaryCapacity) {
    if (!primaryCapacityReceiptPath) throw new Error('Fallback SUCCESS requires an aggregate App Server capacity attempt or --primary-capacity-receipt for the selected primary model.');
    primaryCapacityReceipt = readJson(primaryCapacityReceiptPath);
    const matchesPrimary = primaryCapacityReceipt?.actual?.model === route.preferredModel && primaryCapacityReceipt?.actual?.hostReasoning === route.hostReasoning && primaryCapacityReceipt?.actual?.result === 'CAPACITY';
    if (!matchesPrimary || primaryCapacityReceipt?.routeDigest !== routeDigest) throw new Error('Fallback SUCCESS requires a matching primary CAPACITY receipt for the exact route.');
  }
}

const receipt = {
  schemaVersion: 2,
  receiptKind: 'model-route-execution',
  route: {
    ...routeIdentity,
    displayReasoning: routeDisplayReasoning,
    fallbackDisplayReasoning: route.fallbackDisplayReasoning || route.fallbackHostReasoning || null,
    reasoningCeiling: route.reasoningCeiling || null,
    aboveCeilingAuthorized: route.aboveCeilingAuthorized === true,
    requestedCurrentModel: route.requestedCurrentModel || null,
    currentModelConstraintApplied: route.currentModelConstraintApplied === true,
    currentModelConstraintOverridden: route.currentModelConstraintOverridden === true
  },
  routeDigest,
  hostDispatch: {
    threadId: dispatch.threadId || null,
    hostId: dispatch.hostId || null,
    attemptId: dispatch.attemptId || dispatch.requestId || dispatch.turnId || null
  },
  hostCompletion: completion ? { provider: completion.provider, turnId: completion.turnId, observedAt: completion.observedAt } : null,
  actual: {
    model,
    displayReasoning: model === route.preferredModel
      ? (routeDisplayReasoning || effort)
      : (route.fallbackDisplayReasoning || route.fallbackHostReasoning || effort),
    hostReasoning: effort,
    result
  },
  primaryCapacityReceipt: primaryCapacityReceiptPath ? { path: primaryCapacityReceiptPath, sha256: sha256File(primaryCapacityReceiptPath) } : null,
  observedAt: new Date().toISOString()
};
fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, `${JSON.stringify(receipt, null, 2)}\n`, { flag: 'wx' });
process.stdout.write(`${JSON.stringify({ receiptPath: outputPath, routeDigest, threadId: dispatch.threadId || null, attemptId: dispatch.attemptId || dispatch.requestId || dispatch.turnId || null, model, hostReasoning: effort, result })}\n`);
