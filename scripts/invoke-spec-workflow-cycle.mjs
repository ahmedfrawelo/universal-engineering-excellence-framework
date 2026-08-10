import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { fileURLToPath } from 'node:url';

const args = process.argv.slice(2);
const valueAfter = (flag) => {
  const index = args.indexOf(flag);
  return index === -1 ? null : args[index + 1] || null;
};
const required = (flag) => {
  const value = valueAfter(flag);
  if (!value) throw new Error(`${flag} is required`);
  return path.resolve(value);
};
const scripts = path.dirname(fileURLToPath(import.meta.url));
const graph = required('--graph');
const state = required('--state');
const route = required('--route');
const specRoot = required('--spec-root');
const cwd = path.resolve(valueAfter('--cwd') || process.cwd());
const adapter = valueAfter('--adapter') || 'codex';
const executionMode = valueAfter('--execution-mode') || 'managed-production';
const hostExecutable = valueAfter('--host-executable');
const hostArgs = args.flatMap((value, index) => value === '--host-arg' ? [args[index + 1]] : []).filter(Boolean);
const maxCycles = Number(valueAfter('--max-cycles') || 100);
const bridgeOverride = valueAfter('--bridge');
const lockTimeoutMs = Number(valueAfter('--lock-timeout-ms') || 10 * 60 * 1000);
const bridge = path.resolve(bridgeOverride || path.join(scripts, `invoke-spec-workflow-${adapter}-host.mjs`));
const engine = path.join(scripts, 'invoke-spec-workflow-engine.ps1');
const approvals = path.join(specRoot, 'approvals.json');

if (!['codex', 'claude', 'generic'].includes(adapter)) throw new Error('--adapter must be codex, claude, or generic');
if (!['managed-production', 'external', 'test'].includes(executionMode)) throw new Error('--execution-mode must be managed-production, external, or test');
if (bridgeOverride) throw new Error('--bridge overrides are forbidden; select an adapter and use its owned host bridge');
if (executionMode === 'managed-production' && adapter !== 'codex') throw new Error('managed-production execution requires the codex adapter');
if (executionMode === 'managed-production' && hostExecutable) throw new Error('managed-production execution forbids host executable overrides');
if (executionMode === 'external' && !['claude', 'generic'].includes(adapter)) throw new Error('external execution requires the claude or generic adapter');
if (executionMode === 'test' && adapter !== 'generic') throw new Error('test execution requires the generic adapter');
if (adapter === 'generic' && !hostExecutable) throw new Error('--host-executable is required for generic adapter');
if (!Number.isInteger(maxCycles) || maxCycles < 1 || maxCycles > 1000) throw new Error('--max-cycles must be from 1 through 1000');
if (!Number.isInteger(lockTimeoutMs) || lockTimeoutMs < 1000 || lockTimeoutMs > 15 * 60 * 1000) throw new Error('--lock-timeout-ms must be from 1000 through 900000');
for (const [name, target] of Object.entries({ graph, route, specRoot, cwd, bridge, engine })) {
  if (!fs.existsSync(target)) throw new Error(`${name} does not exist: ${target}`);
}

function engineCall(commandArgs) {
  const result = spawnSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', engine, ...commandArgs], { cwd, encoding: 'utf8', windowsHide: true });
  if (result.status !== 0) throw new Error((result.stderr || result.stdout || 'spec workflow engine failed').trim());
  try { return JSON.parse(result.stdout); } catch { throw new Error(`engine returned invalid JSON for ${commandArgs[0]}`); }
}

const sleepBuffer = new Int32Array(new SharedArrayBuffer(4));
const sleep = (milliseconds) => Atomics.wait(sleepBuffer, 0, 0, milliseconds);
function acquireCycleLock(statePath) {
  const canonicalState = fs.existsSync(statePath)
    ? fs.realpathSync.native(statePath)
    : path.join(fs.realpathSync.native(path.dirname(statePath)), path.basename(statePath));
  const lockPath = `${canonicalState}.cycle-lock.sqlite`;
  const database = new DatabaseSync(lockPath);
  let acquired = false;
  try {
    database.exec(`PRAGMA busy_timeout=${lockTimeoutMs}; BEGIN EXCLUSIVE;`);
    acquired = true;
    database.exec('CREATE TABLE IF NOT EXISTS cycle_lock (state TEXT NOT NULL, pid INTEGER NOT NULL, acquired_at TEXT NOT NULL); DELETE FROM cycle_lock;');
    database.prepare('INSERT INTO cycle_lock (state, pid, acquired_at) VALUES (?, ?, ?)').run(canonicalState, process.pid, new Date().toISOString());
    const acquiredDelay = Number(process.env.UEEF_TEST_LOCK_AFTER_ACQUIRE_DELAY_MS || 0);
    if (Number.isInteger(acquiredDelay) && acquiredDelay > 0 && acquiredDelay <= 10_000) {
      sleep(acquiredDelay);
    }
    return () => {
      try {
        database.exec('COMMIT;');
      } finally {
        database.close();
      }
    };
  } catch (error) {
    try {
      if (acquired) database.exec('ROLLBACK;');
    } finally {
      database.close();
    }
    if (String(error).includes('database is locked')) {
      throw new Error(`timed out waiting for workflow cycle lock: ${lockPath}`);
    }
    throw error;
  }
}

const releaseCycleLock = acquireCycleLock(state);
let temporary = null;
let dispatched = 0;
let applied = 0;
let verifiedHostExecutions = 0;
let terminalReport = null;
try {
  temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'ueef-spec-cycle-'));
  const graphDocument = JSON.parse(fs.readFileSync(graph, 'utf8'));
  const readiness = engineCall([
    'prepare', '--root', specRoot, '--workflow-id', graphDocument.workflowId, '--route', route,
  ]);
  const validation = engineCall(['validate', '--graph', graph]);
  if (readiness.status !== 'READY' || readiness.graphDigest !== validation.graphDigest) {
    throw new Error('workflow graph is not the current mandatory lifecycle plan');
  }
  for (let cycle = 1; cycle <= maxCycles; cycle += 1) {
    const stateExisted = fs.existsSync(state);
    const stagedState = path.join(temporary, `staged-state-${cycle}.json`);
    if (!stateExisted) {
      engineCall(['init', '--graph', graph, '--state', stagedState]);
    }
    const before = engineCall(['status', '--graph', graph, '--state', stateExisted ? state : stagedState]);
    if (['DONE', 'FAILED', 'BLOCKED', 'VERIFYING', 'NEEDS_REPLAN'].includes(before.status)) {
      const productionVerified = executionMode === 'managed-production'
        && adapter === 'codex'
        && dispatched > 0
        && verifiedHostExecutions === dispatched;
      terminalReport = { schemaVersion: 2, status: before.status, cycles: cycle - 1, dispatched, applied, adapter, executionMode, productionVerified, verifiedHostExecutions, capabilities: adapter === 'codex' ? ['dispatch', 'collect-receipt', 'codex-app-server'] : ['dispatch', 'collect-receipt'] };
      break;
    }
    const schedulingState = before.status === 'RESERVED' ? state : stagedState;
    if (before.status !== 'RESERVED' && stateExisted) fs.copyFileSync(state, stagedState);
    const wave = before.status === 'RESERVED'
      ? engineCall(['pending-contracts', '--graph', graph, '--state', state, '--adapter', adapter,
          ...(executionMode === 'managed-production' ? ['--require-approval-risk', '3', ...(fs.existsSync(approvals) ? ['--approvals', approvals] : [])] : [])])
      : engineCall(['schedule', '--graph', graph, '--state', schedulingState, '--adapter', adapter,
          ...(executionMode === 'managed-production' ? ['--require-approval-risk', '3', ...(fs.existsSync(approvals) ? ['--approvals', approvals] : [])] : [])]);
    if (!Array.isArray(wave.dispatchContracts) || wave.dispatchContracts.length === 0) {
      throw new Error(`controller made no progress from state ${before.status}`);
    }
    const receipts = [];
    for (const contract of wave.dispatchContracts) {
      const bridgeArgs = adapter === 'generic'
        ? [bridge, '--executable', hostExecutable, ...hostArgs.flatMap((value) => ['--arg', value]), '--cwd', cwd]
        : [bridge, '--route', route, '--cwd', cwd];
      const host = spawnSync(process.execPath, bridgeArgs, {
        cwd, encoding: 'utf8', input: JSON.stringify(contract), windowsHide: true,
      });
      if (host.status !== 0) throw new Error((host.stderr || 'host bridge failed').trim());
      let document;
      try { document = JSON.parse(host.stdout); } catch { throw new Error('host bridge returned invalid JSON'); }
      if (document.schemaVersion !== 2 || !Array.isArray(document.results) || document.results.length !== 1) {
        throw new Error('host bridge must return one schema-version-2 result');
      }
      if (adapter === 'codex') {
        const host = document.hostExecution;
        if (
          !host
          || host.provider !== 'codex-app-server:turn/start'
          || host.executionVerified !== true
          || host.ephemeral !== true
          || host.providerModelFallbackAllowed !== false
          || host.routeDigest !== contract.routeDigest
          || host.executionSpecDigest !== contract.executionSpecDigest
          || typeof host.threadId !== 'string' || !host.threadId
          || typeof host.turnId !== 'string' || !host.turnId
          || typeof host.actualModel !== 'string' || !host.actualModel
          || typeof host.actualHostReasoning !== 'string' || !host.actualHostReasoning
        ) throw new Error('Codex bridge did not prove a verified App Server execution for this contract');
        verifiedHostExecutions += 1;
      }
      receipts.push(document.results[0]);
      dispatched += 1;
    }
    const receiptPath = path.join(temporary, `receipts-${cycle}.json`);
    fs.mkdirSync(temporary, { recursive: true });
    fs.writeFileSync(receiptPath, `${JSON.stringify({ schemaVersion: 2, results: receipts })}\n`, 'utf8');
    if (before.status !== 'RESERVED') {
      engineCall([
        'commit-staged-reservation', '--graph', graph, '--state', state, '--staged', stagedState,
        ...(!stateExisted ? ['--allow-create'] : []),
      ]);
    }
    const result = engineCall(['apply-results', '--graph', graph, '--state', state, '--adapter', adapter, '--results', receiptPath]);
    applied += Number(result.appliedResultCount || 0);
  }
  if (!terminalReport) throw new Error(`controller exceeded max cycles: ${maxCycles}`);
} finally {
  if (temporary) fs.rmSync(temporary, { recursive: true, force: true });
  releaseCycleLock();
}
process.stdout.write(`${JSON.stringify(terminalReport)}\n`);
