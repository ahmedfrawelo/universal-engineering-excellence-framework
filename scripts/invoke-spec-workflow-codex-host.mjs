import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { receiptFromHostText, receiptTemplate } from './spec-workflow-host-receipt-lib.mjs';

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

if (!route || !fs.existsSync(route)) {
  fail('provide an existing --route file');
} else if (!fs.existsSync(cwd) || !fs.statSync(cwd).isDirectory()) {
  fail('--cwd must be an existing directory');
} else if (!['read-only', 'workspace-write', 'danger-full-access'].includes(sandbox)) {
  fail('--sandbox is invalid');
} else {
  let contract;
  try { contract = JSON.parse(fs.readFileSync(0, 'utf8')); } catch { fail('stdin must contain one dispatch contract JSON object'); }
  if (contract && (contract.adapter !== 'codex' || contract.transport !== 'codex-thread')) {
    fail('contract must use the Codex thread transport');
  } else if (contract && (![contract.taskId, contract.worker, contract.prompt, contract.workflowId, contract.executionId, contract.graphDigest, contract.routeDigest, contract.executionSpecDigest, contract.attemptId, contract.fencingToken].every((value) => typeof value === 'string' && value.trim()) || !Number.isInteger(contract.leaseGeneration) || contract.leaseGeneration < 1 || Buffer.byteLength(JSON.stringify(contract), 'utf8') > 256 * 1024)) {
    fail('contract must have bounded schema-version-2 identity and prompt fields');
  } else if (contract) {
    const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'ueef-codex-host-'));
    try {
      const promptPath = path.join(temp, 'prompt.txt');
      const outputPath = path.join(temp, 'dispatch.json');
      const prompt = `${contract.prompt}\n\nThe dispatcher supplies a prevalidated one-shot host route for this turn. Do not record, replace, or redispatch that route. After the work, return ONLY this exact JSON-shaped receipt with the outcome and evidence filled in. Do not omit or rename identity fields:\n${JSON.stringify(receiptTemplate(contract))}`;
      fs.writeFileSync(promptPath, prompt, 'utf8');
      const result = spawnSync(process.execPath, [dispatch, '--route', route, '--prompt-file', promptPath, '--output', outputPath, '--cwd', cwd, '--sandbox', sandbox, '--response-language', 'en'], { encoding: 'utf8' });
      if (result.status !== 0 || !fs.existsSync(outputPath)) throw new Error((result.stderr || 'Codex App Server dispatch failed').trim());
      const dispatchResult = JSON.parse(fs.readFileSync(outputPath, 'utf8'));
      const routeDocument = JSON.parse(fs.readFileSync(route, 'utf8'));
      const approvedPairs = new Set([
        `${routeDocument.preferredModel}\u0000${routeDocument.hostReasoning}`,
        routeDocument.fallbackModel && routeDocument.fallbackHostReasoning
          ? `${routeDocument.fallbackModel}\u0000${routeDocument.fallbackHostReasoning}`
          : null,
      ].filter(Boolean));
      if (
        dispatchResult.schemaVersion !== 1
        || dispatchResult.provider !== 'codex-app-server:turn/start'
        || dispatchResult.result !== 'SUCCESS'
        || dispatchResult.executionVerified !== true
        || dispatchResult.providerModelFallbackAllowed !== false
        || dispatchResult.routeDigest !== contract.routeDigest
        || dispatchResult.executionSpecDigest !== contract.executionSpecDigest
        || !approvedPairs.has(`${dispatchResult.actualModel}\u0000${dispatchResult.actualHostReasoning}`)
        || typeof dispatchResult.finalText !== 'string'
        || !dispatchResult.finalText.trim()
      ) throw new Error(dispatchResult.errorMessage || 'Codex App Server execution identity was not verified');
      process.stdout.write(`${JSON.stringify({
        schemaVersion: 2,
        hostExecution: {
          provider: dispatchResult.provider,
          executionVerified: true,
          ephemeral: dispatchResult.ephemeral === true,
          threadId: dispatchResult.threadId,
          turnId: dispatchResult.turnId,
          routeDigest: dispatchResult.routeDigest,
          executionSpecDigest: dispatchResult.executionSpecDigest,
          actualModel: dispatchResult.actualModel,
          actualHostReasoning: dispatchResult.actualHostReasoning,
          capacityFallbackUsed: dispatchResult.capacityFallbackUsed === true,
          providerModelFallbackAllowed: false,
        },
        results: [receiptFromHostText(dispatchResult.finalText, contract)],
      })}\n`);
    } catch (error) {
      fail(error instanceof Error ? error.message : String(error));
    } finally {
      fs.rmSync(temp, { recursive: true, force: true });
    }
  }
}
