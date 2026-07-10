# Realtime Notifications And Refresh

For large systems, choose polling, server-sent events, WebSocket, or SignalR from freshness, scale, infrastructure, and delivery requirements. Define connection lifecycle, authentication, tenant scope, reconnection backoff, heartbeat, event version, ordering, deduplication, and offline behavior.

A data event must identify entity, operation, scope, version, and correlation id. The frontend must reconcile events with the active query, invalidate or patch affected rows safely, preserve user edits, and expose a quiet refresh indicator. Notifications should not force full-grid reloads when a targeted invalidation or row patch is sufficient.
