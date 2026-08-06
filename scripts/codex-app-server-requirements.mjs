import { spawn } from 'node:child_process';
import { resolveCodexExecutable } from './codex-app-server-client-lib.mjs';

const args = process.argv.slice(2);
const valueAfter = (flag) => {
  const index = args.indexOf(flag);
  return index === -1 ? null : args[index + 1] || null;
};
const { executable, executableSource } = resolveCodexExecutable(valueAfter('--executable'));
const timeoutMs = Number(valueAfter('--timeout-ms') || 15000);

let child;
try {
  child = spawn(executable, ['app-server'], {
    stdio: ['pipe', 'pipe', 'pipe'],
    windowsHide: true
  });
} catch (error) {
  process.stderr.write(`Codex App Server requirements discovery failed: ${error.message}\n`);
  process.exit(1);
}

let complete = false;
let buffer = '';
let requirements = null;
const send = (message) => child.stdin.write(`${JSON.stringify(message)}\n`);
const finish = (error) => {
  if (complete) return;
  complete = true;
  clearTimeout(timer);
  child.kill();
  if (error) {
    process.stderr.write(`Codex App Server requirements discovery failed: ${error.message}\n`);
    process.exitCode = 1;
  }
};
const timer = setTimeout(
  () => finish(new Error(`Timed out after ${timeoutMs} ms`)),
  timeoutMs
);

child.on('error', finish);
child.stderr.on('data', () => {});
child.stdout.on('data', (chunk) => {
  buffer += chunk;
  for (;;) {
    const end = buffer.indexOf('\n');
    if (end === -1) break;
    const line = buffer.slice(0, end);
    buffer = buffer.slice(end + 1);
    if (!line.trim()) continue;
    let message;
    try { message = JSON.parse(line); } catch { continue; }
    if (message.id === 0) {
      if (message.error) return finish(new Error(message.error.message || 'initialize failed'));
      send({ method: 'initialized', params: {} });
      send({ method: 'configRequirements/read', id: 1, params: {} });
    }
    if (message.id === 1) {
      if (message.error) return finish(new Error(message.error.message || 'configRequirements/read failed'));
      requirements = message.result ?? null;
      send({ method: 'config/read', id: 2, params: { includeLayers: false } });
    }
    if (message.id === 2) {
      if (message.error) return finish(new Error(message.error.message || 'config/read failed'));
      const config = message.result?.config || message.result || {};
      process.stdout.write(`${JSON.stringify({
        schemaVersion: 1,
        discoveredAt: new Date().toISOString(),
        provenance: {
          provider: 'codex-app-server:configRequirements/read',
          executable,
          executableSource
        },
        data: {
          requirements,
          effective: {
            userHooksFeatureOverride: typeof config.features?.hooks === 'boolean' ? config.features.hooks : null,
            hooksConfigured: config.hooks != null,
            hookEventCounts: Object.fromEntries(Object.entries(config.hooks || {}).map(([name, groups]) => [name, Array.isArray(groups) ? groups.length : 0]))
          }
        }
      })}\n`);
      finish();
    }
  }
});

send({
  method: 'initialize',
  id: 0,
  params: {
    clientInfo: {
      name: 'ueef-managed-enforcement-status',
      title: 'UEEF managed enforcement status',
      version: '1.0.0'
    }
  }
});
