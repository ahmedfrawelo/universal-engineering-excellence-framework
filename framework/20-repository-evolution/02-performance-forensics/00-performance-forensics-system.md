# Performance Forensics System

Version: 1.0.0
Status: Enforced
Applies to: slow tables, data grids, dashboards, APIs, collection queries, cache paths, search, sort, filter, pagination, and slow interactive pages

## Purpose

Find performance bottlenecks with evidence before changing the system.

## Mandatory Sequence

1. Identify the exact target flow, user action, route, component, endpoint, query, cache path, and infrastructure boundary.
2. Decide whether the task is quick triage, full forensic audit, or approved implementation.
3. Audit mode is report-only: for audit-only requests, do not edit production code, create indexes, add caches, add migrations, install packages, or change infrastructure.
4. Measure cold start, warm path, cold cache, warm cache, first page, deep page, filtered, sorted, searched, and concurrent-user behavior when applicable.
5. Mark each checklist item as working correctly, defective, missing and applicable, not applicable, or unable to verify.
6. Classify findings as confirmed, strongly suspected, or unverified possibility.
7. Recommend the smallest safe implementation package with success thresholds, correctness checks, security checks, monitoring, and rollback.
8. Stop for explicit approval before mutation when the task was an audit or report request.

## Evidence Standard

Every recommendation must cite at least one concrete evidence type: measured timing, trace, browser profile, network timing, SQL plan, logical reads, wait stats, source-code path, payload size, dependency metric, or documented behavior for the exact installed version.

## Failure Conditions

- Recommending an optimization without evidence.
- Stopping after the first bottleneck when the user requested end-to-end audit.
- Treating existing cache, pagination, index, or lazy loading code as effective without measuring or tracing it.
- Improving speed by weakening authorization, tenant isolation, ordering correctness, pagination consistency, or data freshness without explicit acceptance.
- Running high-load, destructive, production-mutating, or infrastructure-changing tests without explicit approval.
