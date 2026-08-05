# Workspace Hygiene Gate

Pass only when generated artifacts have an owner, retention policy, and cleanup path. The cleanup command must default to dry run, protect source/configuration/secrets/Git/release paths, skip tracked files, and print evidence before deletion.

Fail on drive-level deletion, silent deletion, unbounded retention, deletion of evidence, or a machine-specific script that is absent from the repository.
