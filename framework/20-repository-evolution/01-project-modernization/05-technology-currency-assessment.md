# Technology Currency Assessment

Before substantial work on an existing project, inspect runtime and dependency currency from authoritative local evidence and, when current support status matters, official vendor or registry sources.

Inventory direct and transitive packages, runtimes, frameworks, SDKs, compilers, package managers, databases, container bases, CI actions, infrastructure providers, language targets, and deprecated APIs. Distinguish latest, latest stable, latest supported for this project, long-term support, security-only support, and end of life.

Do not recommend an upgrade solely because a larger version exists. Consider platform compatibility, peer constraints, lockfile integrity, licensing, supply-chain risk, security advisories, bundle/runtime cost, data migrations, deployment support, and rollback.

Never invent a current version. Use lockfiles and local commands for installed versions, and verify changing release/support facts with official sources.
