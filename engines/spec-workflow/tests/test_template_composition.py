from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

from ueef_spec_workflow.errors import WorkflowError
from ueef_spec_workflow.template_composition import (
    compose_templates,
    materialize_composition,
    validate_template_path,
)


class TemplateCompositionTests(unittest.TestCase):
    def test_composes_content_deterministically_with_declared_precedence(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            layers = {name: root / name for name in ("core", "extension", "preset", "project")}
            for path in layers.values():
                path.mkdir()
            (layers["core"] / "shared.md").write_text("core", encoding="utf-8")
            (layers["extension"] / "shared.md").write_text("extension", encoding="utf-8")
            (layers["preset"] / "shared.md").write_text("preset", encoding="utf-8")
            (layers["project"] / "shared.md").write_text("project", encoding="utf-8")
            (layers["core"] / "only-core.md").write_text("kept", encoding="utf-8")

            first = compose_templates(layers)
            second = compose_templates(dict(reversed(list(layers.items()))))

            self.assertEqual(first.digest, second.digest)
            self.assertEqual(first.files["shared.md"], b"project")
            self.assertEqual(first.files["only-core.md"], b"kept")
            self.assertEqual(
                first.manifest["precedence"], ["project", "preset", "extension", "core"]
            )
            with self.assertRaises(TypeError):
                first.files["other.md"] = b"change"  # type: ignore[index]

    def test_rejects_executable_content_and_symlinks(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "run.py").write_text("print('no')", encoding="utf-8")
            with self.assertRaisesRegex(WorkflowError, "executable"):
                compose_templates({"core": root})
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / "target.md"
            target.write_text("target", encoding="utf-8")
            link = root / "link.md"
            try:
                link.symlink_to(target)
            except OSError:
                if os.name != "nt":
                    raise
                target_dir = root / "target-dir"
                target_dir.mkdir()
                (target_dir / "target.md").write_text("target", encoding="utf-8")
                link = root / "link-dir"
                created = subprocess.run(
                    ["cmd", "/d", "/c", "mklink", "/J", str(link), str(target_dir)],
                    capture_output=True,
                    check=False,
                    text=True,
                )
                self.assertEqual(created.returncode, 0, created.stderr or created.stdout)
            with self.assertRaisesRegex(WorkflowError, "symlink"):
                compose_templates({"core": root})

    def test_enforces_resource_boundaries_and_rejects_unsafe_paths(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "one.md").write_bytes(b"1234")
            (root / "two.md").write_bytes(b"56")
            composition = compose_templates(
                {"core": root}, max_files=2, max_file_bytes=4, max_total_bytes=6
            )
            self.assertEqual(len(composition.files), 2)
            with self.assertRaisesRegex(WorkflowError, "file limit"):
                compose_templates({"core": root}, max_files=1)
            with self.assertRaisesRegex(WorkflowError, "byte limit"):
                compose_templates({"core": root}, max_file_bytes=3)
            with self.assertRaisesRegex(WorkflowError, "byte limit"):
                compose_templates({"core": root}, max_total_bytes=5)
        for unsafe in ("../escape.md", "/absolute.md", "C:/absolute.md", "a/../../escape.md"):
            with self.subTest(path=unsafe), self.assertRaisesRegex(WorkflowError, "unsafe"):
                validate_template_path(unsafe)

    def test_materializes_multi_layer_composition_atomically(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            core = root / "core"
            project = root / "project"
            core.mkdir()
            project.mkdir()
            (core / "template.md").write_text("core", encoding="utf-8")
            (project / "template.md").write_text("project", encoding="utf-8")
            composition = compose_templates({"core": core, "project": project})
            destination = materialize_composition(composition, root / "output")
            self.assertEqual((destination / "payload" / "template.md").read_text(), "project")
            with self.assertRaisesRegex(WorkflowError, "already exists"):
                materialize_composition(composition, destination)


if __name__ == "__main__":
    unittest.main()
