# Theme Responsive Interaction Security and Performance Scorecard

Version: 1.1.0

Score each item from 0 to 4: 0 missing, 1 unsafe or broken, 2 partial, 3 complete with evidence, 4 complete with automated regression protection.

| Domain | Criteria |
|---|---|
| Theme | Existing-theme consistency; light quality; dark quality; system response; persistence; semantic-token compliance |
| Visual | Radius consistency; solid-line compliance; typography, spacing, surface, focus, and state coherence |
| Responsive | Mobile; tablet; desktop; orientation; zoom; short height; forms; tables; dashboards; media |
| Input | Touch targets; mouse behavior; keyboard navigation; assistive semantics |
| Overlays | Dropdown; panel; modal; outside click; trigger toggle; peer coordination; Escape; focus; scroll; collision; layering |
| Motion | Meaningful transitions; interruption; reduced-motion support; no layout shift |
| Security | Frontend; backend/API; authorization; tenant isolation; database; abuse controls; testing |
| Performance | Rendering; API; backend; database; network; assets; bundle; measured budgets |
| Evidence | Commands; interaction traces; security reports; performance baselines and thresholds |

Passing requires every applicable item to score at least 3 and at least 80 percent overall. Accessibility, backend authorization, tenant isolation, and critical performance-budget failures force FAIL regardless of average.
