import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const [command, ...args] = process.argv.slice(2);
const sha256 = (file) => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const normalizePath = (value) => {
  const resolved = path.resolve(value);
  return process.platform === 'win32' ? resolved.toLowerCase() : resolved;
};

function readState(file) {
  const state = JSON.parse(fs.readFileSync(file, 'utf8'));
  if (!state || typeof state !== 'object' || Array.isArray(state)) throw new Error('Active state must be a JSON object.');
  return state;
}

function managedEnforcementValid(state, expectedRuntimePath) {
  if (!state?.managedEnforcement || state.managedEnforcement.required !== true || state.managedEnforcement.contractVersion !== 1) return false;
  const managed = state.managedEnforcement;
  if (typeof managed.requirementsPath !== 'string' || typeof managed.requirementsSha256 !== 'string' ||
      typeof managed.hooksPath !== 'string' || typeof managed.nodePath !== 'string' || typeof managed.nodeSha256 !== 'string' || !Array.isArray(managed.hookFiles)) return false;
  const expectedHooksPath = path.join(path.dirname(expectedRuntimePath), 'managed-hooks');
  if (normalizePath(managed.hooksPath) !== normalizePath(expectedHooksPath)) return false;
  if (!fs.existsSync(managed.requirementsPath) || fs.lstatSync(managed.requirementsPath).isSymbolicLink() ||
      sha256(managed.requirementsPath) !== managed.requirementsSha256) return false;
  if (!fs.existsSync(managed.nodePath) || fs.lstatSync(managed.nodePath).isSymbolicLink() || sha256(managed.nodePath) !== managed.nodeSha256) return false;
  const requirementsText = fs.readFileSync(managed.requirementsPath, 'utf8');
  if (!requirementsText.startsWith('# UEEF-MANAGED-REQUIREMENTS') || !/^hooks\s*=\s*true$/m.test(requirementsText)) return false;
  const requiredHookFiles = new Set([
    'ueef-codex-hook.mjs', 'record-ueef-route.mjs', 'ueef-hook-common.mjs', 'codex-enforcement-policy.json',
    'model-routing-policy.json', 'resolve-model-route.mjs', 'codex-app-server-models.mjs', 'codex-app-server-client-lib.mjs'
  ]);
  if (managed.hookFiles.length !== requiredHookFiles.size || !fs.existsSync(managed.hooksPath) || fs.lstatSync(managed.hooksPath).isSymbolicLink()) return false;
  for (const item of managed.hookFiles) {
    if (!item || typeof item.relativePath !== 'string' || typeof item.sha256 !== 'string' || !requiredHookFiles.delete(item.relativePath)) return false;
    const hookPath = path.join(managed.hooksPath, item.relativePath);
    if (!fs.existsSync(hookPath) || fs.lstatSync(hookPath).isSymbolicLink() || sha256(hookPath) !== item.sha256) return false;
  }
  return requiredHookFiles.size === 0;
}

if (command === 'write') {
  const [file, version, codexHome, runtimeRoot, runtimePath, agent, repositoryPath, sourceRepositoryPath, loaderPath, agentsPath, requireAgents, agentsOk] = args;
  if (fs.existsSync(file) && fs.lstatSync(file).isSymbolicLink()) throw new Error(`Refusing symbolic-link active state: ${file}`);
  if (agent.toLowerCase() === 'codex' && requireAgents !== '1') {
    throw new Error('Refusing to write an ACTIVE Codex state without RequireAgents.');
  }
  if (agent.toLowerCase() === 'codex') {
    throw new Error('The portable active-state writer cannot write Codex state without managed enforcement; use sync-runtime.ps1.');
  }
  const state = {
    active: true,
    agentRoutingContractVersion: 4,
    reasoningCeiling: 'proportional',
    version,
    generatedAtUtc: new Date().toISOString(),
    codexHome,
    runtimeRoot,
    runtimePath,
    agent,
    repositoryPath,
    sourceRepositoryPath,
    sourceCommit: 'UNKNOWN',
    loaderPath,
    runtimeLoaderSha256: sha256(loaderPath),
    agentsPath,
    requireAgents: requireAgents === '1',
    oldHomeUeefExists: false,
    requiredChecks: {
      loader: true,
      agents: agentsOk === 'true',
      coreSystem: true,
      masterLoader: true,
      masterIndex: true,
      activationGate: true,
      statusScript: true,
      managedRequirements: true,
      managedHooks: true
    }
  };
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const temporary = `${file}.tmp.${process.pid}`;
  fs.writeFileSync(temporary, `${JSON.stringify(state, null, 2)}\n`, 'utf8');
  fs.renameSync(temporary, file);
} else if (command === 'validate') {
  const [file, expectedVersion, expectedAgent, expectedRuntimePath, expectedLoaderPath] = args;
  if (!expectedRuntimePath || !expectedLoaderPath) {
    throw new Error('Active-state validation requires the expected runtime and loader paths.');
  }
  const state = readState(file);
  const codexRequiresAgents = expectedAgent.toLowerCase() === 'codex';
  const requiredCheckNames = ['loader', 'agents', 'coreSystem', 'masterLoader', 'masterIndex', 'activationGate', 'statusScript', 'managedRequirements', 'managedHooks'];
  const requiredChecksValid = state.requiredChecks && typeof state.requiredChecks === 'object' && !Array.isArray(state.requiredChecks) &&
    requiredCheckNames.every((name) => state.requiredChecks[name] === true) &&
    Object.values(state.requiredChecks).every((value) => value === true);
  const loaderHashValid = typeof state.runtimeLoaderSha256 === 'string' && typeof state.loaderPath === 'string' &&
    fs.existsSync(state.loaderPath) && !fs.lstatSync(state.loaderPath).isSymbolicLink() && state.runtimeLoaderSha256 === sha256(state.loaderPath);
  const runtimePathValid = typeof state.runtimePath === 'string' && normalizePath(state.runtimePath) === normalizePath(expectedRuntimePath);
  const loaderPathValid = typeof state.loaderPath === 'string' && normalizePath(state.loaderPath) === normalizePath(expectedLoaderPath);
  const managedValid = !codexRequiresAgents || managedEnforcementValid(state, expectedRuntimePath);
  const valid = state.active === true && state.agentRoutingContractVersion === 4 && state.reasoningCeiling === 'proportional' &&
    state.version === expectedVersion && state.agent === expectedAgent && state.requiredChecks &&
    (!codexRequiresAgents || state.requireAgents === true) &&
    runtimePathValid && loaderPathValid &&
    loaderHashValid && requiredChecksValid && managedValid;
  if (!valid) process.exit(1);
} else if (command === 'validate-managed') {
  const [file, expectedRuntimePath] = args;
  if (!expectedRuntimePath || !managedEnforcementValid(readState(file), expectedRuntimePath)) process.exit(1);
} else if (command === 'source') {
  const state = readState(args[0]);
  if (typeof state.sourceRepositoryPath !== 'string' || !state.sourceRepositoryPath) process.exit(1);
  process.stdout.write(state.sourceRepositoryPath);
} else if (command === 'require-agents') {
  process.stdout.write(readState(args[0]).requireAgents === false ? 'false' : 'true');
} else {
  throw new Error(`Unknown active-state command: ${command || '<missing>'}`);
}
