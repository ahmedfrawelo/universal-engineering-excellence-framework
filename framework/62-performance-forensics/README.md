# Performance Forensics

Use this pack when a page, table, grid, dashboard, API, query, cache path, or user flow is slow and the user needs evidence before changes.

## Principle

Performance work starts as an investigation, not an optimization. Measure the real flow, classify each finding by evidence strength, and produce a plan before code, index, cache, migration, or infrastructure changes.

## Use Levels

- Quick triage: establish whether the dominant delay is frontend, API, database, cache, network, infrastructure, or duplicate work.
- Full forensic audit: trace every applicable stage end to end and mark every applicable checklist item.
- Approved implementation: after the user approves a plan, apply the smallest safe change set with before-and-after measurements.

## Completion Rule

Do not claim a bottleneck is confirmed unless it has timing, trace, plan, logical-read, payload, source-code, or runtime metric evidence from the inspected system.
