import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const scripts = path.dirname(fileURLToPath(import.meta.url));
const recorder = path.join(scripts, 'codex-hooks', 'record-ueef-route.mjs');
const catalog = path.join(scripts, 'fixtures', 'model-catalog.json');
const stateRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'ueef-route-owner-'));
const sessionId = 'lead-session';
const turnId = 'shared-turn';
const statePath = path.join(stateRoot, `${sessionId}.${turnId}.json`);
const routePath = path.join(stateRoot, 'lead.route.json');
const digest = (file) => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const baseArgs = [recorder, '--session-id', sessionId, '--turn-id', turnId, '--tier', 'T2', '--intent', 'owner regression', '--agent-route', 'single lead', '--browser-reason', 'not required', '--acceptance', 'lead route remains immutable to workers', '--owner-paths', 'test sandbox', '--non-goals', 'no external changes', '--model-catalog', catalog, '--allow-test-catalog'];
const envFor = (threadId) => ({ ...process.env, CODEX_THREAD_ID: threadId, UEEF_ALLOW_TEST_HOOK_STATE_ROOT: '1', UEEF_TEST_HOOK_STATE_ROOT: stateRoot });

try {
  fs.writeFileSync(statePath, `${JSON.stringify({
    schemaVersion: 1,
    sessionId,
    turnId,
    ownerThreadId: 'lead-thread',
    promptSha256: crypto.createHash('sha256').update('prompt').digest('hex'),
    pickerModel: '',
    authorizations: {},
    route: null,
    validations: { executionSpec: false, modelDispatch: false }
  }, null, 2)}\n`, 'utf8');

  const lead = spawnSync(process.execPath, [...baseArgs, '--work-unit-id', 'lead-work', '--route-output', routePath], {
    encoding: 'utf8', timeout: 10_000, windowsHide: true, env: envFor('lead-thread')
  });
  assert.equal(lead.status, 0, `lead route failed: ${lead.stderr}`);
  const stateDigest = digest(statePath);
  const routeDigest = digest(routePath);

  const worker = spawnSync(process.execPath, [...baseArgs, '--work-unit-id', 'worker-overwrite'], {
    encoding: 'utf8', timeout: 10_000, windowsHide: true, env: envFor('worker-thread')
  });
  assert.notEqual(worker.status, 0, 'worker must not re-record the lead route');
  assert.match(worker.stderr, /cross-agent overwrite denied/u);
  assert.equal(digest(statePath), stateDigest, 'worker changed the lead turn state');
  assert.equal(digest(routePath), routeDigest, 'worker changed the lead route artifact');
  process.stdout.write('Cross-agent route ownership tests passed\n');
} finally {
  fs.rmSync(stateRoot, { recursive: true, force: true });
}
