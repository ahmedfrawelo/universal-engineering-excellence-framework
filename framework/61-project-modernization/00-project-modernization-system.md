# Project Modernization System

Version: 1.0.0  
Status: Enforced  
Applies to: existing projects, legacy code, broad refactors, dependency upgrades, runtime upgrades, architecture modernization

## Purpose

Modernize an established project without rewriting blindly, deleting reachable behavior, or upgrading dependencies without impact evidence.

## Mandatory Sequence

1. Map repository boundaries, manifests, lockfiles, entrypoints, runtime paths, public APIs, dynamic loading, generated code, tests, deployment, and ownership.
2. Establish behavior, architecture, performance, security, dependency, and operational baselines before edits.
3. Classify findings as dead, obsolete, duplicated, risky, unsupported, slow, insecure, or merely old. Age alone is not a defect.
4. Produce a dependency-aware modernization plan with reversible slices, acceptance evidence, migration order, and rollback points.
5. Preserve behavior with characterization tests before structural edits when existing intent is not already proven.
6. Remove dead code only with multi-source reachability evidence.
7. Upgrade technology only after support, compatibility, security, migration, and deployment impact are known.
8. Compare the final state with the baseline and leave no known regression unowned.

## Completion Rule

Modernization passes only when current evidence proves behavior preservation, architecture improvement, dependency safety, and operational rollback. A cleaner file tree or green compilation alone is insufficient.
