# Backend Engineering

Version: 1.1
Pack: 11-backend  
Status: Stable  
Applies To: server endpoints, domain services, workers, integrations, and data-access paths

## Purpose

This module governs backend domain boundaries, data integrity, security, reliability, performance, and operational behavior.

## Architecture Contract

- Organize files under the owning endpoint, feature, application service, domain model, data-access layer, worker, integration, test, or migration area.
- Split large backend files before controllers or transports combine validation, authorization, mapping, business invariants, queries, caching, and integration policy.
- Reuse established clients, repositories, policies, schemas, telemetry, and error contracts before creating parallel mechanisms.
- Make transaction boundaries, idempotency, retries, timeouts, cancellation, concurrency, and shutdown explicit.

## Data and API Behavior

- Validate at trust boundaries and enforce authorization and tenant isolation on the server for every resource operation.
- Support bounded pagination, filtering, sorting, aggregation, projection, and export for large or sensitive collections.
- Prevent backend-driven over-render and over-refresh behavior by avoiding over-fetching, over-serialization, repeated queries, noisy realtime broadcasts, broad invalidation, and unbounded background work.
- When events drive clients, publish minimal scoped events with authorization context, deduplication, ordering strategy, coalescing, and backpressure.

## Reliability and Operations

- Define stable error semantics, correlation, structured logs without secrets, health signals, metrics, and actionable alerts.
- Review latency budgets, cancellation, concurrency, caching, serialization, authorization cost, rate limits, and burst behavior.
- Bound external dependencies with deadlines, failure classification, retry policy, circuit or degradation behavior, and recovery ownership.
- Require phased rollout and rollback for schema, contract, dependency, or production-risk changes.

## Required Evidence

- Unit tests for domain invariants and integration or contract tests for real boundaries.
- Negative-path authorization, validation, timeout, retry, cancellation, and duplicate-request coverage where applicable.
- Query plans or representative latency and load evidence for material paths.
- Deployment, health, migration, and rollback evidence for production-impacting changes.

## Failure Conditions

- Business rules, transport, persistence, and authorization are collapsed into an untestable owner.
- Client-side filtering or authorization protects sensitive data.
- Retries, concurrency, or event delivery can duplicate effects without an idempotency strategy.
- Operational or performance claims are made without representative evidence.
