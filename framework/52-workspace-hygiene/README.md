# 52-workspace-hygiene

This pack keeps generated diagnostics and temporary build output from accumulating in a project. It is designed for repeated use by AI coding assistants and humans.

The cleanup policy is conservative: source, configuration, secrets, Git metadata, release artifacts, and tracked files are protected by default. Cleanup runs in dry-run mode unless the operator explicitly enables deletion.
