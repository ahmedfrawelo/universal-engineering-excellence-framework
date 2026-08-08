from __future__ import annotations

import unittest

from ueef_spec_workflow.upstream import verify_snapshot


class UpstreamSnapshotTests(unittest.TestCase):
    def test_snapshot_matches_recorded_release_digest(self) -> None:
        result = verify_snapshot()
        self.assertTrue(result["valid"])
        self.assertEqual(result["release"], "v0.16.1")
        self.assertEqual(result["commit"], "ad4104b56c219b0a27bac06547d1a3c7d6a0dbd6")
        self.assertEqual(result["fileCount"], 130)


if __name__ == "__main__":
    unittest.main()
