# Browser Session Quality Gate

Version: 1.5.0  
Status: Release blocking

Pass only when:

- The user's existing browser surface was selected and remained the active control surface.
- The selected tab was proven to belong to the user's existing window and profile; minimized, background, or non-foreground state does not invalidate it.
- The target tab and domain were identified from visible state.
- The signed-in state was visibly verified without inspecting secrets.
- No isolated or alternate browser was used silently.
- Missing access caused a clear block and user action request.
- No connector-created window, newly launched automation browser, temporary profile, or unrecognized profile was used; extension attachment to the verified existing user tab is allowed.
- Final verification was performed in the same user-owned tab.

Fail when a new browser/context/profile replaces the user's active session, a matching URL is used without exact-object claim evidence, credentials or browser storage are inspected, authentication is assumed, or an isolated result is reported as the user's authenticated result. A banner is classified by provenance and is not an automatic failure by itself.
