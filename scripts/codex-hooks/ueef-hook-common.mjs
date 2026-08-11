import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const hookRoot = path.dirname(fileURLToPath(import.meta.url));
export const runtimeRoot = path.dirname(hookRoot);
export const runtimePath = path.join(runtimeRoot, 'codex');
const testStateRoot = process.env.UEEF_ALLOW_TEST_HOOK_STATE_ROOT === '1'
  ? process.env.UEEF_TEST_HOOK_STATE_ROOT
  : null;
export const stateRoot = testStateRoot ? path.resolve(testStateRoot) : path.join(runtimeRoot, 'hook-state');
const sleepBuffer = new Int32Array(new SharedArrayBuffer(4));

export function sha256Text(value) {
  return crypto.createHash('sha256').update(String(value), 'utf8').digest('hex');
}

export function hostRoutePathsFromPrompt(prompt) {
  const encoded = String(prompt || '').match(/^UEEF_HOST_ROUTE_INHERIT_V1:([A-Za-z0-9_-]+)\r?$/mu)?.[1];
  if (!encoded) return null;
  try {
    const value = JSON.parse(Buffer.from(encoded, 'base64url').toString('utf8'));
    if (!value || typeof value.routePath !== 'string' || typeof value.claimPath !== 'string') return null;
    if (!path.isAbsolute(value.routePath) || !path.isAbsolute(value.claimPath)) return null;
    return { routePath: value.routePath, claimPath: value.claimPath };
  } catch { return null; }
}

export function inheritValidatedHostRoute(
  state,
  routePath,
  claimPath,
  trustedRoutePath = process.env.UEEF_VALIDATED_HOST_ROUTE,
  trustedClaimPath = process.env.UEEF_VALIDATED_HOST_ROUTE_CLAIM
) {
  if (!routePath || !claimPath) {
    if (state.hostRouteEnvelopeObserved) state.hostRouteInheritanceError = 'ENVELOPE_NOT_PARSED';
    return state;
  }
  if (!trustedRoutePath || !trustedClaimPath) {
    state.hostRouteInheritanceError = 'HOST_ROUTE_ENV_MISSING';
    return state;
  }
  if (routePath !== trustedRoutePath || claimPath !== trustedClaimPath) {
    state.hostRouteInheritanceError = 'HOST_ROUTE_ENV_MISMATCH';
    return state;
  }
  if (!fs.existsSync(routePath)) { state.hostRouteInheritanceError = 'ROUTE_NOT_FOUND'; return state; }
  let route;
  try { route = JSON.parse(fs.readFileSync(routePath, 'utf8')); } catch { state.hostRouteInheritanceError = 'ROUTE_UNREADABLE'; return state; }
  const catalogIdentity = (route.catalogCoverage || []).map((entry) => ({
    model: entry.model,
    hidden: entry.hidden,
    capabilityClass: entry.capabilityClass,
    supportedReasoningEfforts: entry.supportedReasoningEfforts,
    defaultReasoningEffort: entry.defaultReasoningEffort,
    upgrade: entry.upgrade
  }));
  const catalogDigest = sha256Text(JSON.stringify(catalogIdentity));
  const routeDigest = sha256Text(JSON.stringify({
    tier: route.tier,
    workUnitId: route.workUnitId || null,
    invocationIndex: route.invocationIndex ?? 0,
    preferredModel: route.preferredModel,
    hostReasoning: route.hostReasoning,
    fallbackModel: route.fallbackModel || null,
    fallbackHostReasoning: route.fallbackHostReasoning || null,
    tokenEconomy: route.tokenEconomy || null,
    catalogDigest: route.catalogDigest,
    catalogProvider: route.catalogProvider,
    catalogDiscoveredAt: route.catalogDiscoveredAt
  }));
  const discoveredAt = Date.parse(route.catalogDiscoveredAt || '');
  const selectedModel = state.pickerModel === route.preferredModel
    ? route.preferredModel
    : state.pickerModel === route.fallbackModel ? route.fallbackModel : null;
  if (route.accountCatalogVerified !== true || route.catalogFresh !== true || route.catalogContractValid !== true) { state.hostRouteInheritanceError = 'CATALOG_NOT_VERIFIED'; return state; }
  if (route.catalogProvider !== 'codex-app-server:model/list' || route.catalogDigest !== catalogDigest) { state.hostRouteInheritanceError = 'CATALOG_IDENTITY_INVALID'; return state; }
  if (route.routeDigest !== routeDigest) { state.hostRouteInheritanceError = 'ROUTE_DIGEST_INVALID'; return state; }
  if (!selectedModel) { state.hostRouteInheritanceError = 'MODEL_MISMATCH'; return state; }
  if (!Number.isFinite(discoveredAt) || Date.now() - discoveredAt > 10 * 60 * 1000 || discoveredAt - Date.now() > 60_000) { state.hostRouteInheritanceError = 'ROUTE_STALE'; return state; }
  if (route.tokenEconomy?.specRequired === true) {
    if (!route.executionSpec?.digest) { state.hostRouteInheritanceError = 'EXECUTION_SPEC_MISSING'; return state; }
    const { digest, ...body } = route.executionSpec;
    if (digest !== sha256Text(JSON.stringify(body))) { state.hostRouteInheritanceError = 'EXECUTION_SPEC_INVALID'; return state; }
  }
  let claimHandle;
  try {
    claimHandle = fs.openSync(claimPath, 'wx');
    fs.writeFileSync(claimHandle, `${route.routeDigest}\n`, 'utf8');
  } catch { state.hostRouteInheritanceError = 'ROUTE_ALREADY_CLAIMED'; return state; }
  finally { if (claimHandle !== undefined) fs.closeSync(claimHandle); }
  state.route = {
    ...route,
    actualModel: selectedModel,
    actualHostReasoning: selectedModel === route.fallbackModel ? route.fallbackHostReasoning : route.hostReasoning,
    actualDisplayReasoning: selectedModel === route.fallbackModel ? route.fallbackHostReasoning : route.displayReasoning,
    capacityFallbackUsed: selectedModel === route.fallbackModel,
    modelRouteVerified: true,
    inheritedHostDispatch: true,
    routeLine: route.routeLine || `Model route: ${route.workUnitId} | ${route.preferredModel} / ${route.displayReasoning || route.hostReasoning} (host: ${route.hostReasoning})`
  };
  state.executionSpec = route.executionSpec || null;
  state.validations.executionSpec = route.tokenEconomy?.specRequired !== true || Boolean(route.executionSpec?.digest);
  state.validations.modelDispatch = true;
  state.hostRouteInheritanceError = null;
  return state;
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

function processIsAlive(pid) {
  if (!Number.isInteger(pid) || pid <= 0) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    return error?.code === 'EPERM';
  }
}

function readLockOwner(lockPath) {
  try {
    const stat = fs.lstatSync(lockPath);
    if (!stat.isFile() || stat.isSymbolicLink()) return null;
    const owner = JSON.parse(fs.readFileSync(lockPath, 'utf8'));
    if (typeof owner?.token !== 'string' || !Number.isInteger(owner?.pid)) return null;
    return { ...owner, ino: stat.ino, size: stat.size, mtimeMs: stat.mtimeMs };
  } catch { return null; }
}

const malformedLockGraceMs = 2000;

function readLockIdentity(lockPath) {
  try {
    const stat = fs.lstatSync(lockPath);
    if (!stat.isFile() || stat.isSymbolicLink()) return null;
    return { ino: stat.ino, size: stat.size, mtimeMs: stat.mtimeMs };
  } catch { return null; }
}

function sameLockIdentity(left, right) {
  return Boolean(left && right && left.ino === right.ino && left.size === right.size && left.mtimeMs === right.mtimeMs);
}

function reclaimAbandonedLock(lockPath) {
  const owner = readLockOwner(lockPath);
  if (owner && processIsAlive(owner.pid)) return false;
  if (owner) {
    const current = readLockOwner(lockPath);
    if (!current || current.token !== owner.token || current.pid !== owner.pid || !sameLockIdentity(owner, current)) return false;
  } else {
    const identity = readLockIdentity(lockPath);
    if (!identity || Date.now() - identity.mtimeMs < malformedLockGraceMs) return false;
    const currentOwner = readLockOwner(lockPath);
    const currentIdentity = readLockIdentity(lockPath);
    if (currentOwner || !sameLockIdentity(identity, currentIdentity)) return false;
  }
  try {
    fs.rmSync(lockPath);
    return true;
  } catch (error) {
    if (error?.code === 'ENOENT') return true;
    return false;
  }
}

export function withLock(sessionId, turnId, action) {
  assertStateRoot();
  const lockPath = path.join(stateRoot, `${sha256Text(`${sessionId}\n${turnId}`).slice(0, 32)}.lock`);
  const deadline = Date.now() + 5000;
  const token = crypto.randomBytes(16).toString('hex');
  let handle;
  while (handle === undefined) {
    try {
      handle = fs.openSync(lockPath, 'wx');
      fs.writeFileSync(handle, `${JSON.stringify({ schemaVersion: 1, pid: process.pid, token, sessionId: safeId(sessionId), turnId: safeId(turnId), createdAtUtc: new Date().toISOString() })}\n`, 'utf8');
    }
    catch (error) {
      if (handle !== undefined) {
        fs.closeSync(handle);
        handle = undefined;
        fs.rmSync(lockPath, { force: true });
      }
      if (error.code !== 'EEXIST') throw error;
      if (Date.now() >= deadline) throw new Error('Timed out waiting for the UEEF hook state lock.');
      if (reclaimAbandonedLock(lockPath)) continue;
      Atomics.wait(sleepBuffer, 0, 0, 25);
    }
  }
  try { return action(); }
  finally {
    fs.closeSync(handle);
    const owner = readLockOwner(lockPath);
    if (owner?.token === token && owner.pid === process.pid) fs.rmSync(lockPath, { force: true });
  }
}

export function cleanupHookState({
  root = stateRoot,
  currentSessionId = null,
  nowMs = Date.now(),
  ttlMs = 7 * 24 * 60 * 60 * 1000,
  maxFilesPerSession = 100,
  maxFilesGlobal = 2000,
  maxScan = 1000,
  maxDelete = 100
} = {}) {
  if (![ttlMs, maxFilesPerSession, maxFilesGlobal, maxScan, maxDelete].every((value) => Number.isInteger(value) && value >= 0)) throw new Error('Hook state cleanup limits must be non-negative integers.');
  const resolvedRoot = path.resolve(root);
  if (!fs.existsSync(resolvedRoot)) return { scanned: 0, before: 0, deleted: 0, after: 0, bounded: false };
  if (!fs.lstatSync(resolvedRoot).isDirectory() || fs.lstatSync(resolvedRoot).isSymbolicLink()) throw new Error(`Refusing unsafe hook state cleanup root: ${resolvedRoot}`);
  const names = fs.readdirSync(resolvedRoot).sort((left, right) => Number(right.endsWith('.lock')) - Number(left.endsWith('.lock')) || left.localeCompare(right));
  const bounded = names.length > maxScan;
  const selectedNames = names.slice(0, maxScan);
  const activeSessions = new Set();
  for (const name of selectedNames) {
    if (!name.endsWith('.lock')) continue;
    const owner = readLockOwner(path.join(resolvedRoot, name));
    if (owner && processIsAlive(owner.pid) && typeof owner.sessionId === 'string') activeSessions.add(owner.sessionId);
  }
  const current = currentSessionId === null ? null : safeId(currentSessionId);
  const records = [];
  for (const name of selectedNames) {
    if (!name.endsWith('.json')) continue;
    const file = path.join(resolvedRoot, name);
    let stat;
    let value;
    try {
      stat = fs.lstatSync(file);
      if (!stat.isFile() || stat.isSymbolicLink()) continue;
      value = JSON.parse(fs.readFileSync(file, 'utf8'));
    } catch { continue; }
    const sessionId = typeof value?.sessionId === 'string'
      ? safeId(value.sessionId)
      : name.endsWith('.session.json') ? name.slice(0, -'.session.json'.length) : null;
    records.push({ file, name, sessionId, mtimeMs: stat.mtimeMs, recent: nowMs - stat.mtimeMs < ttlMs });
  }
  const protectedRecord = (record) => record.recent || record.sessionId === current || activeSessions.has(record.sessionId);
  const deletions = new Set(records.filter((record) => !protectedRecord(record) && nowMs - record.mtimeMs >= ttlMs).map((record) => record.file));
  const bySession = new Map();
  for (const record of records) {
    if (!record.sessionId || record.name.endsWith('.session.json')) continue;
    const group = bySession.get(record.sessionId) || [];
    group.push(record);
    bySession.set(record.sessionId, group);
  }
  for (const group of bySession.values()) {
    const retained = group.filter((record) => !deletions.has(record.file));
    const overflow = Math.max(0, retained.length - maxFilesPerSession);
    retained.filter((record) => !protectedRecord(record)).sort((left, right) => left.mtimeMs - right.mtimeMs).slice(0, overflow).forEach((record) => deletions.add(record.file));
  }
  const globallyRetained = records.filter((record) => !deletions.has(record.file));
  const globalOverflow = Math.max(0, globallyRetained.length - maxFilesGlobal);
  globallyRetained.filter((record) => !protectedRecord(record)).sort((left, right) => left.mtimeMs - right.mtimeMs).slice(0, globalOverflow).forEach((record) => deletions.add(record.file));
  const ordered = [...deletions].sort((left, right) => {
    const leftRecord = records.find((record) => record.file === left);
    const rightRecord = records.find((record) => record.file === right);
    return leftRecord.mtimeMs - rightRecord.mtimeMs;
  }).slice(0, maxDelete);
  for (const file of ordered) fs.rmSync(file, { force: true });
  return { scanned: selectedNames.length, before: records.length, deleted: ordered.length, after: records.length - ordered.length, bounded };
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

export function reserveWorkUnitInvocation(sessionId, workUnitId, invocationIndex, turnId, nonce) {
  const key = safeId(workUnitId);
  let reserved = false;
  updateSessionState(sessionId, (state) => {
    state.routeInvocations ||= {};
    state.routeInvocationReservations ||= {};
    if (Number(state.routeInvocations[key] || 0) !== invocationIndex) return;
    const existing = state.routeInvocationReservations[key];
    if (existing) {
      const age = Date.now() - Date.parse(existing.createdAtUtc || '');
      if (processIsAlive(existing.pid) && Number.isFinite(age) && age <= 11 * 60 * 1000) return;
    }
    state.routeInvocationReservations[key] = { schemaVersion: 1, workUnitId: key, invocationIndex, turnId: safeId(turnId), nonce, pid: process.pid, createdAtUtc: new Date().toISOString() };
    reserved = true;
  });
  return reserved;
}

export function releaseWorkUnitInvocationReservation(sessionId, workUnitId, nonce) {
  const key = safeId(workUnitId);
  updateSessionState(sessionId, (state) => {
    if (state.routeInvocationReservations?.[key]?.nonce === nonce) delete state.routeInvocationReservations[key];
  });
}

export function commitReservedWorkUnitInvocation(sessionId, workUnitId, invocationIndex, nonce) {
  const key = safeId(workUnitId);
  let committed = false;
  updateSessionState(sessionId, (state) => {
    state.routeInvocations ||= {};
    state.routeInvocationReservations ||= {};
    const reservation = state.routeInvocationReservations[key];
    if (Number(state.routeInvocations[key] || 0) !== invocationIndex || reservation?.nonce !== nonce) return;
    state.routeInvocations[key] = invocationIndex + 1;
    delete state.routeInvocationReservations[key];
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

function normalizeDirectiveText(value) {
  return String(value || '')
    .normalize('NFKC')
    .replace(/[\u0640\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]/gu, '')
    .toLowerCase();
}

const freeModePhrases = [
  'تجاوز التعليمات',
  'انسى التعليمات',
  'تجاوز اليو اي اي اف',
  'تجاوز ueef',
  'free-mode',
  'اشتغل بحرية',
  'ابتكر خارج الإطار',
  'اعمل بدون ueef'
];

const freeModeQuotedContext = /(?:\b(?:phrase|string|quote|quoted|mention|mentioned|saying|means?|meaning|analy[sz]e|analysis)\b|(?:عبارة|اقتباس|اقتبس|اذكر|ذكر|يعني|معنى|تحليل))/iu;

function detectFreeModeDirective(text) {
  const normalized = normalizeDirectiveText(text);
  for (const phrase of freeModePhrases) {
    const needle = normalizeDirectiveText(phrase);
    let index = normalized.indexOf(needle);
    while (index >= 0) {
      const before = normalized.slice(Math.max(0, index - 48), index);
      const after = normalized.slice(index + needle.length, index + needle.length + 48);
      const quotedBefore = /["'`]\s*$/u.test(before);
      const quotedAfter = /^\s*["'`]/u.test(after);
      const explanatoryQuestion = /[?؟]/u.test(after) && freeModeQuotedContext.test(`${before} ${after}`);
      if (!quotedBefore && !quotedAfter && !explanatoryQuestion && !freeModeQuotedContext.test(before)) {
        return { active: true, trigger: phrase };
      }
      index = normalized.indexOf(needle, index + needle.length);
    }
  }
  return { active: false, trigger: null };
}

export function newTurnState(sessionId, turnId, prompt, cwd, pickerModel = '') {
  const text = String(prompt || '');
  const userTaskText = text.replace(/<in-app-browser-context\b[^>]*>[\s\S]*?<\/in-app-browser-context>/giu, ' ');
  const policy = loadPolicy();
  const frontendPolicy = policy.frontendEnforcement || {};
  const matches = (patterns) => patterns.some((pattern) => new RegExp(String(pattern).replace(/^\(\?i\)/u, ''), 'iu').test(userTaskText));
  const frontendLikely = matches(frontendPolicy.promptPatterns || []) && !matches(frontendPolicy.metaPromptExclusionPatterns || []);
  const promptGoal = /(^|\s)\/goal\b|<objective>|\bgoal\b|الهدف/iu.test(text);
  const previous = readSessionState(sessionId);
  const goalTask = promptGoal || previous?.goalActive === true;
  if (promptGoal) setSessionGoalState(sessionId, true);
  const freeMode = detectFreeModeDirective(userTaskText);
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
  authorizations.newUserTask = explicitlyPositive(/(?:\b(?:create|open|start|fork|handoff|move)\b.{0,50}\b(?:new\s+)?(?:task|thread|chat)\b|\bnew\s+(?:task|thread|chat)\b|(?:\u0627\u0641\u062a\u062d|\u0627\u0639\u0645\u0644|\u0627\u0646\u0634\u0626|\u0623\u0646\u0634\u0626|\u0633\u0644\u0645|\u062d\u0648\u0644|\u062d\u0648\u0651\u0644).{0,60}(?:(?:\u062a\u0627\u0633\u0643|\u0645\u0647\u0645\u0629|\u062b\u0631\u064a\u062f|\u0634\u0627\u062a).{0,20}\u062c\u062f\u064a\u062f(?:\u0629|\u0647)?|\u062c\u062f\u064a\u062f(?:\u0629|\u0647)?.{0,20}(?:\u062a\u0627\u0633\u0643|\u0645\u0647\u0645\u0629|\u062b\u0631\u064a\u062f|\u0634\u0627\u062a)))/iu);
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
    freeMode,
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
      modelDispatch: false,
      executionSpec: false
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
