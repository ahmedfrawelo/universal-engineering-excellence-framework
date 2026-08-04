import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const hookRoot = path.dirname(fileURLToPath(import.meta.url));
export const runtimeRoot = path.dirname(hookRoot);
export const runtimePath = path.join(runtimeRoot, 'codex');
export const stateRoot = path.join(runtimeRoot, 'hook-state');
const sleepBuffer = new Int32Array(new SharedArrayBuffer(4));

export function sha256Text(value) {
  return crypto.createHash('sha256').update(String(value), 'utf8').digest('hex');
}

export function safeId(value) {
  const text = String(value || 'missing');
  return /^[A-Za-z0-9._-]{1,128}$/.test(text) ? text : sha256Text(text).slice(0, 32);
}

function assertStateRoot() {
  fs.mkdirSync(stateRoot, { recursive: true });
  if (fs.lstatSync(stateRoot).isSymbolicLink()) throw new Error(`Refusing symbolic-link hook state root: ${stateRoot}`);
}

export function turnStatePath(sessionId, turnId) {
  assertStateRoot();
  const target = path.resolve(stateRoot, `${safeId(sessionId)}.${safeId(turnId)}.json`);
  const prefix = `${path.resolve(stateRoot)}${path.sep}`;
  if (!(process.platform === 'win32' ? target.toLowerCase().startsWith(prefix.toLowerCase()) : target.startsWith(prefix))) throw new Error('Unsafe UEEF hook state path.');
  return target;
}

export function sessionStatePath(sessionId) {
  assertStateRoot();
  return path.join(stateRoot, `${safeId(sessionId)}.session.json`);
}

function withLock(sessionId, turnId, action) {
  assertStateRoot();
  const lockPath = path.join(stateRoot, `${sha256Text(`${sessionId}\n${turnId}`).slice(0, 32)}.lock`);
  const deadline = Date.now() + 5000;
  let handle;
  while (!handle) {
    try { handle = fs.openSync(lockPath, 'wx'); }
    catch (error) {
      if (error.code !== 'EEXIST' || Date.now() >= deadline) throw new Error('Timed out waiting for the UEEF hook state lock.');
      Atomics.wait(sleepBuffer, 0, 0, 25);
    }
  }
  try { return action(); }
  finally {
    fs.closeSync(handle);
    fs.rmSync(lockPath, { force: true });
  }
}

function atomicWrite(file, value) {
  const temporary = `${file}.tmp.${process.pid}.${crypto.randomBytes(4).toString('hex')}`;
  fs.writeFileSync(temporary, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
  fs.renameSync(temporary, file);
}

export function readTurnState(sessionId, turnId) {
  const file = turnStatePath(sessionId, turnId);
  if (!fs.existsSync(file)) return null;
  if (fs.lstatSync(file).isSymbolicLink()) throw new Error(`Refusing symbolic-link hook state: ${file}`);
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

export function writeTurnState(sessionId, turnId, state) {
  return withLock(sessionId, turnId, () => atomicWrite(turnStatePath(sessionId, turnId), state));
}

export function updateTurnState(sessionId, turnId, update) {
  return withLock(sessionId, turnId, () => {
    const file = turnStatePath(sessionId, turnId);
    if (!fs.existsSync(file)) return null;
    const state = JSON.parse(fs.readFileSync(file, 'utf8'));
    update(state);
    atomicWrite(file, state);
    return state;
  });
}

export function readSessionState(sessionId) {
  const file = sessionStatePath(sessionId);
  return fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : null;
}

export function updateSessionState(sessionId, update) {
  return withLock(sessionId, '__session__', () => {
    const file = sessionStatePath(sessionId);
    const state = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : { schemaVersion: 1, goalActive: false };
    update(state);
    state.updatedAtUtc = new Date().toISOString();
    atomicWrite(file, state);
    return state;
  });
}

export function peekWorkUnitInvocation(sessionId, workUnitId) {
  const key = safeId(workUnitId);
  const state = readSessionState(sessionId);
  return Number(state?.routeInvocations?.[key] || 0);
}

export function commitWorkUnitInvocation(sessionId, workUnitId, invocationIndex) {
  const key = safeId(workUnitId);
  let committed = false;
  updateSessionState(sessionId, (state) => {
    state.routeInvocations ||= {};
    const current = Number(state.routeInvocations[key] || 0);
    if (current !== invocationIndex) return;
    state.routeInvocations[key] = invocationIndex + 1;
    state.lastRouteInvocation = { workUnitId: key, invocationIndex, committedAtUtc: new Date().toISOString() };
    committed = true;
  });
  return committed;
}

export function setSessionGoalState(sessionId, active) {
  return updateSessionState(sessionId, (state) => {
    state.schemaVersion = 1;
    state.goalActive = Boolean(active);
    if (!active) delete state.routeInvocations;
  });
}

export function loadPolicy() {
  const file = path.join(hookRoot, 'codex-enforcement-policy.json');
  if (!fs.existsSync(file)) throw new Error(`UEEF hook policy missing: ${file}`);
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

export function newTurnState(sessionId, turnId, prompt, cwd, pickerModel = '') {
  const text = String(prompt || '');
  const policy = loadPolicy();
  const frontendPolicy = policy.frontendEnforcement || {};
  const matches = (patterns) => patterns.some((pattern) => new RegExp(String(pattern).replace(/^\(\?i\)/u, ''), 'iu').test(text));
  const frontendLikely = matches(frontendPolicy.promptPatterns || []) && !matches(frontendPolicy.metaPromptExclusionPatterns || []);
  const promptGoal = /(^|\s)\/goal\b|<objective>|\bgoal\b|الهدف/iu.test(text);
  const previous = readSessionState(sessionId);
  const goalTask = promptGoal || previous?.goalActive === true;
  if (promptGoal) setSessionGoalState(sessionId, true);
  const authorizations = {
    delete: /(delete|remove|cleanup|امسح|احذف|نظف)/iu.test(text),
    reset: /(reset|clean|checkout|ريست|كلين)/iu.test(text),
    push: /(\bpush\b|ارفع|جيت.?هب)/iu.test(text),
    release: /(release|publish|ريل)/iu.test(text),
    browserEmergency: /(remote debugging|loopback|emergency|الطوارئ|البديل)/iu.test(text)
  };
  const explicitlyPositive = (pattern) => {
    const matcher = new RegExp(pattern.source, [...new Set(`${pattern.flags}g`.split(''))].join(''));
    for (const match of text.matchAll(matcher)) {
      const prefix = text.slice(Math.max(0, match.index - 80), match.index);
      if (!/(?:\b(?:do\s+not|don't|never|not|no)\b|(?:لا|عدم))[^.!?\n]{0,60}$/iu.test(prefix)) return true;
    }
    return false;
  };
  authorizations.useCurrentModel = explicitlyPositive(/(use|keep|stick to).{0,30}(current|selected|picker).{0,20}model|استخدم.{0,20}(الموديل الحالي|الموديل المختار)|اشتغل.{0,20}(بالموديل الحالي|بالموديل المختار)/iu);
  authorizations.allowModelConstraintOverride = explicitlyPositive(/(allow|permit|authorize).{0,40}(model constraint|override|break constraint)|اسمح.{0,30}(بتجاوز|بكسر).{0,20}(قيد|الموديل)/iu);
  authorizations.allowAboveHigh = explicitlyPositive(/\b(xhigh|max|ultra|extra[ -]?high|above[ -]?high)\b|أعلى من هاي|تجاوز هاي|فوق هاي/iu);
  return {
    schemaVersion: 1,
    sessionId: safeId(sessionId),
    turnId: safeId(turnId),
    promptSha256: sha256Text(text),
    promptLength: text.length,
    cwdSha256: sha256Text(cwd || ''),
    pickerModel: String(pickerModel || ''),
    createdAtUtc: new Date().toISOString(),
    goalTask,
    engineeringLikely: fs.existsSync(path.join(cwd || '.', '.git')) || /(code|repo|project|build|test|fix|implement|release|push|deploy|browser|كود|مشروع|اختبر|اصلح|نفذ|ارفع|متصفح)/iu.test(text),
    frontendLikely,
    frontendMutation: false,
    authorizations,
    route: null,
    toolsUsed: 0,
    validations: {
      runtime: false,
      taskEvidence: false,
      freshReview: false,
      completionAudit: false,
      goalLifecycleComplete: false,
      goalLifecycleBlocked: false,
      browserPreflight: false,
      browserVerified: false,
      frontendRouting: false,
      frontendExecutionEvidence: false,
      tests: false,
      runtimeSync: false,
      push: false,
      release: false,
      goalComplete: false,
      goalBlocked: false,
      modelDispatch: false
    }
  };
}

export function passingToolResponse(response) {
  const text = typeof response === 'string' ? response : JSON.stringify(response ?? '');
  if (/(Exit code:\s*[1-9]|Script failed|"isError"\s*:\s*true)/iu.test(text)) return false;
  return /(Exit code:\s*0|\bPASS\b|"status"\s*:\s*"(complete|blocked|PASS)"|"result"\s*:\s*"SUCCESS")/iu.test(text);
}

export function assistantMessageContains(transcriptPath, expectedText) {
  if (!transcriptPath || !expectedText || !fs.existsSync(transcriptPath)) return false;
  const stat = fs.statSync(transcriptPath);
  if (!stat.isFile()) return false;
  const maximumBytes = 2 * 1024 * 1024;
  const start = Math.max(0, stat.size - maximumBytes);
  const handle = fs.openSync(transcriptPath, 'r');
  try {
    const buffer = Buffer.alloc(stat.size - start);
    fs.readSync(handle, buffer, 0, buffer.length, start);
    for (const line of buffer.toString('utf8').split(/\r?\n/u)) {
      if (!line.trim()) continue;
      let item;
      try { item = JSON.parse(line); } catch { continue; }
      const payload = item?.type === 'response_item' ? item.payload : item;
      if (payload?.type !== 'message' || payload?.role !== 'assistant') continue;
      const text = Array.isArray(payload.content)
        ? payload.content.map((entry) => entry?.text || '').join('')
        : '';
      if (text.includes(expectedText)) return true;
    }
    return false;
  } finally {
    fs.closeSync(handle);
  }
}

export const preToolDeny = (reason) => ({hookSpecificOutput:{hookEventName:'PreToolUse',permissionDecision:'deny',permissionDecisionReason:reason}});
export const stopBlock = (reason) => ({decision:'block',reason});
