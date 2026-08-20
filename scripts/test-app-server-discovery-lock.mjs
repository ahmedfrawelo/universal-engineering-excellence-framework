import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { acquireAppServerDiscoveryLock, resolveAppServerDiscoveryLockRoot } from './codex-app-server-client-lib.mjs';

const args = process.argv.slice(2);
const sleep = (ms) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);

if (args[0] === '--worker') {
  const tracePath = args[1];
  const holdMs = Number(args[2]);
  const crash = args.includes('--crash');
  const release = acquireAppServerDiscoveryLock({ waitMs: 10_000, root: resolveAppServerDiscoveryLockRoot() });
  fs.appendFileSync(tracePath, `START ${process.pid}\n`, 'utf8');
  if (crash) process.exit(23);
  sleep(holdMs);
  fs.appendFileSync(tracePath, `END ${process.pid}\n`, 'utf8');
  release();
  process.exit(0);
}

const here = fileURLToPath(import.meta.url);
const sandbox = fs.mkdtempSync(path.join(os.tmpdir(), 'ueef-discovery-lock-'));
const stateRoot = path.join(sandbox, 'state');
const discoveryRoot = path.join(sandbox, 'shared-discovery');
const tracePath = path.join(sandbox, 'trace.log');
fs.mkdirSync(stateRoot, { recursive: true });
fs.writeFileSync(tracePath, '', 'utf8');
const originalExplicitRoot = process.env.UEEF_APP_SERVER_DISCOVERY_LOCK_ROOT;
const originalGlobalPath = process.env.UEEF_GLOBAL_PATH;
delete process.env.UEEF_APP_SERVER_DISCOVERY_LOCK_ROOT;
process.env.UEEF_GLOBAL_PATH = path.join(sandbox, 'read-only-runtime-fixture');
const defaultDiscoveryRoot = resolveAppServerDiscoveryLockRoot();
assert.equal(path.dirname(defaultDiscoveryRoot), os.tmpdir(), 'default discovery lock must not live inside the managed runtime');
assert.match(path.basename(defaultDiscoveryRoot), /^ueef-app-server-discovery-/u);
if (originalExplicitRoot === undefined) delete process.env.UEEF_APP_SERVER_DISCOVERY_LOCK_ROOT;
else process.env.UEEF_APP_SERVER_DISCOVERY_LOCK_ROOT = originalExplicitRoot;
if (originalGlobalPath === undefined) delete process.env.UEEF_GLOBAL_PATH;
else process.env.UEEF_GLOBAL_PATH = originalGlobalPath;
const env = {
  ...process.env,
  UEEF_ALLOW_TEST_HOOK_STATE_ROOT: '1',
  UEEF_TEST_HOOK_STATE_ROOT: stateRoot,
  UEEF_APP_SERVER_DISCOVERY_LOCK_ROOT: discoveryRoot
};
process.env.UEEF_APP_SERVER_DISCOVERY_LOCK_ROOT = discoveryRoot;
assert.equal(resolveAppServerDiscoveryLockRoot(), discoveryRoot);

const runWorker = (extra = [], expectedCode = 0) => new Promise((resolve, reject) => {
  const child = spawn(process.execPath, [here, '--worker', tracePath, '200', ...extra], { env, windowsHide: true });
  child.once('error', reject);
  child.once('exit', (code, signal) => {
    try {
      assert.equal(signal, null, 'discovery-lock worker must exit without a signal');
      assert.equal(code, expectedCode, `unexpected discovery-lock worker exit: ${code}`);
      resolve();
    } catch (error) { reject(error); }
  });
});

try {
  await Promise.all([runWorker(), runWorker(), runWorker()]);
  const events = fs.readFileSync(tracePath, 'utf8').trim().split(/\r?\n/u);
  let active = 0;
  let maximumActive = 0;
  for (const event of events) {
    if (event.startsWith('START ')) active += 1;
    if (event.startsWith('END ')) active -= 1;
    maximumActive = Math.max(maximumActive, active);
    assert.ok(active >= 0, `invalid discovery-lock trace ordering: ${event}`);
  }
  assert.equal(active, 0, 'all discovery-lock workers must release their lock');
  assert.equal(maximumActive, 1, 'App Server discovery critical sections must be serialized');
  assert.equal(events.filter((event) => event.startsWith('START ')).length, 3);

  await runWorker(['--crash'], 23);
  await runWorker();
  const finalEvents = fs.readFileSync(tracePath, 'utf8').trim().split(/\r?\n/u);
  assert.equal(finalEvents.filter((event) => event.startsWith('START ')).length, 5);
  assert.equal(finalEvents.filter((event) => event.startsWith('END ')).length, 4);
  process.stdout.write('App Server discovery lock tests passed\n');
} finally {
  fs.rmSync(sandbox, { recursive: true, force: true });
}
