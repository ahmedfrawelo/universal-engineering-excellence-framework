"""UEEF task-graph scheduling and execution-state package."""

from .approvals import ApprovalGate, ApprovalLedger
from .benchmark import compare_runs
from .control_plane import aggregate_control_status
from .convergence import converge
from .model import TaskGraph, TaskSpec, WorkflowPolicy
from .orchestration import HostResult, HostRuntime, Orchestrator, RecordedHostRuntime
from .portfolio import PortfolioFeature, orchestrate_portfolio
from .scheduler import ScheduleDecision, Scheduler
from .state import ExecutionState, StateStore, TaskStatus
from .team_manager import ManagementAction, ManagementReport, TeamManager, WorkerProfile

__all__ = [
    "ExecutionState",
    "ApprovalGate",
    "ApprovalLedger",
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
    "PortfolioFeature",
    "orchestrate_portfolio",
    "converge",
    "compare_runs",
    "aggregate_control_status",
]

__version__ = "0.1.0"
