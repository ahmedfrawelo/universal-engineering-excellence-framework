# Global Live Refresh And State Reconciliation

Version: 1.2.0  
Status: Enforced  
Applies to: any mutable remote state, notifications, counters, dashboards, detail views, forms, workflows, jobs, collaboration, and data views

## Required Practice

- Choose push, targeted invalidation, stale-while-revalidate, bounded polling, or manual refresh from freshness, scale, security, cost, and failure requirements.
- Update the smallest authorized state scope without reloading the page, route, shell, or whole component tree.
- Preserve route, navigation, filters, sort, pagination, selection, focus, expanded state, scroll, drafts, validation, and unsaved edits.
- Use stable entity identity, event IDs, versions or sequences, schema version, tenant and resource scope, deduplication, ordering, gap detection, conflict handling, and reconnect reconciliation.
- Authenticate the connection and authorize each subscription and mutation. Re-check authorization after reconnect, tenant switch, permission change, and token refresh.
- For WebSocket, validate the browser `Origin`, authenticate before accepting subscriptions, prohibit long-lived credentials in URLs, rotate credentials without losing ordering, and disconnect revoked permissions within a defined deadline.
- For SSE, define allowed origins and credentials, disable intermediary caching and buffering where required, send heartbeat comments, rotate or re-establish authorization safely, and close revoked streams promptly.
- Coalesce bursts, bound queues and retries, cancel obsolete requests, apply backpressure, scope cache invalidation, and prevent render or query storms.
- Define one retry owner across browser, proxy, gateway, and backend. Allowlist retryable failures, honor `Retry-After`, use exponential backoff with jitter and caps on attempts and elapsed time, stop on authorization or validation failures, and use a circuit breaker or degraded mode for sustained failure.
- Show quiet freshness and stale/offline/reconnecting state; background refresh must not replace content with a blocking spinner.
- Prove event-to-visible-state latency, render count, stale age, reconnect time, dropped events, memory, fan-out, payload, and burst behavior under realistic load.

## Allowed Full Reload

A full page reload is allowed only for an unrecoverable bootstrap failure, a deployed-client incompatibility that cannot be migrated in place, or a security boundary change requiring a fresh trusted bootstrap. Record the exact reason and recovery path.

## Completion Rule

Live refresh passes only with frontend reconciliation, backend authorization, transport lifecycle, failure recovery, performance, and explicit no-page-reload evidence.
