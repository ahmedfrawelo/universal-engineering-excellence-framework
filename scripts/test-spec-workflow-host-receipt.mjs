import assert from 'node:assert/strict';
import { parseHostReceipt, receiptFromHostText, receiptTemplate } from './spec-workflow-host-receipt-lib.mjs';

const contract = {
  taskId: 'TASK-001', worker: 'worker-1', workflowId: 'demo-flow', executionId: 'execution-1',
  graphDigest: '1'.repeat(64), routeDigest: '2'.repeat(64), executionSpecDigest: '3'.repeat(64),
  attemptId: 'attempt-1', leaseGeneration: 1, fencingToken: '4'.repeat(64),
};
const receipt = { ...receiptTemplate(contract), evidence: 'verified' };
assert.equal(parseHostReceipt(JSON.stringify(receipt), contract).evidence, 'verified');
assert.equal(parseHostReceipt(`Result:\n\n\`\`\`JSON\n${JSON.stringify(receipt)}\n\`\`\``, contract).taskId, 'TASK-001');
assert.equal(parseHostReceipt(`Completed. ${JSON.stringify(receipt)} End.`, contract).worker, 'worker-1');
assert.equal(parseHostReceipt(JSON.stringify({ ...receipt, outcome: 'completed' }), contract).outcome, 'complete');
assert.equal(parseHostReceipt(JSON.stringify({ ...receipt, outcome: 'FAILED', evidence: '', error: 'x' }), contract).outcome, 'fail');
assert.throws(
  () => parseHostReceipt(JSON.stringify({ ...receipt, fencingToken: 'stale' }), contract),
  /identity does not match.*fencingToken/,
);
assert.throws(
  () => receiptFromHostText(JSON.stringify({ ...receipt, fencingToken: 'stale' }), contract),
  /identity does not match/,
);
assert.throws(
  () => receiptFromHostText('Read-only task completed; heading is # UEEF Spec Workflow Engine.', contract),
  /must contain one JSON receipt/,
);
assert.equal(receiptTemplate(contract).outcome, 'success');
assert.throws(
  () => parseHostReceipt(JSON.stringify({ ...receipt, tokens: false }), contract),
  /tokens must be a non-negative integer/,
);
process.stdout.write('Spec workflow host receipt parser tests passed\n');
