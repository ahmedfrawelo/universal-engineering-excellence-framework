# ADR-006: Govern frontend design production as a native UEEF route

Status: Accepted
Date: 2026-08-03

## Context

UEEF already routes frontend implementation and design skills, but it had no single contract connecting durable design intent, expressive taste guidance, measured visual review, and an open design canvas. Treating all four as universal skills would create conflicting authorities and would incorrectly apply marketing-page guidance to dense product UI.

## Decision

- Add `framework/10-frontend/02-production-design/` as the semantic owner.
- Make repository `DESIGN.md` the durable design identity and token contract.
- Keep exactly one primary director: `interface-design` for dense product UI and `frontend-design` for expressive/general frontend.
- Select `design-taste-frontend` only for expressive surfaces.
- Select `styleseed-design-review` only for measured post-build review, with a minimum score of 80 plus rendered behavioral verification.
- Prefer Penpot MCP for new UEEF-controlled design-canvas work, while preserving explicit Figma artifact workflows.
- Require current MCP configuration, reachability, plugin connection, target file, and successful operation before claiming live Penpot use.

## Consequences

The route is deterministic and testable, optional tools remain non-blocking when repository evidence can satisfy the task, and capability manifests expand by two pinned skills and one conditional MCP. New public configuration is validated by existing framework and enforcement gates.

## Alternatives rejected

- Universal stacking: creates competing directors and excess context.
- Taste for dashboards: violates the upstream scope and UEEF product-UI ownership.
- Penpot declaration as live proof: confuses preference/configuration with callable external state.
- Removing Figma: breaks tasks whose source artifact is explicitly Figma.
