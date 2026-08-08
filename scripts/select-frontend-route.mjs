#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {selectDesignProductionRoute} from './frontend-design-production-route-lib.mjs';

const args = process.argv.slice(2);
const value = (name, fallback = '') => {
  const index = args.indexOf(name);
  return index >= 0 ? (args[index + 1] ?? fallback) : fallback;
};
const task = value('--task', args.find((arg) => !arg.startsWith('--')) ?? '');
const override = value('--mode', 'Auto');
const mutationOverride = value('--mutation', 'Auto');
const forceFrontend = args.includes('--force-frontend');
if (!task) {
  console.error('usage: select-frontend-route.mjs --task "task summary" [--mode Auto|Quick|Build|Audit]');
  process.exit(2);
}
if (!['Auto', 'Quick', 'Build', 'Audit'].includes(override) || !['Auto', 'Implement', 'ReadOnly'].includes(mutationOverride)) {
  console.error('invalid frontend mode or mutation override');
  process.exit(2);
}

const augmentArabicSignals = (input) => {
  const signals = [];
  const add = (pattern, value) => { if (pattern.test(input)) signals.push(value); };
  add(/[اأ]صلح|عدل|غير|حدث|حسن|طور/, 'fix update change improve');
  add(/نفذ|طبق/, 'implement');
  add(/[اأ]ضف|ضيف/, 'add');
  add(/[اأ]حذف|[اأ]مسح/, 'remove delete');
  add(/ثبت/, 'install');
  add(/[اأ]عمل|[اأ]بني|[اأ]نشئ|صمم/, 'build create new');
  add(/[اأ]فحص|راجع|دقق|حلل|[اأ]ختبر|ت[اأ]كد|ات[اأ]كد|شوف|شخص/, 'audit review inspect verify diagnose test');
  add(/كل حاج[ةه]|كل شي[ءئ]|بالكامل|شامل|حرفي[اً]|من ال[اأ]ول لل[اآ]خر/, 'system-wide entire project all issues');
  add(/واجهة المستخدم|الواجه[ةه]|فرونت|فورنت|صفح[ةه]|شاش[ةه]|مكون/, 'ui frontend page screen component');
  add(/(?:ال)?قائم[ةه] (?:ال)?منسدل[ةه]/, 'dropdown');
  add(/جدول/, 'table');
  add(/تصميم/, 'design');
  add(/[اأ]لوان/, 'palette');
  add(/متصفح|كروم|تبويب|موقع|لقط[ةه] شاش[ةه]/, 'browser chrome tab website screenshot');
  add(/مشكل[ةه]|خط[أا]|عطل|مكسور|مختل|بط[ءي]|كفا[ءئ][ةه]|فشل|بيكرر/, 'bug broken error slow performance failure debugging');
  add(/سريع|[اأ]داء|تحسين/, 'performance optimize');
  return signals.length ? `${input} ${signals.join(' ')}` : input;
};const text = augmentArabicSignals(task.toLowerCase());
const has = (pattern) => pattern.test(text);
const unique = (items) => [...new Set(items)];
const signals = {
  actionChange: has(/\b(build|create|add|implement|fix|repair|update|change|refactor|redesign|polish|optimi[sz]e|improve|develop|scaffold|style|tune)\b/),
  actionAudit: has(/\b(audit|review|critique|assess|evaluate|inspect|verify|validate|analy[sz]e|diagnos\w*|test)\b/),
  actionRecommend: has(/\b(recommend|choose|suggest|compare|select)\b/),
  broad: has(/\b(project|repository|system|application|app)[- ]wide\b|\b(entire|whole|all)\b|design system|component library/),
  frontend: has(/\b(ui|ux|frontend|front-end|web app|react|angular|vue|svelte|css|scss|tailwind|page|screen|component|card|button|form|dashboard|landing page|modal|dialog|dropdown|popover|drawer|tooltip|sidebar|navbar|navigation|header|theme|responsive|breakpoint|typography|palette|font|skeleton|shimmer|data grid|table|layout)\b/),
  overlay: has(/\b(modal|dialog|dropdown|menu|popover|drawer|panel|tooltip|overlay)\b|outside click|escape key|focus restoration/),
  theme: has(/\b(theme|dark mode|light mode|color token|semantic color|palette)\b/),
  responsive: has(/\b(responsive|mobile|breakpoint|container quer\w*|orientation|zoom|small height)\b/),
  dataGrid: has(/\b(data grid|datatable|data table|table|grid|pagination|aggregation|bulk action|row selection)\b|filter(?:ing)? and sort(?:ing)?/),
  appShell: has(/\b(sidebar|navbar|navigation|header|app shell|application shell|page chrome|route transition)\b/),
  accessibility: has(/\b(accessibility|a11y|aria|screen reader|keyboard navigation|contrast|focus trap|focus management)\b/),
  performance: has(/\b(performance|slow|rendering|bundle size|lcp|inp|cls|virtuali[sz]ation|re-render|latency|frame rate)\b|optimi[sz]e/),
  loading: has(/\b(loading state|loading placeholder|content loading|skeleton|shimmer|placeholder|hydration|async state|reveal timing)\b/),
  identity: has(/\b(role|permission|entitlement|tenant|authorization|access-aware|access visibility)\b/),
  motion: has(/\b(motion|animation|animate|transition|easing|micro-interaction)\b/),
  design: has(/design system|design token|\b(token|palette|typography|font pairing|iconography|spacing|radius|shadow|visual design)\b/),
  react: has(/\breact(?:js)?\b/),
  angular: has(/\bangular\b/),
  harness: has(/\b(component harness|table harness|angular harness|componentharness)\b/),
  prototype: has(/\b(prototype|design alternatives|visual alternatives|multiple variants)\b/),
  extractDesign: has(/\b(extract|reverse.engineer)\b.*\b(design system|design tokens|visual style)\b/),
  sourceDriven: has(/\b(official docs|official documentation|current angular|latest angular|source.cited)\b/),
  codeReview: has(/\b(code review|review (?:the )?(?:pr|diff)|pull request review)\b/),
  visualQa: has(/\b(visual qa|visual regression|screenshot diff|browser verification|responsive verification)\b/),
  expressive: has(/\b(landing page|portfolio|marketing site|expressive|visual redesign)\b|صفحة هبوط|بورتفوليو|تسويق|إعادة تصميم/),
  designReview: has(/\b(design score|styleseed|post-build design review|visual quality floor)\b|تقييم التصميم|مراجعة بصرية|راجع التصميم بصري/),
  penpot: has(/\b(penpot|design canvas|code-to-design|design-to-code)\b|بنبوت|بينبوت|لوحة تصميم/),
};

const domains = Object.entries(signals)
  .filter(([key, matched]) => matched && !key.startsWith('action') && !['broad', 'frontend', 'react', 'angular'].includes(key))
  .map(([key]) => key.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`));
const frontendNativeDomain = signals.overlay || signals.theme || signals.responsive || signals.dataGrid || signals.appShell || signals.accessibility || signals.loading || signals.motion || signals.design || signals.visualQa || signals.expressive || signals.designReview || signals.penpot;
const frontendPerformanceNative = has(/\b(lcp|inp|cls|bundle size|re-render|frame rate)\b/);
const applies = forceFrontend || override !== 'Auto' || signals.frontend || frontendNativeDomain || frontendPerformanceNative || signals.react || signals.angular;
const auditReviewPhrase = has(/\b(audit|review|critique|assess|evaluate|inspect)\b.*\b(polish|visual design|design system)\b/);
let intent = signals.actionRecommend && !signals.actionChange ? 'Recommend' : ((signals.actionAudit || signals.visualQa) && !signals.actionChange) || auditReviewPhrase ? 'Audit' : signals.actionChange ? 'Change' : 'Audit';
let mutation = intent === 'Change' ? 'Implement' : 'ReadOnly';
let scope = signals.broad ? 'Broad' : has(/\b(build|create|add|implement|redesign|develop|scaffold|new)\b/) || signals.performance ? 'Build' : 'Quick';
let frontendMode = mutation === 'ReadOnly' ? 'Audit' : scope === 'Quick' ? 'Quick' : 'Build';
if (override !== 'Auto') {
  frontendMode = override;
  if (override === 'Audit') { intent = 'Audit'; mutation = 'ReadOnly'; }
  scope = override === 'Quick' ? 'Quick' : override === 'Build' ? 'Build' : scope;
}
if (mutationOverride === 'Implement') { intent = 'Change'; mutation = 'Implement'; }
if (mutationOverride === 'ReadOnly') { if (intent === 'Change') intent = 'Audit'; mutation = 'ReadOnly'; }
if (override === 'Auto') frontendMode = mutation === 'ReadOnly' ? 'Audit' : scope === 'Quick' ? 'Quick' : 'Build';

const modules = [];
const gates = [];
const skills = [];
const reasons = [];
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const designProductionPolicy = JSON.parse(fs.readFileSync(path.join(root, 'config/frontend-design-production-policy.json'), 'utf8'));
const add = (target, ...items) => target.push(...items);
if (applies) {
  add(modules, 'framework/10-frontend/01-engineering/00-frontend-engineering.md', 'framework/10-frontend/01-engineering/01-frontend-task-modes.md');
  add(gates, 'framework/12-delivery-quality/04-quality-gates/ui-gate.md');
  add(skills, 'typeui-fundamentals');
  reasons.push(`frontend ${intent.toLowerCase()} with ${scope.toLowerCase()} scope`);
  if (forceFrontend) reasons.push('explicit frontend tag');
}
if (applies && signals.accessibility) {
  add(modules, 'framework/12-delivery-quality/07-accessibility/00-accessibility-system.md');
  add(gates, 'framework/12-delivery-quality/04-quality-gates/accessibility-gate.md');
  reasons.push('accessibility contract detected');
}
if (applies && signals.overlay) {
  add(modules, 'framework/16-design-system/01-consistency-reuse/04-form-table-modal-notification-systems.md', 'framework/16-design-system/02-theme-responsive-interaction-security-performance/21-overlay-interaction-contract.md');
  if (has(/modal|dialog/)) add(modules, 'framework/16-design-system/02-theme-responsive-interaction-security-performance/24-modal-dialog-contract.md');
  if (has(/dropdown|menu|popover/)) add(modules, 'framework/16-design-system/02-theme-responsive-interaction-security-performance/22-dropdown-menu-popover-contract.md');
  if (has(/focus|keyboard|escape/)) add(modules, 'framework/16-design-system/02-theme-responsive-interaction-security-performance/29-escape-focus-and-keyboard-behavior.md', 'framework/16-design-system/02-theme-responsive-interaction-security-performance/30-scroll-lock-and-focus-restoration.md');
  reasons.push('overlay interaction detected');
}
if (applies && signals.theme) {
  add(modules, 'framework/16-design-system/02-theme-responsive-interaction-security-performance/01-theme-architecture.md', 'framework/16-design-system/02-theme-responsive-interaction-security-performance/04-design-token-enforcement.md', 'framework/16-design-system/02-theme-responsive-interaction-security-performance/05-semantic-color-system.md');
  reasons.push('theme and color system detected');
}
if (applies && signals.responsive) {
  add(modules, 'framework/16-design-system/02-theme-responsive-interaction-security-performance/10-responsive-first-architecture.md', 'framework/16-design-system/02-theme-responsive-interaction-security-performance/11-breakpoint-and-container-system.md', 'framework/16-design-system/02-theme-responsive-interaction-security-performance/14-responsive-components.md');
  reasons.push('responsive behavior detected');
  add(skills, 'responsive-craft');
}
if (applies && signals.dataGrid) {
  add(modules, 'framework/17-product-platform/03-data-grid-platform/00-data-grid-platform-system.md', 'framework/17-product-platform/03-data-grid-platform/02-frontend-query-and-state-contract.md', 'framework/17-product-platform/03-data-grid-platform/03-pagination-filter-sort-and-aggregation.md');
  reasons.push('data-grid contract detected');
  add(skills, 'company-data-table');
}
if (applies && signals.appShell) {
  add(modules, 'framework/17-product-platform/04-application-shell-design/00-application-shell-system.md', 'framework/17-product-platform/04-application-shell-design/02-sidebar-navigation-contract.md', 'framework/17-product-platform/04-application-shell-design/03-header-and-page-chrome-contract.md');
  reasons.push('application-shell surface detected');
}
if (applies && signals.loading) {
  add(modules, 'framework/17-product-platform/02-skeleton-loading/00-skeleton-loading-system.md', 'framework/17-product-platform/02-skeleton-loading/02-state-contract.md', 'framework/17-product-platform/02-skeleton-loading/04-performance-and-layout-stability.md');
  add(gates, 'framework/12-delivery-quality/04-quality-gates/25-skeleton-loading-gate.md');
  reasons.push('loading-state contract detected');
}
if (applies && signals.identity) {
  add(modules, 'framework/17-product-platform/01-identity-access-application-models/02-authorization-entitlement-contract.md', 'framework/17-product-platform/01-identity-access-application-models/08-access-aware-ui-and-audit.md');
  add(gates, 'framework/12-delivery-quality/04-quality-gates/security-gate.md');
  reasons.push('access-aware UI detected');
}
if (applies && signals.performance) {
  add(modules, 'framework/16-design-system/02-theme-responsive-interaction-security-performance/42-frontend-rendering-performance.md', 'framework/16-design-system/02-theme-responsive-interaction-security-performance/46-performance-budgets-and-measurement.md', 'framework/20-repository-evolution/02-performance-forensics/00-performance-forensics-system.md');
  add(gates, 'framework/12-delivery-quality/04-quality-gates/performance-gate.md');
  reasons.push('frontend performance evidence required');
  add(skills, 'performance-optimization');
}
if (applies && signals.design) {
  add(modules, 'framework/16-design-system/01-consistency-reuse/00-unified-design-system-architecture.md', 'framework/16-design-system/01-consistency-reuse/09-reuse-decision-engine.md', 'framework/16-design-system/03-governance/00-design-governance.md', 'framework/16-design-system/03-governance/02-design-token-system.md');
  if (intent === 'Recommend') add(skills, 'ui-ux-pro-max');
  if (intent === 'Audit') add(skills, 'impeccable');
  reasons.push('design-system decision detected');
  add(skills, 'design-system-guardian');
}
const designProductionApplies = applies && (signals.expressive || signals.designReview || signals.penpot || signals.design || (mutation === 'Implement' && scope !== 'Quick'));
const designProduction = designProductionApplies ? selectDesignProductionRoute(task, designProductionPolicy, {mutation, frontendMode}) : null;
if (designProductionApplies) {
  add(modules, 'framework/10-frontend/02-production-design/00-frontend-design-production-system.md');
  add(gates, 'framework/12-delivery-quality/04-quality-gates/35-frontend-design-production-gate.md');
  add(skills, ...designProduction.skills);
  reasons.push('mandatory frontend design-production execution contract selected');
}
if (applies && signals.expressive && !signals.dataGrid && !signals.appShell && !has(/\b(dashboard|admin|saas|settings|dense product ui)\b/)) {
  add(skills, 'design-taste-frontend');
  reasons.push('expressive surface matched Taste scope');
}
if (applies && signals.designReview) {
  add(skills, 'styleseed-design-review');
  reasons.push('measured Styleseed review requested');
}
if (applies && signals.penpot) reasons.push('Penpot preferred; live MCP health evidence remains required');
if (applies && signals.motion) { add(skills, 'emil-design-eng'); reasons.push('motion craft detected'); }
// Angular has its own implementation authority. The general UI engineering
// skill contains framework-specific examples that must not override it.
if (applies && mutation === 'Implement' && !signals.angular) add(skills, 'frontend-ui-engineering');
if (applies && mutation === 'Implement' && scope !== 'Quick') {
  if (signals.dataGrid || signals.appShell || has(/\b(dashboard|admin|saas|settings|product ui)\b/)) add(skills, 'interface-design');
  else add(skills, 'frontend-design');
}
if (applies && signals.react) { add(modules, 'framework/15-tech-stacks/02-react/00-react-pack.md'); reasons.push('React stack detected'); }
if (applies && signals.angular) { add(modules, 'framework/15-tech-stacks/07-angular/00-angular-pack.md'); add(skills, 'angular-developer'); reasons.push('Angular stack detected'); }
if (applies && signals.harness) { add(skills, 'angular-table-harness'); reasons.push('stable Angular harness API requested'); }
if (applies && signals.prototype) { add(skills, 'prototype'); if (has(/\b(dashboard|admin|saas|settings|product ui)\b/)) add(skills, 'interface-design'); reasons.push('explicit divergent prototype requested'); }
if (applies && signals.extractDesign) { add(skills, 'extract-design-system'); reasons.push('public design-system extraction requested'); }
if (applies && signals.sourceDriven) { add(skills, 'source-driven-development'); reasons.push('official source grounding requested'); }
if (applies && signals.codeReview) { add(skills, 'code-review-and-quality'); reasons.push('multi-axis code review requested'); }
if (applies && signals.visualQa) { add(skills, 'frontend-visual-qa'); reasons.push('deterministic visual verification requested'); }
if (applies && intent === 'Audit' && has(/\b(frontend design review|design review|ui code review)\b/)) add(skills, 'frontend-design-review');
if (applies && intent === 'Audit' && has(/\b(web guidelines|interface guidelines|best practices)\b/)) add(skills, 'web-design-guidelines');
if (applies && intent === 'Audit' && signals.design) add(gates, 'framework/12-delivery-quality/04-quality-gates/30-visual-composition-gate.md');

const matchedSignals = Object.entries(signals).filter(([, matched]) => matched).map(([name]) => name);
const confidence = !applies ? 0 : Math.min(0.99, Number((0.62 + Math.min(0.32, matchedSignals.length * 0.04)).toFixed(2)));
console.log(JSON.stringify({
  schemaVersion: 1, task, applies, forcedFrontend: forceFrontend, frontendMode: applies ? frontendMode : 'NA', intent: applies ? intent : 'NA',
  scope: applies ? scope : 'NA', mutation: applies ? mutation : 'NA', domains, stack: [signals.react ? 'React' : null, signals.angular ? 'Angular' : null].filter(Boolean),
  skills: unique(skills), modules: unique(modules), gates: unique(gates), reasons, confidence, matchedSignals,
  designProductionApplies, designProduction,
}, null, 2));
