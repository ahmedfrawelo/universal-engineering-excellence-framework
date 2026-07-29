# Database Security

Version: 2.0
Pack: 07-security  
Status: Stable  
Applies To: schemas, queries, migrations, backups, and data access

## Mandatory controls

- Use separate least-privilege identities for application reads/writes,
  migrations, reporting, and administration where the platform supports it.
- Parameterize every query and constrain dynamic identifiers through an
  allowlist; never interpolate user input into SQL or database commands.
- Enforce tenant and row ownership in the data-access boundary as well as in
  the API policy. A filtered UI is not isolation.
- Select only required columns, avoid sensitive data in broad joins/logs, and
  redact query parameters and result samples in diagnostics.
- Make migrations forward-safe, review destructive operations explicitly, and
  define backup, rollback/forward-fix, lock, timeout, and compatibility steps.
- Encrypt data in transit and at rest according to the deployment contract;
  keep keys outside the repository and rotate them through the approved path.

## Migration review

Record affected tables/indexes, cardinality and lock expectations, old/new
application compatibility, backfill batching, retry/idempotency behavior, and
the recovery plan. A migration that parses is not necessarily safe to deploy.

## Verification

Run query/authorization tests, injection regression tests, migration dry-run or
rollback evidence, explain-plan/performance checks for changed queries, backup
restore evidence when required, and a check that secrets and personal data do
not enter logs or fixtures.
