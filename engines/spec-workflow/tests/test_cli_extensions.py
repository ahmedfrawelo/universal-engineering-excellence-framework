from __future__ import annotations

import base64
import contextlib
import io
import json
import tempfile
import unittest
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import cast
from unittest import mock

from ueef_spec_workflow.approvals import ApprovalLedger, ApprovalStore, task_approval_binding
from ueef_spec_workflow.cli import _publish_new_json_pair, build_parser, main
from ueef_spec_workflow.compiler import compile_plan
from ueef_spec_workflow.errors import WorkflowError
from ueef_spec_workflow.model import TaskGraph
from ueef_spec_workflow.package_store import sign_package_metadata
from ueef_spec_workflow.state import ExecutionState, StateStore
from ueef_spec_workflow.template_composition import compose_templates

from .helpers import graph, task
from .test_compiler import TASKS, route


class CliExtensionTests(unittest.TestCase):
    @staticmethod
    def trust_policy(path: Path, *, approval_key: bytes, package_key: bytes) -> None:
        path.write_text(json.dumps({
            "schemaVersion": 1,
            "approvalKeys": [{
                "identity": "user:owner", "keyId": "owner-1",
                "secretBase64": base64.b64encode(approval_key).decode(),
            }],
            "packageSignerKeys": [{
                "signerId": "ueef-publisher", "keyId": "publisher-1",
                "secretBase64": base64.b64encode(package_key).decode(),
            }],
        }), encoding="utf-8")

    def test_cli_trusted_approval_record_signs_and_schedule_verifies(self) -> None:
        subject = graph(task("TASK-001", risk=3))
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            graph_path, state_path = root / "graph.json", root / "state.json"
            approvals_path, trust_path = root / "approvals.json", root / "trust.json"
            graph_path.write_text(json.dumps(subject.to_dict()), encoding="utf-8")
            state = ExecutionState.new(subject)
            StateStore(state_path).save(state)
            binding = task_approval_binding(subject, state, "TASK-001")
            ledger = ApprovalLedger.from_dict({
                "schemaVersion": 2,
                "gates": [{
                    "id": "high-risk-task", **binding,
                    "approvers": [{"identity": "user:owner", "role": "release-manager"}],
                    "threshold": 1, "expiresAt": "2099-01-01T00:00:00Z",
                }],
                "events": [],
            })
            ApprovalStore(approvals_path).save(ledger)
            self.trust_policy(trust_path, approval_key=b"a" * 32, package_key=b"p" * 32)
            common = ["--trust-policy", str(trust_path)]
            unsigned_path = root / "unsigned-approvals.json"
            ApprovalStore(unsigned_path).save(ledger)
            ApprovalStore(unsigned_path).record(
                "high-risk-task", "user:owner", "release-manager", "GRANT",
                "e" * 64, binding, now=datetime.now(UTC),
            )
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(main([
                    "approval-status", "--graph", str(graph_path), "--state", str(state_path),
                    "--approvals", str(unsigned_path), "--task", "TASK-001", *common,
                ]), 1)
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(main([
                    "approval-record", "--graph", str(graph_path), "--state", str(state_path),
                    "--approvals", str(approvals_path), "--task", "TASK-001",
                    "--gate", "high-risk-task", "--identity", "user:owner",
                    "--role", "release-manager", "--action", "GRANT",
                    "--evidence-digest", "e" * 64, *common,
                ]), 0)
                self.assertEqual(main([
                    "schedule", "--graph", str(graph_path), "--state", str(state_path),
                    "--approvals", str(approvals_path), "--require-approval-risk", "3",
                    *common,
                ]), 0)
            persisted = json.loads(approvals_path.read_text(encoding="utf-8"))
            self.assertEqual(persisted["events"][0]["signature"]["keyId"], "owner-1")

    def test_cli_package_commands_are_trusted_by_default_and_verify_attestation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, store = root / "source", root / "store"
            source.mkdir()
            (source / "template.md").write_text("signed", encoding="utf-8")
            trust_path, metadata_path = root / "trust.json", root / "metadata.json"
            package_key = b"p" * 32
            self.trust_policy(trust_path, approval_key=b"a" * 32, package_key=package_key)
            digest = compose_templates({"core": source}).digest
            now = datetime.now(UTC)
            signed = sign_package_metadata({
                "schemaVersion": 1,
                "identity": {"name": "workflow", "version": "1.0.0", "compositionDigest": digest},
                "provenance": {"source": "repository://trusted", "digest": "a" * 64},
                "compatibility": {"engineSchema": 1, "engineVersionRange": ">=0.1.0,<1.0.0"},
                "policy": {"authorityDigest": "0" * 64, "permissions": ["read"]},
            }, signer_id="ueef-publisher", key_id="publisher-1", signing_key=package_key,
                sequence=1, issued_at=now - timedelta(minutes=1),
                expires_at=now + timedelta(hours=1))
            metadata_path.write_text(json.dumps(signed), encoding="utf-8")
            install_output = io.StringIO()
            with contextlib.redirect_stdout(install_output):
                self.assertEqual(main([
                    "package-install", "--store", str(store), "--name", "workflow",
                    "--version", "1.0.0", "--source", str(source),
                    "--metadata", str(metadata_path), "--trust-policy", str(trust_path),
                ]), 0)
            receipt = json.loads(install_output.getvalue())
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(main([
                    "package-activate", "--store", str(store), "--name", "workflow",
                    "--version", "1.0.0", "--digest", receipt["digest"],
                    "--trust-policy", str(trust_path),
                ]), 0)
                self.assertEqual(main([
                    "package-install", "--store", str(root / "missing-policy-store"),
                    "--name", "workflow", "--version", "1.0.0", "--source", str(source),
                ]), 1)

    def test_all_pre_control_plane_public_commands_remain_available(self) -> None:
        legacy = {
            "validate", "compile", "init", "status", "pause", "resume", "prepare",
            "hierarchy", "resolve-customizations", "expand-workflow", "host-status",
            "schedule", "pending-contracts", "transition", "converge", "verify",
            "replan", "migrate", "benchmark", "benchmark-run", "run", "apply-results",
            "manage",
        }
        subparsers = next(
            action for action in build_parser()._actions if hasattr(action, "choices")
            and isinstance(action.choices, dict)
        )
        choices = cast(dict[str, object], subparsers.choices)
        self.assertEqual(legacy - set(choices), set())
        self.assertTrue({"upstream-status", "upstream-validate"}.isdisjoint(choices))

    def test_cli_materializes_and_installs_multi_layer_composition(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            core = root / "core"
            project = root / "project"
            output = root / "materialized"
            store = root / "store"
            core.mkdir()
            project.mkdir()
            (core / "template.md").write_text("core", encoding="utf-8")
            (project / "template.md").write_text("project", encoding="utf-8")
            composed = io.StringIO()
            with contextlib.redirect_stdout(composed):
                self.assertEqual(main([
                    "compose-templates", "--core", str(core), "--project", str(project),
                    "--output", str(output),
                ]), 0)
            digest = json.loads(composed.getvalue())["digest"]
            self.assertEqual(
                (output / "payload" / "template.md").read_text(encoding="utf-8"),
                "project",
            )
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(main([
                    "package-install-composition", "--store", str(store),
                    "--name", "workflow", "--version", "1.0.0",
                    "--core", str(core), "--project", str(project),
                    "--expected-digest", digest,
                    "--legacy-unsigned",
                ]), 0)
                self.assertEqual(main([
                    "package-activate", "--store", str(store), "--name", "workflow",
                    "--version", "1.0.0", "--digest", digest,
                    "--legacy-unsigned",
                ]), 0)

    def test_control_status_distinguishes_waiting_approval_from_unavailable_host(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for risk, expected in ((3, "WAITING_APPROVAL"), (1, "UNAVAILABLE")):
                with self.subTest(risk=risk):
                    subject = graph(task("TASK-001", risk=risk))
                    graph_path = root / f"graph-{risk}.json"
                    state_path = root / f"state-{risk}.json"
                    graph_path.write_text(json.dumps(subject.to_dict()), encoding="utf-8")
                    StateStore(state_path).save(ExecutionState.new(subject))
                    output = io.StringIO()
                    with contextlib.redirect_stdout(output):
                        code = main([
                            "control-status", "--graph", str(graph_path),
                            "--state", str(state_path),
                        ])
                    self.assertEqual(code, 0)
                    self.assertEqual(json.loads(output.getvalue())["status"], expected)

    def test_high_risk_schedule_requires_approved_gate_before_reservation(self) -> None:
        subject = graph(task("TASK-001", risk=3))
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            graph_path = root / "graph.json"
            state_path = root / "state.json"
            approvals_path = root / "approvals.json"
            graph_path.write_text(json.dumps(subject.to_dict()), encoding="utf-8")
            state = ExecutionState.new(subject)
            StateStore(state_path).save(state)
            command = [
                "schedule", "--graph", str(graph_path), "--state", str(state_path),
                "--require-approval-risk", "3",
            ]
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(main(command), 1)
            unchanged = StateStore(state_path).load(subject)
            self.assertEqual(unchanged.revision, state.revision)
            self.assertEqual(unchanged.tasks["TASK-001"].status, "READY")

            binding = task_approval_binding(subject, state, "TASK-001")
            ledger = ApprovalLedger.from_dict(
                {
                    "schemaVersion": 2,
                    "gates": [{
                        "id": "high-risk-task", **binding,
                        "approvers": [{"identity": "user:owner", "role": "release-manager"}],
                        "threshold": 1,
                        "expiresAt": "2099-01-01T00:00:00Z",
                    }],
                    "events": [],
                }
            )
            ApprovalStore(approvals_path).save(ledger)
            ApprovalStore(approvals_path).record(
                "high-risk-task", "user:owner", "release-manager", "GRANT",
                "e" * 64, binding, now=datetime.now(UTC),
            )
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(main([
                    *command, "--approvals", str(approvals_path), "--legacy-unsigned",
                ]), 0)
            self.assertEqual(
                StateStore(state_path).load(subject).tasks["TASK-001"].status,
                "RESERVED",
            )

    def test_pause_and_resume_commands_persist_operator_state(self) -> None:
        subject = graph(task("TASK-001"))
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            graph_path = root / "graph.json"
            state_path = root / "state.json"
            graph_path.write_text(json.dumps(subject.to_dict()), encoding="utf-8")
            StateStore(state_path).save(ExecutionState.new(subject))
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(
                    main([
                        "pause", "--graph", str(graph_path), "--state", str(state_path),
                        "--reason", "operator maintenance",
                    ]),
                    0,
                )
            self.assertEqual(StateStore(state_path).load(subject).overall_status, "PAUSED")
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(
                    main(["resume", "--graph", str(graph_path), "--state", str(state_path)]),
                    0,
                )
            self.assertEqual(StateStore(state_path).load(subject).overall_status, "READY")

    def test_verify_command_binds_report_and_unlocks_v2_done(self) -> None:
        subject = TaskGraph.from_dict(compile_plan(TASKS, "demo-flow", route()))
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            graph_path = root / "graph.json"
            state_path = root / "state.json"
            report_path = root / "verification.json"
            graph_path.write_text(json.dumps(subject.to_dict()), encoding="utf-8")
            state = ExecutionState.new(subject)
            for task_id in ("TASK-001", "TASK-002"):
                state.reserve_wave([(task_id, f"worker-{task_id[-1]}")], 1)
                state.transition(subject, task_id, "start", worker=f"worker-{task_id[-1]}")
                state.transition(subject, task_id, "complete", evidence="done")
            StateStore(state_path).save(state)
            report_path.write_text(
                json.dumps(
                    {
                        "schemaVersion": 2,
                        "workflowId": subject.workflow_id,
                        "executionId": state.execution_id,
                        "graphDigest": subject.digest,
                        "passed": True,
                        "independent": True,
                        "evidence": "fresh review passed",
                        "diffDigest": "a" * 64,
                        "changedPaths": ["src/one"],
                    }
                ),
                encoding="utf-8",
            )
            with contextlib.redirect_stdout(io.StringIO()):
                code = main(
                    [
                        "verify",
                        "--graph",
                        str(graph_path),
                        "--state",
                        str(state_path),
                        "--report",
                        str(report_path),
                    ]
                )
            self.assertEqual(code, 0)
            self.assertEqual(StateStore(state_path).load(subject).overall_status, "DONE")

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
                        "--graph",
                        str(graph_path),
                        "--state",
                        str(state_path),
                        "--findings",
                        str(findings_path),
                        "--output-graph",
                        str(next_graph),
                        "--output-state",
                        str(next_state),
                    ]
                )
            self.assertEqual(code, 0)
            self.assertTrue(next_graph.exists())
            self.assertTrue(next_state.exists())

    def test_force_init_requires_matching_persisted_identity_and_revision(self) -> None:
        subject = graph(task("TASK-001"))
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            graph_path = root / "graph.json"
            state_path = root / "state.json"
            graph_path.write_text(json.dumps(subject.to_dict()), encoding="utf-8")
            current = ExecutionState.new(subject)
            StateStore(state_path).save(current)
            for extra in (
                [],
                ["--current-execution-id", "wrong", "--current-revision", "0"],
                [
                    "--current-execution-id",
                    current.execution_id,
                    "--current-revision",
                    "1",
                ],
            ):
                with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(
                    io.StringIO()
                ):
                    code = main(
                        [
                            "init",
                            "--graph",
                            str(graph_path),
                            "--state",
                            str(state_path),
                            "--force",
                            *extra,
                        ]
                    )
                self.assertEqual(code, 1)
            with contextlib.redirect_stdout(io.StringIO()):
                code = main(
                    [
                        "init",
                        "--graph",
                        str(graph_path),
                        "--state",
                        str(state_path),
                        "--force",
                        "--current-execution-id",
                        current.execution_id,
                        "--current-revision",
                        "0",
                    ]
                )
            self.assertEqual(code, 0)
            self.assertNotEqual(
                StateStore(state_path).load(subject).execution_id, current.execution_id
            )

    def test_convergence_pair_rejects_alias_and_rolls_back_second_promotion_failure(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            same = root / "same.json"
            with self.assertRaisesRegex(WorkflowError, "different paths"):
                _publish_new_json_pair(same, {"graph": 1}, root / "." / "same.json", {"state": 1})
            graph_path = root / "next-graph.json"
            state_path = root / "next-state.json"
            import os

            real_replace = os.replace
            calls = 0

            def fail_second(source: str | Path, target: str | Path) -> None:
                nonlocal calls
                calls += 1
                if calls == 2:
                    raise OSError("injected second promotion failure")
                real_replace(source, target)

            with mock.patch("os.replace", side_effect=fail_second):
                with self.assertRaisesRegex(WorkflowError, "rolled back"):
                    _publish_new_json_pair(
                        graph_path, {"graph": 1}, state_path, {"state": 1}
                    )
            self.assertFalse(graph_path.exists())
            self.assertFalse(state_path.exists())

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

    def test_apply_results_command_persists_fenced_host_receipt_and_events(self) -> None:
        subject = graph(task("TASK-001"))
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            graph_path = root / "graph.json"
            state_path = root / "state.json"
            results_path = root / "results.json"
            graph_path.write_text(json.dumps(subject.to_dict()), encoding="utf-8")
            StateStore(state_path).save(ExecutionState.new(subject))
            schedule_output = io.StringIO()
            with contextlib.redirect_stdout(schedule_output):
                self.assertEqual(
                    main(["schedule", "--graph", str(graph_path), "--state", str(state_path)]), 0
                )
            contract = json.loads(schedule_output.getvalue())["dispatchContracts"][0]
            result = {
                key: contract[key]
                for key in (
                    "taskId",
                    "worker",
                    "workflowId",
                    "executionId",
                    "graphDigest",
                    "routeDigest",
                    "executionSpecDigest",
                    "attemptId",
                    "leaseGeneration",
                    "fencingToken",
                )
            }
            result.update(
                {
                    "outcome": "complete",
                    "evidence": '{"AC-001":"test passed"}',
                    "tokens": 9,
                }
            )
            results_path.write_text(
                json.dumps({"schemaVersion": 2, "results": [result]}), encoding="utf-8"
            )
            with contextlib.redirect_stdout(io.StringIO()):
                code = main(
                    [
                        "apply-results",
                        "--graph",
                        str(graph_path),
                        "--state",
                        str(state_path),
                        "--results",
                        str(results_path),
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
                        "--graph",
                        str(graph_path),
                        "--state",
                        str(state_path),
                        "--workers",
                        str(workers_path),
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
