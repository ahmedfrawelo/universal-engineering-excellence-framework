#!/usr/bin/env node
import fs from 'node:fs';
import crypto from 'node:crypto';

const path = process.argv[2];
if (!path || !fs.existsSync(path)) throw new Error(`Completion audit not found: ${path ?? ''}`);
const audit = JSON.parse(fs.readFileSync(path, 'utf8').replace(/^\uFEFF/, ''));
const text = (value, name) => {
  if (typeof value !== 'string' || !value.trim() || /^(replace-me|todo|tbd)$/i.test(value.trim())) throw new Error(`Completion audit requires substantive ${name}.`);
};
if (audit.schemaVersion !== 2) throw new Error('Completion audit schemaVersion 2 is required for literal goal coverage.');
text(audit.taskId, 'taskId'); text(audit.requestedOutcome, 'requestedOutcome');
const auditTime = Date.parse(audit.auditedAt);
if (Number.isNaN(auditTime)) throw new Error('Completion audit requires a valid auditedAt timestamp.');
const review = audit.sourceReview;
if (!review || review.coverageMode !== 'verbatim-segments' || review.status !== 'PASS') throw new Error('sourceReview must PASS with verbatim-segments coverage.');
text(review.sourceText, 'sourceReview.sourceText'); text(review.sourceSha256, 'sourceReview.sourceSha256');
const hash = crypto.createHash('sha256').update(Buffer.from(review.sourceText, 'utf8')).digest('hex').toUpperCase();
if (hash !== String(review.sourceSha256).toUpperCase()) throw new Error('sourceReview.sourceSha256 does not match sourceText.');
const requirements = Array.isArray(audit.requirements) ? audit.requirements : [];
const criteria = Array.isArray(audit.acceptanceCriteria) ? audit.acceptanceCriteria : [];
if (!requirements.length || !criteria.length) throw new Error('Completion audit requires requirements and acceptance criteria.');
const reqIds = new Set();
for (const r of requirements) { text(r.id, 'requirement id'); const id=String(r.id).toLowerCase(); if(reqIds.has(id)) throw new Error(`Duplicate requirement id: ${r.id}`); reqIds.add(id); }
const criterionIds = new Set();
for (const c of criteria) {
  text(c.id, 'acceptance criterion id'); text(c.text, `acceptance criterion ${c.id} text`);
  const id=String(c.id).toLowerCase(); if(criterionIds.has(id)) throw new Error(`Duplicate acceptance criterion id: ${c.id}`); criterionIds.add(id);
  if (c.status !== 'PASS' || !Array.isArray(c.evidence) || !c.evidence.length) throw new Error(`Acceptance criterion ${c.id} is not evidenced PASS.`);
  for (const e of c.evidence) { text(e.kind, 'evidence kind'); text(e.source, 'evidence source'); const observedAt=Date.parse(e.observedAt); if (e.result !== 'PASS' || Number.isNaN(observedAt) || observedAt > auditTime + 60000) throw new Error(`Acceptance criterion ${c.id} contains invalid or future evidence.`); }
}
const linkedCriteria = new Set();
for (const r of requirements) { text(r.id, 'requirement id'); text(r.text, `requirement ${r.id} text`); if (r.status !== 'PASS' || !Array.isArray(r.acceptanceCriteria) || !r.acceptanceCriteria.length) throw new Error(`Requirement ${r.id} is not linked PASS.`); for (const id of r.acceptanceCriteria) { if (!criterionIds.has(String(id).toLowerCase())) throw new Error(`Requirement ${r.id} references missing criterion ${id}.`); linkedCriteria.add(String(id).toLowerCase()); } }
for (const id of criterionIds) if (!linkedCriteria.has(id)) throw new Error(`Acceptance criterion ${id} is not linked to a requirement.`);
const units = Array.isArray(review.reviewUnits) ? [...review.reviewUnits].sort((a, b) => a.start - b.start) : [];
if (!units.length) throw new Error('sourceReview requires review units.');
let end = 0; const unitIds = new Set();
for (const u of units) { text(u.id, 'review unit id'); if (unitIds.has(String(u.id).toLowerCase())) throw new Error(`Duplicate review unit ${u.id}.`); unitIds.add(String(u.id).toLowerCase()); if (u.status !== 'PASS' || !['requirement','constraint','instruction','context','non-goal'].includes(u.classification)) throw new Error(`Review unit ${u.id} is invalid.`); if (!Number.isInteger(u.start) || !Number.isInteger(u.end) || u.start < end || u.end <= u.start || u.end > review.sourceText.length) throw new Error(`Review unit ${u.id} has invalid bounds.`); if (/\S/.test(review.sourceText.slice(end, u.start))) throw new Error(`Unreviewed source text before ${u.id}.`); if (u.sourceQuote !== review.sourceText.slice(u.start, u.end)) throw new Error(`Review unit ${u.id} quote mismatch.`); if (!Array.isArray(u.linkedRequirements) || !u.linkedRequirements.length || u.linkedRequirements.some(id => !reqIds.has(String(id).toLowerCase()))) throw new Error(`Review unit ${u.id} has invalid requirement links.`); end = u.end; }
if (/\S/.test(review.sourceText.slice(end))) throw new Error('Unreviewed source text remains after final review unit.');
const implementation = audit.implementationReview;
if (!implementation) throw new Error('Completion audit requires implementationReview.');
const implementationCompletedAt = Date.parse(implementation.implementationCompletedAt);
const goalReviewStartedAt = Date.parse(implementation.goalReviewStartedAt);
if (Number.isNaN(implementationCompletedAt) || Number.isNaN(goalReviewStartedAt) || goalReviewStartedAt < implementationCompletedAt) throw new Error('Goal review must start at or after implementation completion.');
if (!implementation.transitionAnnounced || !implementation.goalRemainedActiveDuringReview || implementation.requestedImplementationStatus !== 'PASS' || implementation.bestFeasibleOutcomeStatus !== 'PASS' || implementation.goalToImplementationComparisonStatus !== 'PASS' || implementation.status !== 'PASS') throw new Error('implementationReview must announce and PASS actual implementation comparison while the goal remains ACTIVE.');
text(implementation.bestFeasibleOutcomeRationale, 'implementationReview.bestFeasibleOutcomeRationale');
const actualInventory = Array.isArray(implementation.actualImplementationInventory) ? implementation.actualImplementationInventory : [];
if (!actualInventory.length) throw new Error('implementationReview requires an actual implementation inventory.');
if ((implementation.missingImplementation ?? []).length) throw new Error('Required implementation is still missing; implement it and repeat the comparison.');
if ((implementation.untracedImplementation ?? []).length) throw new Error('Untraced implementation remains outside the requirement comparison.');
const implementationMap = new Map();
for (const actual of actualInventory) { text(actual.id, 'actual implementation id'); text(actual.surface, 'actual implementation surface'); text(actual.observedBehavior, 'actual implementation observed behavior'); text(actual.evidence, 'actual implementation evidence'); const id=String(actual.id).toLowerCase(); if(implementationMap.has(id)) throw new Error(`Duplicate actual implementation id: ${actual.id}`); if(actual.status !== 'PASS' || !Array.isArray(actual.linkedRequirements) || !actual.linkedRequirements.length || actual.linkedRequirements.some(req => !reqIds.has(String(req).toLowerCase()))) throw new Error(`Actual implementation ${actual.id} is not traced PASS.`); implementationMap.set(id,actual); }
const checklist = Array.isArray(audit.completionChecklist) ? audit.completionChecklist : [];
if (checklist.length !== requirements.length) throw new Error('completionChecklist must contain exactly one item per requirement.');
const unitMap = new Map(units.map(u => [String(u.id).toLowerCase(), u]));
const checkedRequirements = new Set();
for (const item of checklist) {
  const requirementId = String(item.requirementId).toLowerCase();
  if (!reqIds.has(requirementId) || checkedRequirements.has(requirementId)) throw new Error(`completionChecklist contains a missing or duplicate requirement: ${item.requirementId}`);
  checkedRequirements.add(requirementId);
  if (!item.checked || item.status !== 'PASS' || item.requestedImplementationStatus !== 'PASS' || item.bestFeasibleOutcomeStatus !== 'PASS' || item.goalToImplementationComparisonStatus !== 'PASS') throw new Error(`completionChecklist item ${item.requirementId} is not fully compared and checked PASS.`);
  text(item.bestFeasibleOutcomeRationale, `completionChecklist item ${item.requirementId} rationale`);
  const requirement = requirements.find(r => String(r.id).toLowerCase() === requirementId);
  const itemCriteria = new Set((item.acceptanceCriteria ?? []).map(id => String(id).toLowerCase()));
  for (const id of requirement.acceptanceCriteria) if (!itemCriteria.has(String(id).toLowerCase())) throw new Error(`completionChecklist item ${item.requirementId} omits acceptance criterion ${id}.`);
  if (!Array.isArray(item.sourceReviewUnits) || !item.sourceReviewUnits.length) throw new Error(`completionChecklist item ${item.requirementId} has no source review units.`);
  for (const id of item.sourceReviewUnits) { const unit = unitMap.get(String(id).toLowerCase()); if (!unit || !unit.linkedRequirements.some(req => String(req).toLowerCase() === requirementId)) throw new Error(`completionChecklist item ${item.requirementId} has invalid source review unit ${id}.`); }
  if (!Array.isArray(item.actualImplementationIds) || !item.actualImplementationIds.length) throw new Error(`completionChecklist item ${item.requirementId} has no actual implementation evidence.`);
  for (const id of item.actualImplementationIds) { const actual=implementationMap.get(String(id).toLowerCase()); if(!actual || !actual.linkedRequirements.some(req => String(req).toLowerCase() === requirementId)) throw new Error(`completionChecklist item ${item.requirementId} has invalid actual implementation ${id}.`); }
}
const regressions = audit.regressionReview;
if (!regressions || regressions.status !== 'PASS') throw new Error('Completion audit requires a passing regressionReview.');
text(regressions.scope, 'regressionReview.scope');
if (!Array.isArray(regressions.changedSurfaces) || !regressions.changedSurfaces.length || !Array.isArray(regressions.checks) || !regressions.checks.length) throw new Error('regressionReview requires changed surfaces and focused checks.');
for (const check of regressions.checks) { text(check.surface, 'regression check surface'); text(check.evidence, 'regression check evidence'); if (check.result !== 'PASS') throw new Error(`Regression check ${check.surface} is not PASS.`); }
if (Array.isArray(regressions.taskCausedRegressions) && regressions.taskCausedRegressions.length) throw new Error('Task-caused regressions remain; fix them before completion.');
for (const finding of regressions.unrelatedFindings ?? []) { text(finding.description, 'unrelated finding description'); text(finding.evidence, 'unrelated finding evidence'); text(finding.outOfScopeReason, 'unrelated finding out-of-scope reason'); }
const commitments = audit.userCommitmentReview;
if (!commitments || commitments.status !== 'PASS') throw new Error('Completion audit requires a passing userCommitmentReview.');
if (Array.isArray(commitments.pendingCommitments) && commitments.pendingCommitments.length) throw new Error('An explicit before-finish user commitment remains pending.');
if (commitments.explicitBeforeFinishRequestDetected && !commitments.clarificationAskedBeforeCompletion) throw new Error('Before-finish commitment clarification was not asked before completion.');
if (!Array.isArray(commitments.resolutionEvidence) || !commitments.resolutionEvidence.length) throw new Error('userCommitmentReview requires resolution evidence.');
for (const item of commitments.resolutionEvidence) text(item, 'user commitment resolution evidence');
const goalUpdates = audit.goalUpdateReview;
if (!goalUpdates || goalUpdates.status !== 'PASS') throw new Error('Completion audit requires a passing goalUpdateReview.');
if (!goalUpdates.allReceivedUpdatesClassified || goalUpdates.updateDetectionStatus !== 'PASS') throw new Error('Every received goal update must be detected and classified.');
const updateRoutes = Array.isArray(goalUpdates.routes) ? goalUpdates.routes : [];
if (!Number.isInteger(goalUpdates.updatesReceived) || goalUpdates.updatesReceived < 0 || updateRoutes.length !== goalUpdates.updatesReceived) throw new Error('goalUpdateReview routes must account for every received update.');
if ((goalUpdates.pendingUpdates ?? []).length || (goalUpdates.openResumePoints ?? []).length) throw new Error('Goal updates or resume points remain pending.');
const updateIds = new Set();
for (const route of updateRoutes) { text(route.id, 'goal update route id'); text(route.summary, 'goal update route summary'); text(route.targetStep, 'goal update target step'); text(route.resolutionEvidence, 'goal update resolution evidence'); const id=String(route.id).toLowerCase(); if(updateIds.has(id)) throw new Error(`Duplicate goal update route id: ${route.id}`); updateIds.add(id); if(!['CURRENT_STEP','PRIOR_STEP_CORRECTION','FUTURE_STEP','INVALIDATES_CURRENT_WORK','CONFLICT_OR_AMBIGUOUS'].includes(route.relation) || route.status !== 'PASS') throw new Error(`Invalid goal update route: ${route.id}`); }
if ((audit.remainingWork ?? []).length || (audit.knownProblems ?? []).length || audit.conclusion !== 'COMPLETE') throw new Error('Completion audit is not COMPLETE.');
console.log(JSON.stringify({ schemaVersion: 2, status: 'PASS', taskId: audit.taskId, requirements: requirements.length, acceptanceCriteria: criteria.length, reviewUnits: units.length, checklistItems: checklist.length, path: path }));
