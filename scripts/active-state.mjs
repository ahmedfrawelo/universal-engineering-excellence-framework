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

if (command === 'write') {
  const [file, version, codexHome, runtimeRoot, runtimePath, agent, repositoryPath, sourceRepositoryPath, loaderPath, agentsPath, requireAgents, agentsOk] = args;
  if (fs.existsSync(file) && fs.lstatSync(file).isSymbolicLink()) throw new Error(`Refusing symbolic-link active state: ${file}`);
  if (agent.toLowerCase() === 'codex' && requireAgents !== '1') {
    throw new Error('Refusing to write an ACTIVE Codex state without RequireAgents.');
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
      statusScript: true
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
  const requiredCheckNames = ['loader', 'agents', 'coreSystem', 'masterLoader', 'masterIndex', 'activationGate', 'statusScript'];
  const requiredChecksValid = state.requiredChecks && typeof state.requiredChecks === 'object' && !Array.isArray(state.requiredChecks) &&
    requiredCheckNames.every((name) => state.requiredChecks[name] === true) &&
    Object.values(state.requiredChecks).every((value) => value === true);
  const loaderHashValid = typeof state.runtimeLoaderSha256 === 'string' && typeof state.loaderPath === 'string' &&
    fs.existsSync(state.loaderPath) && !fs.lstatSync(state.loaderPath).isSymbolicLink() && state.runtimeLoaderSha256 === sha256(state.loaderPath);
  const runtimePathValid = typeof state.runtimePath === 'string' && normalizePath(state.runtimePath) === normalizePath(expectedRuntimePath);
  const loaderPathValid = typeof state.loaderPath === 'string' && normalizePath(state.loaderPath) === normalizePath(expectedLoaderPath);
  const valid = state.active === true && state.agentRoutingContractVersion === 4 && state.reasoningCeiling === 'proportional' &&
    state.version === expectedVersion && state.agent === expectedAgent && state.requiredChecks &&
    (!codexRequiresAgents || state.requireAgents === true) &&
    runtimePathValid && loaderPathValid &&
    loaderHashValid && requiredChecksValid;
  if (!valid) process.exit(1);
} else if (command === 'source') {
  const state = readState(args[0]);
  if (typeof state.sourceRepositoryPath !== 'string' || !state.sourceRepositoryPath) process.exit(1);
  process.stdout.write(state.sourceRepositoryPath);
} else if (command === 'require-agents') {
  process.stdout.write(readState(args[0]).requireAgents === false ? 'false' : 'true');
} else {
  throw new Error(`Unknown active-state command: ${command || '<missing>'}`);
}
