# Red Flag Detection

## Purpose

Red flags catch shortcut behavior before it becomes low-quality code, fake completion, or repeated rework.

## Red Flags

- Starting implementation before checking relevant skills, tools, and project conventions.
- Debugging by changing code before reproducing or gathering evidence.
- Saying "probably", "should", or "looks fine" where a command, test, screenshot, or code reference is available.
- Skipping tests because the change appears small.
- Creating a custom UI, validator, service, API client, or data mapper before searching shared owners.
- Treating a passing build as proof of UX, browser, realtime, accessibility, or data correctness.
- Letting a subagent implement without an explicit bounded task, files, context, and verification evidence.
- Accepting a spec-compliance issue as "close enough".
- Reporting `BLOCKED` for an internal bug that can still be investigated locally.
- Adding files to root or generic folders without ownership and lifecycle.

## Required Response

When a red flag is found:

1. Stop that path.
2. Name the red flag internally in the plan or task record.
3. Re-route through the correct skill, UEEF pack, test, or verification gate.
4. Continue implementation after the correction.

## Quality Gate

Passes when no red flag remains unaddressed in the final implementation or verification story.
