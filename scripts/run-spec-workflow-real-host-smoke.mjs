import { spawnSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const args = process.argv.slice(2);
const valueAfter = (flag) => {
  const index = args.indexOf(flag);
  return index === -1 ? null : args[index + 1] || null;
};
const routePath = valueAfter('--route');
const cwd = path.resolve(valueAfter('--cwd') || process.cwd());
if (!routePath || !fs.existsSync(routePath)) throw new Error('provide an existing --route file');
const route = JSON.parse(fs.readFileSync(routePath, 'utf8'));
const identityDigest = crypto.createHash('sha256').update(`${route.routeDigest}:real-host-smoke`).digest('hex');
const contract = {
  adapter: 'codex',
  taskId: 'TASK-SMOKE',
  worker: 'lead-smoke',
  prompt: 'Read engines/spec-workflow/README.md and report its exact first Markdown heading with file-based evidence. Do not change any file.',
  ownership: { readOnly: true, allowedWriteSet: [], forbiddenPaths: [] },
  requiredCapabilities: ['read'],
  acceptance: ['Exact first heading is supported by file-based evidence'],
  transport: 'codex-thread',
  resultProtocol: 'ueef-host-result/v2',
  workflowId: 'real-host-smoke',
  executionId: crypto.randomUUID(),
  graphDigest: identityDigest,
  routeDigest: route.routeDigest,
  executionSpecDigest: route.executionSpec?.digest || route.routeDigest,
  attemptId: crypto.randomUUID(),
  leaseGeneration: 1,
  fencingToken: crypto.randomBytes(32).toString('hex'),
};
const bridge = path.join(path.dirname(fileURLToPath(import.meta.url)), 'invoke-spec-workflow-codex-host.mjs');
const result = spawnSync(process.execPath, [bridge, '--route', path.resolve(routePath), '--cwd', cwd, '--sandbox', 'read-only'], {
  cwd,
  encoding: 'utf8',
  input: JSON.stringify(contract),
  windowsHide: true,
});
if (result.status !== 0) throw new Error((result.stderr || 'real host smoke failed').trim());
const document = JSON.parse(result.stdout);
const hostExecution = document.hostExecution;
if (
  hostExecution?.provider !== 'codex-app-server:turn/start'
  || hostExecution.executionVerified !== true
  || hostExecution.ephemeral !== true
  || hostExecution.providerModelFallbackAllowed !== false
  || hostExecution.routeDigest !== contract.routeDigest
  || hostExecution.executionSpecDigest !== contract.executionSpecDigest
  || typeof hostExecution.threadId !== 'string' || !hostExecution.threadId
  || typeof hostExecution.turnId !== 'string' || !hostExecution.turnId
  || typeof hostExecution.actualModel !== 'string' || !hostExecution.actualModel
  || typeof hostExecution.actualHostReasoning !== 'string' || !hostExecution.actualHostReasoning
) throw new Error('real host smoke did not prove a verified Codex App Server execution');
const receipt = document.results?.[0];
for (const [field, expected] of Object.entries({
  taskId: contract.taskId,
  worker: contract.worker,
  workflowId: contract.workflowId,
  executionId: contract.executionId,
  graphDigest: contract.graphDigest,
  routeDigest: contract.routeDigest,
  executionSpecDigest: contract.executionSpecDigest,
  attemptId: contract.attemptId,
  leaseGeneration: contract.leaseGeneration,
  fencingToken: contract.fencingToken,
})) {
  if (receipt?.[field] !== expected) throw new Error(`receipt identity mismatch: ${field}`);
}
if (receipt.outcome !== 'complete' || typeof receipt.evidence !== 'string' || !receipt.evidence.trim()) {
  throw new Error(`real host smoke returned outcome ${JSON.stringify(receipt.outcome)} with error ${JSON.stringify(receipt.error || '')}`);
}
process.stdout.write(`${JSON.stringify({ schemaVersion: 2, result: 'PASS', provider: hostExecution.provider, actualModel: hostExecution.actualModel, actualHostReasoning: hostExecution.actualHostReasoning, threadId: hostExecution.threadId, turnId: hostExecution.turnId, routeDigest: hostExecution.routeDigest, outcome: receipt.outcome, evidence: receipt.evidence })}\n`);
