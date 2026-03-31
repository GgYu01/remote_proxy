from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path

from tests.test_support import BASH_BIN, GIT_BASH, run_bash_script, shell_executable, to_posix_path


class TestSupportTests(unittest.TestCase):
    def test_linux_path_is_preserved_as_posix(self) -> None:
        linux_path = Path("/tmp/proxy-test-script.sh")

        self.assertEqual("/tmp/proxy-test-script.sh", to_posix_path(linux_path))

    def test_shell_executable_matches_platform(self) -> None:
        expected = GIT_BASH if os.name == "nt" else BASH_BIN

        self.assertEqual(expected, shell_executable())

    def test_run_bash_script_does_not_require_executable_bit(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workdir = Path(tmp)
            script_path = workdir / "sample.sh"
            script_path.write_text("#!/bin/sh\necho helper-ok\n", encoding="utf-8")
            script_path.chmod(0o644)

            result = run_bash_script(script_path, cwd=workdir)

            self.assertEqual(0, result.returncode, msg=result.stderr or result.stdout)
            self.assertIn("helper-ok", result.stdout)


if __name__ == "__main__":
    unittest.main()
