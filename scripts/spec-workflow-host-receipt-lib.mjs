export const identityFields = Object.freeze([
  'taskId', 'worker', 'workflowId', 'executionId', 'graphDigest', 'routeDigest',
  'executionSpecDigest', 'attemptId', 'leaseGeneration', 'fencingToken',
]);

export function parseHostReceipt(text, contract) {
  const trimmed = String(text || '').trim();
  const fenced = trimmed.match(/```json\s*([\s\S]*?)\s*```/iu)?.[1];
  let candidate = fenced || trimmed;
  let result;
  try {
    result = JSON.parse(candidate);
  } catch {
    const first = candidate.indexOf('{');
    const last = candidate.lastIndexOf('}');
    if (first < 0 || last <= first) throw new Error('worker final response must contain one JSON receipt');
    candidate = candidate.slice(first, last + 1);
    try { result = JSON.parse(candidate); } catch { throw new Error('worker final response must contain one JSON receipt'); }
  }
  if (!result || result.schemaVersion !== 2 || typeof result !== 'object' || Array.isArray(result)) throw new Error('worker receipt schemaVersion must be 2');
  const mismatchedIdentity = identityFields.filter((field) => result[field] !== contract[field]);
  if (mismatchedIdentity.length) throw new Error(`worker receipt identity does not match the dispatch contract: ${mismatchedIdentity.join(', ')}`);
  const outcomeAliases = new Map([
    ['complete', 'complete'], ['completed', 'complete'], ['success', 'complete'], ['passed', 'complete'],
    ['fail', 'fail'], ['failed', 'fail'], ['failure', 'fail'], ['error', 'fail'],
    ['block', 'block'], ['blocked', 'block'],
  ]);
  const outcome = typeof result.outcome === 'string' ? outcomeAliases.get(result.outcome.trim().toLowerCase()) : null;
  if (!outcome) throw new Error('worker receipt has an invalid outcome');
  if (outcome === 'complete' && (typeof result.evidence !== 'string' || !result.evidence.trim())) throw new Error('complete receipt requires evidence');
  const tokens = result.tokens === undefined ? 0 : result.tokens;
  if (!Number.isInteger(tokens) || tokens < 0) throw new Error('worker receipt tokens must be a non-negative integer');
  return {
    taskId: result.taskId,
    worker: result.worker,
    outcome,
    evidence: typeof result.evidence === 'string' ? result.evidence : '',
    error: typeof result.error === 'string' ? result.error : '',
    tokens,
    ...Object.fromEntries(identityFields.slice(2).map((field) => [field, result[field]])),
  };
}

export function receiptTemplate(contract) {
  const identity = Object.fromEntries(identityFields.map((field) => [field, contract[field]]));
  // Use the protocol alias "success" so the host's Stop hook does not mistake
  // a worker receipt for a top-level project completion claim.
  return { schemaVersion: 2, ...identity, outcome: 'success', evidence: 'acceptance evidence', error: '', tokens: 0 };
}

export function receiptFromHostText(text, contract) {
  return parseHostReceipt(text, contract);
}
