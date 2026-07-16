# Render Timing And Flicker Control

Every skeleton region must use the shared loading timing policy. The policy defines a reveal delay, a minimum visible duration, an indefinite-loading timeout, and cancellation behavior. Defaults are product-level tokens that may be tuned from measured latency; feature code must not create independent magic-number timers.

If content resolves before the reveal delay, render content directly and never flash the skeleton. If the skeleton is already visible, keep its structure stable until the minimum duration is satisfied, then transition once to content, empty, error, or partial. Never delay navigation, cancellation, permission denial, or a ready accessible response merely to complete an animation.

Coalesce rapid requests and stale responses so the same region cannot oscillate between skeleton and content. Background refresh preserves usable content and uses restrained progress feedback. Tests cover fast, normal, slow, cancelled, failed, retried, and superseded requests with deterministic clocks.
