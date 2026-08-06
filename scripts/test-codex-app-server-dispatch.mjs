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
readline.createInterface({input:process.stdin}).on('line',(line)=>{
 const message=JSON.parse(line);
 if(message.id===0) return send({id:0,result:{}});
 if(message.method==='thread/start') {
   if(process.env.FAKE_THREAD_START_CAPACITY==='1' && message.params.model==='primary-model') return send({id:message.id,error:{message:'Selected model is at capacity'}});
   if(process.env.FAKE_FALLBACK_THREAD_START_CAPACITY==='1' && message.params.model==='fallback-model') return send({id:message.id,error:{message:'Selected model is at capacity'}});
   return send({id:message.id,result:{thread:{id:'thread-'+message.params.model},model:message.params.model,reasoningEffort:message.params.model==='primary-model'?'medium':'low'}});
 }
  if(message.method==='turn/start') {
   if(process.env.FAKE_REQUIRE_AR==='1' && !message.params.additionalContext?.['ueef-response-language']?.value?.includes(' ar.')) return send({id:message.id,error:{message:'missing Arabic response-language context'}});
   if(process.env.FAKE_REQUIRE_EXECUTION_SPEC==='1' && !message.params.additionalContext?.['ueef-execution-spec']?.value?.includes('"maxWords":250')) return send({id:message.id,error:{message:'missing execution spec token budget context'}});
   if(process.env.FAKE_TURN_START_CAPACITY==='1' && message.params.model==='primary-model') return send({id:message.id,error:{message:'Selected model is at capacity'}});
   send({id:message.id,result:{turn:{id:'turn-'+message.params.model}}});
   send({method:'thread/settings/updated',params:{threadId:'thread-'+message.params.model,threadSettings:{model:message.params.model,effort:message.params.effort}}});
   if(message.params.model==='primary-model') return send({method:'turn/completed',params:{turn:{id:'turn-primary',status:'failed',error:{message:'Selected model is at capacity'}}}});
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
    executionSpec
  };
  route.routeDigest = crypto.createHash('sha256').update(JSON.stringify({ tier: route.tier, workUnitId: route.workUnitId, invocationIndex: route.invocationIndex, preferredModel: route.preferredModel, hostReasoning: route.hostReasoning, fallbackModel: route.fallbackModel, fallbackHostReasoning: route.fallbackHostReasoning, tokenEconomy: route.tokenEconomy, catalogDigest: route.catalogDigest, catalogProvider: route.catalogProvider, catalogDiscoveredAt: route.catalogDiscoveredAt })).digest('hex');
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
  ], { encoding: 'utf8', timeout: 20_000, env: { ...process.env, FAKE_REQUIRE_AR: '1', FAKE_REQUIRE_EXECUTION_SPEC: '1' } });
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
  assert.deepEqual(doubleCapacityResult.attempts.map((attempt) => attempt.result), ['CAPACITY', 'CAPACITY']);
  assert.deepEqual(doubleCapacityResult.attempts.map((attempt) => attempt.stage), ['thread/start', 'thread/start']);
  process.stdout.write('Codex App Server dispatch tests passed\n');
} finally {
  fs.rmSync(sandbox, { recursive: true, force: true });
}
