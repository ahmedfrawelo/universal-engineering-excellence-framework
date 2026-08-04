# Frontend Design Production System

## Contract

Every material frontend design build must resolve these layers in order:

1. repository architecture, ownership, and existing design system;
2. a valid root or project-scoped `DESIGN.md` design contract;
3. one primary director: `interface-design` for product UI or `frontend-design` for expressive/general frontend;
4. conditional specialists selected by the route, never a universal skill stack;
5. implementation in the owning component or design-system boundary;
6. behavioral, accessibility, responsive, and rendered verification;
7. Styleseed score/revise/render gate when the task requests a design review or material visual release.

`config/frontend-design-production-policy.json` is the machine-readable policy. `scripts/select-frontend-route.mjs` embeds the deterministic design-production route used by managed enforcement; `scripts/select-design-production-route.mjs` exposes the same route directly. They share `scripts/frontend-design-production-route-lib.mjs`, so routing cannot drift between the two entrypoints.

For a frontend mutation, route selection is mandatory before the first edit. Delivery is blocked until `scripts/validate-frontend-execution-evidence.mjs` passes a current evidence artifact. The final `UIUX:` label must summarize actual state, responsive, accessibility, performance, test, and render evidence; `NA` is invalid after a frontend mutation.

## Non-substitution rule

Code existence, build success, a numerical score, or a design canvas alone cannot prove the requested behavior. The exact user-facing behavior and applicable UEEF gates remain authoritative.
