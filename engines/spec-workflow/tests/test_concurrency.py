from __future__ import annotations

import json
import multiprocessing
import tempfile
import unittest
from pathlib import Path
from typing import Any

from ueef_spec_workflow.errors import StateConflictError
from ueef_spec_workflow.model import TaskGraph
from ueef_spec_workflow.scheduler import Scheduler
from ueef_spec_workflow.state import ExecutionState, StateStore

from .helpers import graph, task


def _schedule_once(
    graph_path: str,
    state_path: str,
    barrier: Any,
    results: Any,
) -> None:
    subject = TaskGraph.from_json_file(graph_path)
    store = StateStore(state_path)
    state = store.load(subject)
    revision = state.revision
    decision = Scheduler(subject).decide(state)
    barrier.wait(timeout=10)
    state.reserve_wave(
        [(item.task_id, item.worker) for item in decision.tasks],
        decision.desired_workers,
    )
    try:
        store.save(state, expected_revision=revision)
        results.put("saved")
    except StateConflictError:
        results.put("conflict")


class ConcurrentScheduleTests(unittest.TestCase):
    def test_two_schedulers_cannot_reserve_the_same_wave(self) -> None:
        subject = graph(task("TASK-001"))
        with tempfile.TemporaryDirectory() as directory:
            graph_path = Path(directory) / "graph.json"
            state_path = Path(directory) / "state.json"
            graph_path.write_text(
                json.dumps(subject.to_dict()), encoding="utf-8", newline="\n"
            )
            StateStore(state_path).save(ExecutionState.new(subject))
            context = multiprocessing.get_context("spawn")
            barrier = context.Barrier(2)
            results = context.Queue()
            workers = [
                context.Process(
                    target=_schedule_once,
                    args=(str(graph_path), str(state_path), barrier, results),
                )
                for _ in range(2)
            ]
            for worker in workers:
                worker.start()
            for worker in workers:
                worker.join(timeout=15)
                self.assertEqual(worker.exitcode, 0)
            outcomes = sorted(results.get(timeout=2) for _ in workers)
            self.assertEqual(outcomes, ["conflict", "saved"])
            resumed = StateStore(state_path).load(subject)
            self.assertEqual(resumed.revision, 1)
            self.assertEqual(resumed.tasks["TASK-001"].status, "RESERVED")


if __name__ == "__main__":
    unittest.main()
