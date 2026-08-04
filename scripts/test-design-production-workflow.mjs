#!/usr/bin/env node
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const route = (task) => JSON.parse(execFileSync(process.execPath, [path.join(root,'scripts/select-design-production-route.mjs'),'--task',task], {encoding:'utf8'}));
const dashboard = route('Build an admin dashboard and data grid');
assert.equal(dashboard.director, 'interface-design'); assert.equal(dashboard.tasteSelected, false);
const landing = route('Create an expressive landing page visual redesign');
assert.equal(landing.director, 'frontend-design'); assert.equal(landing.tasteSelected, true);
assert.equal(landing.schemaVersion, 2);
assert(landing.phases.includes('ownership-preflight')); assert(landing.phases.includes('taste-preflight')); assert(landing.phases.includes('frontend-execution-evidence'));
assert.deepEqual(landing.tasteAntiRepetitionChecks, ['duplicate-cta-intent','section-layout-repetition','zigzag-alternation','eyebrow-density']);
assert(!dashboard.phases.includes('taste-preflight')); assert.deepEqual(dashboard.tasteAntiRepetitionChecks, []);
const review = route('Review and score a marketing landing page in Penpot');
assert(review.skills.includes('styleseed-design-review')); assert.equal(review.canvas, 'penpot'); assert.equal(review.livePenpotUseClaimed, false);
assert(review.phases.includes('styleseed-score-revise-render'));
const arabicReadOnly = route('راجع تصميم الواجهة وقيّمه');
assert.equal(arabicReadOnly.mutation, 'ReadOnly'); assert(!arabicReadOnly.phases.includes('build'));
assert(route('صمم صفحة هبوط وراجعها').skills.includes('styleseed-design-review'));
assert.equal(route('Implement supplied Figma file').canvas, 'figma@openai-curated-remote');
const temp = fs.mkdtempSync(path.join(os.tmpdir(),'ueef-design-contract-'));
try {
  const valid = path.join(temp,'DESIGN.md');
  fs.writeFileSync(valid, `---\nname: Test product design\ncolors:\n  primary: '#1457d9'\ntypography:\n  body: 'Inter, sans-serif'\nspacing:\n  unit: '4px'\nrounded:\n  control: '8px'\n---\n\n## Overview\nA durable product interface with restrained visual hierarchy.\n## Color\nSemantic primary, surface, text, border, success, and danger roles.\n## Typography\nA readable body family with a deliberate heading scale and line length.\n## Spacing\nA four-pixel base rhythm with semantic component spacing tokens.\n## Shapes\nControls use consistent radii and borders based on their interaction role.\n## Components\nShared controls own states; feature components compose those public primitives.\n## Do / Don't\nDo reuse semantic tokens and owners. Do not add isolated raw visual values.\n`);
  execFileSync(process.execPath,[path.join(root,'scripts/validate-design-contract.mjs'),'--path',valid]);
  const invalid = path.join(temp,'BAD.md'); fs.writeFileSync(invalid,'# Missing contract');
  assert.throws(()=>execFileSync(process.execPath,[path.join(root,'scripts/validate-design-contract.mjs'),'--path',invalid],{stdio:'pipe'}));
  const weak = path.join(temp,'WEAK.md'); fs.writeFileSync(weak, `---\nname: Test\ncolors: {}\ntypography: {}\nspacing: {}\nrounded: {}\n---\n${['Overview','Color','Typography','Spacing','Shapes','Components',"Do / Don't"].map((h)=>`## ${h}\nX`).join('\n')}`);
  assert.throws(()=>execFileSync(process.execPath,[path.join(root,'scripts/validate-design-contract.mjs'),'--path',weak],{stdio:'pipe'}));
  const task = 'Build an admin dashboard and data grid';
  const dashboardRoute = route(task);
  const evidence = path.join(temp,'frontend-evidence.json');
  fs.writeFileSync(evidence, JSON.stringify({
    schemaVersion:1, task, completedPhases:dashboardRoute.phases,
    ownership:{inspected:true,owner:'src/shared/design-system public component owner',reuseSearch:'Searched shared components, tokens, and public imports',decision:'Extended the existing shared owner without duplication'},
    designContract:{required:true,path:'DESIGN.md',status:'PASS'},
    tokens:{inspected:true,semanticTokensReused:true,rawValuesReviewed:true,themesVerified:['light','dark']},
    states:{verified:['default','hover','focus-visible','active','disabled','loading','empty','error'],notApplicable:{}},
    responsive:{verified:true,evidence:'Verified small phone, tablet, desktop, zoom, and short viewport layouts'},
    accessibility:{verified:true,evidence:'Verified keyboard, focus, names, contrast, and reduced motion behavior'},
    performance:{reviewed:true,measured:false,evidence:'Reviewed rendering boundaries, bundle impact, and layout stability'},
    tests:{status:'PASS',commands:['npm run test:frontend -- dashboard']},
    render:{visualChange:false,status:'NOT_APPLICABLE',evidence:'',rationale:'Fixture validates the evidence contract rather than changing a rendered interface'},
    taste:{preflight:'NOT_APPLICABLE',finalCheck:'NOT_APPLICABLE',checks:[]},styleseed:{score:null,finalRenderVerified:false},penpot:{liveUseClaimed:false},status:'PASS'
  }, null, 2));
  fs.copyFileSync(valid, path.join(temp,'DESIGN.md'));
  execFileSync(process.execPath,[path.join(root,'scripts/validate-frontend-execution-evidence.mjs'),'--path',evidence]);
  const brokenEvidence = JSON.parse(fs.readFileSync(evidence,'utf8')); brokenEvidence.states.verified = brokenEvidence.states.verified.filter((x)=>x!=='focus-visible');
  fs.writeFileSync(evidence,JSON.stringify(brokenEvidence));
  assert.throws(()=>execFileSync(process.execPath,[path.join(root,'scripts/validate-frontend-execution-evidence.mjs'),'--path',evidence],{stdio:'pipe'}));
} finally { fs.rmSync(temp,{recursive:true,force:true}); }
console.log('Design production workflow tests: PASS');
