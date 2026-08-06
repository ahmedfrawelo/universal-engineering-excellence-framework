import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { resolveCodexExecutable } from './codex-app-server-client-lib.mjs';

const args = process.argv.slice(2);
const valueAfter = (flag) => {
  const index = args.indexOf(flag);
  return index === -1 ? null : args[index + 1] || null;
};
const cwd = path.resolve(valueAfter('--cwd') || path.dirname(path.dirname(fileURLToPath(import.meta.url))));
const stateDir = path.resolve(valueAfter('--state-dir') || 'D:/shared folder/codex-home/ueef/hook-state');
const timeoutMs = Number(valueAfter('--timeout-ms') || 90000);
const { executable, executableSource } = resolveCodexExecutable(valueAfter('--executable'));
const startedAt = Date.now();
const requiredLabels = [
  'UEEF: active',
  'Loaded: boot-loader, core-system',
  'Selected: T0 live managed-hook verification',
  'Gates: live hook invocation only',
  'Tools: none',
  'Skills: none',
  'UIUX: NA',
  'Status: ACTIVE'
].join('\n');
const prompt = `Do not use tools. Reply with exactly these eight lines and nothing else:\n${requiredLabels}`;

let child;
try {
  const executableArgs = args.includes('--bypass-hook-trust')
    ? ['--dangerously-bypass-hook-trust', 'app-server']
    : ['app-server'];
  child = spawn(executable, executableArgs, {
    stdio: ['pipe', 'pipe', 'pipe'],
    windowsHide: true
  });
} catch (error) {
  process.stderr.write(`Live managed-hook verification failed: ${error.message}\n`);
  process.exit(1);
}

let buffer = '';
let stderr = '';
let finished = false;
let threadId = null;
let turnId = null;
let turnStatus = null;
let finalText = '';
const send = (message) => child.stdin.write(`${JSON.stringify(message)}\n`);
const finish = (error = null) => {
  if (finished) return;
  finished = true;
  clearTimeout(timer);
  child.kill();
  if (error) {
    process.stderr.write(`Live managed-hook verification failed: ${error.message}\n${stderr}`);
    process.exitCode = 1;
    return;
  }
  const artifacts = fs.existsSync(stateDir)
    ? fs.readdirSync(stateDir)
      .filter((name) => name.endsWith('.json'))
      .map((name) => path.join(stateDir, name))
      .filter((file) => fs.statSync(file).mtimeMs >= startedAt - 1000)
    : [];
  const states = artifacts.flatMap((file) => {
    try { return [{ file, state: JSON.parse(fs.readFileSync(file, 'utf8')) }]; }
    catch { return []; }
  });
  const turnState = states.find(({ state }) => state.sessionId === threadId && state.turnId === turnId);
  if (turnStatus !== 'completed') {
    process.stderr.write(`Live managed-hook verification failed: turn status was ${turnStatus || 'unknown'}.\n`);
    process.exitCode = 1;
    return;
  }
  if (!turnState) {
    process.stderr.write(`Live managed-hook verification failed: no digest-bound UserPromptSubmit state was created.\n${stderr}`);
    process.exitCode = 1;
    return;
  }
  process.stdout.write(`${JSON.stringify({
    schemaVersion: 1,
    verifiedAt: new Date().toISOString(),
    provenance: {
      provider: 'codex-app-server:thread/start+turn/start+managed-hook-state',
      executable,
      executableSource
    },
    threadId,
    turnId,
    turnStatus,
    ephemeral: true,
    hookArtifact: turnState.file,
    hookValidations: turnState.state.validations,
    finalLabelsMatched: finalText.trim() === requiredLabels
  })}\n`);
};
const timer = setTimeout(() => finish(new Error(`Timed out after ${timeoutMs} ms`)), timeoutMs);

child.on('error', finish);
child.stderr.on('data', (chunk) => { stderr += chunk.toString(); });
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
      send({ method: 'thread/start', id: 1, params: {
        cwd,
        approvalPolicy: 'never',
        sandbox: 'read-only',
        ephemeral: true,
        allowProviderModelFallback: false
      } });
      continue;
    }
    if (message.id === 1) {
      if (message.error) return finish(new Error(message.error.message || 'thread/start failed'));
      threadId = message.result?.thread?.id || null;
      if (!threadId) return finish(new Error('thread/start returned no thread id'));
      send({ method: 'turn/start', id: 2, params: {
        threadId,
        input: [{ type: 'text', text: prompt }],
        cwd,
        approvalPolicy: 'never',
        sandboxPolicy: { type: 'readOnly', networkAccess: false },
        summary: 'concise',
        personality: 'pragmatic'
      } });
      continue;
    }
    if (message.id === 2) {
      if (message.error) return finish(new Error(message.error.message || 'turn/start failed'));
      turnId = message.result?.turn?.id || null;
      continue;
    }
    if (message.method === 'item/completed') {
      const item = message.params?.item;
      if (item?.type === 'agentMessage' && typeof item.text === 'string') finalText = item.text;
      continue;
    }
    if (message.method === 'turn/completed') {
      turnId = message.params?.turn?.id || turnId;
      turnStatus = message.params?.turn?.status || 'failed';
      if (turnStatus !== 'completed') {
        return finish(new Error(message.params?.turn?.error?.message || `turn status ${turnStatus}`));
      }
      setTimeout(() => finish(), 250);
    }
  }
});

send({
  method: 'initialize',
  id: 0,
  params: {
    clientInfo: {
      name: 'ueef-live-managed-hook-verification',
      title: 'UEEF live managed-hook verification',
      version: '1.0.0'
    },
    capabilities: { experimentalApi: true }
  }
});
