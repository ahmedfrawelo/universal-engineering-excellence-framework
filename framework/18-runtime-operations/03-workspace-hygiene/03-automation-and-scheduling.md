# Automation And Scheduling

Run the cleanup script at task boundaries or from a user-owned scheduler. Scheduling must invoke dry-run first and apply deletion only after the policy is reviewed. Keep the command in the repository so a fresh installation behaves the same way without machine-specific scripts.

Recommended Windows command: `powershell -ExecutionPolicy Bypass -File scripts/cleanup-workspace.ps1 -OlderThanDays 14 -Apply`. Recommended Unix command: `CLEANUP_APPLY=1 CLEANUP_OLDER_THAN_DAYS=14 ./scripts/cleanup-workspace.sh`.
