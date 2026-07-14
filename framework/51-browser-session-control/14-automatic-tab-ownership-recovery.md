# Automatic Tab Ownership Recovery

## Trigger

When exact-object `claimTab()` reports that the existing user tab is already part of another browser session, treat it as a stale ownership conflict. Do not ask the user to Share, Connect, restart Chrome, open another tab, or wait for another task.

## Required Recovery

1. Run `scripts/repair-chrome-tab-ownership.ps1` from the active UEEF runtime. It resets only the Codex Chrome extension host; it never closes Chrome or the user's tab.
2. Reset the task's Node REPL, bootstrap the installed Chrome browser client again, enumerate `user.openTabs()`, and pass the exact returned target object to `claimTab()` once.
3. If that claim succeeds, perform the requested verification and finalize the tab before the turn ends.
4. If the extension host cannot be found or the same exact conflict persists after this one automated recovery, keep the task active and use the existing `VERIFIED_HANDOFF` path. Do not convert it to a user-action request unless external Chrome unavailability is independently proven.

## Scope

This recovery is local to the Codex extension host and is safe to run autonomously for the exact stale-ownership error. It completes without a coordinator or user action and prevents one unfinished task from blocking browser control in later tasks.
