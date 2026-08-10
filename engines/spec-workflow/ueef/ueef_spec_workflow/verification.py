"""Independent verifier contract used by the persisted controller."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol

from .model import TaskGraph
from .state import ExecutionState


@dataclass(frozen=True)
class VerificationReport:
    passed: bool
    evidence: str
    diff_digest: str
    changed_paths: tuple[str, ...] = ()
    findings: tuple[str, ...] = ()
    independent: bool = True


class Verifier(Protocol):
    def verify(self, graph: TaskGraph, state: ExecutionState) -> VerificationReport: ...
