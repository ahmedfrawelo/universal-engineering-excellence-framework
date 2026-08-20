from __future__ import annotations

import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from ueef_spec_workflow.compiler import compile_plan, write_compiled_graph
from ueef_spec_workflow.errors import WorkflowError
from ueef_spec_workflow.model import TaskGraph

TASKS = """# Tasks: Demo

Status: READY

## Ordered work

- [ ] TASK-001 First task
  - Requirements: REQ-001
  - Acceptance: AC-001
  - Delegation: lead
  - Allowed write set: src/one
  - Forbidden paths: secrets
  - Depends on: none
  - Capabilities: python
  - Effort points: 2
  - Risk: 1
  - Priority: 3
  - Parallel safe: true
  - Read only: false
  - Evidence: {"AC-001":"unit test"}
  - Done when: test passes
- [ ] TASK-002 Verify
  - Requirements: REQ-002
  - Acceptance: AC-002
  - Delegation: verifier
  - Allowed write set: none
  - Forbidden paths: secrets
  - Depends on: TASK-001
  - Capabilities: verification
  - Effort points: 1
  - Risk: 0
  - Priority: 0
  - Parallel safe: false
  - Read only: true
  - Evidence: {"AC-002":"report"}
  - Done when: report passes
"""


def route(max_workers: int = 4) -> dict[str, object]:
    execution_spec: dict[str, object] = {
        "schemaVersion": 1,
        "tier": "T4",
        "workUnitId": "demo-flow",
        "promptSha256": "c" * 64,
        "outcome": "compile the demo workflow",
        "acceptanceCriteria": "tests pass",
        "ownerPaths": "tests",
        "nonGoals": "no production mutation",
        "tokenEconomy": {"budgetMode": "expanded", "maxWorkerCount": max_workers},
        "requiredEvidence": ["tests"],
        "createdAtUtc": "2026-08-11T00:00:00.000Z",
    }
    execution_spec["digest"] = hashlib.sha256(
        json.dumps(execution_spec, separators=(",", ":")).encode()
    ).hexdigest()
    result: dict[str, object] = {
        "schemaVersion": 3,
        "tier": "T4",
        "workUnitId": "demo-flow",
        "invocationIndex": 0,
        "preferredModel": "gpt-test",
        "hostReasoning": "medium",
        "fallbackModel": None,
        "fallbackHostReasoning": None,
        "tokenEconomy": {
            "budgetMode": "expanded",
            "maxWorkerCount": max_workers,
        },
        "decision": {
            "mode": "IMPLEMENTATION",
            "spec": "FULL_REQUIRED",
            "specReason": "FULL_SPEC_REQUIRED_BY_SCOPE_OR_RISK",
            "team": "SPAWN",
            "teamReason": "USER_AUTHORIZED",
            "delegationAuthorized": True,
            "delegationAuthorizationSource": "USER",
            "delegationScope": "WORKERS",
        },
        "catalogDigest": "d" * 64,
        "catalogProvider": "test-catalog",
        "catalogDiscoveredAt": "2026-08-11T00:00:00.000Z",
        "executionSpec": execution_spec,
    }
    identity = {
        key: result[key]
        for key in (
            "tier", "workUnitId", "invocationIndex", "preferredModel",
            "hostReasoning", "fallbackModel", "fallbackHostReasoning",
            "tokenEconomy", "decision", "catalogDigest", "catalogProvider",
            "catalogDiscoveredAt",
        )
    }
    result["routeDigest"] = hashlib.sha256(
        json.dumps(identity, separators=(",", ":")).encode()
    ).hexdigest()
    return result


class CompilerTests(unittest.TestCase):
    def test_compile_is_deterministic_and_bound_to_route(self) -> None:
        first = compile_plan(TASKS, "demo-flow", route())
        second = compile_plan(TASKS, "demo-flow", route())
        self.assertEqual(first, second)
        self.assertEqual(first["schemaVersion"], 2)
        self.assertEqual(first["policy"]["maxWorkers"], 4)
        self.assertEqual(first["policy"]["tokenBudgetMode"], "expanded")
        self.assertEqual(first["routeBinding"]["routeDigest"], route()["routeDigest"])
        self.assertEqual(first["tasks"][1]["dependsOn"], ["TASK-001"])
        self.assertTrue(first["tasks"][1]["readOnly"])
        self.assertEqual(TaskGraph.from_dict(first).schema_version, 2)

    def test_requested_worker_cap_cannot_widen_route(self) -> None:
        with self.assertRaisesRegex(WorkflowError, "cannot exceed route maximum"):
            compile_plan(TASKS, "demo-flow", route(3), requested_max_workers=4)

    def test_route_and_execution_spec_tampering_are_rejected(self) -> None:
        tampered_route = route()
        tampered_route["preferredModel"] = "attacker-model"
        with self.assertRaisesRegex(WorkflowError, "canonical identity"):
            compile_plan(TASKS, "demo-flow", tampered_route)

        tampered_spec = route()
        assert isinstance(tampered_spec["executionSpec"], dict)
        tampered_spec["executionSpec"]["outcome"] = "different outcome"
        with self.assertRaisesRegex(WorkflowError, "canonical content"):
            compile_plan(TASKS, "demo-flow", tampered_spec)

    def test_evidence_is_structured_and_bound_to_every_acceptance_criterion(self) -> None:
        invalid = TASKS.replace(
            '{"AC-001":"unit test"}', '{"AC-999":"unit test"}', 1
        )
        with self.assertRaisesRegex(WorkflowError, "acceptance binding mismatch"):
            compile_plan(invalid, "demo-flow", route())
        generic = TASKS.replace('{"AC-001":"unit test"}', "unit test", 1)
        with self.assertRaisesRegex(WorkflowError, "JSON object"):
            compile_plan(generic, "demo-flow", route())

    def test_check_detects_generated_graph_drift(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "task-graph.json"
            graph = compile_plan(TASKS, "demo-flow", route())
            self.assertTrue(write_compiled_graph(output, graph))
            self.assertFalse(write_compiled_graph(output, graph, check=True))
            changed = json.loads(output.read_text(encoding="utf-8"))
            changed["tasks"][0]["title"] = "manual edit"
            output.write_text(json.dumps(changed), encoding="utf-8")
            with self.assertRaisesRegex(WorkflowError, "drift"):
                write_compiled_graph(output, graph, check=True)


if __name__ == "__main__":
    unittest.main()
