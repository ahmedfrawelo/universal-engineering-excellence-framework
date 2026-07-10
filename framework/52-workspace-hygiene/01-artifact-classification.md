# Artifact Classification

Safe routine candidates include old `*.log`, `*.trace`, `*.har`, and `*.tmp` files plus explicitly named generated directories such as `coverage`, `test-results`, `playwright-report`, `.cache`, and `.pytest_cache`.

Build output such as `dist`, `build`, `out`, and `publish` is disposable only when it is untracked and reproducible. Temporary deployment staging such as `.deploy` and `server-upload` is also eligible when it is untracked. Release folders, server-upload packages that are the only deployment copy, published bundles, snapshots used as evidence, and any tracked artifact require explicit operator selection.
