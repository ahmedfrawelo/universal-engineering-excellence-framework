from __future__ import annotations

import unittest

from ueef_spec_workflow.benchmark import compare_runs
from ueef_spec_workflow.errors import WorkflowError


def run(mode: str, success: bool = True, makespan: int = 100) -> dict:
    return {
        "runId": mode,
        "mode": mode,
        "success": success,
        "makespanMs": makespan,
        "tokens": 1000,
        "retries": 0,
        "conflicts": 0,
        "rework": 0,
    }


class BenchmarkTests(unittest.TestCase):
    def test_three_mode_recorded_comparison(self) -> None:
        result = compare_runs(
            {
                "schemaVersion": 1,
                "scenarioId": "benchmark-test",
                "workloadDigest": "digest-1",
                "runs": [
                    run("single-agent", makespan=300),
                    run("ueef-static", makespan=200),
                    run("dynamic-team", makespan=100),
                ],
            }
        )
        self.assertEqual(result["source"], "recorded-runs")
        self.assertEqual(result["summary"]["dynamic-team"]["makespanMs"], 100)
        self.assertEqual(result["summary"]["single-agent"]["successRate"], 1.0)

    def test_missing_mode_is_rejected(self) -> None:
        with self.assertRaisesRegex(WorkflowError, "missing modes"):
            compare_runs(
                {
                    "schemaVersion": 1,
                    "scenarioId": "benchmark-test",
                    "workloadDigest": "digest-1",
                    "runs": [run("single-agent")],
                }
            )


if __name__ == "__main__":
    unittest.main()
