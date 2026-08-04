#!/usr/bin/env node
import {execFileSync} from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {selectDesignProductionRoute} from './frontend-design-production-route-lib.mjs';

const args = process.argv.slice(2);
const value = (name, fallback = '') => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] ?? fallback : fallback; };
const evidencePath = path.resolve(value('--path', 'frontend-execution-evidence.json'));
const fail = (message) => { console.error(`FRONTEND_EXECUTION_EVIDENCE: FAIL\n${message}`); process.exit(1); };
const substantive = (value) => typeof value === 'string' && value.trim().length >= 8 && !/^(?:todo|tbd|replace-me|none)$/iu.test(value.trim());
if (!fs.existsSync(evidencePath)) fail(`Missing: ${evidencePath}`);
let evidence;
try { evidence = JSON.parse(fs.readFileSync(evidencePath, 'utf8')); } catch (error) { fail(`Invalid JSON: ${error.message}`); }
if (evidence.schemaVersion !== 1 || !substantive(evidence.task) || evidence.status !== 'PASS') fail('schemaVersion 1, substantive task, and status PASS are required.');
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const policy = JSON.parse(fs.readFileSync(path.join(root, 'config/frontend-design-production-policy.json'), 'utf8'));
const route = selectDesignProductionRoute(evidence.task, policy);
const phases = new Set(evidence.completedPhases || []);
for (const phase of route.phases) if (!phases.has(phase)) fail(`Missing completed phase: ${phase}`);
const ownership = evidence.ownership || {};
if (ownership.inspected !== true || !substantive(ownership.owner) || !substantive(ownership.reuseSearch) || !substantive(ownership.decision)) fail('Ownership inspection, owner, reuse search, and decision are mandatory.');
const contract = evidence.designContract || {};
if (contract.required !== true || contract.status !== 'PASS' || !substantive(contract.path)) fail('A passing DESIGN.md contract is mandatory for material frontend execution.');
const contractPath = path.resolve(path.dirname(evidencePath), contract.path);
try { execFileSync(process.execPath, [path.join(root, 'scripts/validate-design-contract.mjs'), '--path', contractPath], {stdio:'pipe'}); }
catch { fail(`DESIGN.md validation failed: ${contractPath}`); }
const tokens = evidence.tokens || {};
if (tokens.inspected !== true || tokens.semanticTokensReused !== true || tokens.rawValuesReviewed !== true || !Array.isArray(tokens.themesVerified) || !tokens.themesVerified.length) fail('Token inspection, semantic reuse, raw-value review, and supported-theme verification are mandatory.');
const state = evidence.states || {};
const verifiedStates = new Set(state.verified || []);
for (const requiredState of policy.qualityContract.states) {
  if (verifiedStates.has(requiredState)) continue;
  if (!substantive(state.notApplicable?.[requiredState])) fail(`State '${requiredState}' needs verification or a substantive not-applicable reason.`);
}
for (const area of ['responsive', 'accessibility']) {
  if (evidence[area]?.verified !== true || !substantive(evidence[area]?.evidence)) fail(`${area} verification evidence is mandatory.`);
}
const performance = evidence.performance || {};
if (performance.reviewed !== true || !substantive(performance.evidence)) fail('Performance review evidence is mandatory.');
if (/performance|slow|lcp|inp|cls|bundle|سرع|أداء|اداء/iu.test(evidence.task) && (performance.measured !== true || !/\d+(?:\.\d+)?\s*(?:ms|s|kb|mb|%|fps|score)/iu.test(performance.evidence))) fail('Performance-scoped work requires a numeric measurement with a unit.');
if (evidence.tests?.status !== 'PASS' || !Array.isArray(evidence.tests?.commands) || !evidence.tests.commands.some(substantive)) fail('Passing focused test commands are mandatory.');
const render = evidence.render || {};
if (render.visualChange === true) {
  if (render.status !== 'PASS' || !substantive(render.evidence)) fail('Visual changes require passing rendered evidence.');
} else if (!substantive(render.rationale)) fail('Non-visual classification requires a substantive rationale.');
if (route.tasteSelected) {
  if (evidence.taste?.preflight !== 'PASS' || evidence.taste?.finalCheck !== 'PASS') fail('Taste preflight and final check are mandatory when Taste is selected.');
  const checks = new Set(evidence.taste?.checks || []);
  for (const check of route.tasteAntiRepetitionChecks) if (!checks.has(check)) fail(`Missing Taste check: ${check}`);
}
if (route.skills.includes(policy.routing.reviewGate)) {
  if (Number(evidence.styleseed?.score) < policy.styleseed.minimumScore || evidence.styleseed?.finalRenderVerified !== true) fail(`Styleseed score >= ${policy.styleseed.minimumScore} and final render verification are mandatory.`);
}
if (evidence.penpot?.liveUseClaimed === true) {
  for (const field of ['configured','reachable','pluginConnected','targetSelected','operationSucceeded']) if (evidence.penpot[field] !== true) fail(`Live Penpot claim missing: ${field}`);
}
console.log(JSON.stringify({schemaVersion:1,status:'PASS',task:evidence.task,director:route.director,skills:route.skills,phases:[...phases],evidencePath}, null, 2));
console.log('FRONTEND_EXECUTION_EVIDENCE: PASS');
