# State Contract

Define initial loading, refreshing, empty, error, partial-data, permission-denied, and retry states where the product needs them. Initial loading may use the full structural skeleton; background refresh should preserve existing content and expose a restrained progress signal instead of replacing the screen with a skeleton.

The contract must define when loading ends, what happens on cancellation, how retry works, and which state owns focus. Never show a skeleton indefinitely without timeout, error, or recovery behavior.
