# Page Regions and Route Transitions

- Define stable regions: shell frame, page header, toolbar, content, secondary panel, overlay, notification, and status/live region.
- Keep the shell mounted when route changes do not require its teardown; preserve scroll and state intentionally.
- Route transitions must not flash, duplicate, or briefly render the wrong page. Coordinate outlet activation with loading and authorization.
- Use route metadata for title, breadcrumbs, navigation selection, transition policy, analytics context, and required permissions.
- Support deep links, refresh, browser history, cancellation, and failure recovery. Never make transitions the only indication that content changed.
