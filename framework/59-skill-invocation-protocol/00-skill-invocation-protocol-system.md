# Skill Invocation Protocol System

## Purpose

This module requires the assistant to evaluate relevant installed skills, project skills, and workflow packs before acting. Skill routing is a decision gate, not a decorative note in the final response.

## Core Rules

- Before non-trivial work, list the task type and the matching skill or UEEF pack candidates.
- Use the most specific applicable skill first: domain skill, UI skill, browser skill, data skill, documentation skill, then general engineering workflow.
- Do not skip a matching skill because the task appears simple; simple tasks still fail when assumptions are hidden.
- If multiple skills apply, use the smallest ordered chain that covers discovery, implementation, verification, and review.
- If no dedicated skill exists, state that explicitly and continue with the relevant UEEF module set.
- Do not load broad skill suites by default. Route narrowly and only expand after evidence of need.
- Skill invocation must produce a concrete effect: plan structure, checklist, test, review, browser path, artifact, or verification choice.

## Workflow

1. Classify the request and risk.
2. Detect installed skills and project-local skills.
3. Match relevant skills to the task.
4. Choose an ordered skill chain.
5. Convert the chain into todo steps or quality gates.
6. Execute with evidence.
7. Record any skipped skill and the reason.

## Quality Gate

Passes when the assistant can show the selected skills or explain why none applied, and the final implementation follows the selected workflow evidence.
