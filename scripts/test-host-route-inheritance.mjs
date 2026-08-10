import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { hostRoutePathsFromPrompt, inheritValidatedHostRoute } from './codex-hooks/ueef-hook-common.mjs';

const sandbox = fs.mkdtempSync(path.join(os.tmpdir(), 'ueef-host-route-inheritance-'));
const digest = (value) => crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
try {
  const catalogCoverage = [{
    model: 'primary-model', hidden: false, capabilityClass: 'frontier',
    supportedReasoningEfforts: ['medium'], defaultReasoningEffort: 'medium', upgrade: null,
  }];
  const executionSpec = { schemaVersion: 1, outcome: 'test' };
  executionSpec.digest = digest(executionSpec);
  const route = {
    accountCatalogVerified: true, catalogFresh: true, catalogContractValid: true,
    catalogDiscoveredAt: new Date().toISOString(), catalogCoverage,
    catalogDigest: digest(catalogCoverage), catalogProvider: 'codex-app-server:model/list',
    tier: 'T2', workUnitId: 'inherited-host-work', invocationIndex: 0,
    preferredModel: 'primary-model', displayReasoning: 'medium', hostReasoning: 'medium',
    fallbackModel: null, fallbackHostReasoning: null,
    tokenEconomy: { specRequired: true, maxWorkerCount: 1 },
    executionSpec,
  };
  route.routeDigest = digest({
    tier: route.tier, workUnitId: route.workUnitId, invocationIndex: route.invocationIndex,
    preferredModel: route.preferredModel, hostReasoning: route.hostReasoning,
    fallbackModel: route.fallbackModel, fallbackHostReasoning: route.fallbackHostReasoning,
    tokenEconomy: route.tokenEconomy, catalogDigest: route.catalogDigest,
    catalogProvider: route.catalogProvider, catalogDiscoveredAt: route.catalogDiscoveredAt,
  });
  const routePath = path.join(sandbox, 'route.json');
  fs.writeFileSync(routePath, JSON.stringify(route), 'utf8');
  const state = () => ({ pickerModel: 'primary-model', route: null, executionSpec: null, validations: { executionSpec: false, modelDispatch: false } });
  const claimPath = path.join(sandbox, 'valid.claim');
  const envelope = Buffer.from(JSON.stringify({ routePath, claimPath }), 'utf8').toString('base64url');
  assert.deepEqual(hostRoutePathsFromPrompt(`UEEF_HOST_ROUTE_INHERIT_V1:${envelope}\nwork`), { routePath, claimPath });
  assert.deepEqual(hostRoutePathsFromPrompt(`UEEF_HOST_ROUTE_INHERIT_V1:${envelope}\r\nwork`), { routePath, claimPath });
  assert.equal(hostRoutePathsFromPrompt('UEEF_HOST_ROUTE_INHERIT_V1:not-json'), null);
  assert.equal(hostRoutePathsFromPrompt('UEEF_HOST_ROUTE_INHERIT_V1:' + Buffer.from(JSON.stringify({ routePath: 'relative', claimPath })).toString('base64url')), null);
  const forgedClaimPath = path.join(sandbox, 'forged.claim');
  const forged = inheritValidatedHostRoute(state(), routePath, forgedClaimPath, null, null);
  assert.equal(forged.route, null);
  assert.equal(forged.hostRouteInheritanceError, 'HOST_ROUTE_ENV_MISSING');
  assert.equal(fs.existsSync(forgedClaimPath), false);
  const mismatchClaimPath = path.join(sandbox, 'mismatch.claim');
  const mismatch = inheritValidatedHostRoute(
    state(), routePath, mismatchClaimPath, routePath, path.join(sandbox, 'trusted.claim')
  );
  assert.equal(mismatch.route, null);
  assert.equal(mismatch.hostRouteInheritanceError, 'HOST_ROUTE_ENV_MISMATCH');
  assert.equal(fs.existsSync(mismatchClaimPath), false);
  const previousTrustedRoute = process.env.UEEF_VALIDATED_HOST_ROUTE;
  const previousTrustedClaim = process.env.UEEF_VALIDATED_HOST_ROUTE_CLAIM;
  process.env.UEEF_VALIDATED_HOST_ROUTE = routePath;
  process.env.UEEF_VALIDATED_HOST_ROUTE_CLAIM = claimPath;
  const inherited = inheritValidatedHostRoute(state(), routePath, claimPath);
  assert.equal(inherited.route.inheritedHostDispatch, true);
  assert.equal(inherited.route.routeDigest, route.routeDigest);
  assert.equal(inherited.route.preferredModel, 'primary-model');
  assert.equal(inherited.route.actualModel, 'primary-model');
  assert.equal(inherited.route.capacityFallbackUsed, false);
  assert.equal(inherited.validations.executionSpec, true);
  assert.equal(inherited.validations.modelDispatch, true);
  assert.equal(inheritValidatedHostRoute(state(), routePath, claimPath).route, null);
  if (previousTrustedRoute === undefined) delete process.env.UEEF_VALIDATED_HOST_ROUTE;
  else process.env.UEEF_VALIDATED_HOST_ROUTE = previousTrustedRoute;
  if (previousTrustedClaim === undefined) delete process.env.UEEF_VALIDATED_HOST_ROUTE_CLAIM;
  else process.env.UEEF_VALIDATED_HOST_ROUTE_CLAIM = previousTrustedClaim;

  const fallbackRoute = { ...route, fallbackModel: 'fallback-model', fallbackHostReasoning: 'medium' };
  fallbackRoute.catalogCoverage = [...catalogCoverage, { ...catalogCoverage[0], model: 'fallback-model' }];
  fallbackRoute.catalogDigest = digest(fallbackRoute.catalogCoverage);
  fallbackRoute.routeDigest = digest({
    tier: fallbackRoute.tier, workUnitId: fallbackRoute.workUnitId, invocationIndex: fallbackRoute.invocationIndex,
    preferredModel: fallbackRoute.preferredModel, hostReasoning: fallbackRoute.hostReasoning,
    fallbackModel: fallbackRoute.fallbackModel, fallbackHostReasoning: fallbackRoute.fallbackHostReasoning,
    tokenEconomy: fallbackRoute.tokenEconomy, catalogDigest: fallbackRoute.catalogDigest,
    catalogProvider: fallbackRoute.catalogProvider, catalogDiscoveredAt: fallbackRoute.catalogDiscoveredAt,
  });
  const fallbackPath = path.join(sandbox, 'fallback.json');
  const fallbackClaimPath = path.join(sandbox, 'fallback.claim');
  fs.writeFileSync(fallbackPath, JSON.stringify(fallbackRoute), 'utf8');
  const fallbackState = { ...state(), pickerModel: 'fallback-model' };
  const fallbackInherited = inheritValidatedHostRoute(
    fallbackState, fallbackPath, fallbackClaimPath, fallbackPath, fallbackClaimPath
  );
  assert.equal(fallbackInherited.route.routeDigest, fallbackRoute.routeDigest);
  assert.equal(fallbackInherited.route.preferredModel, 'primary-model');
  assert.equal(fallbackInherited.route.actualModel, 'fallback-model');
  assert.equal(fallbackInherited.route.actualHostReasoning, 'medium');
  assert.equal(fallbackInherited.route.capacityFallbackUsed, true);
  assert.equal(fs.existsSync(fallbackClaimPath), true);
  assert.equal(inheritValidatedHostRoute(
    { ...state(), pickerModel: 'fallback-model' }, fallbackPath, fallbackClaimPath,
    fallbackPath, fallbackClaimPath
  ).route, null);

  const tamperedPath = path.join(sandbox, 'tampered.json');
  fs.writeFileSync(tamperedPath, JSON.stringify({ ...route, hostReasoning: 'high' }), 'utf8');
  const tamperedClaim = path.join(sandbox, 'tampered.claim');
  assert.equal(inheritValidatedHostRoute(state(), tamperedPath, tamperedClaim, tamperedPath, tamperedClaim).route, null);
  const modelClaim = path.join(sandbox, 'model.claim');
  assert.equal(inheritValidatedHostRoute({ ...state(), pickerModel: 'other-model' }, routePath, modelClaim, routePath, modelClaim).route, null);
  const stalePath = path.join(sandbox, 'stale.json');
  fs.writeFileSync(stalePath, JSON.stringify({ ...route, catalogDiscoveredAt: '2020-01-01T00:00:00.000Z' }), 'utf8');
  const staleClaim = path.join(sandbox, 'stale.claim');
  assert.equal(inheritValidatedHostRoute(state(), stalePath, staleClaim, stalePath, staleClaim).route, null);
  process.stdout.write('Validated host route inheritance tests passed\n');
} finally {
  fs.rmSync(sandbox, { recursive: true, force: true });
}
