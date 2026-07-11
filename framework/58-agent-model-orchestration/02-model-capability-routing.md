# Model Capability Routing

## Capability Classes

- `Fast`: low cost and latency for deterministic, bounded tasks.
- `Balanced`: everyday implementation, debugging, and moderate reasoning.
- `Frontier`: complex architecture, broad integration, high ambiguity, or high-risk review.

## Default Mapping

When the platform exposes the current Codex model family:

| Tier | Model | Reasoning |
| --- | --- | --- |
| T0 | lead agent; no override | inherited |
| T1 | `gpt-5.6-luna` | low, medium when code changes |
| T2 | `gpt-5.6-terra` | medium or high |
| T3 | `gpt-5.6-sol` | high or xhigh |
| T4 | `gpt-5.6-sol` | xhigh, max, or ultra according to risk |

Use an inherited model when it already satisfies the class. Do not override merely to make routing visible. If names differ or overrides are unavailable, select the nearest available capability class and keep the same risk floor.

## Quality Protection

- Never choose from token price alone.
- A smaller model may execute a mechanical child task inside a critical rollout, but it may not own the critical decision or final verification.
- Escalate after two inconclusive attempts, one unexplained test regression, missing architecture context, or conflicting evidence.
- Do not downgrade a route after discovering security, data-loss, production, or shared-contract risk.
