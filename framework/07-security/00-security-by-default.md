# Security By Default

Version: 2.0
Pack: 07-security  
Status: Stable  
Applies To: application, API, infrastructure, data, and AI-assisted changes

## Purpose

Make security an explicit design constraint rather than a final checklist.
Load this module whenever a change can expose data, alter trust boundaries,
create an endpoint, process a file, add a dependency, or change deployment
configuration.

## Required threat pass

Before editing, record:

1. The protected assets and their confidentiality, integrity, and availability
   impact.
2. The actors and trust boundaries involved, including tenant, service,
   browser, queue, storage, and administrator boundaries.
3. The untrusted inputs and the sinks they can reach.
4. The abuse cases that would cause unauthorized access, data loss, denial of
   service, secret disclosure, or unsafe execution.
5. The control and the evidence that will prove it works.

Do not claim “secure by default” from a dependency scan alone. The scan does
not prove authorization, tenant isolation, safe error handling, or correct
configuration.

## Mandatory controls

- Deny access until identity, tenant, resource, and action are verified.
- Validate at the boundary, canonicalize once, and encode for the output
  context; never concatenate untrusted input into commands or queries.
- Keep secrets out of source, logs, fixtures, URLs, screenshots, and evidence.
- Minimize data returned, retained, broadcast, and cached.
- Apply dependency and image updates through the repository's lockfile and
  reproducible build path.
- Make security failures observable without logging credentials or personal
  data.
- Add rollback or containment for changes that affect authentication,
  authorization, migrations, payments, production, or incident response.

## Verification

Use the closest evidence: focused authorization tests, negative tests for
cross-tenant/object access, input-fuzz or schema tests, secret scans, dependency
review, migration dry runs, and a security-gate review. Record commands and
results; list any unavailable scanner or unverified production assumption.

## Anti-patterns

- Client-side permission checks treated as enforcement.
- “Internal” endpoints without authentication because they are not linked in UI.
- Logging full request bodies, tokens, cookies, or stack traces to users.
- Broad wildcard CORS, debug mode, default credentials, or fail-open recovery.
- A green build presented as proof that a trust-boundary change is safe.

## Completion criteria

The change identifies its trust boundary, enforces the decision server-side,
protects sensitive data, has direct negative evidence for the highest-risk
abuse case, and states residual limitations honestly.
