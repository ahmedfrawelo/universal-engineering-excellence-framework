# Verification, Rollout, And Rollback

- Maintain a requirements-to-evidence matrix for each modernization slice.
- Run characterization, unit, integration, contract, migration, security, performance, accessibility, build, deployment, and runtime checks according to affected risk.
- Compare baseline and final metrics; investigate unexplained changes instead of averaging them away.
- Use canary, feature flag, shadow traffic, dual read/write, compatibility adapter, or staged rollout when blast radius warrants it.
- Define rollback before deployment, including data compatibility and forward-fix limits.
- Monitor errors, latency, resource use, stale data, event gaps, dependency failures, and user-visible regressions during adoption.
- Remove flags, adapters, deprecated paths, and temporary telemetry after stable adoption is proven.
