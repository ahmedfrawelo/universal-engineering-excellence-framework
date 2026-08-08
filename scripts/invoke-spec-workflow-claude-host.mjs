import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

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

function receipt(text, contract) {
  const trimmed = String(text || '').trim();
  const candidate = trimmed.match(/```json\s*([\s\S]*?)\s*```/u)?.[1] || trimmed;
  let result;
  try { result = JSON.parse(candidate); } catch { throw new Error('worker result must contain one JSON receipt'); }
  if (!result || result.schemaVersion !== 1 || typeof result !== 'object') throw new Error('worker receipt schemaVersion must be 1');
  if (result.taskId !== contract.taskId || result.worker !== contract.worker) throw new Error('worker receipt does not match the dispatch contract');
  if (!['complete', 'fail', 'block'].includes(result.outcome)) throw new Error('worker receipt has an invalid outcome');
  if (result.outcome === 'complete' && (typeof result.evidence !== 'string' || !result.evidence.trim())) throw new Error('complete receipt requires evidence');
  if (!Number.isInteger(result.tokens || 0) || (result.tokens || 0) < 0) throw new Error('worker receipt tokens must be a non-negative integer');
  return {
    taskId: result.taskId,
    worker: result.worker,
    outcome: result.outcome,
    evidence: typeof result.evidence === 'string' ? result.evidence : '',
    error: typeof result.error === 'string' ? result.error : '',
    tokens: result.tokens || 0
  };
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
  } else if (contract && (![contract.taskId, contract.worker, contract.prompt].every((value) => typeof value === 'string' && value.trim()) || Buffer.byteLength(JSON.stringify(contract), 'utf8') > 256 * 1024)) {
    fail('contract must have bounded taskId, worker, and prompt strings');
  } else if (contract) {
    const prompt = `${contract.prompt}\n\nReturn ONLY this JSON receipt (or a single json code fence):\n${JSON.stringify({ schemaVersion: 1, taskId: contract.taskId, worker: contract.worker, outcome: 'complete', evidence: 'acceptance evidence', error: '', tokens: 0 })}`;
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
        process.stdout.write(`${JSON.stringify({ schemaVersion: 1, results: [receipt(response.result, contract)] })}\n`);
      } catch (error) {
        fail(error instanceof Error ? error.message : String(error));
      }
    }
  }
}
