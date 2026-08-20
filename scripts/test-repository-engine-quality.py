from __future__ import annotations

import importlib.util
from pathlib import Path
from unittest import mock


module_path = Path(__file__).with_name("check-repository-engine-quality.py")
spec = importlib.util.spec_from_file_location("repository_quality", module_path)
assert spec and spec.loader
quality = importlib.util.module_from_spec(spec)
spec.loader.exec_module(quality)


def rejects(action) -> None:
    try:
        action()
    except SystemExit:
        return
    raise AssertionError("quality ratchet accepted malformed tool output")


with mock.patch.object(quality, "run_json", return_value={}):
    rejects(quality.check_pyright)
    rejects(quality.check_bandit)

with mock.patch.object(
    quality.subprocess,
    "run",
    return_value=quality.subprocess.CompletedProcess([], 7, stdout="{}", stderr="tool crashed"),
):
    rejects(lambda: quality.run_json(["tool"], allowed_exit_codes={0, 1}))

print("Repository engine quality ratchet tests passed")
