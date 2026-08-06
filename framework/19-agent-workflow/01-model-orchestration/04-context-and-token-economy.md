# Context and Token Economy

## Purpose

Reduce context and token spend without lowering correctness, security, traceability, or completion proof. Token economy is a routing constraint: it decides how much context, which model class, how many agents, and how much output a work unit may consume.

## Lead/Worker Economy Model

Use the strongest selected route for decisions, integration, and final verification. Use cheaper or narrower workers only for bounded work that can be specified, verified, and summarized without copying the full conversation.

- Lead responsibilities: classify the task, produce or confirm the execution spec, choose topology, preserve the critical path, integrate results, and verify acceptance criteria.
- Worker responsibilities: execute one bounded read, implementation, test, review, or comparison task with explicit files, constraints, evidence, and stop condition.
- Verifier responsibilities: inspect the final diff or artifact against requirements, not worker summaries, when the selected tier requires independent review.

Do not spawn a worker for vague exploration, overlapping edits, immediate blockers, or work whose setup context costs more than doing it locally.

## Spec-First Budget Contract

For T2+ work, the lead must establish a lightweight execution spec before delegation or broad source inspection. The spec may be an in-chat route record for small T2 work or a durable `.ueef/specs/<id>` workflow when ambiguity, impact, or reuse justifies it.

The execution spec must include:

- outcome and non-goals;
- acceptance criteria;
- selected domains or likely owner paths;
- token budget mode: `minimal`, `bounded`, or `expanded`;
- delegation policy: `none`, `sidecar`, `parallel-specialists`, or `lead-workers-verifier`;
- maximum worker count;
- worker output cap;
- required evidence and final convergence checks.

If implementation discovers a requirement gap, update the spec or task list before spending more context on implementation.

The managed route recorder enforces this contract. For T2+, it refuses a route without explicit acceptance criteria, owner paths, and non-goals; resolves the tier's budget and delegation defaults from `config/model-routing-policy.json`; persists a digest-bound execution spec; and exposes the protected route artifact to the App Server dispatcher. The managed hook denies other task tools and completion when that execution spec is absent or invalid.

## Child Context Packet

Send only:

- outcome and acceptance criteria;
- exact repository root and relevant paths;
- constraints and risk floor;
- owned files or read-only question;
- token budget mode and output cap;
- expected evidence and concise response format.

Do not send full chat history by default. Prefer explicit file references and current repository evidence. Reuse an existing agent for dependent follow-up instead of spawning another one.

## Worker Output Cap

Workers return a compact result, not a transcript:

- decision or finding;
- files inspected or changed;
- commands run and PASS/FAIL result;
- evidence path or exact output excerpt;
- blockers only when they are external or outside the worker scope.

Default cap: 12 bullets or 250 words. For implementation workers, include changed files and validation only; put long logs, analysis tables, or inventories in artifacts.

The App Server dispatcher passes the execution spec and output cap as application context to the routed work unit. The managed hook counts post-route worker creation and denies any worker above the tier's `maxWorkerCount`.

## Economy Rules

- Route first, then inspect only the selected surface.
- Query repository intelligence or a project context map before broad scans.
- Parallelize independent reads or tests, not coupled decisions.
- Avoid duplicate summaries and repeated repository scans.
- Cap child output to decisions, evidence, changed files, and blockers.
- Cancel obsolete work after scope changes.
- Cache stable findings inside the rollout, but re-check drift-prone state.
- The lead synthesizes results once and does not re-perform completed child work.
- Escalate model capability only for risk, ambiguity, repeated failure, or final verification needs.
- De-escalate materially simpler follow-up work after the high-risk decision is complete.

Token reduction is a constraint, not the success metric. Correctness, security, and completion remain release gates.

## Completion Gate

Before claiming completion, verify that the accepted token economy did not remove required evidence:

- every explicit requirement still has acceptance evidence;
- every worker result is integrated or explicitly discarded with reason;
- no broad claim relies on a narrow worker check;
- no unresolved gap is hidden as a token-saving shortcut.
