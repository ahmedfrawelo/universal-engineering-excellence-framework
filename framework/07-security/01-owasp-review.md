# OWASP Review

Version: 2.0
Pack: 07-security  
Status: Stable  
Applies To: security reviews and security-sensitive implementation changes

## Purpose

Turn an OWASP-style review into evidence about this repository, not a copied
list of category names.

## Review sequence

1. Map the request to the affected assets, entrypoints, trust boundaries,
   dependencies, and deployment path.
2. Walk the relevant categories: broken access control, cryptographic
   failures, injection, insecure design, misconfiguration, vulnerable
   components, authentication failures, integrity failures, logging/monitoring
   failures, and server-side request forgery.
3. For each applicable category, write `control`, `test/evidence`, and
   `residual risk`. Mark a category `not applicable` only with a reason.
4. Check both positive behavior and a denied/abused behavior. A happy-path test
   alone is not an OWASP control.
5. Re-run the closest quality gate after fixing findings.

## Evidence expectations

- Access control: authenticated and unauthorized/other-tenant fixtures.
- Injection: parameterized queries/commands plus boundary rejection tests.
- Authentication and crypto: lifecycle, expiry, rotation, recovery, and
  algorithm/configuration evidence.
- Misconfiguration: production-like settings, headers, CORS, debug, and
  default-secret checks.
- Components and integrity: lockfile review, provenance, signature/checksum or
  reproducible-build evidence where the project supports it.
- Logging and SSRF: redaction tests, alertable security events, egress
  restrictions, and allowlisted destinations.

Do not use the OWASP label as a severity score. Severity depends on the asset,
exposure, exploitability, and business impact recorded for this task.

## Completion criteria

The review names applicable categories, shows direct evidence for the highest
risks, records accepted residual risk and owner, and does not imply that an
unavailable scanner or external audit was run.
