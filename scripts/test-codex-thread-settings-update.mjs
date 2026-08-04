import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const root = path.resolve(import.meta.dirname, '..');
const sandbox = fs.mkdtempSync(path.join(os.tmpdir(), 'ueef-thread-settings-'));
try {
  const fakeServer = path.join(sandbox, 'fake-app-server.mjs');
  const routePath = path.join(sandbox, 'route.json');
  fs.writeFileSync(fakeServer, `
import readline from 'node:readline';
const send=(value)=>process.stdout.write(JSON.stringify(value)+'\\n');
readline.createInterface({input:process.stdin}).on('line',(line)=>{
 const message=JSON.parse(line);
 if(message.id===0) return send({id:0,result:{}});
 if(message.method==='thread/resume') return send({id:message.id,result:{thread:{id:message.params.threadId},model:'gpt-test',reasoningEffort:'high'}});
 if(message.method==='thread/read') return send({id:message.id,result:{thread:{id:message.params.threadId},model:'gpt-test',reasoningEffort:'high'}});
 if(message.method==='thread/settings/update') {
   const settings = message.params.threadSettings || message.params.settings || {};
   send({id:message.id,result:{}});
   return send({method:'thread/settings/updated',params:{threadId:message.params.threadId,threadSettings:{model:settings.model,effort:settings.effort}}});
 }
});
`, 'utf8');
  fs.writeFileSync(routePath, JSON.stringify({
    preferredModel: 'gpt-test',
    hostReasoning: 'high',
    routeDigest: 'route-digest-test'
  }), 'utf8');

  const dryRun = spawnSync(process.execPath, [
    path.join(root, 'scripts', 'update-codex-thread-settings.mjs'),
    '--thread-id', 'thread-test',
    '--route', routePath,
    '--dry-run',
    '--executable', process.execPath,
    '--executable-arg', fakeServer,
  ], { encoding: 'utf8', timeout: 20_000 });
  assert.equal(dryRun.status, 0, dryRun.stderr || dryRun.stdout);
  assert.equal(JSON.parse(dryRun.stdout).result, 'DRY_RUN');

  const missingThread = spawnSync(process.execPath, [
    path.join(root, 'scripts', 'update-codex-thread-settings.mjs'),
    '--model', 'gpt-test',
    '--effort', 'high',
    '--executable', process.execPath,
    '--executable-arg', fakeServer,
  ], { encoding: 'utf8', timeout: 20_000 });
  assert.notEqual(missingThread.status, 0);
  assert.match(`${missingThread.stderr}${missingThread.stdout}`, /explicit --thread-id/u);

  const update = spawnSync(process.execPath, [
    path.join(root, 'scripts', 'update-codex-thread-settings.mjs'),
    '--thread-id', 'thread-test',
    '--route', routePath,
    '--timeout-ms', '10000',
    '--executable', process.execPath,
    '--executable-arg', fakeServer,
  ], { encoding: 'utf8', timeout: 20_000 });
  assert.equal(update.status, 0, update.stderr || update.stdout);
  const result = JSON.parse(update.stdout);
  assert.equal(result.provider, 'codex-app-server:thread/settings/update');
  assert.equal(result.requestedModel, 'gpt-test');
  assert.equal(result.requestedHostReasoning, 'high');
  assert.equal(result.acceptedModel, 'gpt-test');
  assert.equal(result.acceptedHostReasoning, 'high');
  assert.equal(result.uiPickerMutationVerified, true);
  assert.equal(result.result, 'SUCCESS');

  const resumeUpdate = spawnSync(process.execPath, [
    path.join(root, 'scripts', 'update-codex-thread-settings.mjs'),
    '--thread-id', 'thread-test',
    '--route', routePath,
    '--resume-first',
    '--timeout-ms', '10000',
    '--executable', process.execPath,
    '--executable-arg', fakeServer,
  ], { encoding: 'utf8', timeout: 20_000 });
  assert.equal(resumeUpdate.status, 0, resumeUpdate.stderr || resumeUpdate.stdout);
  const resumeResult = JSON.parse(resumeUpdate.stdout);
  assert.equal(resumeResult.resumeFirst, true);
  assert.equal(resumeResult.uiPickerMutationVerified, true);
  assert.equal(resumeResult.result, 'SUCCESS');

  process.stdout.write('Codex thread settings update tests passed\n');
} finally {
  fs.rmSync(sandbox, { recursive: true, force: true });
}
