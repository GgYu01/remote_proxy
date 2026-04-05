from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from tests.test_support import REPO_ROOT, run_bash_script, write_executable


class SetupEnvTests(unittest.TestCase):
    def test_setup_env_installs_dependencies_without_full_system_upgrade(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workdir = Path(tmp)
            (workdir / "scripts").mkdir()
            (workdir / "scripts" / "manage_swap.sh").write_text(
                "#!/bin/sh\nexit 0\n",
                encoding="utf-8",
                newline="\n",
            )
            (workdir / "scripts" / "manage_swap.sh").chmod(0o755)

            bin_dir = workdir / "bin"
            bin_dir.mkdir()
            log_file = workdir / "apt.log"
            write_executable(
                bin_dir / "apt-get",
                "#!/bin/sh\n"
                f"printf '%s\\n' \"$*\" >> '{log_file.as_posix()}'\n"
                "exit 0\n",
            )
            write_executable(bin_dir / "podman", "#!/bin/sh\nexit 0\n")
            write_executable(bin_dir / "sudo", "#!/bin/sh\n\"$@\"\n")

            result = run_bash_script(
                REPO_ROOT / "scripts" / "setup_env.sh",
                cwd=workdir,
                env={"TEST_EXTRA_PATH": str(bin_dir)},
            )

            self.assertEqual(0, result.returncode, msg=result.stderr or result.stdout)
            apt_log = log_file.read_text(encoding="utf-8")
            self.assertIn("update -q", apt_log)
            self.assertIn("install -yq curl jq python3 podman", apt_log)
            self.assertNotIn("upgrade -yq", apt_log)


if __name__ == "__main__":
    unittest.main()
