import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { appServerSandboxPolicy, resolveCodexExecutable } from './codex-app-server-client-lib.mjs';

const args = process.argv.slice(2);
const valueAfter = (flag) => {
  const index = args.indexOf(flag);
  return index === -1 ? null : args[index + 1] || null;
};
const has = (flag) => args.includes(flag);

const threadId = valueAfter('--thread-id');
const routePath = valueAfter('--route');
const modelArg = valueAfter('--model');
const effortArg = valueAfter('--effort');
const outputPath = valueAfter('--output');
const cwd = path.resolve(valueAfter('--cwd') || process.cwd());
const timeoutMs = Number(valueAfter('--timeout-ms') || 30_000);
const dryRun = has('--dry-run');
const resumeFirst = has('--resume-first');
const { executable, executableSource } = resolveCodexExecutable(valueAfter('--executable'));
const executableArgs = args.flatMap((entry, index) => entry === '--executable-arg' && args[index + 1] ? [args[index + 1]] : []);

if (!threadId || !/^[A-Za-z0-9._:-]{8,160}$/u.test(threadId)) throw new Error('Provide an explicit --thread-id. UEEF never guesses or discovers the current UI thread.');
if (Boolean(routePath) === Boolean(modelArg || effortArg)) throw new Error('Provide either --route <route.json> or both --model <id> --effort <host-effort>.');
if (!fs.existsSync(cwd) || !fs.statSync(cwd).isDirectory()) throw new Error(`Working directory does not exist: ${cwd}`);
if (!Number.isFinite(timeoutMs) || timeoutMs < 1_000 || timeoutMs > 300_000) throw new Error('timeout-ms must be from 1000 to 300000.');

let requestedModel = modelArg;
let requestedEffort = effortArg;
let routeDigest = null;
if (routePath) {
  if (!fs.existsSync(routePath)) throw new Error(`Route file does not exist: ${routePath}`);
  const route = JSON.parse(fs.readFileSync(routePath, 'utf8').replace(/^\uFEFF/u, ''));
  requestedModel = route.preferredModel;
  requestedEffort = route.hostReasoning;
  routeDigest = route.routeDigest || null;
}
if (!requestedModel || !requestedEffort) throw new Error('Target model and effort are required.');
if (!/^[A-Za-z0-9._:-]+$/u.test(requestedModel)) throw new Error(`Invalid model identifier: ${requestedModel}`);
if (!/^[A-Za-z0-9._:-]+$/u.test(requestedEffort)) throw new Error(`Invalid host effort: ${requestedEffort}`);

const resultBase = {
  schemaVersion: 1,
  provider: 'codex-app-server:thread/settings/update',
  executableSource,
  threadId,
  requestedModel,
  requestedHostReasoning: requestedEffort,
  routeDigest,
  dryRun,
  resumeFirst,
  observedAt: new Date().toISOString(),
};
const emitResult = (value) => {
  const serialized = `${JSON.stringify(value, null, outputPath ? 2 : 0)}\n`;
  if (outputPath) {
    fs.mkdirSync(path.dirname(path.resolve(outputPath)), { recursive: true });
    fs.writeFileSync(outputPath, serialized, { flag: 'wx' });
  }
  process.stdout.write(serialized);
};

if (dryRun) {
  emitResult({ ...resultBase, result: 'DRY_RUN' });
  process.exit(0);
}

const child = spawn(executable, [...executableArgs, 'app-server'], { stdio: ['pipe', 'pipe', 'pipe'], windowsHide: true, cwd });
let buffer = '';
let stderr = '';
let finished = false;
let updateAcknowledged = false;
let readBackRequested = false;
let observedModel = null;
let observedEffort = null;

const send = (message) => child.stdin.write(`${JSON.stringify(message)}\n`);
const finish = (error = null) => {
  if (finished) return;
  finished = true;
  clearTimeout(timer);
  if (!child.killed) child.kill();
  if (error) {
    process.stderr.write(`Codex thread settings update failed: ${error.message}\n`);
    process.exitCode = 1;
    return;
  }
  const verified = updateAcknowledged && observedModel === requestedModel && observedEffort === requestedEffort;
  emitResult({
    ...resultBase,
    acceptedModel: observedModel,
    acceptedHostReasoning: observedEffort,
    uiPickerMutationAttempted: true,
    uiPickerMutationVerified: verified,
    result: verified ? 'SUCCESS' : 'UNVERIFIED',
  });
};
const timer = setTimeout(() => finish(new Error(`Timed out after ${timeoutMs} ms`)), timeoutMs);

child.on('error', (error) => finish(error));
child.stderr.on('data', (chunk) => { stderr += chunk.toString(); });
child.on('exit', (code) => {
  if (!finished && code !== 0) finish(new Error(stderr.trim() || `App Server exited with code ${code}`));
});
child.stdout.on('data', (chunk) => {
  buffer += chunk.toString();
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
      if (resumeFirst) {
        send({ method: 'thread/resume', id: 1, params: { threadId } });
      } else {
        send({ method: 'thread/settings/update', id: 1, params: {
          threadId,
          threadSettings: { model: requestedModel, effort: requestedEffort },
          settings: { model: requestedModel, effort: requestedEffort },
          model: requestedModel,
          effort: requestedEffort,
        } });
      }
      continue;
    }
    if (message.id === 1 && resumeFirst) {
      if (message.error) return finish(new Error(message.error.message || 'thread/resume failed'));
      send({ method: 'thread/settings/update', id: 2, params: {
        threadId,
        threadSettings: { model: requestedModel, effort: requestedEffort },
        settings: { model: requestedModel, effort: requestedEffort },
        model: requestedModel,
        effort: requestedEffort,
      } });
      continue;
    }
    if (message.id === (resumeFirst ? 2 : 1)) {
      if (message.error) return finish(new Error(message.error.message || 'thread/settings/update failed'));
      updateAcknowledged = true;
      readBackRequested = true;
      send({ method: 'thread/resume', id: 3, params: { threadId } });
      continue;
    }
    if (message.id === 3) {
      if (message.error) return finish(new Error(message.error.message || 'thread/resume after settings update failed'));
      observedModel = message.result?.model || message.result?.thread?.model || observedModel;
      observedEffort = message.result?.reasoningEffort || message.result?.thread?.reasoningEffort || observedEffort;
      return finish();
    }
    if (message.method === 'thread/settings/updated' && message.params?.threadId === threadId) {
      const settings = message.params?.threadSettings || {};
      observedModel = settings.model || observedModel;
      observedEffort = settings.effort || observedEffort;
      if (readBackRequested && (!observedModel || !observedEffort)) return;
      return finish();
    }
  }
});

send({ method: 'initialize', id: 0, params: {
  clientInfo: { name: 'ueef-thread-settings', title: 'UEEF thread settings update', version: '1.0.0' },
  capabilities: { experimentalApi: true },
  sandboxPolicy: appServerSandboxPolicy('read-only', cwd),
} });
