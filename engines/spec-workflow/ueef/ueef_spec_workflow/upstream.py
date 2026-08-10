"""Compatibility tombstones for the retired runtime upstream bridge.

Reference comparison is intentionally owned by the repository review script.  Production
Python must not load or inspect the vendored reference snapshot.
"""

from __future__ import annotations

from typing import NoReturn

from .errors import WorkflowError


def _retired() -> NoReturn:
    raise WorkflowError("runtime reference inspection is retired; use the offline review tool")


def verify_snapshot() -> NoReturn:
    """Reject the removed production snapshot-inspection capability."""

    _retired()


def validate_workflow(*_args: object, **_kwargs: object) -> NoReturn:
    """Reject the removed production reference-validator bridge."""

    _retired()
