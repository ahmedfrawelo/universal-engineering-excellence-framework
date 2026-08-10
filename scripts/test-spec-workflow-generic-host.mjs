import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.dirname(fileURLToPath(import.meta.url));
const bridge = path.join(root, 'invoke-spec-workflow-generic-host.mjs');
const fixture = path.join(root, '..', 'engines', 'spec-workflow', 'tests', 'fixtures', 'fake_spec_workflow_host.mjs');
const contract = {
  adapter: 'generic', transport: 'external', taskId: 'TASK-001', worker: 'worker-1',
  workflowId: 'demo-flow', executionId: 'execution-1', graphDigest: '1'.repeat(64),
  routeDigest: '2'.repeat(64), executionSpecDigest: '3'.repeat(64), attemptId: 'attempt-1',
  leaseGeneration: 1, fencingToken: '4'.repeat(64), prompt: 'execute', acceptance: ['AC-001'],
};
const result = spawnSync(process.execPath, [bridge, '--executable', process.execPath, '--arg', fixture], {
  input: JSON.stringify(contract), encoding: 'utf8', windowsHide: true,
});
assert.equal(result.status, 0, result.stderr);
const receipt = JSON.parse(result.stdout).results[0];
assert.equal(receipt.taskId, contract.taskId);
assert.deepEqual(JSON.parse(receipt.evidence), { 'AC-001': 'fixture verified' });
process.stdout.write('Spec workflow generic host tests passed\n');
