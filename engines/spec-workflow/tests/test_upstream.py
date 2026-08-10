from __future__ import annotations

import sys
import unittest

from ueef_spec_workflow.errors import WorkflowError
from ueef_spec_workflow.upstream import validate_workflow, verify_snapshot


class RetiredUpstreamBridgeTests(unittest.TestCase):
    def test_runtime_reference_bridge_is_fail_closed_and_loads_nothing(self) -> None:
        before = set(sys.modules)
        with self.assertRaisesRegex(WorkflowError, "offline review tool"):
            verify_snapshot()
        with self.assertRaisesRegex(WorkflowError, "offline review tool"):
            validate_workflow("untrusted.yml")
        loaded = set(sys.modules) - before
        self.assertFalse(
            any(name == "specify_cli" or name.startswith("specify_cli.") for name in loaded)
        )


if __name__ == "__main__":
    unittest.main()
