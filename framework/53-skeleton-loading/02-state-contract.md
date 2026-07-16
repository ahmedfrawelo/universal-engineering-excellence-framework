# State Contract

Define initial loading, refreshing, empty, error, partial-data, permission-denied, and retry states where the product needs them. Initial loading may use the full structural skeleton; background refresh should preserve existing content and expose a restrained progress signal instead of replacing the screen with a skeleton.

The contract must define when loading ends, what happens on cancellation, how retry works, and which state owns focus. Never show a skeleton indefinitely without timeout, error, or recovery behavior.

Define the temporal state path as `pending-hidden -> skeleton-visible -> content | empty | error | partial`. A refresh with usable content remains content-present and does not return to the initial path. Define a reveal delay and minimum visible duration through shared loading-policy tokens. Data that resolves before the reveal delay renders content directly. Once a skeleton becomes visible, keep it stable for the configured minimum duration unless cancellation, navigation, error, or an accessibility requirement needs an immediate transition. Do not add arbitrary feature-local timers or delay ready content merely to display a skeleton.
