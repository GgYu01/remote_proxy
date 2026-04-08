from __future__ import annotations

import subprocess
import unittest

from tests.test_support import REPO_ROOT

SHELL_SCRIPTS = [
    "install.sh",
    "scripts/service.sh",
    "scripts/setup_env.sh",
    "scripts/manage_swap.sh",
    "scripts/deploy.sh",
    "scripts/verify.sh",
    "scripts/lib/common.sh",
    "scripts/services/cliproxy_plus/install.sh",
    "scripts/services/cliproxy_plus/deploy.sh",
    "scripts/services/cliproxy_plus/usage_backup.sh",
    "scripts/services/cliproxy_plus/usage_restore.sh",
    "scripts/services/cliproxy_plus/verify.sh",
    "scripts/services/cliproxy_plus/switch_version.sh",
]


class GitIndexModesTests(unittest.TestCase):
    def test_release_shell_scripts_are_marked_executable_in_git_index(self) -> None:
        result = subprocess.run(
            ["git", "ls-files", "--stage", "--", *SHELL_SCRIPTS],
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

        self.assertEqual(sorted(SHELL_SCRIPTS), sorted(parsed))
        offenders = [path for path, mode in parsed.items() if mode != "100755"]
        self.assertEqual([], offenders)


if __name__ == "__main__":
    unittest.main()
