"""Run ratcheted repository-engine quality checks without hiding legacy debt."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys


BASELINES = {
    "pyright": {"errors": 351, "warnings": 4},
    "bandit": {"HIGH": 3, "MEDIUM": 5, "LOW": 97},
}


def run_json(command: list[str], *, allowed_exit_codes: set[int]) -> dict:
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode not in allowed_exit_codes:
        raise SystemExit(
            f"Quality tool failed with exit code {result.returncode}: {' '.join(command)}\n{result.stderr}"
        )
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Quality tool did not emit JSON: {' '.join(command)}\n{result.stderr}") from exc
    if not isinstance(payload, dict):
        raise SystemExit(f"Quality tool emitted a non-object payload: {' '.join(command)}")
    return payload


def check_pyright() -> None:
    payload = run_json(
        [sys.executable, "-m", "pyright", "graphify", "--outputjson"],
        allowed_exit_codes={0, 1},
    )
    summary = payload.get("summary", {})
    if not isinstance(summary, dict) or not all(
        isinstance(summary.get(key), int) and summary[key] >= 0
        for key in ("errorCount", "warningCount")
    ):
        raise SystemExit("Pyright JSON is missing non-negative errorCount/warningCount values")
    actual = {"errors": summary["errorCount"], "warnings": summary["warningCount"]}
    exceeded = {name: (actual[name], limit) for name, limit in BASELINES["pyright"].items() if actual[name] > limit}
    print(json.dumps({"tool": "pyright", "status": "FAIL" if exceeded else "PASS", "actual": actual, "baseline": BASELINES["pyright"]}))
    if exceeded:
        raise SystemExit(f"Pyright debt increased: {exceeded}")


def check_bandit() -> None:
    payload = run_json(
        [sys.executable, "-m", "bandit", "-q", "-r", "graphify", "-f", "json"],
        allowed_exit_codes={0, 1},
    )
    if not isinstance(payload.get("results"), list) or not isinstance(payload.get("metrics"), dict):
        raise SystemExit("Bandit JSON is missing results or metrics")
    actual = {severity: 0 for severity in BASELINES["bandit"]}
    for finding in payload.get("results", []):
        severity = str(finding.get("issue_severity", "")).upper()
        if severity in actual:
            actual[severity] += 1
    exceeded = {name: (actual[name], limit) for name, limit in BASELINES["bandit"].items() if actual[name] > limit}
    print(json.dumps({"tool": "bandit", "status": "FAIL" if exceeded else "PASS", "actual": actual, "baseline": BASELINES["bandit"]}))
    if exceeded:
        raise SystemExit(f"Bandit debt increased: {exceeded}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("tool", choices=("pyright", "bandit"))
    args = parser.parse_args()
    {"pyright": check_pyright, "bandit": check_bandit}[args.tool]()


if __name__ == "__main__":
    main()
