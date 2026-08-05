# Repository Intelligence System

Version: 1.0
Pack: 20-repository-evolution/03-repository-intelligence
Status: Stable
Applies To: every repository-scoped UEEF task, broad or unfamiliar repositories, architecture discovery, dependency tracing, and impact analysis

## Purpose

Provide an automatically selected local knowledge graph as fresh repository evidence. It
supplements source inspection; it never replaces inspection of the owning files
or direct behavioral verification.

## Selection

Select this pack when a task needs one or more of:

- any repository-scoped task or chat where a project root is available;
- broad orientation in an unfamiliar repository;
- architecture or ownership mapping across multiple files;
- dependency-path or affected-code analysis;
- a durable, incrementally refreshed repository graph.

Do not select it only when no repository root is in scope or the answer is
truly non-repository. Narrow repository edits still start with graph status and
a bounded query so the first source inspection is informed by current project
context.

For repository-scoped tasks, task preflight selects this pack automatically.
Use is mandatory: preflight checks graph status, builds the graph when missing,
refreshes it when stale, and runs one bounded task query before other
substantial repository work continues. A failed selected graph gate makes
preflight non-ready instead of silently falling back to prose-only orientation.

## Commands

PowerShell:

```powershell
.\scripts\repository-intelligence.ps1 -Command build -Root . -Json
.\scripts\repository-intelligence.ps1 -Command query -Root . -Query 'authentication flow' -Json
.\scripts\repository-intelligence.ps1 -Command path -Root . -From 'controller' -To 'repository' -Json
.\scripts\repository-intelligence.ps1 -Command explain -Root . -Query 'PaymentService' -Json
.\scripts\repository-intelligence.ps1 -Command affected -Root . -Query 'shared validator' -Json
.\scripts\repository-intelligence.ps1 -Command status -Root . -Json
.\scripts\repository-intelligence.ps1 -Command doctor -Root . -Json
```

Unix/Git Bash uses the same command vocabulary through
`scripts/repository-intelligence.sh`.

## Contract

- Output ownership: `.ueef/repository-graph/` in the analyzed repository.
- Durable artifacts: `graph.json`, `GRAPH_REPORT.md`, `graph.html`, and `state.json`.
- Evidence levels: `EXTRACTED`, `INFERRED`, and `AMBIGUOUS`; consumers must retain
  source evidence and must not present an inferred edge as extracted fact.
- Builds are incremental. An unchanged build reuses the inventory; changed and
  deleted files refresh or prune their owned graph data.
- Query responses are bounded and include portable source paths.
- Generated output, dependency caches, vendor trees, VCS metadata, and
  secret-like files are excluded by default.

## Safety boundary

The native entrypoints expose only `build`, `query`, `path`, `explain`,
`affected`, `status`, and `doctor`. Default execution is local and offline. It
must not install assistant integrations, modify hooks, start MCP, invoke an LLM,
call cloud services, ingest URLs, connect to remote databases, control a browser,
or read conversation memory.

The curated embedded engine subset and all retained licenses, notices,
provenance, declared exclusions, and modification records stay inside
`engines/repository-intelligence/`. UEEF-owned entrypoints outside that boundary
must not copy or expose the upstream general-purpose CLI or MCP surface.

## Evidence use

1. Run task preflight; for repository-scoped work this pack is selected
   automatically and checks, builds or refreshes, and performs one bounded
   query without asking the user.
2. Use additional `query`, `path`, `explain`, or `affected` calls when the
   initial bounded query does not answer the repository question.
3. Open the cited owning files and confirm the relevant implementation.
4. Test the requested behavior itself and run the applicable UEEF gates.
5. Treat missing or ambiguous graph evidence as unresolved, never as proof of absence.
