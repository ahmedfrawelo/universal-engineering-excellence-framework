import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { parseHostReceipt } from './spec-workflow-host-receipt-lib.mjs';

const args = process.argv.slice(2);
const valueAfter = (flag) => {
  const index = args.indexOf(flag);
  return index === -1 ? null : args[index + 1] || null;
};
const executable = valueAfter('--executable');
const cwd = path.resolve(valueAfter('--cwd') || process.cwd());
const commandArgs = args.flatMap((value, index) => value === '--arg' ? [args[index + 1]] : []).filter(Boolean);

function fail(message) {
  process.stderr.write(`Spec-workflow generic host failed: ${message}\n`);
  process.exitCode = 1;
}

if (!executable) {
  fail('provide --executable for the explicit generic host command');
} else if (!fs.existsSync(cwd) || !fs.statSync(cwd).isDirectory()) {
  fail('--cwd must be an existing directory');
} else {
  let contract;
  try { contract = JSON.parse(fs.readFileSync(0, 'utf8')); } catch { fail('stdin must contain one dispatch contract JSON object'); }
  if (contract && (contract.adapter !== 'generic' || contract.transport !== 'external')) {
    fail('contract must use the generic external transport');
  } else if (contract) {
    const result = spawnSync(executable, commandArgs, {
      cwd,
      input: JSON.stringify(contract),
      encoding: 'utf8',
      windowsHide: true,
      timeout: 300_000,
      maxBuffer: 1024 * 1024,
    });
    if (result.error) {
      fail(result.error.message);
    } else if (result.status !== 0) {
      fail((result.stderr || 'generic host command failed').trim());
    } else {
      try {
        const envelope = JSON.parse(result.stdout);
        if (envelope.schemaVersion !== 2 || !Array.isArray(envelope.results) || envelope.results.length !== 1) {
          throw new Error('generic host must return one schema-version-2 result');
        }
        const receipt = parseHostReceipt(
          JSON.stringify({ schemaVersion: 2, ...envelope.results[0] }),
          contract,
        );
        process.stdout.write(`${JSON.stringify({ schemaVersion: 2, results: [receipt] })}\n`);
      } catch (error) {
        fail(error instanceof Error ? error.message : String(error));
      }
    }
  }
}
