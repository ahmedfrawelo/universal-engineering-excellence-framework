import { spawn, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'ueef-cycle-test-'));
const startAsync = (executable, commandArgs, options) => {
  const child = spawn(executable, commandArgs, options);
  let stdout = '';
  let stderr = '';
  const result = new Promise((resolve) => {
    child.stdout.on('data', (chunk) => { stdout += chunk; });
    child.stderr.on('data', (chunk) => { stderr += chunk; });
    child.on('close', (status, signal) => resolve({ status, signal, stdout, stderr }));
  });
  return { child, result };
};
const runAsync = (executable, commandArgs, options) => startAsync(executable, commandArgs, options).result;
try {
  const created = spawnSync('powershell.exe', ['-NoProfile', '-File', path.join(root, 'scripts/new-spec-workflow.ps1'), '-Id', 'cycle-fixture', '-Root', temp], { encoding: 'utf8' });
  if (created.status !== 0) throw new Error(created.stderr || 'fixture creation failed');
  const spec = JSON.parse(created.stdout).path;
  const graph = path.join(spec, 'task-graph.json');
  for (const name of ['constitution.md', 'spec.md', 'clarifications.md', 'plan.md', 'tasks.md']) {
    const target = path.join(spec, name);
    let text = fs.readFileSync(target, 'utf8').replace(/\{\{[A-Z0-9_]+\}\}/g, 'Completed');
    text = text.replace('Status: DRAFT', name === 'clarifications.md' ? 'Status: RESOLVED' : 'Status: READY');
    text = text.replace('- Token budget mode: Completed', '- Token budget mode: bounded');
    text = text.replace('- Delegation policy: Completed', '- Delegation policy: none');
    text = text.replace('- Maximum worker count: Completed', '- Maximum worker count: 1');
    fs.writeFileSync(target, text, 'utf8');
  }
  const route = path.join(root, 'scripts/fixtures/spec-workflow-route.json');
  const compile = spawnSync('powershell.exe', ['-NoProfile', '-File', path.join(root, 'scripts/invoke-spec-workflow-engine.ps1'), 'compile', '--tasks', path.join(spec, 'tasks.md'), '--workflow-id', 'cycle-fixture', '--route', route, '--output', graph], { encoding: 'utf8' });
  if (compile.status !== 0) throw new Error(compile.stderr || 'fixture compilation failed');
  const state = path.join(spec, 'execution-state.json');
  const result = spawnSync(process.execPath, [
    path.join(root, 'scripts/invoke-spec-workflow-cycle.mjs'),
    '--graph', graph, '--state', state, '--spec-root', spec,
    '--route', route,
    '--cwd', root, '--adapter', 'generic', '--execution-mode', 'test',
    '--host-executable', process.execPath,
    '--host-arg', path.join(root, 'engines/spec-workflow/tests/fixtures/fake_spec_workflow_host.mjs'),
  ], { encoding: 'utf8' });
  if (result.status !== 0) throw new Error(result.stderr || result.stdout || 'cycle failed');
  const report = JSON.parse(result.stdout);
  if (report.status !== 'VERIFYING' || report.dispatched !== 1 || report.applied !== 1) throw new Error(`cycle did not reach independent verification: ${result.stdout}`);
  if (report.executionMode !== 'test' || report.productionVerified !== false) throw new Error('test execution was mislabeled as production');

  const defaultGeneric = spawnSync(process.execPath, [
    path.join(root, 'scripts/invoke-spec-workflow-cycle.mjs'),
    '--graph', graph, '--state', path.join(spec, 'default-generic-state.json'), '--spec-root', spec,
    '--route', route, '--cwd', root, '--adapter', 'generic',
    '--host-executable', process.execPath,
    '--host-arg', path.join(root, 'engines/spec-workflow/tests/fixtures/fake_spec_workflow_host.mjs'),
  ], { encoding: 'utf8' });
  if (defaultGeneric.status === 0 || !/managed-production execution requires the codex adapter/u.test(defaultGeneric.stderr)) {
    throw new Error('default managed-production mode accepted the generic adapter');
  }

  const externalClaude = spawnSync(process.execPath, [
    path.join(root, 'scripts/invoke-spec-workflow-cycle.mjs'),
    '--graph', graph, '--state', state, '--spec-root', spec,
    '--route', route, '--cwd', root, '--adapter', 'claude', '--execution-mode', 'external',
  ], { encoding: 'utf8' });
  if (externalClaude.status !== 0) throw new Error(externalClaude.stderr || 'external Claude mode was rejected');
  const externalClaudeReport = JSON.parse(externalClaude.stdout);
  if (externalClaudeReport.executionMode !== 'external' || externalClaudeReport.adapter !== 'claude' || externalClaudeReport.productionVerified !== false) {
    throw new Error('external Claude execution contract was mislabeled');
  }

  const resumeState = path.join(spec, 'resume-state.json');
  const initialized = spawnSync('powershell.exe', ['-NoProfile', '-File', path.join(root, 'scripts/invoke-spec-workflow-engine.ps1'), 'init', '--graph', graph, '--state', resumeState], { encoding: 'utf8' });
  if (initialized.status !== 0) throw new Error(initialized.stderr || 'resume state initialization failed');
  const reserved = spawnSync('powershell.exe', ['-NoProfile', '-File', path.join(root, 'scripts/invoke-spec-workflow-engine.ps1'), 'schedule', '--graph', graph, '--state', resumeState, '--adapter', 'generic'], { encoding: 'utf8' });
  if (reserved.status !== 0) throw new Error(reserved.stderr || 'reservation failed');
  const resumed = spawnSync(process.execPath, [
    path.join(root, 'scripts/invoke-spec-workflow-cycle.mjs'),
    '--graph', graph, '--state', resumeState, '--spec-root', spec,
    '--route', route,
    '--cwd', root, '--adapter', 'generic', '--execution-mode', 'test',
    '--host-executable', process.execPath,
    '--host-arg', path.join(root, 'engines/spec-workflow/tests/fixtures/fake_spec_workflow_host.mjs'),
  ], { encoding: 'utf8' });
  if (resumed.status !== 0) throw new Error(resumed.stderr || resumed.stdout || 'reserved cycle resume failed');
  const resumedReport = JSON.parse(resumed.stdout);
  if (resumedReport.status !== 'VERIFYING' || resumedReport.dispatched !== 1 || resumedReport.applied !== 1) throw new Error('reserved cycle did not reach independent verification');

  const forbiddenBridge = spawnSync(process.execPath, [
    path.join(root, 'scripts/invoke-spec-workflow-cycle.mjs'),
    '--graph', graph, '--state', path.join(spec, 'forbidden-state.json'), '--spec-root', spec,
    '--route', route, '--cwd', root, '--adapter', 'codex',
    '--execution-mode', 'managed-production',
    '--bridge', path.join(root, 'engines/spec-workflow/tests/fixtures/fake_spec_workflow_host.mjs'),
  ], { encoding: 'utf8' });
  if (forbiddenBridge.status === 0 || !/bridge overrides are forbidden/u.test(forbiddenBridge.stderr)) {
    throw new Error('Codex adapter accepted a replaceable simulated bridge');
  }

  const failedState = path.join(spec, 'failed-host-state.json');
  const failedHost = spawnSync(process.execPath, [
    path.join(root, 'scripts/invoke-spec-workflow-cycle.mjs'),
    '--graph', graph, '--state', failedState, '--spec-root', spec,
    '--route', route, '--cwd', root, '--adapter', 'generic', '--execution-mode', 'test',
    '--host-executable', process.execPath,
    '--host-arg', '-e', '--host-arg', 'process.exit(7)',
  ], { encoding: 'utf8' });
  if (failedHost.status === 0) throw new Error('failed host unexpectedly completed');
  if (fs.existsSync(failedState)) {
    throw new Error('host failure mutated durable state before a verified receipt');
  }
  const healthyCycleArgs = (targetState) => [
    path.join(root, 'scripts/invoke-spec-workflow-cycle.mjs'),
    '--graph', graph, '--state', targetState, '--spec-root', spec,
    '--route', route, '--cwd', root, '--adapter', 'generic', '--execution-mode', 'test',
    '--host-executable', process.execPath,
    '--host-arg', path.join(root, 'engines/spec-workflow/tests/fixtures/fake_spec_workflow_host.mjs'),
  ];
  const failedStateRetry = spawnSync(process.execPath, healthyCycleArgs(failedState), { encoding: 'utf8' });
  if (failedStateRetry.status !== 0 || JSON.parse(failedStateRetry.stdout).status !== 'VERIFYING') {
    throw new Error(failedStateRetry.stderr || 'host-failure retry did not prove lock release');
  }

  const tempFailureState = path.join(spec, 'temp-failure-state.json');
  const missingTempRoot = path.join(temp, 'missing-temp-root');
  const tempFailure = spawnSync(process.execPath, [
    path.join(root, 'scripts/invoke-spec-workflow-cycle.mjs'),
    '--graph', graph, '--state', tempFailureState, '--spec-root', spec,
    '--route', route, '--cwd', root, '--adapter', 'generic', '--execution-mode', 'test',
    '--host-executable', process.execPath,
    '--host-arg', path.join(root, 'engines/spec-workflow/tests/fixtures/fake_spec_workflow_host.mjs'),
  ], {
    encoding: 'utf8',
    env: { ...process.env, TEMP: missingTempRoot, TMP: missingTempRoot },
  });
  if (tempFailure.status === 0) throw new Error('invalid temporary root unexpectedly succeeded');
  const tempFailureRetry = spawnSync(process.execPath, healthyCycleArgs(tempFailureState), { encoding: 'utf8' });
  if (tempFailureRetry.status !== 0 || JSON.parse(tempFailureRetry.stdout).status !== 'VERIFYING') {
    throw new Error(tempFailureRetry.stderr || 'temporary-directory retry did not prove lock release');
  }

  const crashState = path.join(spec, 'crash-lock-state.json');
  const crashCounter = path.join(spec, 'crash-holder-invocations.log');
  const crashHolder = startAsync(process.execPath, [
    ...healthyCycleArgs(crashState), '--lock-timeout-ms', '30000',
  ], {
    cwd: root,
    env: {
      ...process.env,
      UEEF_TEST_LOCK_AFTER_ACQUIRE_DELAY_MS: '10000',
      UEEF_FAKE_HOST_COUNTER: crashCounter,
    },
    windowsHide: true,
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  await new Promise((resolve) => setTimeout(resolve, 500));
  const lockedProbe = spawnSync(process.execPath, [
    ...healthyCycleArgs(crashState), '--lock-timeout-ms', '1000',
  ], { encoding: 'utf8', timeout: 5000 });
  if (lockedProbe.status === 0 || !/timed out waiting for workflow cycle lock/u.test(lockedProbe.stderr)) {
    crashHolder.child.kill();
    await crashHolder.result;
    throw new Error('crash holder did not observably own the SQLite cycle lock');
  }
  const killedAt = Date.now();
  if (crashHolder.child.kill() !== true) {
    throw new Error('failed to terminate the process holding the SQLite cycle lock');
  }
  const crashResult = await crashHolder.result;
  const terminatedAbnormally = process.platform === 'win32'
    ? crashResult.status !== 0
    : crashResult.signal !== null;
  if (
    !terminatedAbnormally
    || Date.now() - killedAt > 5000
  ) {
    throw new Error('cycle lock holder did not terminate abnormally and promptly');
  }
  if (fs.existsSync(crashState) || fs.existsSync(crashCounter)) {
    throw new Error('terminated lock holder reached durable state or external host execution');
  }
  const crashRetry = spawnSync(process.execPath, [
    ...healthyCycleArgs(crashState), '--lock-timeout-ms', '5000',
  ], { encoding: 'utf8', timeout: 30000 });
  if (crashRetry.status !== 0 || JSON.parse(crashRetry.stdout).status !== 'VERIFYING') {
    throw new Error(crashRetry.stderr || 'process crash did not release the SQLite cycle lock');
  }

  const concurrentState = path.join(spec, 'concurrent-state.json');
  const counter = path.join(spec, 'host-invocations.log');
  const concurrentArgs = [
    path.join(root, 'scripts/invoke-spec-workflow-cycle.mjs'),
    '--graph', graph, '--state', concurrentState, '--spec-root', spec,
    '--route', route, '--cwd', root, '--adapter', 'generic', '--execution-mode', 'test',
    '--host-executable', process.execPath,
    '--host-arg', path.join(root, 'engines/spec-workflow/tests/fixtures/fake_spec_workflow_host.mjs'),
    '--lock-timeout-ms', '30000',
  ];
  const concurrentOptions = {
    cwd: root,
    env: { ...process.env, UEEF_FAKE_HOST_COUNTER: counter, UEEF_FAKE_HOST_DELAY_MS: '750' },
    windowsHide: true,
    stdio: ['ignore', 'pipe', 'pipe'],
  };
  const aliasSpec = path.join(temp, 'cycle-fixture-alias');
  fs.symlinkSync(spec, aliasSpec, process.platform === 'win32' ? 'junction' : 'dir');
  const aliasState = path.join(aliasSpec, 'concurrent-state.json');
  const aliasArgs = [...concurrentArgs];
  aliasArgs[aliasArgs.indexOf('--state') + 1] = aliasState;
  const delayedCandidateOptions = {
    ...concurrentOptions,
    env: { ...concurrentOptions.env, UEEF_TEST_LOCK_AFTER_ACQUIRE_DELAY_MS: '6000' },
  };
  const firstCyclePromise = runAsync(process.execPath, concurrentArgs, delayedCandidateOptions);
  await new Promise((resolve) => setTimeout(resolve, 250));
  const secondCyclePromise = runAsync(process.execPath, aliasArgs, concurrentOptions);
  const [firstCycle, secondCycle] = await Promise.all([firstCyclePromise, secondCyclePromise]);
  for (const cycleResult of [firstCycle, secondCycle]) {
    if (cycleResult.status !== 0) throw new Error(cycleResult.stderr || 'concurrent cycle failed');
  }
  const concurrentReports = [firstCycle, secondCycle].map((item) => JSON.parse(item.stdout));
  if (concurrentReports.reduce((sum, item) => sum + item.dispatched, 0) !== 1) {
    throw new Error('concurrent cycles reported more than one host dispatch');
  }
  if (fs.readFileSync(counter, 'utf8').trim().split(/\r?\n/u).length !== 1) {
    throw new Error('concurrent cycles executed the external host more than once');
  }
  process.stdout.write('Spec workflow host cycle tests passed\n');
} finally {
  fs.rmSync(temp, { recursive: true, force: true });
}
