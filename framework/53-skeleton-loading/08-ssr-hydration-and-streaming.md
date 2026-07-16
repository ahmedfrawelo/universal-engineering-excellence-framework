# SSR Hydration And Streaming

Evaluate SSR, SSG, route pre-rendering, server components, and streaming whenever the route uses them or would benefit from them. The server fallback, first client render, and hydrated state must use deterministic skeleton structure: stable row counts, dimensions, keys, variants, and token-derived values. Do not use random widths, browser-only measurements, current time, or client-only data to shape server markup.

Place skeletons at intentional suspense or streaming boundaries that match independently loadable content regions. Preserve already rendered shell and content while later regions stream. A nested boundary must not replace a stable parent with a second full-page skeleton.

Hydration must not remount the loading region, steal focus, repeat announcements, or produce warnings. Cache and request-state handoff must prevent a server-rendered content response from reverting to a client skeleton. If the stack is intentionally client-rendered, record that SSR and hydration are not applicable and still verify deterministic first render.
