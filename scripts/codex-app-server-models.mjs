import { spawn } from 'node:child_process';
import { acquireAppServerDiscoveryLock, resolveAppServerDiscoveryLockRoot, resolveCodexExecutable } from './codex-app-server-client-lib.mjs';

const args = process.argv.slice(2);
const valueAfter = (flag) => { const i = args.indexOf(flag); return i === -1 ? null : args[i + 1] || null; };
const { executable, executableSource } = resolveCodexExecutable(valueAfter('--executable'));
const timeoutMs = Number(valueAfter('--timeout-ms') || 15000);
const discoveryLockWaitMs = Number(valueAfter('--discovery-lock-wait-ms') || 60000);
if (!Number.isInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 300_000) {
  throw new Error('--timeout-ms requires an integer from 1 to 300000.');
}
if (!Number.isInteger(discoveryLockWaitMs) || discoveryLockWaitMs < 1 || discoveryLockWaitMs > 300_000) {
  throw new Error('--discovery-lock-wait-ms requires an integer from 1 to 300000.');
}
const includeHidden = !args.includes('--picker-visible-only');
const releaseDiscoveryLock = acquireAppServerDiscoveryLock({ waitMs: discoveryLockWaitMs, root: resolveAppServerDiscoveryLockRoot() });
let child;
try {
  child = spawn(executable, ['app-server'], { stdio: ['pipe', 'pipe', 'pipe'], windowsHide: true });
} catch (error) {
  releaseDiscoveryLock();
  process.stderr.write(`Codex App Server catalog discovery failed: ${error.message}\n`);
  process.exit(1);
}
let complete = false;
let lockReleased = false;
let shutdownTimer = null;
let buffer = '';
const collectedModels = [];
const seenCursors = new Set();
const requestModels = (cursor = null) => {
  const params = { limit: 100, includeHidden };
  if (cursor) params.cursor = cursor;
  send({ method: 'model/list', id: 1, params });
};
const finish = (error) => {
  if (complete) return;
  complete = true;
  clearTimeout(timer);
  if (error) { process.stderr.write(`Codex App Server catalog discovery failed: ${error.message}\n`); process.exitCode = 1; }
  if (child.exitCode === null && child.signalCode === null) {
    child.kill();
    shutdownTimer = setTimeout(() => {
      if (child.exitCode === null && child.signalCode === null) child.kill('SIGKILL');
    }, 5000);
    shutdownTimer.unref();
  }
  else releaseLockOnce();
};
const releaseLockOnce = () => {
  if (lockReleased) return;
  lockReleased = true;
  if (shutdownTimer) clearTimeout(shutdownTimer);
  releaseDiscoveryLock();
  child.stdin.destroy();
  child.stdout.destroy();
  child.stderr.destroy();
};
const send = (message) => child.stdin.write(`${JSON.stringify(message)}\n`);
const timer = setTimeout(() => finish(new Error(`Timed out after ${timeoutMs} ms`)), timeoutMs);
child.once('close', releaseLockOnce);
child.on('error', (error) => { finish(error); if (!child.pid) releaseLockOnce(); });
child.stderr.on('data', () => {});
child.stdout.on('data', (chunk) => {
  buffer += chunk;
  for (;;) {
    const end = buffer.indexOf('\n');
    if (end === -1) break;
    const line = buffer.slice(0, end); buffer = buffer.slice(end + 1);
    if (!line.trim()) continue;
    let message; try { message = JSON.parse(line); } catch { continue; }
    if (message.id === 0) { send({ method: 'initialized', params: {} }); requestModels(); }
    if (message.id === 1) {
      if (message.error) return finish(new Error(message.error.message || 'model/list failed'));
      const page = message.result?.data || message.result || [];
      if (!Array.isArray(page)) return finish(new Error('model/list returned a non-array data payload'));
      collectedModels.push(...page);
      const nextCursor = message.result?.nextCursor || null;
      if (nextCursor) {
        if (seenCursors.has(nextCursor)) return finish(new Error('model/list returned a repeated pagination cursor'));
        seenCursors.add(nextCursor);
        requestModels(nextCursor);
        continue;
      }
      // Preserve the source of this response.  Consumers must never mistake an
      // arbitrary JSON file (or a screenshot-derived fixture) for the signed-in
      // account catalog.
      process.stdout.write(`${JSON.stringify({
        schemaVersion: 1,
        discoveredAt: new Date().toISOString(),
        provenance: {
          provider: 'codex-app-server:model/list',
          executable,
          executableSource
        },
        data: collectedModels
      })}\n`); finish();
    }
  }
});
send({ method: 'initialize', id: 0, params: { clientInfo: { name: 'ueef-model-routing', title: 'UEEF model routing', version: '1.0.0' } } });
