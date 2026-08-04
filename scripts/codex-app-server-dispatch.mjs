import { spawn } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { appServerSandboxPolicy, resolveCodexExecutable } from './codex-app-server-client-lib.mjs';

const args = process.argv.slice(2);
const valueAfter = (flag) => { const index = args.indexOf(flag); return index === -1 ? null : args[index + 1] || null; };
const routePath = valueAfter('--route');
const promptPath = valueAfter('--prompt-file');
const promptValue = valueAfter('--prompt');
const outputPath = valueAfter('--output');
const cwd = path.resolve(valueAfter('--cwd') || process.cwd());
const sandbox = valueAfter('--sandbox') || 'read-only';
const timeoutMs = Number(valueAfter('--timeout-ms') || 10 * 60 * 1000);
const responseLanguage = valueAfter('--response-language') || 'auto';
const { executable, executableSource } = resolveCodexExecutable(valueAfter('--executable'));
const executableArgs = args.flatMap((entry, index) => entry === '--executable-arg' && args[index + 1] ? [args[index + 1]] : []);

if (!routePath || Boolean(promptPath) === Boolean(promptValue)) throw new Error('Provide --route <route.json> and exactly one of --prompt-file <prompt.txt> or --prompt <text>.');
if (!fs.existsSync(routePath) || (promptPath && !fs.existsSync(promptPath))) throw new Error('Route or prompt file does not exist.');
if (!fs.existsSync(cwd) || !fs.statSync(cwd).isDirectory()) throw new Error(`Working directory does not exist: ${cwd}`);
if (!['read-only', 'workspace-write', 'danger-full-access'].includes(sandbox)) throw new Error(`Unsupported sandbox mode: ${sandbox}`);
if (!Number.isFinite(timeoutMs) || timeoutMs < 1_000 || timeoutMs > 60 * 60 * 1000) throw new Error('timeout-ms must be from 1000 to 3600000.');
if (responseLanguage !== 'auto' && !/^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*$/u.test(responseLanguage)) throw new Error('--response-language must be auto or a BCP-47 language tag.');

const route = JSON.parse(fs.readFileSync(routePath, 'utf8'));
const catalogIdentity = (route.catalogCoverage || []).map((entry) => ({
  model: entry.model,
  hidden: entry.hidden,
  capabilityClass: entry.capabilityClass,
  supportedReasoningEfforts: entry.supportedReasoningEfforts,
  defaultReasoningEffort: entry.defaultReasoningEffort,
  upgrade: entry.upgrade
}));
const computedCatalogDigest = crypto.createHash('sha256').update(JSON.stringify(catalogIdentity), 'utf8').digest('hex');
if (!route.catalogDigest || route.catalogDigest !== computedCatalogDigest) throw new Error('Dispatch route catalog digest does not match canonical catalog coverage.');
const computedRouteDigest = crypto.createHash('sha256').update(JSON.stringify({
  tier: route.tier,
  workUnitId: route.workUnitId || null,
  invocationIndex: route.invocationIndex ?? 0,
  preferredModel: route.preferredModel,
  hostReasoning: route.hostReasoning,
  fallbackModel: route.fallbackModel || null,
  fallbackHostReasoning: route.fallbackHostReasoning || null,
  catalogDigest: route.catalogDigest,
  catalogProvider: route.catalogProvider,
  catalogDiscoveredAt: route.catalogDiscoveredAt
}), 'utf8').digest('hex');
if (route.accountCatalogVerified !== true || route.catalogFresh !== true || route.catalogContractValid !== true) throw new Error('Dispatch requires a fresh account-verified App Server route.');
if (!route.preferredModel || !route.hostReasoning) throw new Error('Dispatch route is missing preferredModel or hostReasoning.');
if (!route.routeDigest || route.routeDigest !== computedRouteDigest) throw new Error('Dispatch route digest does not bind the complete route identity.');
const discoveredAtMs = Date.parse(route.catalogDiscoveredAt || '');
if (!Number.isFinite(discoveredAtMs) || Date.now() - discoveredAtMs > 10 * 60 * 1000 || discoveredAtMs - Date.now() > 60_000) throw new Error('Dispatch route is stale. Resolve it again immediately before dispatch.');

const prompt = promptPath ? fs.readFileSync(promptPath, 'utf8') : promptValue;
if (!prompt.trim() || Buffer.byteLength(prompt, 'utf8') > 256 * 1024) throw new Error('Prompt must contain 1 to 262144 UTF-8 bytes.');

const child = spawn(executable, [...executableArgs, 'app-server'], { stdio: ['pipe', 'pipe', 'pipe'], windowsHide: true, cwd });
let buffer = '';
let stderr = '';
let finished = false;
let threadId = null;
let turnId = null;
let finalText = '';
let turnStatus = null;
let turnError = null;
let acceptedModel = null;
let acceptedHostReasoning = null;
let threadStartReasoningEffort = null;
const modelReroutes = [];
const attempts = [];
let attemptIndex = 0;
let selectedModel = route.preferredModel;
let selectedHostReasoning = route.hostReasoning;
const startedAt = new Date().toISOString();

const emitResult = (value) => {
  const serialized = `${JSON.stringify(value, null, outputPath ? 2 : 0)}\n`;
  if (outputPath) {
    fs.mkdirSync(path.dirname(path.resolve(outputPath)), { recursive: true });
    fs.writeFileSync(outputPath, serialized, { flag: 'wx' });
  }
  process.stdout.write(serialized);
};

const send = (message) => child.stdin.write(`${JSON.stringify(message)}\n`);
const stopChild = () => {
  if (!child.killed) child.kill();
};
const finish = (error = null) => {
  if (finished) return;
  finished = true;
  clearTimeout(timer);
  stopChild();
  if (error) {
    process.stderr.write(`Codex App Server dispatch failed: ${error.message}\n`);
    process.exitCode = 1;
    return;
  }
  const providerMessage = String(turnError?.message || turnError || '');
  const capacity = providerMessage.includes('Selected model is at capacity');
  const result = capacity ? 'CAPACITY' : turnStatus === 'completed' ? 'SUCCESS' : turnStatus === 'interrupted' ? 'INTERRUPTED' : 'FAILED';
  const effectiveModel = modelReroutes.filter((entry) => entry.attemptIndex === attemptIndex).at(-1)?.toModel || acceptedModel;
  const executionVerified = result === 'SUCCESS' && Boolean(effectiveModel) && Boolean(acceptedHostReasoning);
  emitResult({
    schemaVersion: 1,
    provider: 'codex-app-server:turn/start',
    executableSource,
    ephemeral: true,
    threadId,
    turnId,
    requestedModel: route.preferredModel,
    requestedHostReasoning: route.hostReasoning,
    routeDigest: route.routeDigest,
    attemptId: attempts.at(-1)?.requestId || turnId || null,
    responseLanguage,
    acceptedModel,
    acceptedHostReasoning,
    threadStartReasoningEffort,
    actualModel: executionVerified ? effectiveModel : null,
    actualHostReasoning: executionVerified ? acceptedHostReasoning : null,
    executionVerified,
    executionVerificationSource: executionVerified ? 'codex-app-server:thread/start+thread/settings/updated+model/rerouted' : null,
    modelReroutes,
    attempts,
    capacityFallbackUsed: attemptIndex === 1,
    providerModelFallbackAllowed: false,
    result,
    errorMessage: providerMessage || null,
    finalText,
    startedAt,
    completedAt: new Date().toISOString()
  });
};
const timer = setTimeout(() => finish(new Error(`Timed out after ${timeoutMs} ms`)), timeoutMs);

const startThread = () => {
  const requestId = 1 + (attemptIndex * 2);
  send({ method: 'thread/start', id: requestId, params: {
    model: selectedModel,
    cwd,
    approvalPolicy: 'never',
    sandbox,
    ephemeral: true,
    allowProviderModelFallback: false,
    personality: 'pragmatic',
    serviceName: 'ueef-model-routing'
  } });
};
const startSingleFallback = (errorMessage, stage) => {
  if (!String(errorMessage).includes('Selected model is at capacity') || attemptIndex !== 0 || !route.fallbackModel || !route.fallbackHostReasoning) return false;
  const requestId = stage === 'thread/start' ? 1 + (attemptIndex * 2) : 2 + (attemptIndex * 2);
  attempts.push({ attemptIndex, stage, requestId, model: selectedModel, hostReasoning: selectedHostReasoning, threadId, turnId, result: 'CAPACITY', errorMessage: String(errorMessage) });
  attemptIndex = 1;
  selectedModel = route.fallbackModel;
  selectedHostReasoning = route.fallbackHostReasoning;
  acceptedModel = null;
  acceptedHostReasoning = null;
  threadStartReasoningEffort = null;
  threadId = null;
  turnId = null;
  turnStatus = null;
  turnError = null;
  finalText = '';
  startThread();
  return true;
};
const finishAttemptFailure = (errorMessage, stage) => {
  const message = String(errorMessage || `${stage} failed`);
  turnStatus = 'failed';
  turnError = { message };
  attempts.push({
    attemptIndex,
    stage,
    requestId: stage === 'thread/start' ? 1 + (attemptIndex * 2) : 2 + (attemptIndex * 2),
    model: selectedModel,
    hostReasoning: selectedHostReasoning,
    threadId,
    turnId,
    result: message.includes('Selected model is at capacity') ? 'CAPACITY' : 'FAILED',
    errorMessage: message
  });
  finish();
};

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
      startThread();
      continue;
    }
    if (message.id === 1 + (attemptIndex * 2)) {
      if (message.error) {
        const errorMessage = message.error.message || 'thread/start failed';
        if (startSingleFallback(errorMessage, 'thread/start')) continue;
        return finishAttemptFailure(errorMessage, 'thread/start');
      }
      threadId = message.result?.thread?.id;
      acceptedModel = message.result?.model || null;
      threadStartReasoningEffort = message.result?.reasoningEffort || null;
      if (!threadId) return finish(new Error('thread/start did not return a thread id'));
      if (!acceptedModel) return finish(new Error('thread/start did not return the effective model'));
      if (acceptedModel !== selectedModel) {
        return finish(new Error(`App Server accepted model ${acceptedModel}, not the routed ${selectedModel}`));
      }
      send({ method: 'turn/start', id: 2 + (attemptIndex * 2), params: {
        threadId,
        input: [{ type: 'text', text: prompt }],
        cwd,
        approvalPolicy: 'never',
        sandboxPolicy: appServerSandboxPolicy(sandbox, cwd),
        model: selectedModel,
        effort: selectedHostReasoning,
        summary: 'concise',
        personality: 'pragmatic',
        additionalContext: responseLanguage === 'auto' ? null : {
          'ueef-response-language': { kind: 'application', value: `Respond in the language identified by BCP-47 tag ${responseLanguage}. Keep technical identifiers unchanged.` }
        }
      } });
      continue;
    }
    if (message.id === 2 + (attemptIndex * 2)) {
      if (message.error) {
        const errorMessage = message.error.message || 'turn/start failed';
        if (startSingleFallback(errorMessage, 'turn/start')) continue;
        return finishAttemptFailure(errorMessage, 'turn/start');
      }
      turnId = message.result?.turn?.id || null;
      continue;
    }
    if (message.method === 'item/completed') {
      const item = message.params?.item;
      if (item?.type === 'agentMessage' && typeof item.text === 'string') finalText = item.text;
      continue;
    }
    if (message.method === 'thread/settings/updated') {
      const settings = message.params?.threadSettings || {};
      if (message.params?.threadId === threadId) {
        acceptedModel = settings.model || acceptedModel;
        acceptedHostReasoning = settings.effort || acceptedHostReasoning;
      }
      continue;
    }
    if (message.method === 'model/rerouted') {
      modelReroutes.push({
        fromModel: message.params?.fromModel || null,
        toModel: message.params?.toModel || null,
        reason: message.params?.reason || null,
        threadId: message.params?.threadId || threadId,
        turnId: message.params?.turnId || turnId,
        attemptIndex
      });
      continue;
    }
    if (message.method === 'turn/completed') {
      const turn = message.params?.turn || {};
      turnId = turn.id || turnId;
      turnStatus = turn.status || 'failed';
      turnError = turn.error || null;
      const providerMessage = String(turnError?.message || turnError || '');
      if (startSingleFallback(providerMessage, 'turn/completed')) continue;
      attempts.push({
        attemptIndex,
        stage: 'turn/completed',
        requestId: 2 + (attemptIndex * 2),
        model: selectedModel,
        hostReasoning: selectedHostReasoning,
        threadId,
        turnId,
        result: providerMessage.includes('Selected model is at capacity') ? 'CAPACITY' : turnStatus === 'completed' ? 'SUCCESS' : turnStatus === 'interrupted' ? 'INTERRUPTED' : 'FAILED',
        errorMessage: providerMessage || null
      });
      finish();
    }
  }
});

send({ method: 'initialize', id: 0, params: {
  clientInfo: { name: 'ueef-model-routing', title: 'UEEF routed execution', version: '1.0.0' },
  capabilities: { experimentalApi: true }
} });
