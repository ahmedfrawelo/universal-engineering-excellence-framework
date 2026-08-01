#!/usr/bin/env node
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const route = (task) => JSON.parse(execFileSync(process.execPath, [path.join(root, 'scripts/select-frontend-route.mjs'), '--task', task], { encoding: 'utf8' }));
const cases = [
  ['Create a modal with focus restoration', 'Build', 'overlay', '/47-theme-responsive-interaction-security-performance/24-'],
  ['Fix dropdown focus', 'Quick', 'overlay', '/47-theme-responsive-interaction-security-performance/22-'],
  ['Add dark theme', 'Build', 'theme', '/47-theme-responsive-interaction-security-performance/01-'],
  ['Build responsive layout', 'Build', 'responsive', '/47-theme-responsive-interaction-security-performance/10-'],
  ['Implement loading state', 'Build', 'loading', '/53-skeleton-loading/00-'],
  ['Recommend a color palette and font pairing', 'Audit', 'design', '/48-design-governance/00-'],
  ['Redesign dashboard', 'Build', null, '/10-frontend/00-'],
  ['Optimize frontend rendering', 'Build', 'performance', '/62-performance-forensics/00-'],
  ['Build a data grid', 'Build', 'data-grid', '/56-data-grid-platform/00-'],
  ['Fix sidebar navigation', 'Quick', 'app-shell', '/57-application-shell-design/00-'],
  ['Implement role-based navigation', 'Build', 'identity', '/45-identity-access-application-models/08-'],
  ['Refactor React component internals', 'Quick', null, '/31-react/00-'],
  ['Audit accessibility of a React form', 'Audit', 'accessibility', '/16-accessibility/00-'],
  ['Audit CSS bundle size', 'Audit', 'performance', '/62-performance-forensics/00-'],
  ['Audit design system', 'Audit', 'design', '/46-design-system-consistency-reuse/00-'],
  ['Create Angular sidebar', 'Build', 'app-shell', '/36-angular/00-'],
  ['Fix tooltip escape key', 'Quick', 'overlay', '/47-theme-responsive-interaction-security-performance/29-'],
  ['Add skeleton shimmer', 'Build', 'loading', '/53-skeleton-loading/00-'],
  ['Audit LCP and CLS', 'Audit', 'performance', '/62-performance-forensics/00-'],
  ['Implement permission-aware button', 'Build', 'identity', '/45-identity-access-application-models/08-'],
  ['Recommend typography', 'Audit', 'design', '/48-design-governance/00-'],
  ['Build mobile dashboard', 'Build', 'responsive', '/47-theme-responsive-interaction-security-performance/10-'],
  ['Fix navbar', 'Quick', 'app-shell', '/57-application-shell-design/00-'],
  ['Audit aria focus management', 'Audit', 'accessibility', '/16-accessibility/00-'],
  ['راجع واجهة المستخدم وأصلح القائمة المنسدلة', 'Quick', 'overlay', '/47-theme-responsive-interaction-security-performance/22-'],
];
for (const [task, mode, domain, modulePart] of cases) {
  const result = route(task);
  if (!result.applies || result.frontendMode !== mode) throw new Error(`${task}: expected ${mode}, received ${result.frontendMode}`);
  if (domain && !result.domains.includes(domain)) throw new Error(`${task}: missing domain ${domain}`);
  if (!result.modules.some((item) => item.includes(modulePart))) throw new Error(`${task}: missing module ${modulePart}`);
  if (!result.reasons.length || result.confidence < 0.6) throw new Error(`${task}: missing explainability`);
}
const nonUi = route('Explain dependency injection');
if (nonUi.applies || nonUi.frontendMode !== 'NA' || nonUi.skills.length || nonUi.modules.length || nonUi.gates.length || nonUi.reasons.length) throw new Error('Non-frontend task was falsely routed.');
for (const task of ['Harden authorization security', 'Audit backend performance']) {
  const result = route(task);
  if (result.applies || result.skills.length || result.modules.length || result.gates.length || result.reasons.length) throw new Error(`${task}: non-frontend route leaked selections.`);
}
const accessibility = route('Audit accessibility of a React form');
if (accessibility.gates.some((item) => item.includes('performance')) || accessibility.skills.includes('impeccable')) throw new Error('Accessibility audit over-selected unrelated routes.');
const refactor = route('Refactor React component internals');
if (refactor.modules.some((item) => item.includes('/61-project-modernization/'))) throw new Error('Focused refactor selected modernization.');
const skillCases = [
  ['Build an Angular data grid dashboard', ['angular-developer', 'company-data-table', 'interface-design']],
  ['Build a responsive landing page', ['responsive-craft', 'frontend-design', 'frontend-ui-engineering']],
  ['Create an Angular component harness for the table', ['angular-table-harness', 'angular-developer']],
  ['Prototype multiple visual alternatives for a dashboard', ['prototype', 'interface-design']],
  ['Extract design tokens from a public website', ['extract-design-system', 'design-system-guardian']],
  ['Audit frontend performance and LCP', ['performance-optimization']],
  ['Run visual QA and screenshot diff on the responsive page', ['frontend-visual-qa']],
  ['Review the PR frontend code', ['code-review-and-quality']],
  ['Review UI against web interface guidelines', ['web-design-guidelines']],
  ['Perform a frontend design review', ['frontend-design-review']],
  ['Implement current Angular patterns from official documentation', ['source-driven-development', 'angular-developer']],
];
for (const [task, expectedSkills] of skillCases) {
  const result = route(task);
  for (const skill of expectedSkills) if (!result.skills.includes(skill)) throw new Error(`${task}: missing skill route ${skill}`);
}
const browserPolicy = route('Test the UI with Chrome DevTools MCP');
if (browserPolicy.skills.includes('browser-testing-with-devtools')) throw new Error('Forbidden alternate browser skill must remain installed but unrouted.');
const visualQa = route('Run visual QA and screenshot diff on the responsive page');
if (visualQa.intent !== 'Audit' || visualQa.mutation !== 'ReadOnly' || visualQa.skills.includes('frontend-ui-engineering')) throw new Error('Visual QA must remain a read-only audit route.');
const terseVisualQa = route('Run visual QA');
if (!terseVisualQa.applies || terseVisualQa.intent !== 'Audit' || !terseVisualQa.skills.includes('frontend-visual-qa')) throw new Error('A terse visual-QA request must still route as a frontend audit.');
const forced = JSON.parse(execFileSync(process.execPath, [path.join(root, 'scripts/select-frontend-route.mjs'), '--task', 'Contradictory prose: do not design', '--force-frontend'], { encoding: 'utf8' }));
if (!forced.applies || !forced.forcedFrontend || !forced.skills.includes('typeui-fundamentals')) throw new Error('An explicit frontend tag must force a valid canonical frontend route.');
const explanatory = route('Explain this UI component');
if (explanatory.mutation !== 'ReadOnly' || explanatory.skills.includes('frontend-ui-engineering')) throw new Error('A frontend explanation must not invent implementation work.');
console.log(`Frontend routing tests passed (${cases.length + skillCases.length + 10} assertion groups)`);
