from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from tests.test_support import REPO_ROOT, run_bash_script, write_executable


class ServiceEntrypointTests(unittest.TestCase):
    def test_cliproxy_plus_update_exports_usage_before_redeploy(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workdir = Path(tmp)
            (workdir / "config").mkdir()
            (workdir / "state" / "cliproxy-plus" / "usage").mkdir(parents=True)
            (workdir / "config" / "cliproxy-plus.env").write_text(
                "\n".join(
                    [
                        "CLIPROXY_IMAGE=eceasy/cli-proxy-api-plus:v6.9.15-0",
                        "CLIPROXY_PORT=8317",
                        "CLIPROXY_MANAGEMENT_KEY=test-management-key",
                    ]
                )
                + "\n",
                encoding="utf-8",
                newline="\n",
            )

            bin_dir = workdir / "bin"
            bin_dir.mkdir()
            write_executable(
                bin_dir / "curl",
                "#!/bin/sh\n"
                "printf '[curl] %s\\n' \"$*\" >> dispatch.log\n"
                "case \"$*\" in\n"
                "  *usage/export*) echo '{\"version\":1,\"usage\":{\"total_requests\":1}}' ;;\n"
                "  *usage/import*) echo '{\"added\":1,\"skipped\":0}' ;;\n"
                "  *) echo '{\"ok\":true}' ;;\n"
                "esac\n",
            )
            write_executable(bin_dir / "podman", "#!/bin/sh\nprintf '[podman] %s\\n' \"$*\" >> dispatch.log\nexit 0\n")
            write_executable(bin_dir / "journalctl", "#!/bin/sh\nexit 0\n")
            write_executable(bin_dir / "sleep", "#!/bin/sh\nexit 0\n")
            write_executable(
                bin_dir / "systemctl",
                "#!/bin/sh\n"
                "if [ \"$1\" = \"--user\" ]; then\n"
                "  shift\n"
                "fi\n"
                "printf '[systemctl] %s\\n' \"$*\" >> dispatch.log\n"
                "case \"$1\" in\n"
                "  daemon-reload) exit 0 ;;\n"
                "  list-unit-files) exit 0 ;;\n"
                "  enable) exit 0 ;;\n"
                "  status) exit 0 ;;\n"
                "esac\n"
                "exit 0\n",
            )

            result = run_bash_script(
                REPO_ROOT / "scripts" / "service.sh",
                cwd=workdir,
                env={"TEST_EXTRA_PATH": str(bin_dir), "HOME": str(workdir / "home")},
            )

            self.assertNotEqual(0, result.returncode, msg="service.sh should require explicit service and command")

            result = run_bash_script(
                REPO_ROOT / "scripts" / "service.sh",
                cwd=workdir,
                env={"TEST_EXTRA_PATH": str(bin_dir), "HOME": str(workdir / "home")},
            )
            self.assertNotEqual(0, result.returncode)

            result = run_bash_script(
                REPO_ROOT / "scripts" / "service.sh",
                cwd=workdir,
                env={
                    "TEST_EXTRA_PATH": str(bin_dir),
                    "HOME": str(workdir / "home"),
                    "REMOTE_PROXY_SERVICE": "cliproxy-plus",
                    "REMOTE_PROXY_COMMAND": "update",
                },
            )

            self.assertEqual(0, result.returncode, msg=result.stderr or result.stdout)
            dispatch_log = (workdir / "dispatch.log").read_text(encoding="utf-8")
            self.assertIn("usage/export", dispatch_log)
            self.assertIn("podman", dispatch_log)
            self.assertIn("usage/import", dispatch_log)


if __name__ == "__main__":
    unittest.main()
