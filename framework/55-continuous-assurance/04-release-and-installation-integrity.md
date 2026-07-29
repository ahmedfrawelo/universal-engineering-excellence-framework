# Release And Installation Integrity

Verify version parity, required release notes, installer presence, runtime sync, and clean tracked state before publishing. A release is not complete when source validation passes but generated runtime or installation inputs are stale.

For GitHub publishing, prefer `scripts/publish-github-release.ps1` after the commit and tag are pushed. The script first uses an authenticated `gh` session, then falls back to Git Credential Manager credentials already proven by `git push`; do not start a browser device-login flow merely because `gh` is not authenticated. Never print tokens, passwords, or credential-manager output.
