# 53-skeleton-loading

This pack governs skeleton loaders as a product interaction contract. Every new data-backed page or component must define its loading representation, and every existing loading representation must be updated when the content structure changes.

Skeletons are structural previews, not decoration. They must preserve the final layout, use the governed theme tokens, avoid layout shift, respect reduced motion, and transition cleanly to content, empty, error, or partial states.
