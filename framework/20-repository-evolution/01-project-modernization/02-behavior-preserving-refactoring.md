# Behavior-Preserving Refactoring

- Write characterization tests around uncertain legacy behavior before changing structure.
- Separate mechanical moves from behavior changes and review them independently.
- Prefer branch-by-abstraction, adapters, compatibility aliases, expand-and-contract migrations, and strangler slices over large rewrites.
- Keep every slice deployable or explicitly isolated behind a feature flag.
- Preserve public contracts until consumers migrate; version unavoidable breaking changes.
- Compare outputs, side effects, errors, permissions, timing-sensitive behavior, and data contracts before and after.
- Use mutation, contract, integration, snapshot, golden-master, or differential tests where ordinary unit tests cannot prove parity.
- Remove temporary compatibility seams after adoption is verified; do not leave permanent dual paths without an owner and expiry.

Refactoring is complete only when the old path is retired, tests prove the intended contract, and observability shows no regression.
