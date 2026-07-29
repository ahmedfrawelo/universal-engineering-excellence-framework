# Authorization

Version: 2.0
Pack: 07-security  
Status: Stable  
Applies To: roles, permissions, policies, tenant boundaries, and protected APIs

## Decision model

Every protected operation must evaluate the authenticated principal, tenant or
organization, action, resource, and relevant state on the server. Prefer a
central policy/service or a clearly owned domain boundary so controllers,
clients, jobs, exports, and realtime handlers cannot drift apart.

## Mandatory rules

- Deny by default; fail closed when policy data is missing or a dependency is
  unavailable.
- Check object-level and function-level access separately. A user allowed to
  call an endpoint is not automatically allowed to access every object.
- Derive tenant/resource identity from trusted routing and data ownership, not
  from a mutable client body or hidden field.
- Apply the same policy to synchronous APIs, background jobs, exports,
  notifications, caches, webhooks, and realtime broadcasts.
- Keep role/permission changes auditable, versioned where needed, and
  protected by least privilege.
- Return safe errors that do not disclose resource existence across a trust
  boundary.

## Verification

For each protected action, test an allowed principal, an unauthenticated
principal, a different role, a different tenant, a different object owner,
and a stale/revoked permission. Test direct URL/ID substitution and background
execution paths; client hiding is not evidence.

## Anti-patterns

- `isAdmin` checks scattered through UI code.
- Authorization performed only at route entry while nested resources are
  returned without ownership checks.
- Wildcard permissions, implicit tenant fallback, or “internal job” bypasses.
- Logging full authorization context when it contains personal or secret data.
