# Model Capability Routing

## Capability Classes

- `Fast`: low cost and latency for deterministic, bounded tasks.
- `Balanced`: everyday implementation, debugging, and moderate reasoning.
- `Frontier`: complex architecture, broad integration, high ambiguity, or high-risk review.

## Default Mapping

When the platform exposes the current Codex model family:

| Tier | Model | Reasoning |
| --- | --- | --- |
| T0 | inherited | low |
| T1 | inherited (Fast class) | medium |
| T2 | inherited (Balanced class) | medium |
| T3 | inherited (Frontier class) | high |
| T4 | inherited (Frontier class) | high |

The route selector emits `preferredModel: inherit` for every tier. UEEF describes capability classes (Fast, Balanced, Frontier), not fixed model names, so platform-supplied model families are not overridden by outdated or fictional identifiers.

`medium` is the economical default, not a hard ceiling. A recorded T3/T4 or high-ambiguity route may request a platform-supported higher level; higher-risk work also increases topology, evidence, and independent verification. UEEF must not override a higher level chosen by the platform.

Use an inherited model when it already satisfies the class. Do not override merely to make routing visible. If a specific model must be requested, verify its availability from the current orchestration tool before naming it; otherwise stay with `inherit`.

Verify model entitlement from the current orchestration tool before using a named override. When availability cannot be verified, emit the capability class with no model ID and continue with the strongest available inherited model.

## Quality Protection

- Never choose from token price alone.
- A smaller model may execute a mechanical child task inside a critical rollout, but it may not own the critical decision or final verification.
- Escalate after two inconclusive attempts, one unexplained test regression, missing architecture context, or conflicting evidence.
- Do not downgrade a route after discovering security, data-loss, production, or shared-contract risk.
