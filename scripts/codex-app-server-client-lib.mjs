import fs from 'node:fs';
import path from 'node:path';

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
