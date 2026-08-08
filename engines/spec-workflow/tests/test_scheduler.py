from __future__ import annotations

import unittest

from ueef_spec_workflow.scheduler import Scheduler
from ueef_spec_workflow.state import ExecutionState

from .helpers import graph, task


class SchedulerTests(unittest.TestCase):
    def test_independent_scoped_tasks_form_a_parallel_wave(self) -> None:
        subject = graph(task("TASK-001"), task("TASK-002"), task("TASK-003"))
        decision = Scheduler(subject).decide(ExecutionState.new(subject))
        self.assertEqual(
            [item.task_id for item in decision.tasks],
            ["TASK-001", "TASK-002", "TASK-003"],
        )
        self.assertEqual(decision.desired_workers, 3)
        self.assertEqual(decision.scale_action, "GROW")

    def test_dependency_releases_only_after_evidence_backed_completion(self) -> None:
        subject = graph(task("TASK-001"), task("TASK-002", dependsOn=["TASK-001"]))
        state = ExecutionState.new(subject)
        first = Scheduler(subject).decide(state)
        self.assertEqual([item.task_id for item in first.tasks], ["TASK-001"])
        state.transition(subject, "TASK-001", "start", worker="worker-1")
        state.transition(subject, "TASK-001", "complete", evidence="tests passed")
        second = Scheduler(subject).decide(state)
        self.assertEqual([item.task_id for item in second.tasks], ["TASK-002"])

    def test_write_conflicts_are_deferred(self) -> None:
        subject = graph(
            task("TASK-001", writeSet=["src/api"]),
            task("TASK-002", writeSet=["src/api/routes"]),
        )
        decision = Scheduler(subject).decide(ExecutionState.new(subject))
        self.assertEqual(len(decision.tasks), 1)
        self.assertIn("write scope overlaps", decision.deferred[0]["reason"])

    def test_risk_three_task_is_isolated(self) -> None:
        subject = graph(
            task("TASK-001", risk=3, priority=10),
            task("TASK-002"),
        )
        decision = Scheduler(subject).decide(ExecutionState.new(subject))
        self.assertEqual([item.task_id for item in decision.tasks], ["TASK-001"])
        self.assertIn("isolated", decision.deferred[0]["reason"])

    def test_minimal_budget_mode_forces_single_worker(self) -> None:
        subject = graph(
            task("TASK-001"),
            task("TASK-002"),
            tokenBudgetMode="minimal",
        )
        decision = Scheduler(subject).decide(ExecutionState.new(subject))
        self.assertEqual(decision.worker_cap, 1)
        self.assertEqual(len(decision.tasks), 1)

    def test_budget_can_prevent_a_wave(self) -> None:
        subject = graph(task("TASK-001", effortPoints=3), tokenBudget=1000)
        decision = Scheduler(subject).decide(ExecutionState.new(subject))
        self.assertEqual(decision.worker_cap, 0)
        self.assertEqual(decision.tasks, ())
        self.assertEqual(decision.deferred[0]["reason"], "worker cap reached")

    def test_team_target_records_grow_then_shrink(self) -> None:
        subject = graph(task("TASK-001"))
        state = ExecutionState.new(subject)
        first = Scheduler(subject).decide(state)
        state.reserve_wave(
            [(item.task_id, item.worker) for item in first.tasks],
            first.desired_workers,
        )
        self.assertEqual(first.scale_action, "GROW")
        state.transition(subject, "TASK-001", "start", worker="worker-1")
        state.transition(subject, "TASK-001", "complete", evidence="done")
        final = Scheduler(subject).decide(state)
        self.assertEqual(final.desired_workers, 0)
        self.assertEqual(final.scale_action, "SHRINK")

    def test_running_workers_consume_total_worker_capacity(self) -> None:
        subject = graph(task("TASK-001"), task("TASK-002"), maxWorkers=1)
        state = ExecutionState.new(subject)
        state.transition(subject, "TASK-001", "start", worker="worker-1")
        decision = Scheduler(subject).decide(state)
        self.assertEqual(decision.worker_cap, 1)
        self.assertEqual(decision.tasks, ())

    def test_reserved_wave_cannot_be_scheduled_twice(self) -> None:
        subject = graph(task("TASK-001"), task("TASK-002"))
        state = ExecutionState.new(subject)
        first = Scheduler(subject).decide(state)
        state.reserve_wave(
            [(item.task_id, item.worker) for item in first.tasks],
            first.desired_workers,
        )
        second = Scheduler(subject).decide(state)
        self.assertEqual(second.tasks, ())
        self.assertEqual(second.current_workers, 2)

    def test_new_wave_cannot_conflict_with_active_work(self) -> None:
        subject = graph(
            task("TASK-001", writeSet=["src/api"], priority=10),
            task("TASK-002", writeSet=["src/api/routes"]),
            maxWorkers=2,
        )
        state = ExecutionState.new(subject)
        first = Scheduler(subject).decide(state)
        state.reserve_wave(
            [(item.task_id, item.worker) for item in first.tasks],
            first.desired_workers,
        )
        second = Scheduler(subject).decide(state)
        self.assertEqual(second.tasks, ())
        self.assertIn("write scope overlaps TASK-001", second.deferred[0]["reason"])

    def test_active_estimate_reserves_token_budget(self) -> None:
        subject = graph(
            task("TASK-001", effortPoints=2, priority=10),
            task("TASK-002", effortPoints=2),
            tokenBudget=2000,
            maxWorkers=1,
        )
        state = ExecutionState.new(subject)
        first = Scheduler(subject).decide(state)
        state.reserve_wave(
            [(item.task_id, item.worker) for item in first.tasks],
            first.desired_workers,
        )
        second = Scheduler(subject).decide(state)
        self.assertEqual(second.budget_remaining, 1000)
        self.assertEqual(second.tasks, ())

    def test_worker_names_do_not_collide_with_active_assignments(self) -> None:
        subject = graph(task("TASK-001"), task("TASK-002"), maxWorkers=2)
        state = ExecutionState.new(subject)
        state.transition(subject, "TASK-001", "start", worker="worker-2")
        decision = Scheduler(subject).decide(state)
        self.assertEqual(decision.tasks[0].worker, "worker-1")


if __name__ == "__main__":
    unittest.main()
