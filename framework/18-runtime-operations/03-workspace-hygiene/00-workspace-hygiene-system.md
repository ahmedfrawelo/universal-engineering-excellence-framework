# Workspace Hygiene System

At task start and after validation, inspect generated workspace output. Use `scripts/cleanup-workspace.ps1` on Windows or `scripts/cleanup-workspace.sh` on Unix. The default is a dry run; deletion requires explicit `-Apply` or `CLEANUP_APPLY=1`. This includes stale screenshots, test reports, caches, `dist`/`build` output, and temporary server-upload staging when those paths are untracked.

The assistant must never delete source, configuration, secrets, `.git`, release deliverables, or tracked files as part of routine cleanup. A project may extend the allowlist only through documented repository policy and review.
