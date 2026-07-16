# Superpowers Attribution

UEEF 2.8.18 reviewed the public Superpowers project as an external reference for skill-driven coding-agent workflows.

## Source

- Repository: `https://github.com/TheACJ/superpower`
- Upstream project references: `https://github.com/obra/superpowers`
- Reviewed commit: `6fd4507659784c351abbd2bc264c7162cfd386dc`
- License observed in the reviewed repository: MIT License, copyright Jesse Vincent.

## What UEEF Reused

UEEF did not copy Superpowers skill files into the framework. It adapted general workflow ideas into UEEF-native rules:

- Mandatory skill evaluation before implementation.
- Spec-to-plan-to-execution chain for non-trivial work.
- TDD and evidence-first implementation.
- Red-flag detection for shortcut behavior.
- Bounded subagent dispatch with review before completion.

## Integration Boundary

Superpowers remains an external project. UEEF's `framework/59-skill-invocation-protocol/` is independently written and validated against UEEF runtime, file ownership, browser, security, and delivery-continuation rules.
