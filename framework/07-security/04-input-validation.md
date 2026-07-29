# Input Validation

Version: 2.0
Pack: 07-security  
Status: Stable  
Applies To: HTTP, jobs, imports, files, events, commands, and persistence

## Boundary contract

Define a schema at every trust boundary. Reject unknown or malformed fields
where compatibility permits, constrain size/count/depth/range, and return a
stable safe error shape. Validation is not sanitization: preserve the original
meaning only after canonicalization, then encode for the final sink.

## Mandatory rules

- Use allowlists for enums, paths, hosts, content types, and command choices.
- Normalize Unicode, path separators, encodings, and numeric/date forms once
  before comparison or authorization.
- Parameterize database queries and commands; never build them by string
  concatenation.
- Encode output for HTML, URL, JavaScript, SQL, shell, logs, and headers as
  distinct contexts. Do not reuse “sanitized” text across contexts.
- For uploads, validate size and type by content plus policy, store outside
  executable/public paths, generate safe names, scan/quarantine where
  required, and authorize download separately.
- Reject decompression bombs, oversized arrays, deeply nested JSON, repeated
  keys, and ambiguous duplicate parameters.

## Verification

Cover boundary limits, malformed encodings, null/duplicate fields, parser
differences, traversal, injection probes, invalid content types, oversized
payloads, and safe error/redaction behavior. Add a regression fixture for each
accepted security bug.

## Anti-patterns

- Relying on client validation, filename extensions, or a regex as the only
  parser.
- Silently coercing invalid values into a privileged default.
- Logging rejected secrets or raw upload content.
- Validating one entrypoint while an equivalent job/import path bypasses it.
