# Authenticated Session Verification

Authentication must be verified from visible page state, not from cookies or hidden storage.

- Check the target domain and a visible signed-in indicator or authenticated page state.
- Never request, print, copy, or inspect passwords, cookies, tokens, local storage, or session databases.
- If the target redirects to login, reports signed out, or shows the wrong account, stop and ask the user to sign in to the active browser.
- Treat a successful page load alone as insufficient proof of the correct account.
