import { spawn } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const self = fileURLToPath(import.meta.url);
const ownsSandbox = !process.env.UEEF_TEST_HOOK_STATE_ROOT;
const sandbox = process.env.UEEF_TEST_HOOK_STATE_ROOT
  ? path.resolve(process.env.UEEF_TEST_HOOK_STATE_ROOT)
  : fs.mkdtempSync(path.join(os.tmpdir(), 'ueef-hook-state-lock-'));
process.env.UEEF_ALLOW_TEST_HOOK_STATE_ROOT = '1';
process.env.UEEF_TEST_HOOK_STATE_ROOT = sandbox;
const { sha256Text, stateRoot, updateSessionState, withLock } = await import('./codex-hooks/ueef-hook-common.mjs');
const session = (label) => `lock-test-${label}-${process.pid}-${Date.now()}`;
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const stateFile = (id) => path.join(stateRoot, `${id}.session.json`);
const sessionLockFile = (id) => path.join(stateRoot, `${sha256Text(`${id}\n__session__`).slice(0, 32)}.lock`);

function child(args) {
  return spawn(process.execPath, [self, ...args], { stdio: ['ignore', 'pipe', 'pipe'], windowsHide: true });
}

function waitForLine(processHandle, expected, timeoutMs = 5000) {
  return new Promise((resolve, reject) => {
    let stdout = '';
    const timer = setTimeout(() => reject(new Error(`Timed out waiting for ${expected}`)), timeoutMs);
    processHandle.stdout.on('data', (chunk) => {
      stdout += chunk.toString();
      const line = stdout.split(/\r?\n/u).find((entry) => entry.startsWith(expected));
      if (line) { clearTimeout(timer); resolve(line); }
    });
    processHandle.once('exit', (code) => { if (!stdout.includes(expected)) { clearTimeout(timer); reject(new Error(`Child exited ${code} before ${expected}`)); } });
  });
}

function waitForExit(processHandle) {
  if (processHandle.exitCode !== null) return processHandle.exitCode === 0 ? Promise.resolve() : Promise.reject(new Error(`Child exited ${processHandle.exitCode}`));
  return new Promise((resolve, reject) => {
    let stderr = '';
    processHandle.stderr.on('data', (chunk) => { stderr += chunk.toString(); });
    processHandle.once('exit', (code) => code === 0 ? resolve() : reject(new Error(stderr || `Child exited ${code}`)));
  });
}

if (process.argv[2] === 'hold') {
  const [, , , id, turn, holdMs] = process.argv;
  withLock(id, turn, () => {
    const locks = fs.readdirSync(stateRoot).filter((name) => name.endsWith('.lock'));
    const owned = locks.find((name) => {
      try { return JSON.parse(fs.readFileSync(path.join(stateRoot, name), 'utf8')).pid === process.pid; } catch { return false; }
    });
    process.stdout.write(`ACQUIRED:${owned}\n`);
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, Number(holdMs));
  });
  process.exit(0);
}

if (process.argv[2] === 'increment') {
  const id = process.argv[3];
  const count = Number(process.argv[4]);
  for (let index = 0; index < count; index += 1) updateSessionState(id, (value) => { value.count = Number(value.count || 0) + 1; });
  process.exit(0);
}

const cleanup = new Set();
try {
  const killedSession = session('killed');
  cleanup.add(stateFile(killedSession));
  const killed = child(['hold', killedSession, '__session__', '30000']);
  const killedLine = await waitForLine(killed, 'ACQUIRED:');
  const abandonedLock = path.join(stateRoot, killedLine.slice('ACQUIRED:'.length));
  cleanup.add(abandonedLock);
  killed.kill('SIGKILL');
  await new Promise((resolve) => killed.once('exit', resolve));
  updateSessionState(killedSession, (value) => { value.recovered = true; });
  if (JSON.parse(fs.readFileSync(stateFile(killedSession), 'utf8')).recovered !== true || fs.existsSync(abandonedLock)) throw new Error('Hard-killed lock was not recovered.');

  for (const [kind, contents] of [['empty', ''], ['malformed', '{not-json']]) {
    const malformedSession = session(kind);
    const malformedLock = sessionLockFile(malformedSession);
    cleanup.add(stateFile(malformedSession));
    cleanup.add(malformedLock);
    fs.writeFileSync(malformedLock, contents, 'utf8');
    const stale = new Date(Date.now() - 5000);
    fs.utimesSync(malformedLock, stale, stale);
    updateSessionState(malformedSession, (value) => { value.recoveredMalformed = kind; });
    const recovered = JSON.parse(fs.readFileSync(stateFile(malformedSession), 'utf8')).recoveredMalformed;
    if (recovered !== kind || fs.existsSync(malformedLock)) throw new Error(`${kind} stale lock was not recovered.`);
  }

  const createOnlySession = session('create-only-hard-kill');
  const createOnlyLock = sessionLockFile(createOnlySession);
  cleanup.add(stateFile(createOnlySession));
  cleanup.add(createOnlyLock);
  fs.closeSync(fs.openSync(createOnlyLock, 'wx'));
  const graceStarted = Date.now();
  updateSessionState(createOnlySession, (value) => { value.recoveredAfterGrace = true; });
  const graceElapsed = Date.now() - graceStarted;
  if (graceElapsed < 1500 || !JSON.parse(fs.readFileSync(stateFile(createOnlySession), 'utf8')).recoveredAfterGrace) throw new Error(`Create-only lock ignored its bounded grace: ${graceElapsed} ms.`);

  const liveSession = session('live');
  cleanup.add(stateFile(liveSession));
  const live = child(['hold', liveSession, '__session__', '900']);
  const liveLine = await waitForLine(live, 'ACQUIRED:');
  const liveLock = path.join(stateRoot, liveLine.slice('ACQUIRED:'.length));
  cleanup.add(liveLock);
  const old = new Date(Date.now() - 60_000);
  fs.utimesSync(liveLock, old, old);
  const started = Date.now();
  updateSessionState(liveSession, (value) => { value.waitedForLiveOwner = true; });
  const elapsed = Date.now() - started;
  await waitForExit(live);
  if (elapsed < 650) throw new Error(`Live lock was stolen after ${elapsed} ms.`);

  const concurrentSession = session('concurrent');
  cleanup.add(stateFile(concurrentSession));
  const workers = Array.from({ length: 4 }, () => child(['increment', concurrentSession, '5']));
  await Promise.all(workers.map(waitForExit));
  const count = JSON.parse(fs.readFileSync(stateFile(concurrentSession), 'utf8')).count;
  if (count !== 20) throw new Error(`Concurrent updates lost data: expected 20, got ${count}.`);

  process.stdout.write('Hook state lock recovery tests passed\n');
} finally {
  await sleep(25);
  for (const file of cleanup) fs.rmSync(file, { force: true });
  if (ownsSandbox) fs.rmSync(sandbox, { recursive: true, force: true });
}
