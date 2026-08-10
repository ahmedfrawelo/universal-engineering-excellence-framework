import fs from 'node:fs';

const contract = JSON.parse(fs.readFileSync(0, 'utf8'));
if (process.env.UEEF_FAKE_HOST_COUNTER) {
  fs.appendFileSync(process.env.UEEF_FAKE_HOST_COUNTER, `${contract.attemptId}\n`, 'utf8');
}
const delay = Number(process.env.UEEF_FAKE_HOST_DELAY_MS || 0);
if (Number.isInteger(delay) && delay > 0 && delay <= 10_000) {
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, delay);
}
const fields = ['taskId', 'worker', 'workflowId', 'executionId', 'graphDigest', 'routeDigest', 'executionSpecDigest', 'attemptId', 'leaseGeneration', 'fencingToken'];
const identity = Object.fromEntries(fields.map((field) => [field, contract[field]]));
const evidence = JSON.stringify(Object.fromEntries(contract.acceptance.map((criterion) => [criterion, 'fixture verified'])));
process.stdout.write(`${JSON.stringify({ schemaVersion: 2, results: [{ ...identity, outcome: 'complete', evidence, error: '', tokens: 1 }] })}\n`);
