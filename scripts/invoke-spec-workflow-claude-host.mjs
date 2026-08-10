import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { receiptFromHostText, receiptTemplate } from './spec-workflow-host-receipt-lib.mjs';

const args = process.argv.slice(2);
const valueAfter = (flag) => {
  const index = args.indexOf(flag);
  return index === -1 ? null : args[index + 1] || null;
};
const executable = valueAfter('--executable') || 'claude';
const cwd = path.resolve(valueAfter('--cwd') || process.cwd());
const model = valueAfter('--model');
const maxTurns = Number(valueAfter('--max-turns') || 20);

function fail(message) {
  process.stderr.write(`Spec-workflow Claude host failed: ${message}\n`);
  process.exitCode = 1;
}

if (!fs.existsSync(cwd) || !fs.statSync(cwd).isDirectory()) {
  fail('--cwd must be an existing directory');
} else if (!Number.isInteger(maxTurns) || maxTurns < 1 || maxTurns > 100) {
  fail('--max-turns must be an integer from 1 through 100');
} else {
  let contract;
  try { contract = JSON.parse(fs.readFileSync(0, 'utf8')); } catch { fail('stdin must contain one dispatch contract JSON object'); }
  if (contract && (contract.adapter !== 'claude' || contract.transport !== 'claude-agent-team')) {
    fail('contract must use the Claude agent-team transport');
  } else if (contract && (![contract.taskId, contract.worker, contract.prompt, contract.workflowId, contract.executionId, contract.graphDigest, contract.routeDigest, contract.executionSpecDigest, contract.attemptId, contract.fencingToken].every((value) => typeof value === 'string' && value.trim()) || !Number.isInteger(contract.leaseGeneration) || contract.leaseGeneration < 1 || Buffer.byteLength(JSON.stringify(contract), 'utf8') > 256 * 1024)) {
    fail('contract must have bounded schema-version-2 identity and prompt fields');
  } else if (contract) {
    const prompt = `${contract.prompt}\n\nReturn ONLY this exact JSON-shaped receipt with the outcome and evidence filled in. Do not omit or rename identity fields:\n${JSON.stringify(receiptTemplate(contract))}`;
    const commandArgs = ['-p', prompt, '--output-format', 'json', '--max-turns', String(maxTurns)];
    if (model) commandArgs.push('--model', model);
    const result = spawnSync(executable, commandArgs, { cwd, encoding: 'utf8', windowsHide: true });
    if (result.error) {
      fail(`Claude CLI is unavailable: ${result.error.message}`);
    } else if (result.status !== 0) {
      fail((result.stderr || 'Claude CLI failed').trim());
    } else {
      try {
        const response = JSON.parse(result.stdout);
        if (response.type !== 'result' || response.is_error === true || response.subtype !== 'success') {
          throw new Error(response.result || 'Claude did not return a successful result');
        }
        process.stdout.write(`${JSON.stringify({ schemaVersion: 2, results: [receiptFromHostText(response.result, contract)] })}\n`);
      } catch (error) {
        fail(error instanceof Error ? error.message : String(error));
      }
    }
  }
}
