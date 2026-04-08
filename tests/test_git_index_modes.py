from __future__ import annotations

import subprocess
import unittest

from tests.test_support import REPO_ROOT


def git_tracked_shell_scripts() -> list[str]:
    result = subprocess.run(
        ["git", "ls-files", "--", "*.sh"],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return [line for line in result.stdout.splitlines() if line]


class GitIndexModesTests(unittest.TestCase):
    def test_release_shell_scripts_are_marked_executable_in_git_index(self) -> None:
        tracked_shell_scripts = git_tracked_shell_scripts()
        self.assertNotEqual([], tracked_shell_scripts)

        result = subprocess.run(
            ["git", "ls-files", "--stage", "--", *tracked_shell_scripts],
            cwd=REPO_ROOT,
            check=True,
            capture_output=True,
            text=True,
        )
        parsed: dict[str, str] = {}
        for line in result.stdout.splitlines():
            mode, _object_id, _stage_and_path = line.split(" ", 2)
            _stage, path = _stage_and_path.split("\t", 1)
            parsed[path] = mode

        self.assertEqual(sorted(tracked_shell_scripts), sorted(parsed))
        offenders = [path for path, mode in parsed.items() if mode != "100755"]
        self.assertEqual([], offenders)


if __name__ == "__main__":
    unittest.main()
