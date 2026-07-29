# Scope and Flow Tracing

Trace the complete request path before deciding where to optimize.

## Required Flow Map

Record the path from user action to visible result:

`navigation -> routing -> component initialization -> state -> API request -> DNS/TLS/proxy/CDN/load balancer -> middleware -> authentication -> authorization -> controller -> service -> cache -> ORM/SQL -> database execution -> mapping -> serialization -> compression -> network transfer -> parsing -> state update -> rendering -> interactive`

## Required Inventory

Identify applicable files, methods, systems, and secondary work:

- frontend route, component, template, styles, state, service, interceptors, guards, resolvers, table/grid configuration, and child components
- API endpoint, controller, application service, repository, query handler, mapper, serializer, middleware, authentication, authorization, tenancy, and logging
- ORM query, generated SQL, stored procedures, views, functions, triggers, computed columns, indexes, statistics, and database objects
- cache layers, keys, TTLs, invalidation, serialization, compression, hit/miss behavior, and contamination risks
- network, domain, proxy, CDN, WAF, load balancer, transport, hosting region, and cross-region boundaries
- duplicate requests, background jobs, polling, retries, hidden tabs, eager modal/dropdown loads, and work blocking first rows

## Output

Use:

`Step | File/method/system | Work performed | Duration | Evidence`
