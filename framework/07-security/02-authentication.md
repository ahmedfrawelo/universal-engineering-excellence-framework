# Authentication

Version: 2.0
Pack: 07-security  
Status: Stable  
Applies To: identity, login, session, token, recovery, and account changes

## Identity lifecycle

Model registration, verification, login, step-up/MFA, session creation,
rotation, logout/revocation, recovery, disablement, and deletion as explicit
states. Define what happens to existing sessions and refresh tokens at every
security-sensitive transition.

## Mandatory rules

- Store passwords only with a current adaptive password hash and a repository
  approved cost policy; never encrypt or log raw passwords.
- Use a well-reviewed identity/token library and the project’s documented key
  management path; do not invent cryptography or token formats.
- Use short-lived access credentials, rotate refresh/session identifiers after
  login or privilege changes, and revoke them on logout, reset, disablement,
  or suspected compromise.
- Rate-limit and monitor login, recovery, verification, and MFA attempts
  without creating an account-enumeration oracle.
- Treat reset links, MFA recovery codes, cookies, and authorization headers as
  secrets. Apply secure, HttpOnly, SameSite, expiry, audience, issuer, and
  replay controls appropriate to the transport.
- Require re-authentication or step-up for high-impact actions and make the
  decision server-side.

## Verification

Test valid and invalid credentials, expiry, replay, rotation, logout,
concurrent sessions, reset-token reuse, MFA recovery, rate limits, and
enumeration-safe responses. Verify that a disabled user cannot use an already
issued credential where policy requires immediate revocation.

## Anti-patterns

- Passwords, bearer tokens, or reset secrets in logs, URLs, analytics, or
  screenshots.
- Trusting a client-provided role or “verified” flag.
- Permanent sessions, non-expiring reset links, shared admin accounts, or
  fail-open MFA/recovery.
- Changing the login flow without testing all existing session states.
