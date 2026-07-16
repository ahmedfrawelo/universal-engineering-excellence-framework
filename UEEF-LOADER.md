# UEEF Source Loader

This file is the source-repository loader template. Installers and `scripts/sync-runtime.ps1` generate the active Codex-specific loader under `CODEX_HOME/ueef/codex/UEEF-LOADER.md` with the resolved runtime paths.

Skill/display metadata: `assets/ueef-display.json`; icon asset: `assets/ueef-skill-icon.svg`.

Before every non-trivial engineering task:

1. Route the task through pack 58, select the lowest-cost capable model, and spawn only when delegation has positive benefit.
2. Load only `boot-loader` and `core-system` as always-loaded modules.
3. Run `scripts/environment-bootstrap.ps1` or `scripts/environment-bootstrap.sh` before inspection.
4. Select task-specific modules through `framework/01-core/01-master-loader.md`.
5. For UI/UX work, apply both `ui-ux-pro-max` and `impeccable` together.
6. Apply the Engineering Guardian, relevant quality gates, and final verification before completion.

File, folder, and size discipline:
- Every new file must live under an owned feature, layer, package, route, docs, tests, scripts, generated-artifact, deployment, or configuration folder.
- Reusable behavior, UI, validation, data access, formatting, configuration, and design logic must live in the existing shared/common/library owner and be imported by consumers.
- Before creating custom UI or behavior, inspect existing shared components, design tokens, layouts, registries, services, validators, API clients, utilities, stores, mappers, and pattern libraries.
- Extend existing feature or shared owners before creating a parallel implementation. Create custom feature-local code only when it is genuinely single-use or explicitly isolated by product ownership.
- Do not dump unrelated files into the project root or a generic mixed folder.
- Do not create a standalone-file system unless it is a repository-standard entrypoint, documented configuration, one-off owned script, or explicit user-requested artifact.
- Split files before they become mixed-responsibility sinks. Keep UI, data access, business rules, validation, transport, tests, generated content, and operational scripts in their owned areas.

Backend and frontend performance:
- Backend endpoints that serve UI data must consider server-side pagination, filtering, sorting, aggregation, projection, caching and invalidation, cancellation, concurrency, serialization cost, authorization cost, rate limits, and burst behavior.
- Frontend routes must consider SSR, SSG, streaming, route-level pre-rendering, or server components when SEO, public content, first paint, slow client boot, or first-view data volume makes server rendering useful.
- Do not force SSR for authenticated operational screens or stacks that intentionally use client rendering; record the reason when SSR is considered and skipped.
- Prevent over-rendering end to end: frontend state, selectors, subscriptions, effects, memoization, virtualization, and component boundaries; backend over-fetching, over-serialization, repeated queries, noisy realtime broadcasts, broad cache invalidation, and unbounded recomputation.
- Animations must be smooth, interruptible, reduced-motion aware, and compositor-friendly. Prefer transform and opacity, avoid layout-triggering animation, and prevent animation state from repainting unrelated UI or triggering avoidable backend refreshes.

Response quality:
- Answer the user's direct question first, then give concise evidence.
- Do not claim perfection, completion, release, push, browser verification, or active runtime status without current evidence.
- Keep final responses short and factual, with changed scope and validation when files were modified.
- For Arabic or other RTL prose that mixes English identifiers, isolate the LTR phrase for display readability only. Do not insert hidden bidirectional control characters into code blocks, terminal commands, copyable file paths, JSON/YAML, source files, configuration, or repository content.

Task scope discipline:
- Work only on the requested task, its direct blockers, and regressions introduced by the current change.
- Do not chase unrelated errors, warnings, tests, UI issues, backend endpoints, refactors, dependency warnings, or generated files.
- If an unrelated pre-existing error appears, record it as unrelated, use narrower relevant validation when possible, and continue the requested work.
- Broaden scope only when the user asks, when the unrelated issue directly prevents the requested task from being verified, or when the current change caused it.

Large-project reuse:
- For broad or unfamiliar repositories, run `scripts/project-context-map.ps1`, `scripts/project-context-map.sh`, or an equivalent repository map before implementation.
- Discover module boundaries, aliases, barrel exports, public APIs, registries, package boundaries, shared folders, state stores, validators, service clients, and test utilities before implementation.
- Use public imports/exports and project registries. Do not reach into private internals unless that is the established project convention.
- When adding reusable capability, update the shared public export, tests, and at least one real consumer where project conventions expect it.

Design engineering skill routing:
- Add `emil-design-eng` for motion implementation and polish.
- Add `review-animations` for motion review, `improve-animations` for read-only motion audits, `animation-vocabulary` for naming effects, and `apple-design` for gesture, spring, momentum, and Apple-style interaction work.
- Select only matching skills; never load the full suite by default.

Skill invocation protocol:
- Before non-trivial work, evaluate named user-requested skills, installed skills, project-local skills, and UEEF packs.
- Build the smallest useful skill chain for discovery, implementation, verification, and review.
- Treat shortcut red flags as reroute triggers: missing skill check, untested fix, unsupported claim, partial verification, fake completion, or unbounded subagent work.
- Use TDD or an equivalent evidence loop when behavior changes.

Spec-driven development:
- For broad, ambiguous, multi-file, high-impact, or durable work, make the specification the source of truth before implementation.
- Separate what and why from how, resolve or document ambiguities, then translate requirements into a technical plan and traceable tasks.
- Check consistency across specification, plan, tasks, code, tests, and final claims before completion.
- If implementation reveals a requirement gap, update the specification or task list before continuing.

Agent routing hardening:
- Risk score 3 requires an explicit risk floor.
- Parallel agents require positive delegation benefit and at least two independently owned workstreams.
- Verify current agent and named-model availability before spawning or overriding; fall back to the inherited model without lowering quality gates.
- The hard reasoning ceiling is medium for every model and agent. Never request high, xhigh, max, ultra, or an equivalent level above medium.
- Every non-trivial T1-T4 code-changing task must spawn at least one bounded child when agent tooling is callable. Before the first project command or edit, show `Agent route: <tier> | Agent: spawned <id or nickname>`. The only valid no-spawn reason for code-changing work is `TOOL_UNAVAILABLE`.

Live runtime refresh:
- At the beginning of every user turn, including an existing chat, re-read this loader and verify the active runtime version and status before selecting tools.
- Never rely on a loader or browser decision cached from an earlier turn.
- If the runtime version, loader content, or browser hard-stop policy changed, discard the cached decision and restart preflight.

Delivery continuation:
- An explicit request to expand scope, rebuild, migrate, or redesign is not a reason to suspend execution or wait for the user to resume.
- Revise the plan and continue implementation and tests. `Not ready to release` blocks only a release claim, never requested coding work.
- Use BLOCKED only for a real impasse: missing required access, unavailable mandatory dependency, unresolved destructive decision, or external state that prevents meaningful progress.
- Compile/test failures, API/facade/schema mismatches, save-contract bugs, incomplete wiring, and repeated failed patches are internal engineering work, never BLOCKED conditions. Replan, escalate, delegate bounded verification, and continue. Repetition does not convert an internal bug into an external blocker.
- Mark a goal BLOCKED only for an external or user-only condition after no meaningful local work remains. Never pause an incomplete code path waiting for the user to resume it.
- When a goal is ACTIVE, never emit a final answer saying the work is incomplete or no complete result exists. Use commentary and continue execution. Before finalizing a goal task, read current goal status; final is allowed only for COMPLETE, valid external BLOCKED, or an explicit user request for status-only reporting.

Local command autonomy:
- Run and reuse normal project commands and local development services without asking the user. A Codex command prompt is a platform confirmation, not an agent question or task blocker.
- Reuse a healthy existing service before starting another long-running process.

Browser hard stop:
- Never use a connector-created Chrome window for a task that depends on the user's visible browser.
- Block a newly created automation/Codex window, temporary profile, or unverified profile. A control banner on the verified existing user tab requires provenance classification and is not an automatic block.
- For Chrome tasks, read the installed Chrome control skill and bootstrap its browser client only through `mcp__node_repl__js`, then use the extension binding, enumerate `user.openTabs()`, and `claimTab()` the verified user-owned tab. Never use directly exposed Playwright, Chrome DevTools, or in-app-browser MCP tools for Chrome work; Playwright is allowed only through the claimed tab's `tab.playwright` API.
- A transient Node REPL, browser-client, or extension bridge failure requires the installed skill's bootstrap and Chrome troubleshooting flow plus retry on the same extension binding. Do not invent alternate import syntax or switch browser surfaces.
- A task-local Node REPL or browser-client failure is `THREAD_CONTROL_CHANNEL_DEGRADED`, not proof that Chrome is unavailable. It cannot justify `BLOCKED` or asking the user to restart Chrome. When a trusted coordinator has verified the exact existing user tab, accept its current `VERIFIED_HANDOFF`; request a fresh handoff after relevant code changes.
- After the first local bridge failure, request that handoff and continue implementation. Do not expose retry counts, internal bridge errors, or a stopped-verification message; report only: `Browser verification is being completed on your existing tab; implementation continues.`
- Before a browser-task turn ends, finalize its claimed tabs through `chrome.tabs.finalize(...)` as the final browser action. This releases the user's tab for the next task without closing it and prevents stale ownership locks.
- If `claimTab()` reports a stale browser-session owner, run `scripts/repair-chrome-tab-ownership.ps1`, reset the task browser binding, and reclaim the exact existing tab once. This is autonomous; do not ask another task or the user to intervene.
- When browser or visual verification is required, keep the task active until the exact user-owned tab is claimed and verified. Build, tests, component reuse, source inspection, and structural equivalence cannot substitute for this gate or justify `COMPLETE`.
- Preserve the user's browser window state. Do not resize, emulate, move, restore, minimize, maximize, or alter full screen unless explicitly requested.
- A minimized, background, or non-foreground user-owned Chrome window remains controllable through the extension and must not block or pause the goal. If one visual-only operation genuinely requires foreground visibility, continue all non-visual work and defer only that visual gate.
- Use visible Windows control only as a fallback when the Chrome plugin is unavailable. If the user-owned tab cannot be proven, stop without opening another browser.

The only valid compact verification line is:

```text
Loaded: boot-loader, core-system
```

The active runtime loader is generated from this source contract. Do not report selector files, indexes, runtime sequence, or activation proof as always-loaded modules.
