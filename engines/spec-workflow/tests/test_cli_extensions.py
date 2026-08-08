from __future__ import annotations

import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path

from ueef_spec_workflow.cli import main
from ueef_spec_workflow.state import ExecutionState, StateStore

from .helpers import graph, task


class CliExtensionTests(unittest.TestCase):
    def test_converge_command_writes_new_graph_and_state(self) -> None:
        subject = graph(task("TASK-001"))
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            graph_path = root / "graph.json"
            state_path = root / "state.json"
            findings_path = root / "findings.json"
            next_graph = root / "next-graph.json"
            next_state = root / "next-state.json"
            graph_path.write_text(json.dumps(subject.to_dict()), encoding="utf-8")
            StateStore(state_path).save(ExecutionState.new(subject))
            findings_path.write_text(
                json.dumps(
                    {
                        "schemaVersion": 1,
                        "tasks": [
                            {
                                "id": "GAP-001",
                                "title": "Verifier gap",
                                "readOnly": True,
                                "sourceEvidence": "finding F-1",
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )
            with contextlib.redirect_stdout(io.StringIO()):
                code = main(
                    [
                        "converge",
                        "--graph", str(graph_path),
                        "--state", str(state_path),
                        "--findings", str(findings_path),
                        "--output-graph", str(next_graph),
                        "--output-state", str(next_state),
                    ]
                )
            self.assertEqual(code, 0)
            self.assertTrue(next_graph.exists())
            self.assertTrue(next_state.exists())

    def test_benchmark_command_uses_recorded_metrics(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            input_path = Path(directory) / "runs.json"
            runs = []
            for mode in ("single-agent", "ueef-static", "dynamic-team"):
                runs.append(
                    {
                        "runId": mode,
                        "mode": mode,
                        "success": True,
                        "makespanMs": 10,
                        "tokens": 20,
                        "retries": 0,
                        "conflicts": 0,
                        "rework": 0,
                    }
                )
            input_path.write_text(
                json.dumps(
                    {"schemaVersion": 1, "scenarioId": "cli", "workloadDigest": "abc", "runs": runs}
                ),
                encoding="utf-8",
            )
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                code = main(["benchmark", "--input", str(input_path)])
            self.assertEqual(code, 0)
            self.assertIn('"source": "recorded-runs"', output.getvalue())

    def test_run_command_persists_host_receipt_and_events(self) -> None:
        subject = graph(task("TASK-001"))
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            graph_path = root / "graph.json"
            state_path = root / "state.json"
            results_path = root / "results.json"
            graph_path.write_text(json.dumps(subject.to_dict()), encoding="utf-8")
            StateStore(state_path).save(ExecutionState.new(subject))
            results_path.write_text(
                json.dumps(
                    {
                        "schemaVersion": 1,
                        "results": [
                            {
                                "taskId": "TASK-001",
                                "worker": "worker-1",
                                "outcome": "complete",
                                "evidence": "test passed",
                                "tokens": 9,
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )
            with contextlib.redirect_stdout(io.StringIO()):
                code = main(
                    [
                        "run",
                        "--graph", str(graph_path),
                        "--state", str(state_path),
                        "--results", str(results_path),
                    ]
                )
            self.assertEqual(code, 0)
            self.assertEqual(StateStore(state_path).load(subject).overall_status, "DONE")
            self.assertTrue(StateStore(state_path).events_path.exists())

    def test_manage_command_matches_and_reserves_declared_worker(self) -> None:
        subject = graph(task("TASK-001", capabilities=["backend"]))
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            graph_path = root / "graph.json"
            state_path = root / "state.json"
            workers_path = root / "workers.json"
            graph_path.write_text(json.dumps(subject.to_dict()), encoding="utf-8")
            StateStore(state_path).save(ExecutionState.new(subject))
            workers_path.write_text(
                json.dumps(
                    {
                        "schemaVersion": 1,
                        "workers": [{"id": "backend-1", "capabilities": ["backend"]}],
                    }
                ),
                encoding="utf-8",
            )
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                code = main(
                    [
                        "manage",
                        "--graph", str(graph_path),
                        "--state", str(state_path),
                        "--workers", str(workers_path),
                        "--commit",
                    ]
                )
            self.assertEqual(code, 0)
            self.assertIn('"worker": "backend-1"', output.getvalue())
            self.assertEqual(
                StateStore(state_path).load(subject).tasks["TASK-001"].assigned_worker,
                "backend-1",
            )


if __name__ == "__main__":
    unittest.main()
