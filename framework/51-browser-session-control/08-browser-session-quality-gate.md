# Browser Session Quality Gate

Version: 1.5.0  
Status: Release blocking

Pass only when:

- The user's existing browser surface was selected and remained the active control surface.
- The target tab and domain were identified from visible state.
- The signed-in state was visibly verified without inspecting secrets.
- No isolated or alternate browser was used silently.
- Missing access caused a clear block and user action request.
- Final verification was performed in the same user-owned tab.

Fail when a new browser/context/profile replaces the user's active session, credentials or browser storage are inspected, authentication is assumed, or an isolated result is reported as the user's authenticated result.
