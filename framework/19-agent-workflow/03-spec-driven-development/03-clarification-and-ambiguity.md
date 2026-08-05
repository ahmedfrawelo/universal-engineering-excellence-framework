# Clarification and Ambiguity

## Purpose

Ambiguity must become visible before it turns into guessed behavior. This module defines how to handle unknowns without blocking routine progress.

## Rules

- Mark unknowns explicitly in the specification or plan before implementation.
- Ask the user only for decisions that materially affect correctness, user data, security, cost, deployment, or irreversible behavior.
- For low-risk gaps, choose a conservative default and record it as an assumption.
- Do not bury ambiguity in a final answer after implementation; surface it before the dependent work starts.
- Remove or resolve ambiguity markers before claiming the feature is complete.

## Red Flags

- "I'll just infer it."
- "The tests passed, so the missing requirement is fine."
- "This is probably what they meant."
- "We can clean up the spec later."
- "No one will notice this edge case."
