# Execution Sequence

1. classify the task and inspect architecture, ownership, patterns, and current Git state;
2. validate or create `DESIGN.md` for a material design build;
3. run `scripts/select-frontend-route.mjs` before mutation and retain its embedded `designProduction` route evidence;
4. load only the selected director and specialists;
5. when Taste is selected, run `taste-preflight` and fail on duplicate CTA intent, repeated section layouts, a third consecutive zigzag split, or excessive eyebrow labels;
6. implement and verify the exact behavior;
7. when Taste is selected, run `taste-final-check` against the rendered final composition;
8. for selected visual review, run the Styleseed lock/score/revise/render loop;
9. create a current artifact from `framework/21-framework-resources/01-templates/32-frontend-execution-evidence-template.json` and validate it with `node scripts/validate-frontend-execution-evidence.mjs --path <artifact>`;
10. run `framework/12-delivery-quality/04-quality-gates/35-frontend-design-production-gate.md` with the other selected gates;
11. keep the task active while routing, tests, live-tool, behavioral, accessibility, responsive, performance, or visual evidence is missing.
