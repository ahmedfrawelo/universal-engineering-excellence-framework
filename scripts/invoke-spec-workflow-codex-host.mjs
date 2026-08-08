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
const route = valueAfter('--route');
const cwd = path.resolve(valueAfter('--cwd') || process.cwd());
const sandbox = valueAfter('--sandbox') || 'workspace-write';
const dispatch = path.join(path.dirname(fileURLToPath(import.meta.url)), 'codex-app-server-dispatch.mjs');

function fail(message) {
  process.stderr.write(`Spec-workflow Codex host failed: ${message}\n`);
  process.exitCode = 1;
}

function receipt(text, contract) {
  const trimmed = String(text || '').trim();
  const candidate = trimmed.match(/```json\s*([\s\S]*?)\s*```/u)?.[1] || trimmed;
  let result;
  try { result = JSON.parse(candidate); } catch { throw new Error('worker final response must be one JSON receipt'); }
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

if (!route || !fs.existsSync(route)) {
  fail('provide an existing --route file');
} else if (!fs.existsSync(cwd) || !fs.statSync(cwd).isDirectory()) {
  fail('--cwd must be an existing directory');
} else if (!['read-only', 'workspace-write', 'danger-full-access'].includes(sandbox)) {
  fail('--sandbox is invalid');
} else {
  let contract;
  try { contract = JSON.parse(fs.readFileSync(0, 'utf8')); } catch { fail('stdin must contain one dispatch contract JSON object'); }
  if (contract && (!['codex', 'generic'].includes(contract.adapter) || contract.transport !== 'codex-thread')) {
    fail('contract must use the Codex thread transport');
  } else if (contract && (![contract.taskId, contract.worker, contract.prompt].every((value) => typeof value === 'string' && value.trim()) || Buffer.byteLength(JSON.stringify(contract), 'utf8') > 256 * 1024)) {
    fail('contract must have bounded taskId, worker, and prompt strings');
  } else if (contract) {
    const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'ueef-codex-host-'));
    try {
      const promptPath = path.join(temp, 'prompt.txt');
      const outputPath = path.join(temp, 'dispatch.json');
      const prompt = `${contract.prompt}\n\nReturn ONLY this JSON receipt (or a single json code fence):\n${JSON.stringify({ schemaVersion: 1, taskId: contract.taskId, worker: contract.worker, outcome: 'complete', evidence: 'acceptance evidence', error: '', tokens: 0 })}`;
      fs.writeFileSync(promptPath, prompt, 'utf8');
      const result = spawnSync(process.execPath, [dispatch, '--route', route, '--prompt-file', promptPath, '--output', outputPath, '--cwd', cwd, '--sandbox', sandbox, '--response-language', 'en'], { encoding: 'utf8' });
      if (result.status !== 0 || !fs.existsSync(outputPath)) throw new Error((result.stderr || 'Codex App Server dispatch failed').trim());
      const dispatchResult = JSON.parse(fs.readFileSync(outputPath, 'utf8'));
      if (dispatchResult.result !== 'SUCCESS' || !dispatchResult.executionVerified) throw new Error(dispatchResult.errorMessage || 'Codex execution was not verified');
      process.stdout.write(`${JSON.stringify({ schemaVersion: 1, results: [receipt(dispatchResult.finalText, contract)] })}\n`);
    } catch (error) {
      fail(error instanceof Error ? error.message : String(error));
    } finally {
      fs.rmSync(temp, { recursive: true, force: true });
    }
  }
}
