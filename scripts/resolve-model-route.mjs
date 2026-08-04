import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const args = process.argv.slice(2);
const valueAfter = (flag) => {
  const index = args.indexOf(flag);
  return index === -1 ? null : args[index + 1] || null;
};
const has = (flag) => args.includes(flag);
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(here, '..');
const tier = valueAfter('--tier');
const policyPath = valueAfter('--policy') || path.join(root, 'config', 'model-routing-policy.json');
const catalogPath = valueAfter('--catalog');
const requestedEffort = valueAfter('--reasoning-override');
const currentModel = valueAfter('--current-model');
const outputPath = valueAfter('--output');
const workUnitId = valueAfter('--work-unit-id');
const specialistPurpose = valueAfter('--specialist-purpose');
const invocationIndexRaw = valueAfter('--invocation-index');
const invocationIndex = invocationIndexRaw == null ? 0 : Number(invocationIndexRaw);
const useCurrentModel = has('--use-current-model');
const allowModelConstraintOverride = has('--allow-model-constraint-override');
const allowExceed = has('--allow-exceed');

const emit = (value) => {
  const serialized = `${JSON.stringify(value, null, outputPath ? 2 : 0)}\n`;
  if (outputPath) {
    fs.mkdirSync(path.dirname(path.resolve(outputPath)), { recursive: true });
    fs.writeFileSync(outputPath, serialized, { flag: has('--force-output') ? 'w' : 'wx' });
  }
  process.stdout.write(serialized);
};

if (!['T0', 'T1', 'T2', 'T3', 'T4'].includes(tier)) throw new Error('resolve-model-route requires --tier T0|T1|T2|T3|T4.');
if (useCurrentModel && !currentModel) throw new Error('--use-current-model requires --current-model.');
if (allowModelConstraintOverride && !useCurrentModel) throw new Error('--allow-model-constraint-override requires --use-current-model.');
if (specialistPurpose && !/^[a-z0-9][a-z0-9-]{0,79}$/u.test(specialistPurpose)) throw new Error('--specialist-purpose requires a lowercase kebab-case identifier.');
if (!Number.isInteger(invocationIndex) || invocationIndex < 0 || invocationIndex > 2147483647) throw new Error('--invocation-index requires a non-negative integer.');

const policy = JSON.parse(fs.readFileSync(policyPath, 'utf8'));
if (policy.schemaVersion !== 3 || policy.adapter !== 'codex-host-routing' || !policy.tiers?.[tier]) {
  throw new Error(`Unsupported dynamic model routing policy: ${policyPath}`);
}
const tierPolicy = policy.tiers[tier];
if (typeof tierPolicy.capability !== 'string') {
  throw new Error(`Invalid capability for ${tier}.`);
}
if (typeof policy.reasoningPolicy?.maximum !== 'string') throw new Error('Dynamic model routing policy requires reasoningPolicy.maximum.');
if (!Array.isArray(policy.reasoningPolicy?.executionEffortCycle) || policy.reasoningPolicy.executionEffortCycle.length === 0) throw new Error('Dynamic model routing policy requires a non-empty execution effort cycle.');
if (allowExceed && policy.reasoningPolicy.allowAboveMaximumOnlyWithExplicitUserInstruction !== true) throw new Error('Policy does not permit an above-ceiling authorization.');
if (useCurrentModel && policy.reasoningPolicy.useCurrentModelOnlyWhenExplicit !== true) throw new Error('Policy does not permit an explicit current-model constraint.');
if (allowModelConstraintOverride && policy.reasoningPolicy.allowModelConstraintOverrideOnlyWithExplicitUserInstruction !== true) throw new Error('Policy does not permit a model-constraint override.');
const effort = requestedEffort || null;

const emptyRoute = (modelAvailability, modelSelectionMode, extra = {}) => ({
  schemaVersion: 3,
  adapter: policy.adapter,
  tier,
  capability: tierPolicy.capability,
  preferredModel: null,
  reasoning: null,
  displayReasoning: null,
  hostReasoning: null,
  fallbackModel: null,
  fallbackReasoning: null,
  fallbackDisplayReasoning: null,
  fallbackHostReasoning: null,
  modelAvailability,
  modelSelectionMode,
  accountRotationAllowed: false,
  accountCatalogVerified: false,
  reasoningCeiling: policy.reasoningPolicy.maximum,
  aboveCeilingAuthorized: allowExceed,
  requestedCurrentModel: useCurrentModel ? currentModel : null,
  currentModelConstraintApplied: useCurrentModel,
  currentModelConstraintOverridden: false,
  ...extra
});

if (has('--models-unavailable')) {
  emit(emptyRoute('UNAVAILABLE_BY_CALLER', 'CAPACITY_FALLBACK_REQUIRED'));
  process.exit(0);
}
const readJson = (file, fallback) => fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : fallback;
let discoveryError = null;
const discoverLiveCatalog = () => {
  try {
    return JSON.parse(execFileSync(process.execPath, [path.join(here, 'codex-app-server-models.mjs')], { encoding: 'utf8', timeout: 20_000 }));
  } catch (error) {
    discoveryError = error.message;
    return null;
  }
};
// The caller may pass an envelope taken directly from host metadata.  Without
// one, actively ask the local App Server; never fall back to a saved catalog.
const catalogEnvelope = catalogPath ? readJson(catalogPath, null) : (has('--no-discover') ? null : discoverLiveCatalog());
const catalog = Array.isArray(catalogEnvelope) ? catalogEnvelope : catalogEnvelope?.data;
const catalogProvider = catalogEnvelope?.provenance?.provider || null;
const fixtureCatalog = catalogProvider === 'test-fixture';
if (!Array.isArray(catalog)) {
  emit(emptyRoute(catalogPath || has('--no-discover') ? 'CATALOG_REQUIRED' : 'CATALOG_DISCOVERY_FAILED', 'CATALOG_DISCOVERY_REQUIRED', { catalogDiscoveryError: discoveryError }));
  process.exit(0);
}

const discoveredAt = catalogEnvelope?.discoveredAt || catalogEnvelope?.provenance?.discoveredAt || null;
const discoveredAtMs = Date.parse(discoveredAt || '');
const catalogAgeMs = Number.isFinite(discoveredAtMs) ? Date.now() - discoveredAtMs : Number.POSITIVE_INFINITY;
const freshCatalog = catalogAgeMs >= -60_000 && catalogAgeMs <= 10 * 60_000;
const providerContractValid = catalogProvider === 'host-orchestration-tool'
  ? /^codex_app__/u.test(String(catalogEnvelope?.provenance?.tool || ''))
  : catalogProvider === 'codex-app-server:model/list'
    ? String(catalogEnvelope?.provenance?.executable || '').trim().length > 0
    : false;
const modelIds = catalog.map((model) => model?.model || model?.id).filter(Boolean);
const modelContractsValid = modelIds.length === catalog.length && new Set(modelIds).size === modelIds.length && catalog.every((model) => {
  const entries = model?.supportedReasoningEfforts;
  if (!Array.isArray(entries) || entries.length === 0) return false;
  const ids = entries.map((entry) => typeof entry === 'string' ? entry : entry?.reasoningEffort).filter(Boolean);
  return ids.length === entries.length && new Set(ids).size === ids.length;
});
// A path is caller-controlled input, even when it contains convincing-looking
// provenance fields.  Only this process's direct App Server response may be
// called account-verified in production.  Paths remain available exclusively
// for explicit `test-fixture` simulations.
const accountCatalog = !catalogPath && providerContractValid && freshCatalog && modelContractsValid;

const effortEntries = (model) => (model.supportedReasoningEfforts || []).map((entry) => typeof entry === 'string'
  ? { id: entry, displayName: entry }
  : { id: entry.reasoningEffort, displayName: entry.displayName || entry.reasoningEffort }).filter((entry) => entry.id);
const ceiling = policy.reasoningPolicy.maximum;
const normalize = (value) => String(value || '').toLowerCase();
const tokenize = (value) => normalize(value).split(/[^a-z0-9.+_-]+/u).map((token) => token.trim()).filter(Boolean);
const joinTokens = (...parts) => parts.flatMap((part) => {
  if (part == null) return [];
  if (Array.isArray(part)) return part.flatMap((item) => joinTokens(item));
  return tokenize(part);
  return [];
}).filter(Boolean).map(normalize);
const capabilitySignalFields = (model) => [
  model.capability,
  model.capabilities,
  model.modelCapability,
  model.modelCapabilities,
  model.modelFamily,
  model.family,
  model.category,
  model.type,
  model.tags
];
const capabilityOrder = ['fast', 'balanced', 'frontier'];
const capabilityText = (model) => joinTokens(capabilitySignalFields(model)).join(' ');
const descriptionText = (model) => normalize([model.description, model.displayName].filter(Boolean).join(' '));
const specialistMatches = (model) => {
  if (!specialistPurpose || model.hidden !== true) return false;
  const purposeTokens = specialistPurpose.split('-').filter((token) => token.length >= 4);
  const text = descriptionText(model);
  return purposeTokens.length > 0 && purposeTokens.every((token) => text.includes(token));
};
const explicitCapability = (model) => capabilityOrder.find((item) => tokenize(capabilityText(model)).includes(item)) || null;
const inferredCapability = (model) => {
  if (explicitCapability(model)) return explicitCapability(model);
  const text = descriptionText(model);
  if (/\b(?:ultra[- ]?fast|fast|affordable|small|cost[- ]?efficient|repeatable|speed)\b/u.test(text)) return 'fast';
  if (/\b(?:latest|frontier|complex|research|open[- ]?ended|deep)\b/u.test(text)) return 'frontier';
  if (/\b(?:balanced|everyday|workhorse|strong|general)\b/u.test(text)) return 'balanced';
  return 'unknown';
};
const capabilityDistance = (actual, wanted) => {
  const actualIndex = capabilityOrder.indexOf(actual);
  const wantedIndex = capabilityOrder.indexOf(wanted);
  return actualIndex < 0 || wantedIndex < 0 ? 9 : Math.abs(actualIndex - wantedIndex);
};
const chooseEffort = (model) => {
  const raw = effortEntries(model);
  const ceilingIndex = raw.findIndex((entry) => entry.id === ceiling);
  const available = allowExceed ? raw : (ceilingIndex >= 0 ? raw.slice(0, ceilingIndex + 1) : []);
  if (effort) return available.find((entry) => entry.id === effort) || null;
  const cycle = policy.reasoningPolicy.executionEffortCycleByTier?.[tier] || policy.reasoningPolicy.executionEffortCycle;
  if (tier === 'T4' && (!Array.isArray(cycle) || !cycle.every((cycleEffort) => available.some((entry) => entry.id === cycleEffort)))) return null;
  // Use the shared low/medium/high cycle only for models which expose its
  // first level. Hosts may expose an unrelated ordered vocabulary; preserve
  // that model's own order instead of silently jumping to a later level.
  if (Array.isArray(cycle) && cycle.length > 0 && available.some((entry) => entry.id === cycle[0])) {
    for (let offset = 0; offset < cycle.length; offset += 1) {
      const cycleEffort = cycle[(invocationIndex + offset) % cycle.length];
      const match = available.find((entry) => entry.id === cycleEffort);
      if (match) return match;
    }
  }
  return available[invocationIndex % available.length] || null;
};
const wantedCapability = tierPolicy.capability.toLowerCase();
const modelId = (model) => model?.model || model?.id || null;
const coverage = catalog.map((model, catalogIndex) => {
  const id = modelId(model);
  const capabilityClass = inferredCapability(model);
  const generalEligible = model.hidden !== true;
  const specialistEligible = specialistMatches(model);
  const selectedEffort = id ? chooseEffort(model) : null;
  return {
    model: id,
    displayName: model.displayName || id,
    catalogIndex,
    hidden: model.hidden === true,
    eligibility: generalEligible ? 'GENERAL' : (specialistEligible ? 'MATCHING_SPECIALIST_PURPOSE' : 'HOST_HIDDEN_SPECIALIZED'),
    capabilityClass,
    supportedReasoningEfforts: effortEntries(model).map((entry) => entry.id),
    defaultReasoningEffort: model.defaultReasoningEffort || null,
    upgrade: model.upgrade || null,
    selectedEffort: selectedEffort?.id || null
  };
});
const catalogDigest = crypto.createHash('sha256').update(JSON.stringify(coverage.map((entry) => ({
  model: entry.model,
  hidden: entry.hidden,
  capabilityClass: entry.capabilityClass,
  supportedReasoningEfforts: entry.supportedReasoningEfforts,
  defaultReasoningEffort: entry.defaultReasoningEffort,
  upgrade: entry.upgrade
}))), 'utf8').digest('hex');
const allCandidates = catalog.map((model, catalogIndex) => ({
  model,
  catalogIndex,
  // The App Server contract permits either `id` or `model` as the canonical
  // identifier.  Future catalog entries must not disappear merely because the
  // host supplies the latter form.
  effort: modelId(model) ? chooseEffort(model) : null,
  capabilityClass: inferredCapability(model),
  generalEligible: model.hidden !== true,
  specialistEligible: specialistMatches(model)
})).filter((candidate) => candidate.effort && (candidate.generalEligible || candidate.specialistEligible));
let candidates = useCurrentModel
  ? allCandidates.filter((candidate) => modelId(candidate.model) === currentModel)
  : specialistPurpose
    ? allCandidates.filter((candidate) => candidate.specialistEligible)
    : allCandidates.filter((candidate) => candidate.generalEligible);
const currentModelConstraintOverridden = useCurrentModel && allowModelConstraintOverride && candidates.length === 0;
if (currentModelConstraintOverridden) candidates = allCandidates.filter((candidate) => candidate.generalEligible);
const rank = (candidate) => [
  specialistPurpose ? '00' : String(capabilityDistance(candidate.capabilityClass, wantedCapability)).padStart(2, '0'),
  String(candidate.catalogIndex).padStart(8, '0'),
  modelId(candidate.model)
];
candidates.sort((a, b) => rank(a).join('\u0000').localeCompare(rank(b).join('\u0000')));
const bestDistance = candidates.length ? rank(candidates[0])[0] : null;
const capabilityPool = candidates.filter((candidate) => rank(candidate)[0] === bestDistance);
const upgradeTargets = new Set(catalog.map((model) => model.upgrade).filter(Boolean));
const latestPool = tierPolicy.preferLatest === true
  ? capabilityPool.filter((candidate) => upgradeTargets.has(modelId(candidate.model)) || /\blatest\b/u.test(descriptionText(candidate.model)))
  : [];
const selectionPool = latestPool.length > 0 ? latestPool : capabilityPool;
const distributionKey = workUnitId || null;
const distributionIndex = selectionPool.length > 0 && distributionKey
  ? crypto.createHash('sha256').update(`${tier}\u0000${distributionKey}\u0000${specialistPurpose || 'general'}`, 'utf8').digest().readUInt32BE(0) % selectionPool.length
  : 0;
const selected = selectionPool[distributionIndex] || null;
const fallback = selectionPool.length > 1
  ? selectionPool[(distributionIndex + 1) % selectionPool.length]
  : candidates.find((candidate) => candidate !== selected) || null;
const testCatalogAllowed = fixtureCatalog && has('--allow-test-catalog');
const canDispatch = accountCatalog || testCatalogAllowed;
const resolvedRoute = {
  schemaVersion: 3,
  adapter: policy.adapter,
  tier,
  capability: tierPolicy.capability,
  preferredModel: canDispatch && selected ? (selected.model.model || selected.model.id) : null,
  reasoning: canDispatch && selected ? selected.effort.id : null,
  displayReasoning: canDispatch && selected ? selected.effort.displayName : null,
  hostReasoning: canDispatch && selected ? selected.effort.id : null,
  fallbackModel: canDispatch && fallback ? (fallback.model.model || fallback.model.id) : null,
  fallbackReasoning: canDispatch && fallback ? fallback.effort.id : null,
  fallbackDisplayReasoning: canDispatch && fallback ? fallback.effort.displayName : null,
  fallbackHostReasoning: canDispatch && fallback ? fallback.effort.id : null,
  // A file path alone is not provenance.  Only host/App Server discovery can
  // be reported as an account-verified catalog; fixtures stay explicitly
  // non-production even though they remain useful for deterministic tests.
  modelAvailability: selected ? (accountCatalog ? 'ACCOUNT_CATALOG_VERIFIED' : (fixtureCatalog ? 'TEST_CATALOG_ONLY' : (catalogPath ? 'CATALOG_EXTERNAL_INPUT_REJECTED' : (['host-orchestration-tool', 'codex-app-server:model/list'].includes(catalogProvider) ? 'CATALOG_STALE_OR_INVALID' : 'CATALOG_PROVENANCE_REQUIRED')))) : 'NO_SUPPORTED_MODEL',
  modelSelectionMode: !canDispatch ? 'CATALOG_PROVENANCE_REQUIRED' : (testCatalogAllowed ? 'TEST_ONLY_ROUTE' : (currentModelConstraintOverridden ? 'EXPLICIT_CURRENT_MODEL_OVERRIDE' : (useCurrentModel ? 'EXPLICIT_CURRENT_MODEL' : policy.selection.executionMode))),
  accountRotationAllowed: policy.availability.accountRotationAllowed === true,
  catalogSource: catalogPath || null,
  catalogProvider,
  accountCatalogVerified: accountCatalog,
  testCatalogAllowed,
  catalogFresh: freshCatalog,
  catalogAgeMs: Number.isFinite(catalogAgeMs) ? catalogAgeMs : null,
  catalogContractValid: providerContractValid && modelContractsValid,
  catalogModelCount: catalog.length,
  generalModelCount: coverage.filter((entry) => entry.eligibility === 'GENERAL').length,
  eligibleSelectionPool: selectionPool.map((candidate) => modelId(candidate.model)),
  selectionPoolSize: selectionPool.length,
  distributionKey,
  distributionIndex,
  specialistPurpose: specialistPurpose || null,
  invocationIndex,
  effortRotation: effort ? 'EXPLICIT_OVERRIDE' : 'INVOCATION_CYCLE',
  catalogCoverage: coverage,
  catalogDigest,
  reasoningCeiling: ceiling,
  aboveCeilingAuthorized: allowExceed,
  requestedCurrentModel: useCurrentModel ? currentModel : null,
  currentModelConstraintApplied: useCurrentModel,
  currentModelConstraintOverridden,
  catalogDiscoveredAt: discoveredAt
};
if (workUnitId && resolvedRoute.preferredModel && resolvedRoute.hostReasoning) {
  resolvedRoute.workUnitId = workUnitId;
  resolvedRoute.routeDigest = crypto.createHash('sha256').update(JSON.stringify({
    tier,
    workUnitId,
    invocationIndex: resolvedRoute.invocationIndex,
    preferredModel: resolvedRoute.preferredModel,
    hostReasoning: resolvedRoute.hostReasoning,
    fallbackModel: resolvedRoute.fallbackModel || null,
    fallbackHostReasoning: resolvedRoute.fallbackHostReasoning || null,
    catalogDigest: resolvedRoute.catalogDigest,
    catalogProvider: resolvedRoute.catalogProvider,
    catalogDiscoveredAt: resolvedRoute.catalogDiscoveredAt
  }), 'utf8').digest('hex');
  resolvedRoute.routeLine = `Model route: ${workUnitId} | ${resolvedRoute.preferredModel} / ${resolvedRoute.displayReasoning || resolvedRoute.hostReasoning} (host: ${resolvedRoute.hostReasoning})`;
}
emit(resolvedRoute);
