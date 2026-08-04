import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const scripts = path.dirname(fileURLToPath(import.meta.url));
const resolver = path.join(scripts, 'resolve-model-route.mjs');
const recorder = path.join(scripts, 'record-model-route-result.mjs');
const catalog = path.join(scripts, 'fixtures', 'model-catalog.json');
const fixtureEnvelope = JSON.parse(fs.readFileSync(catalog, 'utf8'));
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'ueef-model-routing-'));
const resolve = (...args) => JSON.parse(execFileSync(process.execPath, [resolver, '--catalog', catalog, '--allow-test-catalog', ...args], { encoding: 'utf8' }));

const t0 = resolve('--tier', 'T0');
assert.equal(t0.preferredModel, 'gpt-5.6-luna');
assert.equal(t0.reasoning, 'low');
assert.equal(t0.displayReasoning, 'low');
assert.equal(t0.hostReasoning, 'low');
assert.equal(t0.modelAvailability, 'TEST_CATALOG_ONLY');
assert.equal(t0.accountCatalogVerified, false);
assert.equal(t0.testCatalogAllowed, true);
assert.equal(t0.fallbackModel, 'gpt-5.4-mini');
assert.equal(t0.catalogModelCount, fixtureEnvelope.data.length);
assert.equal(t0.catalogCoverage.length, fixtureEnvelope.data.length);
assert.equal(t0.catalogCoverage.find((entry) => entry.model === 'codex-auto-review').eligibility, 'HOST_HIDDEN_SPECIALIZED');
assert.equal(t0.catalogCoverage.find((entry) => entry.model === 'gpt-5.3-codex-spark').supportedReasoningEfforts.join(','), 'low,medium,high,xhigh');
assert.equal(resolve('--tier', 'T0').preferredModel, 'gpt-5.6-luna');
assert.equal(resolve('--tier', 'T1').preferredModel, 'gpt-5.6-luna');
assert.equal(resolve('--tier', 'T1').reasoning, 'low');
assert.equal(resolve('--tier', 'T2').preferredModel, 'gpt-5.6-terra');
assert.equal(resolve('--tier', 'T2').reasoning, 'low');
assert.equal(resolve('--tier', 'T3').preferredModel, 'gpt-5.6-sol');
assert.equal(resolve('--tier', 'T3').reasoning, 'low');
assert.equal(resolve('--tier', 'T4').preferredModel, 'gpt-5.6-sol');
assert.equal(resolve('--tier', 'T4').reasoning, 'medium');
assert.equal(resolve('--tier', 'T4').fallbackModel, 'gpt-5.5');
assert.equal(resolve('--tier', 'T4').fallbackReasoning, 'medium');
for (const routeTier of ['T0', 'T1', 'T2', 'T3']) {
  const cycle = [0, 1, 2, 3].map((invocationIndex) => resolve('--tier', routeTier, '--work-unit-id', `same-work-unit-${routeTier}`, '--invocation-index', String(invocationIndex)));
  assert.deepEqual(cycle.map((route) => route.hostReasoning), ['low', 'medium', 'high', 'low'], `${routeTier} did not rotate low -> medium -> high -> low for the same work unit`);
  assert.deepEqual(cycle.map((route) => route.invocationIndex), [0, 1, 2, 3]);
  assert.equal(cycle.every((route) => route.effortRotation === 'INVOCATION_CYCLE'), true);
  assert.notEqual(cycle[0].routeDigest, cycle[1].routeDigest, `${routeTier} route digest did not bind invocation index`);
}
const t4Cycle = [0, 1, 2, 3].map((invocationIndex) => resolve('--tier', 'T4', '--work-unit-id', 'same-work-unit-T4', '--invocation-index', String(invocationIndex)));
assert.deepEqual(t4Cycle.map((route) => route.hostReasoning), ['medium', 'high', 'medium', 'high']);
assert.equal(t4Cycle.every((route) => route.effortRotation === 'INVOCATION_CYCLE'), true);
assert.notEqual(t4Cycle[0].routeDigest, t4Cycle[1].routeDigest, 'T4 route digest did not bind invocation index');
const incompleteT4Catalog = path.join(temp, 'incomplete-t4-catalog.json');
fs.writeFileSync(incompleteT4Catalog, JSON.stringify({ schemaVersion: 1, provenance: { provider: 'test-fixture' }, data: [{ id: 'incomplete-frontier', description: 'Latest frontier', supportedReasoningEfforts: [{ reasoningEffort: 'low' }, { reasoningEffort: 'high' }] }] }));
const incompleteT4 = JSON.parse(execFileSync(process.execPath, [resolver, '--catalog', incompleteT4Catalog, '--allow-test-catalog', '--tier', 'T4'], { encoding: 'utf8' }));
assert.equal(incompleteT4.preferredModel, null, 'T4 must fail closed when a model lacks medium/high cycle support');
for (const routeTier of ['T0', 'T1', 'T2', 'T3', 'T4']) {
  const route = resolve('--tier', routeTier);
  const selectedModel = fixtureEnvelope?.data?.find?.((model) => (model.model || model.id) === route.preferredModel);
  const supported = (selectedModel?.supportedReasoningEfforts || []).map((entry) => entry.reasoningEffort || entry);
  assert.equal(supported.includes(route.hostReasoning), true, `${route.preferredModel}/${route.hostReasoning} is not a host-supported pair`);
}
for (const [routeTier, capability] of [['T0', 'fast'], ['T2', 'balanced'], ['T3', 'frontier']]) {
  const expected = fixtureEnvelope.data.filter((model) => model.hidden !== true && resolve('--tier', routeTier).catalogCoverage.find((entry) => entry.model === (model.model || model.id))?.capabilityClass === capability).map((model) => model.model || model.id).sort();
  const observed = new Set();
  for (let index = 0; index < 64 && observed.size < expected.length; index += 1) {
    observed.add(resolve('--tier', routeTier, '--work-unit-id', `coverage-${routeTier}-${index}`).preferredModel);
  }
  assert.deepEqual([...observed].sort(), expected, `${routeTier} did not distribute work across every eligible ${capability} model`);
}
const specialist = resolve('--tier', 'T4', '--work-unit-id', 'approval-review-1', '--specialist-purpose', 'approval-review');
assert.equal(specialist.preferredModel, 'codex-auto-review');
assert.deepEqual(specialist.eligibleSelectionPool, ['codex-auto-review']);
assert.equal(specialist.catalogCoverage.find((entry) => entry.model === 'codex-auto-review').eligibility, 'MATCHING_SPECIALIST_PURPOSE');
const hiddenCurrent = resolve('--tier', 'T4', '--work-unit-id', 'hidden-current', '--use-current-model', '--current-model', 'codex-auto-review');
assert.equal(hiddenCurrent.preferredModel, null);
assert.equal(hiddenCurrent.catalogCoverage.find((entry) => entry.model === 'codex-auto-review').eligibility, 'HOST_HIDDEN_SPECIALIZED');
assert.equal(resolve('--tier', 'T2', '--use-current-model', '--current-model', 'gpt-5.6-luna').preferredModel, 'gpt-5.6-luna');
const constrained = resolve('--tier', 'T4', '--use-current-model', '--current-model', 'gpt-5.6-luna', '--reasoning-override', 'xhigh', '--allow-exceed');
assert.equal(constrained.preferredModel, null);
assert.equal(constrained.currentModelConstraintApplied, true);
assert.equal(constrained.currentModelConstraintOverridden, false);
const explicitlyOverridden = resolve('--tier', 'T4', '--use-current-model', '--current-model', 'gpt-5.6-luna', '--reasoning-override', 'xhigh', '--allow-exceed', '--allow-model-constraint-override');
assert.equal(explicitlyOverridden.preferredModel, 'gpt-5.6-sol');
assert.equal(explicitlyOverridden.reasoning, 'xhigh');
assert.equal(explicitlyOverridden.currentModelConstraintOverridden, true);
assert.equal(resolve('--tier', 'T4', '--reasoning-override', 'xhigh').preferredModel, null);
assert.equal(resolve('--tier', 'T4', '--reasoning-override', 'xhigh', '--allow-exceed').reasoning, 'xhigh');
assert.throws(() => execFileSync(process.execPath, [resolver, '--catalog', catalog, '--allow-test-catalog', '--tier', 'T2', '--use-current-model'], { stdio: 'pipe' }));
assert.throws(() => execFileSync(process.execPath, [resolver, '--catalog', catalog, '--allow-test-catalog', '--tier', 'T2', '--allow-model-constraint-override'], { stdio: 'pipe' }));

const changingCatalog = path.join(temp, 'changing-catalog.json');
const addedModel = { id: 'aaa-new-frontier', model: 'aaa-new-frontier', displayName: 'New', description: 'Latest frontier model supplied by the host', supportedReasoningEfforts: [{ reasoningEffort: 'low' }, { reasoningEffort: 'medium' }, { reasoningEffort: 'high' }] };
fs.writeFileSync(changingCatalog, JSON.stringify({ ...fixtureEnvelope, data: [addedModel, ...fixtureEnvelope.data] }));
const resolveChanging = (...args) => JSON.parse(execFileSync(process.execPath, [resolver, '--catalog', changingCatalog, '--allow-test-catalog', ...args], { encoding: 'utf8' }));
const routeWithAddedModel = resolveChanging('--tier', 'T4');
assert.equal(routeWithAddedModel.preferredModel, 'aaa-new-frontier');
assert.equal(routeWithAddedModel.catalogCoverage.some((entry) => entry.model === 'aaa-new-frontier' && entry.capabilityClass === 'frontier'), true);
fs.writeFileSync(changingCatalog, JSON.stringify(fixtureEnvelope));
assert.equal(resolveChanging('--tier', 'T4').preferredModel, 'gpt-5.6-sol');
const metadataFrontier = { id: 'metadata-frontier', model: 'metadata-frontier', displayName: 'Metadata Frontier', description: 'Model family add-on', capability: 'frontier', supportedReasoningEfforts: [{ reasoningEffort: 'low' }, { reasoningEffort: 'medium' }, { reasoningEffort: 'high' }, { reasoningEffort: 'xhigh' }] };
fs.writeFileSync(changingCatalog, JSON.stringify({ ...fixtureEnvelope, data: [metadataFrontier, ...fixtureEnvelope.data] }));
const metadataRoute = resolveChanging('--tier', 'T4');
assert.equal(metadataRoute.preferredModel, 'gpt-5.6-sol');
assert.equal(metadataRoute.catalogCoverage.find((entry) => entry.model === 'metadata-frontier').capabilityClass, 'frontier');
const metadataT3 = resolveChanging('--tier', 'T3');
assert.equal(metadataT3.reasoning, 'low');
assert.equal(metadataT3.eligibleSelectionPool.includes('metadata-frontier'), true);
fs.writeFileSync(changingCatalog, JSON.stringify(fixtureEnvelope));

const hostNamedEffort = path.join(temp, 'host-named-effort.json');
fs.writeFileSync(hostNamedEffort, JSON.stringify({ schemaVersion: 1, provenance: { provider: 'test-fixture' }, data: [{ id: 'dynamic-fast', description: 'Fast', supportedReasoningEfforts: [{ reasoningEffort: 'eco', displayName: 'Eco' }, { reasoningEffort: 'high', displayName: 'High' }] }] }));
const named = JSON.parse(execFileSync(process.execPath, [resolver, '--catalog', hostNamedEffort, '--allow-test-catalog', '--tier', 'T0'], { encoding: 'utf8' }));
assert.equal(named.reasoning, 'eco');
assert.equal(named.displayReasoning, 'Eco');

const noCeilingCatalog = path.join(temp, 'no-ceiling.json');
fs.writeFileSync(noCeilingCatalog, JSON.stringify({ schemaVersion: 1, provenance: { provider: 'test-fixture' }, data: [{ id: 'unknown-order', description: 'Frontier', supportedReasoningEfforts: [{ reasoningEffort: 'mystery' }] }] }));
const noCeiling = JSON.parse(execFileSync(process.execPath, [resolver, '--catalog', noCeilingCatalog, '--allow-test-catalog', '--tier', 'T4'], { encoding: 'utf8' }));
assert.equal(noCeiling.preferredModel, null);

const modelSpecificOrderCatalog = path.join(temp, 'model-specific-effort-order.json');
fs.writeFileSync(modelSpecificOrderCatalog, JSON.stringify({ schemaVersion: 1, provenance: { provider: 'test-fixture' }, data: [
  { id: 'fast-a', description: 'Fast', supportedReasoningEfforts: [{ reasoningEffort: 'low' }, { reasoningEffort: 'xhigh' }, { reasoningEffort: 'high' }] },
  { id: 'frontier-b', description: 'Latest frontier', supportedReasoningEfforts: [{ reasoningEffort: 'low' }, { reasoningEffort: 'medium' }, { reasoningEffort: 'high' }, { reasoningEffort: 'xhigh' }] }
] }));
const modelSpecificOrder = JSON.parse(execFileSync(process.execPath, [resolver, '--catalog', modelSpecificOrderCatalog, '--allow-test-catalog', '--tier', 'T4'], { encoding: 'utf8' }));
assert.equal(modelSpecificOrder.preferredModel, 'frontier-b');
assert.equal(modelSpecificOrder.hostReasoning, 'medium');

const productionPolicy = fs.readFileSync(path.join(scripts, '..', 'config', 'model-routing-policy.json'), 'utf8');
const productionResolver = fs.readFileSync(resolver, 'utf8');
assert.equal(/gpt-[0-9]/.test(productionPolicy), false);
assert.equal(/gpt-[0-9]/.test(productionResolver), false);
assert.equal(JSON.parse(productionPolicy).models, undefined);
const unproven = path.join(temp, 'unproven.json');
fs.writeFileSync(unproven, JSON.stringify({ data: JSON.parse(fs.readFileSync(catalog, 'utf8')).data }));
const unprovenRoute = JSON.parse(execFileSync(process.execPath, [resolver, '--catalog', unproven, '--tier', 'T0'], { encoding: 'utf8' }));
assert.equal(unprovenRoute.modelAvailability, 'CATALOG_EXTERNAL_INPUT_REJECTED');
assert.equal(unprovenRoute.preferredModel, null);
const liveCatalog = path.join(temp, 'live-catalog.json');
fs.writeFileSync(liveCatalog, JSON.stringify({ schemaVersion: 1, discoveredAt: new Date().toISOString(), provenance: { provider: 'host-orchestration-tool', tool: 'codex_app__send_message_to_thread' }, data: fixtureEnvelope.data }));
const liveResolved = JSON.parse(execFileSync(process.execPath, [resolver, '--catalog', liveCatalog, '--tier', 'T0'], { encoding: 'utf8' }));
assert.equal(liveResolved.accountCatalogVerified, false);
assert.equal(liveResolved.catalogFresh, true);
assert.equal(liveResolved.catalogContractValid, true);
assert.equal(liveResolved.modelAvailability, 'CATALOG_EXTERNAL_INPUT_REJECTED');
const staleCatalog = path.join(temp, 'stale-catalog.json');
fs.writeFileSync(staleCatalog, JSON.stringify({ schemaVersion: 1, discoveredAt: '2020-01-01T00:00:00.000Z', provenance: { provider: 'host-orchestration-tool', tool: 'codex_app__send_message_to_thread' }, data: fixtureEnvelope.data }));
const staleResolved = JSON.parse(execFileSync(process.execPath, [resolver, '--catalog', staleCatalog, '--tier', 'T0'], { encoding: 'utf8' }));
assert.equal(staleResolved.accountCatalogVerified, false);
assert.equal(staleResolved.preferredModel, null);
const liveRoute = path.join(temp, 'live-route.json');
const dispatch = path.join(temp, 'dispatch.json');
const completion = path.join(temp, 'completion.json');
const receipt = path.join(temp, 'receipt.json');
// Receipt behavior below is explicitly fixture-only.  Production account
// verification is exercised only through direct App Server discovery.
const testResolved = resolve('--tier', 'T0', '--work-unit-id', 'receipt-fixture');
fs.writeFileSync(liveRoute, JSON.stringify(testResolved));
fs.writeFileSync(dispatch, JSON.stringify({ threadId: 'host-thread-test', hostId: 'local' }));
fs.writeFileSync(completion, JSON.stringify({ provider: 'codex-app:read-thread', threadId: 'host-thread-test', turnId: 'turn-success', observedAt: new Date().toISOString(), actualModel: testResolved.preferredModel, actualHostReasoning: testResolved.hostReasoning, result: 'SUCCESS' }));
execFileSync(process.execPath, [recorder, '--allow-test-route', '--route', liveRoute, '--dispatch-result', dispatch, '--completion-result', completion, '--output', receipt]);
const recorded = JSON.parse(fs.readFileSync(receipt, 'utf8'));
assert.equal(recorded.hostDispatch.threadId, 'host-thread-test');
assert.equal(recorded.actual.displayReasoning, 'low');
assert.equal(recorded.route.currentModelConstraintApplied, false);
const invalidCompletion = path.join(temp, 'invalid-completion.json');
fs.writeFileSync(invalidCompletion, JSON.stringify({ provider: 'codex-app:read-thread', threadId: 'host-thread-test', turnId: 'turn-invalid', observedAt: new Date().toISOString(), actualModel: 'not-in-route', actualHostReasoning: 'low', result: 'SUCCESS' }));
assert.throws(() => execFileSync(process.execPath, [recorder, '--allow-test-route', '--route', liveRoute, '--dispatch-result', dispatch, '--completion-result', invalidCompletion, '--output', path.join(temp, 'invalid-receipt.json')], { stdio: 'pipe' }));
const fallbackCompletion = path.join(temp, 'fallback-completion.json');
fs.writeFileSync(fallbackCompletion, JSON.stringify({ provider: 'codex-app:read-thread', threadId: 'host-thread-test', turnId: 'turn-fallback', observedAt: new Date().toISOString(), actualModel: testResolved.fallbackModel, actualHostReasoning: testResolved.fallbackHostReasoning, result: 'SUCCESS' }));
assert.throws(() => execFileSync(process.execPath, [recorder, '--allow-test-route', '--route', liveRoute, '--dispatch-result', dispatch, '--completion-result', fallbackCompletion, '--output', path.join(temp, 'fallback-without-capacity.json')], { stdio: 'pipe' }));
const capacityDispatch = path.join(temp, 'capacity-dispatch.json');
const capacityReceipt = path.join(temp, 'capacity-receipt.json');
fs.writeFileSync(capacityDispatch, JSON.stringify({ status: 'CAPACITY', routeDigest: testResolved.routeDigest, attemptId: 'attempt-1', attemptedModel: testResolved.preferredModel, attemptedHostReasoning: testResolved.hostReasoning, errorMessage: 'Selected model is at capacity' }));
execFileSync(process.execPath, [recorder, '--allow-test-route', '--route', liveRoute, '--dispatch-result', capacityDispatch, '--output', capacityReceipt]);
const fallbackReceipt = path.join(temp, 'fallback-receipt.json');
execFileSync(process.execPath, [recorder, '--allow-test-route', '--route', liveRoute, '--dispatch-result', dispatch, '--completion-result', fallbackCompletion, '--primary-capacity-receipt', capacityReceipt, '--output', fallbackReceipt]);
assert.equal(JSON.parse(fs.readFileSync(fallbackReceipt, 'utf8')).actual.model, testResolved.fallbackModel);
const tamperedFallbackRoute = path.join(temp, 'tampered-fallback-route.json');
fs.writeFileSync(tamperedFallbackRoute, JSON.stringify({ ...testResolved, fallbackModel: 'tampered-fallback' }));
assert.throws(() => execFileSync(process.execPath, [recorder, '--allow-test-route', '--route', tamperedFallbackRoute, '--dispatch-result', dispatch, '--completion-result', completion, '--output', path.join(temp, 'tampered-fallback-receipt.json')], { stdio: 'pipe' }));
const aggregateDispatch = path.join(temp, 'aggregate-fallback-dispatch.json');
const aggregateReceipt = path.join(temp, 'aggregate-fallback-receipt.json');
fs.writeFileSync(aggregateDispatch, JSON.stringify({
  provider: 'codex-app-server:turn/start', routeDigest: testResolved.routeDigest, threadId: 'fallback-thread', turnId: 'fallback-turn',
  actualModel: testResolved.fallbackModel, actualHostReasoning: testResolved.fallbackHostReasoning, result: 'SUCCESS', executionVerified: true,
  executionVerificationSource: 'codex-app-server:thread/start+thread/settings/updated+model/rerouted', providerModelFallbackAllowed: false,
  capacityFallbackUsed: true, attempts: [
    { attemptIndex: 0, requestId: 1, model: testResolved.preferredModel, hostReasoning: testResolved.hostReasoning, result: 'CAPACITY' },
    { attemptIndex: 1, requestId: 3, model: testResolved.fallbackModel, hostReasoning: testResolved.fallbackHostReasoning, result: 'SUCCESS' }
  ]
}));
execFileSync(process.execPath, [recorder, '--allow-test-route', '--route', liveRoute, '--dispatch-result', aggregateDispatch, '--output', aggregateReceipt]);
assert.equal(JSON.parse(fs.readFileSync(aggregateReceipt, 'utf8')).actual.model, testResolved.fallbackModel);
const missingDigestDispatch = path.join(temp, 'aggregate-missing-digest.json');
fs.writeFileSync(missingDigestDispatch, JSON.stringify({ ...JSON.parse(fs.readFileSync(aggregateDispatch, 'utf8')), routeDigest: undefined }));
assert.throws(() => execFileSync(process.execPath, [recorder, '--allow-test-route', '--route', liveRoute, '--dispatch-result', missingDigestDispatch, '--output', path.join(temp, 'aggregate-missing-digest-receipt.json')], { stdio: 'pipe' }));
const missing = JSON.parse(execFileSync(process.execPath, [resolver, '--tier', 'T1', '--no-discover'], { encoding: 'utf8' }));
assert.equal(missing.modelAvailability, 'CATALOG_REQUIRED');
const unavailable = JSON.parse(execFileSync(process.execPath, [resolver, '--tier', 'T4', '--models-unavailable'], { encoding: 'utf8' }));
assert.equal(unavailable.modelAvailability, 'UNAVAILABLE_BY_CALLER');
console.log('Dynamic model routing policy tests passed');
