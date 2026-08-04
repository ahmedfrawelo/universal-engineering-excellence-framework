export function selectDesignProductionRoute(task, policy, context = {}) {
  const text = String(task || '').toLowerCase();
  const has = (pattern) => pattern.test(text);
  const readOnly = context.mutation === 'ReadOnly' || (has(/review|audit|critique|assess|inspect|verify|راجع|مراجعة|قيّم|تقييم|دقق|تدقيق|تحقق/iu) && !has(/build|create|implement|redesign|ابن|أبن|أنش|انش|نفذ|طبق|صمم/iu));
  const productUi = has(/dashboard|admin|data[ -]?grid|data table|saas|settings|dense product|product ui|لوحة|جدول|إدارة|اعدادات|إعدادات/iu);
  const expressive = has(/landing|portfolio|marketing|expressive|visual redesign|صفحة هبوط|بورتفوليو|تسويق|إعادة تصميم|اعادة تصميم/iu);
  const review = has(/review|audit|score|polish|verify|راجع|مراجعة|تقييم|دقق|تدقيق|تحقق/iu);
  const penpot = has(/penpot|design canvas|code[ .-]?to[ .-]?design|design[ .-]?to[ .-]?code|بن(?:بوت|بُوت)|لوحة تصميم/iu);
  const figma = has(/figma|فيجما/iu);
  const skills = [readOnly ? policy.routing.reviewGate : productUi ? policy.routing.productUiDirector : policy.routing.expressiveDirector];
  if (expressive && !productUi) skills.push(policy.routing.tasteSupplement);
  if (review && !readOnly) skills.push(policy.routing.reviewGate);
  const tasteSelected = skills.includes(policy.routing.tasteSupplement);
  const phases = ['ownership-preflight', 'design-contract'];
  if (tasteSelected) phases.push('taste-preflight');
  if (!readOnly) phases.push('build');
  phases.push('state-accessibility-responsive-check', 'performance-check', 'test');
  if (tasteSelected) phases.push('taste-final-check');
  if (review) phases.push('styleseed-score-revise-render');
  phases.push('render-verify', 'frontend-execution-evidence');
  return {
    schemaVersion: 2,
    task,
    mutation: readOnly ? 'ReadOnly' : 'Implement',
    director: skills[0],
    skills: [...new Set(skills)],
    tasteSelected,
    phases,
    tasteAntiRepetitionChecks: tasteSelected ? policy.taste.antiRepetitionChecks : [],
    designContract: 'DESIGN.md',
    styleseedMinimumScore: policy.styleseed.minimumScore,
    canvas: figma ? policy.routing.explicitFigmaArtifact : penpot ? policy.routing.preferredCanvas : 'none',
    livePenpotUseClaimed: false,
    mandatoryExecution: policy.mandatoryExecution,
    qualityContract: policy.qualityContract,
    reasons: [
      productUi ? 'dense product UI keeps interface-design authority' : 'expressive or general frontend route',
      expressive && !productUi ? 'Taste scope matched with mandatory preflight and final check' : 'Taste not selected',
      review ? 'Styleseed review gate selected' : 'review gate not requested',
      figma ? 'explicit Figma artifact wins' : penpot ? 'Penpot requested; live health still required' : 'no canvas requested'
    ]
  };
}
