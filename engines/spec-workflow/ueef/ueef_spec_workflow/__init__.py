"""UEEF task-graph scheduling and execution-state package."""

from .benchmark import compare_runs
from .convergence import converge
from .model import TaskGraph, TaskSpec, WorkflowPolicy
from .orchestration import HostResult, HostRuntime, Orchestrator, RecordedHostRuntime
from .scheduler import ScheduleDecision, Scheduler
from .state import ExecutionState, StateStore, TaskStatus
from .team_manager import ManagementAction, ManagementReport, TeamManager, WorkerProfile

__all__ = [
    "ExecutionState",
    "ScheduleDecision",
    "Scheduler",
    "StateStore",
    "TaskGraph",
    "TaskSpec",
    "TaskStatus",
    "WorkflowPolicy",
    "HostResult",
    "HostRuntime",
    "Orchestrator",
    "RecordedHostRuntime",
    "ManagementAction",
    "ManagementReport",
    "TeamManager",
    "WorkerProfile",
    "converge",
    "compare_runs",
]

__version__ = "0.1.0"
