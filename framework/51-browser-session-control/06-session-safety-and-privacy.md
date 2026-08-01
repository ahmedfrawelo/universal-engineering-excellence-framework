# Session Safety and Privacy

Browser control must preserve session privacy and minimize side effects.

- Do not inspect browser storage, cookies, passwords, extensions' private data, or profile directories.
- Confirm before destructive actions, downloads with side effects, uploads, purchases, messages, or account changes.
- Keep actions scoped to the requested domain and tab.
- Redact authenticated URLs, personal data, and account identifiers from final reports unless necessary.
- Emergency remote debugging is loopback-only and target-scoped. Never call cookie, storage, password, profile, or browser-history APIs through CDP; never expose the debugging endpoint beyond localhost; detach immediately after verification.
