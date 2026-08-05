# Data Grid Platform System

Treat a data grid as a shared product capability, not a repeated page widget. Define one contract for columns, rows, query state, loading, empty, error, permission, selection, editing, export, and responsive behavior. The frontend and backend must agree on stable identifiers, query semantics, totals, cursors or pages, errors, and versioned response metadata.

Before creating a grid, inspect the existing grid, table theme, column registry, filter/sort components, overlay contract, pagination controls, virtual-scroll strategy, aggregate footer, and API query models. Reuse or extend the closest capability.
