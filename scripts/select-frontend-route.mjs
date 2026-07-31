#!/usr/bin/env node

const args = process.argv.slice(2);
const value = (name, fallback = '') => {
  const index = args.indexOf(name);
  return index >= 0 ? (args[index + 1] ?? fallback) : fallback;
};
const task = value('--task', args.find((arg) => !arg.startsWith('--')) ?? '');
const override = value('--mode', 'Auto');
if (!task) {
  console.error('usage: select-frontend-route.mjs --task "task summary" [--mode Auto|Quick|Build|Audit]');
  process.exit(2);
}

const text = task.toLowerCase();
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
};

const domains = Object.entries(signals)
  .filter(([key, matched]) => matched && !key.startsWith('action') && !['broad', 'frontend', 'react', 'angular'].includes(key))
  .map(([key]) => key.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`));
const frontendNativeDomain = signals.overlay || signals.theme || signals.responsive || signals.dataGrid || signals.appShell || signals.accessibility || signals.loading || signals.motion || signals.design || signals.visualQa;
const frontendPerformanceNative = has(/\b(lcp|inp|cls|bundle size|re-render|frame rate)\b/);
const applies = override !== 'Auto' || signals.frontend || frontendNativeDomain || frontendPerformanceNative || signals.react || signals.angular;
const auditReviewPhrase = has(/\b(audit|review|critique|assess|evaluate|inspect)\b.*\b(polish|visual design|design system)\b/);
let intent = signals.actionRecommend && !signals.actionChange ? 'Recommend' : ((signals.actionAudit || signals.visualQa) && !signals.actionChange) || auditReviewPhrase ? 'Audit' : 'Change';
let mutation = intent === 'Change' ? 'Implement' : 'ReadOnly';
let scope = signals.broad ? 'Broad' : has(/\b(build|create|add|implement|redesign|develop|scaffold|new)\b/) || signals.performance ? 'Build' : 'Quick';
let frontendMode = mutation === 'ReadOnly' ? 'Audit' : scope === 'Quick' ? 'Quick' : 'Build';
if (override !== 'Auto') {
  frontendMode = override;
  if (override === 'Audit') { intent = 'Audit'; mutation = 'ReadOnly'; }
  scope = override === 'Quick' ? 'Quick' : override === 'Build' ? 'Build' : scope;
}

const modules = [];
const gates = [];
const skills = [];
const reasons = [];
const add = (target, ...items) => target.push(...items);
if (applies) {
  add(modules, 'framework/10-frontend/00-frontend-engineering.md', 'framework/10-frontend/01-frontend-task-modes.md');
  add(gates, 'framework/27-quality-gates/ui-gate.md');
  add(skills, 'typeui-fundamentals');
  reasons.push(`frontend ${intent.toLowerCase()} with ${scope.toLowerCase()} scope`);
}
if (applies && signals.accessibility) {
  add(modules, 'framework/16-accessibility/00-accessibility-system.md');
  add(gates, 'framework/27-quality-gates/accessibility-gate.md');
  reasons.push('accessibility contract detected');
}
if (applies && signals.overlay) {
  add(modules, 'framework/46-design-system-consistency-reuse/04-form-table-modal-notification-systems.md', 'framework/47-theme-responsive-interaction-security-performance/21-overlay-interaction-contract.md');
  if (has(/modal|dialog/)) add(modules, 'framework/47-theme-responsive-interaction-security-performance/24-modal-dialog-contract.md');
  if (has(/dropdown|menu|popover/)) add(modules, 'framework/47-theme-responsive-interaction-security-performance/22-dropdown-menu-popover-contract.md');
  if (has(/focus|keyboard|escape/)) add(modules, 'framework/47-theme-responsive-interaction-security-performance/29-escape-focus-and-keyboard-behavior.md', 'framework/47-theme-responsive-interaction-security-performance/30-scroll-lock-and-focus-restoration.md');
  reasons.push('overlay interaction detected');
}
if (applies && signals.theme) {
  add(modules, 'framework/47-theme-responsive-interaction-security-performance/01-theme-architecture.md', 'framework/47-theme-responsive-interaction-security-performance/04-design-token-enforcement.md', 'framework/47-theme-responsive-interaction-security-performance/05-semantic-color-system.md');
  reasons.push('theme and color system detected');
}
if (applies && signals.responsive) {
  add(modules, 'framework/47-theme-responsive-interaction-security-performance/10-responsive-first-architecture.md', 'framework/47-theme-responsive-interaction-security-performance/11-breakpoint-and-container-system.md', 'framework/47-theme-responsive-interaction-security-performance/14-responsive-components.md');
  reasons.push('responsive behavior detected');
  add(skills, 'responsive-craft');
}
if (applies && signals.dataGrid) {
  add(modules, 'framework/56-data-grid-platform/00-data-grid-platform-system.md', 'framework/56-data-grid-platform/02-frontend-query-and-state-contract.md', 'framework/56-data-grid-platform/03-pagination-filter-sort-and-aggregation.md');
  reasons.push('data-grid contract detected');
  add(skills, 'company-data-table');
}
if (applies && signals.appShell) {
  add(modules, 'framework/57-application-shell-design/00-application-shell-system.md', 'framework/57-application-shell-design/02-sidebar-navigation-contract.md', 'framework/57-application-shell-design/03-header-and-page-chrome-contract.md');
  reasons.push('application-shell surface detected');
}
if (applies && signals.loading) {
  add(modules, 'framework/53-skeleton-loading/00-skeleton-loading-system.md', 'framework/53-skeleton-loading/02-state-contract.md', 'framework/53-skeleton-loading/04-performance-and-layout-stability.md');
  add(gates, 'framework/27-quality-gates/25-skeleton-loading-gate.md');
  reasons.push('loading-state contract detected');
}
if (applies && signals.identity) {
  add(modules, 'framework/45-identity-access-application-models/02-authorization-entitlement-contract.md', 'framework/45-identity-access-application-models/08-access-aware-ui-and-audit.md');
  add(gates, 'framework/27-quality-gates/security-gate.md');
  reasons.push('access-aware UI detected');
}
if (applies && signals.performance) {
  add(modules, 'framework/47-theme-responsive-interaction-security-performance/42-frontend-rendering-performance.md', 'framework/47-theme-responsive-interaction-security-performance/46-performance-budgets-and-measurement.md', 'framework/62-performance-forensics/00-performance-forensics-system.md');
  add(gates, 'framework/27-quality-gates/performance-gate.md');
  reasons.push('frontend performance evidence required');
  add(skills, 'performance-optimization');
}
if (applies && signals.design) {
  add(modules, 'framework/46-design-system-consistency-reuse/00-unified-design-system-architecture.md', 'framework/46-design-system-consistency-reuse/09-reuse-decision-engine.md', 'framework/48-design-governance/00-design-governance.md', 'framework/48-design-governance/02-design-token-system.md');
  if (intent === 'Recommend') add(skills, 'ui-ux-pro-max');
  if (intent === 'Audit') add(skills, 'impeccable');
  reasons.push('design-system decision detected');
  add(skills, 'design-system-guardian');
}
if (applies && signals.motion) { add(skills, 'emil-design-eng'); reasons.push('motion craft detected'); }
// Angular has its own implementation authority. The general UI engineering
// skill contains framework-specific examples that must not override it.
if (applies && mutation === 'Implement' && !signals.angular) add(skills, 'frontend-ui-engineering');
if (applies && mutation === 'Implement' && scope !== 'Quick') {
  if (signals.dataGrid || signals.appShell || has(/\b(dashboard|admin|saas|settings|product ui)\b/)) add(skills, 'interface-design');
  else add(skills, 'frontend-design');
}
if (applies && signals.react) { add(modules, 'framework/31-react/00-react-pack.md'); reasons.push('React stack detected'); }
if (applies && signals.angular) { add(modules, 'framework/36-angular/00-angular-pack.md'); add(skills, 'angular-developer'); reasons.push('Angular stack detected'); }
if (applies && signals.harness) { add(skills, 'angular-table-harness'); reasons.push('stable Angular harness API requested'); }
if (applies && signals.prototype) { add(skills, 'prototype'); if (has(/\b(dashboard|admin|saas|settings|product ui)\b/)) add(skills, 'interface-design'); reasons.push('explicit divergent prototype requested'); }
if (applies && signals.extractDesign) { add(skills, 'extract-design-system'); reasons.push('public design-system extraction requested'); }
if (applies && signals.sourceDriven) { add(skills, 'source-driven-development'); reasons.push('official source grounding requested'); }
if (applies && signals.codeReview) { add(skills, 'code-review-and-quality'); reasons.push('multi-axis code review requested'); }
if (applies && signals.visualQa) { add(skills, 'frontend-visual-qa'); reasons.push('deterministic visual verification requested'); }
if (applies && intent === 'Audit' && has(/\b(frontend design review|design review|ui code review)\b/)) add(skills, 'frontend-design-review');
if (applies && intent === 'Audit' && has(/\b(web guidelines|interface guidelines|best practices)\b/)) add(skills, 'web-design-guidelines');
if (applies && intent === 'Audit' && signals.design) add(gates, 'framework/27-quality-gates/30-visual-composition-gate.md');

const matchedSignals = Object.entries(signals).filter(([, matched]) => matched).map(([name]) => name);
const confidence = !applies ? 0 : Math.min(0.99, Number((0.62 + Math.min(0.32, matchedSignals.length * 0.04)).toFixed(2)));
console.log(JSON.stringify({
  schemaVersion: 1, task, applies, frontendMode: applies ? frontendMode : 'NA', intent: applies ? intent : 'NA',
  scope: applies ? scope : 'NA', mutation: applies ? mutation : 'NA', domains, stack: [signals.react ? 'React' : null, signals.angular ? 'Angular' : null].filter(Boolean),
  skills: unique(skills), modules: unique(modules), gates: unique(gates), reasons, confidence, matchedSignals,
}, null, 2));
