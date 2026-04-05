from __future__ import annotations

import unittest
from pathlib import Path

from tests.test_support import REPO_ROOT


class LineEndingTests(unittest.TestCase):
    def test_shell_scripts_use_lf_line_endings(self) -> None:
        offenders: list[str] = []
        for path in REPO_ROOT.rglob("*.sh"):
            if ".git" in path.parts:
                continue
            if b"\r\n" in path.read_bytes():
                offenders.append(str(path.relative_to(REPO_ROOT)))
        self.assertEqual([], offenders)


if __name__ == "__main__":
    unittest.main()
