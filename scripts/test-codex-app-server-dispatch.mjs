import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const root = path.resolve(import.meta.dirname, '..');
const sandbox = fs.mkdtempSync(path.join(os.tmpdir(), 'ueef-app-server-dispatch-'));
try {
  const fakeServer = path.join(sandbox, 'fake-app-server.mjs');
  const routePath = path.join(sandbox, 'route.json');
  fs.writeFileSync(fakeServer, `
import readline from 'node:readline';
const send=(value)=>process.stdout.write(JSON.stringify(value)+'\\n');
let threadStartCalls=0;
let turnStartCalls=0;
readline.createInterface({input:process.stdin}).on('line',(line)=>{
 const message=JSON.parse(line);
 if(message.id===0) return send({id:0,result:{}});
 if(message.method==='thread/start') {
   threadStartCalls+=1;
   const transientCount=Number(process.env.FAKE_THREAD_START_TRANSIENT_COUNT || 0);
   if(threadStartCalls<=transientCount) return send({id:message.id,error:{code:-32001,message:'temporarily unavailable'}});
   if(process.env.FAKE_TRANSIENT_THEN_CAPACITY==='1' && threadStartCalls===transientCount+1 && message.params.model==='primary-model') return send({id:message.id,error:{message:'Selected model is at capacity'}});
   if(process.env.FAKE_REQUIRE_HOST_ROUTE==='1' && (!process.env.UEEF_VALIDATED_HOST_ROUTE || !process.env.UEEF_VALIDATED_HOST_ROUTE.endsWith('route.json') || !process.env.UEEF_VALIDATED_HOST_ROUTE_CLAIM)) return send({id:message.id,error:{message:'missing validated host route environment'}});
   if(process.env.FAKE_THREAD_START_CAPACITY==='1' && message.params.model==='primary-model') return send({id:message.id,error:{message:'Selected model is at capacity'}});
   if(process.env.FAKE_FALLBACK_THREAD_START_CAPACITY==='1' && message.params.model==='fallback-model') return send({id:message.id,error:{message:'Selected model is at capacity'}});
   return send({id:message.id,result:{thread:{id:'thread-'+message.params.model},model:message.params.model,reasoningEffort:message.params.model==='primary-model'?'medium':'low'}});
 }
  if(message.method==='turn/start') {
   turnStartCalls+=1;
   const transientCount=Number(process.env.FAKE_TURN_START_TRANSIENT_COUNT || 0);
   if(turnStartCalls<=transientCount) return send({id:message.id,error:{code:-32001,message:'temporarily unavailable'}});
   if(process.env.FAKE_REQUIRE_AR==='1' && !message.params.additionalContext?.['ueef-response-language']?.value?.includes(' ar.')) return send({id:message.id,error:{message:'missing Arabic response-language context'}});
   if(process.env.FAKE_REQUIRE_EXECUTION_SPEC==='1' && !message.params.additionalContext?.['ueef-execution-spec']?.value?.includes('"maxWords":250')) return send({id:message.id,error:{message:'missing execution spec token budget context'}});
   if(process.env.FAKE_TURN_START_CAPACITY==='1' && message.params.model==='primary-model') return send({id:message.id,error:{message:'Selected model is at capacity'}});
   send({id:message.id,result:{turn:{id:'turn-'+message.params.model}}});
   send({method:'thread/settings/updated',params:{threadId:'thread-'+message.params.model,threadSettings:{model:message.params.model,effort:message.params.effort}}});
   if(message.params.model==='primary-model') return send({method:'turn/completed',params:{turn:{id:'turn-primary',status:'failed',error:{message:'Selected model is at capacity'}}}});
   if(process.env.FAKE_UNAPPROVED_REROUTE==='1') send({method:'model/rerouted',params:{fromModel:message.params.model,toModel:'unapproved-model',reason:'provider fallback',threadId:'thread-'+message.params.model,turnId:'turn-'+message.params.model}});
   send({method:'item/completed',params:{item:{type:'agentMessage',text:'OK'}}});
    return send({method:'turn/completed',params:{turn:{id:'turn-fallback',status:'completed',error:null}}});
  }
});
`, 'utf8');
  const catalogCoverage = [
    { model: 'primary-model', hidden: false, capabilityClass: 'balanced', supportedReasoningEfforts: ['low', 'medium'], defaultReasoningEffort: 'medium', upgrade: null },
    { model: 'fallback-model', hidden: false, capabilityClass: 'fast', supportedReasoningEfforts: ['low'], defaultReasoningEffort: 'low', upgrade: null }
  ];
  const catalogDigest = crypto.createHash('sha256').update(JSON.stringify(catalogCoverage)).digest('hex');
  const routeDigestFor = (value) => crypto.createHash('sha256').update(JSON.stringify({
    tier: value.tier,
    workUnitId: value.workUnitId,
    invocationIndex: value.invocationIndex,
    preferredModel: value.preferredModel,
    hostReasoning: value.hostReasoning,
    fallbackModel: value.fallbackModel,
    fallbackHostReasoning: value.fallbackHostReasoning,
    tokenEconomy: value.tokenEconomy,
    decision: value.decision,
    catalogDigest: value.catalogDigest,
    catalogProvider: value.catalogProvider,
    catalogDiscoveredAt: value.catalogDiscoveredAt
  })).digest('hex');
  const executionSpec = { schemaVersion: 1, tier: 'T2', workUnitId: 'dispatch-fixture', promptSha256: 'prompt-digest', outcome: 'test dispatch', acceptanceCriteria: 'dispatch passes', ownerPaths: 'scripts', nonGoals: 'unrelated work', tokenEconomy: { specRequired: true, budgetMode: 'bounded', delegationPolicy: 'sidecar', maxWorkerCount: 1, workerOutputCap: { maxBullets: 12, maxWords: 250, longEvidenceStoredInArtifacts: true }, leadOwns: ['planning'], workerMayOwn: ['bounded-read'], forbiddenSavings: ['omit-required-acceptance-evidence'] }, requiredEvidence: ['test'], createdAtUtc: new Date().toISOString() };
  executionSpec.digest = crypto.createHash('sha256').update(JSON.stringify(executionSpec)).digest('hex');
  const route = {
    accountCatalogVerified: true,
    catalogFresh: true,
    catalogContractValid: true,
    catalogDiscoveredAt: new Date().toISOString(),
    catalogCoverage,
    catalogDigest,
    tier: 'T2',
    workUnitId: 'dispatch-fixture',
    invocationIndex: 0,
    catalogProvider: 'test-fixture',
    preferredModel: 'primary-model',
    hostReasoning: 'medium',
    fallbackModel: 'fallback-model',
    fallbackHostReasoning: 'low',
    tokenEconomy: executionSpec.tokenEconomy,
    decision: { mode: 'IMPLEMENTATION', spec: 'LIGHT', specReason: 'T2 managed execution', team: 'SPAWN', teamReason: 'explicit test authorization', delegationAuthorized: true, delegationAuthorizationSource: 'TASK_INSTRUCTION', delegationScope: 'WORKERS' },
    executionSpec
  };
  route.routeDigest = routeDigestFor(route);
  fs.writeFileSync(routePath, JSON.stringify(route), 'utf8');
  const tamperedRoutePath = path.join(sandbox, 'tampered-route.json');
  fs.writeFileSync(tamperedRoutePath, JSON.stringify({ ...route, fallbackModel: 'tampered-model' }), 'utf8');
  const tampered = spawnSync(process.execPath, [
    path.join(root, 'scripts', 'codex-app-server-dispatch.mjs'), '--route', tamperedRoutePath, '--prompt', 'test', '--cwd', root,
    '--sandbox', 'read-only', '--timeout-ms', '10000', '--executable', process.execPath, '--executable-arg', fakeServer
  ], { encoding: 'utf8', timeout: 20_000 });
  assert.notEqual(tampered.status, 0);
  assert.match(`${tampered.stderr}${tampered.stdout}`, /route digest does not bind the complete route identity/u);
  const tamperedInvocationRoutePath = path.join(sandbox, 'tampered-invocation-route.json');
  fs.writeFileSync(tamperedInvocationRoutePath, JSON.stringify({ ...route, invocationIndex: 1 }), 'utf8');
  const tamperedInvocation = spawnSync(process.execPath, [
    path.join(root, 'scripts', 'codex-app-server-dispatch.mjs'), '--route', tamperedInvocationRoutePath, '--prompt', 'test', '--cwd', root,
    '--sandbox', 'read-only', '--timeout-ms', '10000', '--executable', process.execPath, '--executable-arg', fakeServer
  ], { encoding: 'utf8', timeout: 20_000 });
  assert.notEqual(tamperedInvocation.status, 0);
  assert.match(`${tamperedInvocation.stderr}${tamperedInvocation.stdout}`, /route digest does not bind the complete route identity/u);
  const inconsistentDecisionRoute = {
    ...route,
    decision: { ...route.decision, team: 'SPAWN', delegationAuthorized: false, delegationAuthorizationSource: 'NONE' }
  };
  inconsistentDecisionRoute.routeDigest = routeDigestFor(inconsistentDecisionRoute);
  const inconsistentDecisionPath = path.join(sandbox, 'inconsistent-decision-route.json');
  fs.writeFileSync(inconsistentDecisionPath, JSON.stringify(inconsistentDecisionRoute), 'utf8');
  const inconsistentDecision = spawnSync(process.execPath, [
    path.join(root, 'scripts', 'codex-app-server-dispatch.mjs'), '--route', inconsistentDecisionPath, '--prompt', 'test', '--cwd', root,
    '--sandbox', 'read-only', '--timeout-ms', '10000', '--executable', process.execPath, '--executable-arg', fakeServer
  ], { encoding: 'utf8', timeout: 20_000 });
  assert.notEqual(inconsistentDecision.status, 0);
  assert.match(`${inconsistentDecision.stderr}${inconsistentDecision.stdout}`, /invalid canonical execution decision/u);
  const tierDecisionMismatchRoute = {
    ...route,
    decision: { ...route.decision, spec: 'FULL_REQUIRED' }
  };
  tierDecisionMismatchRoute.routeDigest = routeDigestFor(tierDecisionMismatchRoute);
  const tierDecisionMismatchPath = path.join(sandbox, 'tier-decision-mismatch-route.json');
  fs.writeFileSync(tierDecisionMismatchPath, JSON.stringify(tierDecisionMismatchRoute), 'utf8');
  const tierDecisionMismatch = spawnSync(process.execPath, [
    path.join(root, 'scripts', 'codex-app-server-dispatch.mjs'), '--route', tierDecisionMismatchPath, '--prompt', 'test', '--cwd', root,
    '--sandbox', 'read-only', '--timeout-ms', '10000', '--executable', process.execPath, '--executable-arg', fakeServer
  ], { encoding: 'utf8', timeout: 20_000 });
  assert.notEqual(tierDecisionMismatch.status, 0);
  assert.match(`${tierDecisionMismatch.stderr}${tierDecisionMismatch.stdout}`, /invalid canonical execution decision/u);
  const invalidBudgetRoute = {
    ...route,
    tokenEconomy: { ...route.tokenEconomy, maxWorkerCount: 'one' }
  };
  invalidBudgetRoute.routeDigest = routeDigestFor(invalidBudgetRoute);
  const invalidBudgetPath = path.join(sandbox, 'invalid-budget-route.json');
  fs.writeFileSync(invalidBudgetPath, JSON.stringify(invalidBudgetRoute), 'utf8');
  const invalidBudget = spawnSync(process.execPath, [
    path.join(root, 'scripts', 'codex-app-server-dispatch.mjs'), '--route', invalidBudgetPath, '--prompt', 'test', '--cwd', root,
    '--sandbox', 'read-only', '--timeout-ms', '10000', '--executable', process.execPath, '--executable-arg', fakeServer
  ], { encoding: 'utf8', timeout: 20_000 });
  assert.notEqual(invalidBudget.status, 0);
  assert.match(`${invalidBudget.stderr}${invalidBudget.stdout}`, /invalid canonical execution decision/u);
  const run = spawnSync(process.execPath, [
    path.join(root, 'scripts', 'codex-app-server-dispatch.mjs'),
    '--route', routePath,
    '--prompt', 'test',
    '--response-language', 'ar',
    '--cwd', root,
    '--sandbox', 'read-only',
    '--timeout-ms', '10000',
    '--executable', process.execPath,
    '--executable-arg', fakeServer
  ], { encoding: 'utf8', timeout: 20_000, env: { ...process.env, FAKE_REQUIRE_AR: '1', FAKE_REQUIRE_EXECUTION_SPEC: '1', FAKE_REQUIRE_HOST_ROUTE: '1' } });
  assert.equal(run.status, 0, run.stderr || run.stdout);
  const result = JSON.parse(run.stdout);
  assert.equal(result.result, 'SUCCESS');
  assert.equal(result.executionVerified, true);
  assert.equal(result.capacityFallbackUsed, true);
  assert.equal(result.actualModel, 'fallback-model');
  assert.equal(result.actualHostReasoning, 'low');
  assert.equal(result.responseLanguage, 'ar');
  assert.equal(result.executionSpecDigest, executionSpec.digest);
  assert.equal(result.tokenEconomy.maxWorkerCount, 1);
  assert.deepEqual(result.attempts.map((attempt) => attempt.result), ['CAPACITY', 'SUCCESS']);
  assert.equal(result.attempts.length, 2);
  const threadStartCapacity = spawnSync(process.execPath, [
    path.join(root, 'scripts', 'codex-app-server-dispatch.mjs'),
    '--route', routePath,
    '--prompt', 'test',
    '--cwd', root,
    '--sandbox', 'read-only',
    '--timeout-ms', '10000',
    '--executable', process.execPath,
    '--executable-arg', fakeServer
  ], { encoding: 'utf8', timeout: 20_000, env: { ...process.env, FAKE_THREAD_START_CAPACITY: '1' } });
  assert.equal(threadStartCapacity.status, 0, threadStartCapacity.stderr || threadStartCapacity.stdout);
  const threadStartResult = JSON.parse(threadStartCapacity.stdout);
  assert.equal(threadStartResult.capacityFallbackUsed, true);
  assert.equal(threadStartResult.actualModel, 'fallback-model');
  assert.deepEqual(threadStartResult.transientRetries, []);
  assert.deepEqual(threadStartResult.attempts.map((attempt) => attempt.result), ['CAPACITY', 'SUCCESS']);
  assert.equal(threadStartResult.attempts[0].stage, 'thread/start');
  const turnStartCapacity = spawnSync(process.execPath, [
    path.join(root, 'scripts', 'codex-app-server-dispatch.mjs'), '--route', routePath, '--prompt', 'test', '--cwd', root,
    '--sandbox', 'read-only', '--timeout-ms', '10000', '--executable', process.execPath, '--executable-arg', fakeServer
  ], { encoding: 'utf8', timeout: 20_000, env: { ...process.env, FAKE_TURN_START_CAPACITY: '1' } });
  assert.equal(turnStartCapacity.status, 0, turnStartCapacity.stderr || turnStartCapacity.stdout);
  const turnStartResult = JSON.parse(turnStartCapacity.stdout);
  assert.equal(turnStartResult.result, 'SUCCESS');
  assert.deepEqual(turnStartResult.attempts.map((attempt) => attempt.result), ['CAPACITY', 'SUCCESS']);
  assert.equal(turnStartResult.attempts[0].stage, 'turn/start');
  const doubleCapacity = spawnSync(process.execPath, [
    path.join(root, 'scripts', 'codex-app-server-dispatch.mjs'), '--route', routePath, '--prompt', 'test', '--cwd', root,
    '--sandbox', 'read-only', '--timeout-ms', '10000', '--executable', process.execPath, '--executable-arg', fakeServer
  ], { encoding: 'utf8', timeout: 20_000, env: { ...process.env, FAKE_THREAD_START_CAPACITY: '1', FAKE_FALLBACK_THREAD_START_CAPACITY: '1' } });
  assert.equal(doubleCapacity.status, 0, doubleCapacity.stderr || doubleCapacity.stdout);
  const doubleCapacityResult = JSON.parse(doubleCapacity.stdout);
  assert.equal(doubleCapacityResult.result, 'CAPACITY');
  assert.equal(doubleCapacityResult.executionVerified, false);
  assert.deepEqual(doubleCapacityResult.transientRetries, []);
  assert.deepEqual(doubleCapacityResult.attempts.map((attempt) => attempt.result), ['CAPACITY', 'CAPACITY']);
  assert.deepEqual(doubleCapacityResult.attempts.map((attempt) => attempt.stage), ['thread/start', 'thread/start']);
  const unapprovedReroute = spawnSync(process.execPath, [
    path.join(root, 'scripts', 'codex-app-server-dispatch.mjs'), '--route', routePath, '--prompt', 'test', '--cwd', root,
    '--sandbox', 'read-only', '--timeout-ms', '10000', '--executable', process.execPath, '--executable-arg', fakeServer
  ], { encoding: 'utf8', timeout: 20_000, env: { ...process.env, FAKE_UNAPPROVED_REROUTE: '1' } });
  assert.equal(unapprovedReroute.status, 0, unapprovedReroute.stderr || unapprovedReroute.stdout);
  const unapprovedRerouteResult = JSON.parse(unapprovedReroute.stdout);
  assert.equal(unapprovedRerouteResult.result, 'FAILED');
  assert.equal(unapprovedRerouteResult.executionVerified, false);
  assert.equal(unapprovedRerouteResult.actualModel, null);
  assert.equal(unapprovedRerouteResult.actualHostReasoning, null);
  assert.equal(unapprovedRerouteResult.providerModelFallbackAllowed, false);

  const transientSuccess = spawnSync(process.execPath, [
    path.join(root, 'scripts', 'codex-app-server-dispatch.mjs'), '--route', routePath, '--prompt', 'test', '--cwd', root,
    '--sandbox', 'read-only', '--timeout-ms', '10000', '--executable', process.execPath, '--executable-arg', fakeServer
  ], { encoding: 'utf8', timeout: 20_000, env: { ...process.env, FAKE_THREAD_START_TRANSIENT_COUNT: '2' } });
  assert.equal(transientSuccess.status, 0, transientSuccess.stderr || transientSuccess.stdout);
  const transientSuccessResult = JSON.parse(transientSuccess.stdout);
  assert.equal(transientSuccessResult.result, 'SUCCESS');
  assert.equal(transientSuccessResult.capacityFallbackUsed, true);
  assert.equal(transientSuccessResult.transientRetries.length, 2);
  assert.deepEqual(transientSuccessResult.transientRetries.map((entry) => entry.errorCode), [-32001, -32001]);
  assert.deepEqual(transientSuccessResult.attempts.map((attempt) => attempt.result), ['CAPACITY', 'SUCCESS']);

  const transientThenCapacity = spawnSync(process.execPath, [
    path.join(root, 'scripts', 'codex-app-server-dispatch.mjs'), '--route', routePath, '--prompt', 'test', '--cwd', root,
    '--sandbox', 'read-only', '--timeout-ms', '10000', '--executable', process.execPath, '--executable-arg', fakeServer
  ], { encoding: 'utf8', timeout: 20_000, env: { ...process.env, FAKE_THREAD_START_TRANSIENT_COUNT: '2', FAKE_TRANSIENT_THEN_CAPACITY: '1' } });
  assert.equal(transientThenCapacity.status, 0, transientThenCapacity.stderr || transientThenCapacity.stdout);
  const transientThenCapacityResult = JSON.parse(transientThenCapacity.stdout);
  assert.equal(transientThenCapacityResult.result, 'SUCCESS');
  assert.equal(transientThenCapacityResult.capacityFallbackUsed, true);
  assert.equal(transientThenCapacityResult.transientRetries.length, 2);
  assert.deepEqual(transientThenCapacityResult.attempts.map((attempt) => attempt.result), ['CAPACITY', 'SUCCESS']);

  const turnTransient = spawnSync(process.execPath, [
    path.join(root, 'scripts', 'codex-app-server-dispatch.mjs'), '--route', routePath, '--prompt', 'test', '--cwd', root,
    '--sandbox', 'read-only', '--timeout-ms', '10000', '--executable', process.execPath, '--executable-arg', fakeServer
  ], { encoding: 'utf8', timeout: 20_000, env: { ...process.env, FAKE_TURN_START_TRANSIENT_COUNT: '2' } });
  assert.equal(turnTransient.status, 0, turnTransient.stderr || turnTransient.stdout);
  const turnTransientResult = JSON.parse(turnTransient.stdout);
  assert.equal(turnTransientResult.result, 'SUCCESS');
  assert.equal(turnTransientResult.transientRetries.length, 2);
  assert.deepEqual(turnTransientResult.transientRetries.map((entry) => entry.stage), ['turn/start', 'turn/start']);

  const retryLimit = spawnSync(process.execPath, [
    path.join(root, 'scripts', 'codex-app-server-dispatch.mjs'), '--route', routePath, '--prompt', 'test', '--cwd', root,
    '--sandbox', 'read-only', '--timeout-ms', '10000', '--executable', process.execPath, '--executable-arg', fakeServer
  ], { encoding: 'utf8', timeout: 20_000, env: { ...process.env, FAKE_THREAD_START_TRANSIENT_COUNT: '99' } });
  assert.equal(retryLimit.status, 0, retryLimit.stderr || retryLimit.stdout);
  const retryLimitResult = JSON.parse(retryLimit.stdout);
  assert.equal(retryLimitResult.result, 'FAILED');
  assert.equal(retryLimitResult.capacityFallbackUsed, false);
  assert.equal(retryLimitResult.transientRetries.length, 4);
  assert.deepEqual(retryLimitResult.attempts.map((attempt) => attempt.errorCode), [-32001]);

  const retryDeadline = spawnSync(process.execPath, [
    path.join(root, 'scripts', 'codex-app-server-dispatch.mjs'), '--route', routePath, '--prompt', 'test', '--cwd', root,
    '--sandbox', 'read-only', '--timeout-ms', '1000', '--executable', process.execPath, '--executable-arg', fakeServer
  ], { encoding: 'utf8', timeout: 10_000, env: { ...process.env, FAKE_THREAD_START_TRANSIENT_COUNT: '99' } });
  assert.notEqual(retryDeadline.status, 0);
  assert.match(`${retryDeadline.stderr}${retryDeadline.stdout}`, /Timed out after 1000 ms/u);
  process.stdout.write('Codex App Server dispatch tests passed\n');
} finally {
  fs.rmSync(sandbox, { recursive: true, force: true });
}
