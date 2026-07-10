# Browser Control Surface Selection

Use the least intrusive control surface that can complete the user's browser task.

## Default Selection

- For normal visible work, such as opening a page, clicking, typing, reviewing layout, or checking a local site, prefer verified visible Windows control of the user's active Chrome window.
- Use Chrome debugging control only when the task needs DOM-level inspection, console errors, network requests, performance tracing, or another debugging-only capability.
- Do not use debugging control merely to perform ordinary navigation, clicks, typing, or screenshots when visible control is available.

## User Indicators

- Visible Windows control may show a temporary screen-edge highlight. Chrome debugging may show a browser debugging banner.
- These indicators are platform safety disclosures and must not be hidden or suppressed.
- If the user asks to avoid the Chrome debugging banner, prefer visible Windows control after window identity is verified.

## Completion Rule

Keep one selected control surface for the task unless a documented capability gap requires a switch. Never switch silently to a new browser, profile, or automation window.
