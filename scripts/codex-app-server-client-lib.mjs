import fs from 'node:fs';
import crypto from 'node:crypto';
import os from 'node:os';
import path from 'node:path';

const discoveryLockSleep = new Int32Array(new SharedArrayBuffer(4));

function processExists(pid) {
  if (!Number.isInteger(pid) || pid < 1) return false;
  try { process.kill(pid, 0); return true; }
  catch (error) { return error?.code === 'EPERM'; }
}

function readDiscoveryLockOwner(lockPath) {
  try {
    const owner = JSON.parse(fs.readFileSync(lockPath, 'utf8'));
    return owner?.schemaVersion === 1 && Number.isInteger(owner.pid) && typeof owner.token === 'string' ? owner : null;
  } catch { return null; }
}

function reclaimAbandonedDiscoveryLock(lockPath) {
  const owner = readDiscoveryLockOwner(lockPath);
  if (owner && processExists(owner.pid)) return false;
  try {
    const ageMs = Date.now() - fs.statSync(lockPath).mtimeMs;
    if (!owner && ageMs < 2000) return false;
    fs.rmSync(lockPath);
    return true;
  } catch (error) { return error?.code === 'ENOENT'; }
}

export function resolveAppServerDiscoveryLockRoot() {
  const explicit = String(process.env.UEEF_APP_SERVER_DISCOVERY_LOCK_ROOT || '').trim();
  if (explicit) return path.resolve(explicit);
  const globalPath = String(process.env.UEEF_GLOBAL_PATH || '').trim();
  const codexHome = String(process.env.CODEX_HOME || '').trim();
  const userKey = String(process.env.USERNAME || process.env.USER || 'default').replace(/[^A-Za-z0-9._-]/gu, '_').slice(0, 64) || 'default';
  // App Server turns may be deliberately read-only even when the parent Codex
  // session can write the managed runtime. A coordination lock inside that
  // runtime therefore turns a harmless status/model probe into EPERM. Keep the
  // lock in the OS temp area and namespace it by installation so independent
  // Codex homes still serialize separately.
  const installationKey = globalPath || codexHome || 'default';
  const installationDigest = crypto.createHash('sha256').update(path.resolve(installationKey)).digest('hex').slice(0, 16);
  return path.join(os.tmpdir(), `ueef-app-server-discovery-${userKey}-${installationDigest}`);
}

export function acquireAppServerDiscoveryLock({ waitMs = 60_000, root = resolveAppServerDiscoveryLockRoot() } = {}) {
  if (!Number.isInteger(waitMs) || waitMs < 1 || waitMs > 300_000) {
    throw new Error('App Server discovery lock wait must be an integer from 1 to 300000 ms.');
  }
  const resolvedRoot = path.resolve(root);
  fs.mkdirSync(resolvedRoot, { recursive: true });
  const rootStat = fs.lstatSync(resolvedRoot);
  if (!rootStat.isDirectory() || rootStat.isSymbolicLink()) throw new Error(`Refusing unsafe App Server discovery lock root: ${resolvedRoot}`);
  const lockPath = path.join(resolvedRoot, 'catalog.lock');
  const deadline = Date.now() + waitMs;
  const token = crypto.randomBytes(16).toString('hex');
  let handle;
  while (handle === undefined) {
    try {
      handle = fs.openSync(lockPath, 'wx');
      fs.writeFileSync(handle, `${JSON.stringify({ schemaVersion: 1, pid: process.pid, token, createdAtUtc: new Date().toISOString() })}\n`, 'utf8');
    } catch (error) {
      if (handle !== undefined) {
        fs.closeSync(handle);
        handle = undefined;
        fs.rmSync(lockPath, { force: true });
      }
      if (error?.code !== 'EEXIST') throw error;
      if (Date.now() >= deadline) throw new Error('Timed out waiting for the App Server discovery lock.');
      if (reclaimAbandonedDiscoveryLock(lockPath)) continue;
      Atomics.wait(discoveryLockSleep, 0, 0, 25);
    }
  }
  let released = false;
  return () => {
    if (released) return;
    released = true;
    fs.closeSync(handle);
    const owner = readDiscoveryLockOwner(lockPath);
    if (owner?.pid === process.pid && owner.token === token) fs.rmSync(lockPath, { force: true });
  };
}

export function resolveCodexExecutable(explicitExecutable = null) {
  const explicit = explicitExecutable || process.env.UEEF_CODEX_APP_SERVER_BIN || null;
  const codexHome = process.env.CODEX_HOME || null;
  const executableName = process.platform === 'win32' ? 'codex.exe' : 'codex';
  const bundledCandidates = codexHome ? [
    path.join(codexHome, 'plugins', '.plugin-appserver', executableName),
    path.join(codexHome, '.sandbox-bin', executableName)
  ] : [];
  const executable = explicit || bundledCandidates.find((candidate) => fs.existsSync(candidate)) || 'codex';
  return {
    executable,
    executableSource: explicit
      ? 'explicit'
      : bundledCandidates.includes(executable)
        ? 'codex-home-runtime'
        : 'path'
  };
}

export function appServerSandboxPolicy(mode, cwd) {
  if (mode === 'danger-full-access') return { type: 'dangerFullAccess' };
  if (mode === 'workspace-write') return { type: 'workspaceWrite', writableRoots: [cwd], networkAccess: false };
  if (mode === 'read-only') return { type: 'readOnly', networkAccess: false };
  throw new Error(`Unsupported sandbox mode: ${mode}`);
}
