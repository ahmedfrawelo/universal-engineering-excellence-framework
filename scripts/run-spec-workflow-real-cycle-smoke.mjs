import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const args = process.argv.slice(2);
const valueAfter = (flag) => {
  const index = args.indexOf(flag);
  return index === -1 ? null : args[index + 1] || null;
};
const routeValue = valueAfter('--route');
const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const cwd = path.resolve(valueAfter('--cwd') || root);
if (!routeValue) throw new Error('--route is required');
const route = path.resolve(routeValue);
if (!fs.existsSync(route)) throw new Error(`route does not exist: ${route}`);

const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'ueef-real-codex-cycle-'));
const run = (executable, commandArgs, options = {}) => {
  const result = spawnSync(executable, commandArgs, {
    cwd,
    encoding: 'utf8',
    windowsHide: true,
    timeout: 15 * 60 * 1000,
    ...options,
  });
  if (result.status !== 0) throw new Error((result.stderr || result.stdout || `${path.basename(executable)} failed`).trim());
  return result.stdout;
};

try {
  const created = JSON.parse(run('powershell.exe', [
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(root, 'scripts/new-spec-workflow.ps1'),
    '-Id', 'real-codex-cycle-smoke', '-Root', temporary,
  ]));
  const specRoot = created.path;
  for (const name of ['constitution.md', 'spec.md', 'clarifications.md', 'plan.md', 'tasks.md']) {
    const target = path.join(specRoot, name);
    let text = fs.readFileSync(target, 'utf8');
    text = text.replace('{{TASK}}', 'Read engines/spec-workflow/README.md and report its exact first Markdown heading without changing files');
    text = text.replace('{{EVIDENCE}}', 'Exact heading and source path from the repository');
    text = text.replace('{{DONE_WHEN}}', 'The exact first heading is returned with file-based evidence');
    text = text.replace(/\{\{[A-Z0-9_]+\}\}/gu, 'Completed');
    text = text.replace('Status: DRAFT', name === 'clarifications.md' ? 'Status: RESOLVED' : 'Status: READY');
    text = text.replace('- Token budget mode: Completed', '- Token budget mode: bounded');
    text = text.replace('- Delegation policy: Completed', '- Delegation policy: none');
    text = text.replace('- Maximum worker count: Completed', '- Maximum worker count: 1');
    fs.writeFileSync(target, text, 'utf8');
  }
  const graph = path.join(specRoot, 'task-graph.json');
  run('powershell.exe', [
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(root, 'scripts/invoke-spec-workflow-engine.ps1'),
    'compile', '--tasks', path.join(specRoot, 'tasks.md'), '--workflow-id', 'real-codex-cycle-smoke',
    '--route', route, '--output', graph,
  ]);
  const report = JSON.parse(run(process.execPath, [
    path.join(root, 'scripts/invoke-spec-workflow-cycle.mjs'),
    '--graph', graph,
    '--state', path.join(specRoot, 'execution-state.json'),
    '--spec-root', specRoot,
    '--route', route,
    '--cwd', cwd,
    '--adapter', 'codex',
    '--execution-mode', 'managed-production',
    '--max-cycles', '3',
  ]));
  if (
    report.schemaVersion !== 2
    || report.status !== 'VERIFYING'
    || report.adapter !== 'codex'
    || report.dispatched !== 1
    || report.applied !== 1
    || report.verifiedHostExecutions !== 1
    || report.executionMode !== 'managed-production'
    || report.productionVerified !== true
    || !report.capabilities?.includes('codex-app-server')
  ) throw new Error(`real Codex cycle did not reach verified execution: ${JSON.stringify(report)}`);
  process.stdout.write(`${JSON.stringify({ ...report, result: 'PASS' })}\n`);
} finally {
  fs.rmSync(temporary, { recursive: true, force: true });
}
