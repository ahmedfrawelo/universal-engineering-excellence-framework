#!/usr/bin/env node
import fs from 'node:fs';

const input = process.argv[2];
const output = process.argv[3] || 'design-system-recommendations.json';
if (!input) throw new Error('Usage: node scripts/recommend-design-system.mjs <extraction-json> [output-json]');
const report = JSON.parse(fs.readFileSync(input, 'utf8'));
const evidence = report.evidence || {};
const recommendations = [];
const add = (priority, area, decision, rationale, action) => recommendations.push({ priority, area, decision, rationale, action });

if ((evidence.fonts?.length || 0) > 3) add('P1', 'typography', 'REVIEW', 'Multiple font stacks can create inconsistent hierarchy and loading cost.', 'Group stacks into semantic roles and document the approved fallback order.');
if ((evidence.iconPackages?.length || 0) > 1) add('P1', 'icons', 'CONSOLIDATE', 'Multiple icon sources can create mixed geometry and stroke language.', 'Choose one primary UI icon family and document exceptions for brand or domain assets.');
if ((evidence.cssVars?.length || 0) < 12) add('P1', 'tokens', 'EXTEND', 'The token evidence is too small to govern a mature interface.', 'Define semantic roles for surfaces, text, borders, focus, status, spacing, sizing, and motion in the existing source of truth.');
if ((evidence.colors?.length || 0) > 80) add('P2', 'colors', 'NORMALIZE', 'Many raw colors increase drift and make theme parity harder to prove.', 'Map raw values to semantic roles and remove duplicate literals where consumers permit.');
if (!(evidence.fontAssets?.length)) add('P2', 'font-loading', 'VERIFY', 'No local font asset was found in the scanned source.', 'Verify licensing, network loading, fallback behavior, and language coverage before proposing a new font.');
if (!(evidence.radii?.length)) add('P2', 'shape', 'ADD_ROLE', 'No radius evidence was extracted.', 'Add a small semantic radius scale only in the governed design source.');
if (!(evidence.strokes?.length)) add('P2', 'strokes', 'ADD_ROLE', 'No outline or stroke evidence was extracted.', 'Define semantic outline, divider, focus, and control strokes with theme mappings.');
if (!recommendations.length) add('P3', 'governance', 'MAINTAIN', 'The extracted evidence supports an existing design system.', 'Reuse current tokens and require evidence before introducing new visual primitives.');

const result = {
  generatedAt: new Date().toISOString(),
  sourceReport: '<extraction-report>',
  classification: 'inferred recommendations from extracted evidence; not automatic approval',
  recommendations,
  reviewRequired: recommendations.some((item) => item.priority === 'P1')
};
fs.writeFileSync(output, JSON.stringify(result, null, 2) + '\n', 'utf8');
console.log(`Design recommendations written: ${output}`);
console.log(`Recommendations: ${recommendations.length}; reviewRequired=${result.reviewRequired}`);
