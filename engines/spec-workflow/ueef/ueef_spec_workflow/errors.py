"""Error types with stable user-facing messages."""


class WorkflowError(ValueError):
    """Raised when a graph, state, transition, or policy is invalid."""


class StateConflictError(WorkflowError):
    """Raised when optimistic state revision checks fail."""


class UpstreamDependencyError(WorkflowError):
    """Raised when optional dependencies for the vendored engine are absent."""
