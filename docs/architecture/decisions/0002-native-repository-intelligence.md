# ADR 0002: Native repository intelligence

Status: Accepted
Date: 2026-08-02

## Context

Broad repository work needs faster orientation and traceable dependency evidence,
but UEEF must not make an assistant skill, external service, browser session, or
LLM a prerequisite for understanding local code.

## Decision

UEEF provides a native repository-intelligence facade with a small allowlisted
command surface. The implementation uses a pinned third-party engine as a
curated embedded subset whose license files, notices, provenance, declared
exclusions, and modification history are contained under
`engines/repository-intelligence/`. The machine-readable upstream manifest in
that directory is the authority for upstream identity, revision, and curated
exclusions.

The facade performs local AST extraction plus deterministic document,
configuration, and SQL structure extraction. It writes portable generated data
under `.ueef/repository-graph/` in the analyzed repository. It does not expose
the engine's installer, hook, MCP, network, LLM, remote-database, browser, or
memory features.

## Consequences

- Repository graphs are optional evidence and can be rebuilt incrementally.
- Runtime installation is bounded because demo outputs and upstream
  CI/deploy/docs/history/assistant-skill surfaces that UEEF does not expose are
  excluded.
- A first invocation prepares the pinned Python environment; later invocations reuse it.
- UEEF controls its stable command contract even if the embedded internals change.

## Rollback

Remove pack 63, the two generic entrypoints, their tests and policy, then remove
the single embedded engine directory. Generated `.ueef/repository-graph/` directories are
project-local caches and can be removed independently when explicitly requested.
