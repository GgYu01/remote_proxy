from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path

from tests.test_support import REPO_ROOT, run_bash_script, write_executable


class DeployScriptTests(unittest.TestCase):
    def test_fallback_service_uses_pinned_image_and_optional_compat_flags(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workdir = Path(tmp)
            (workdir / "config.env").write_text(
                "\n".join(
                    [
                        "BASE_PORT=10000",
                        "MEMORY_LIMIT=8M",
                        "SING_BOX_IMAGE=ghcr.io/sagernet/sing-box:v1.13.2",
                        "ENABLE_DEPRECATED_SING_BOX_FLAGS=true",
                    ]
                )
                + "\n",
                encoding="utf-8",
                newline="\n",
            )
            (workdir / "singbox.json").write_text("{}", encoding="utf-8")

            home_dir = workdir / "home"
            home_dir.mkdir()

            bin_dir = workdir / "bin"
            bin_dir.mkdir()
            write_executable(bin_dir / "podman", "#!/bin/sh\nexit 0\n")
            write_executable(bin_dir / "journalctl", "#!/bin/sh\nexit 0\n")
            write_executable(bin_dir / "sleep", "#!/bin/sh\nexit 0\n")
            write_executable(
                bin_dir / "systemctl",
                "#!/bin/sh\n"
                "if [ \"$1\" = \"--user\" ]; then\n"
                "  shift\n"
                "fi\n"
                "case \"$1\" in\n"
                "  daemon-reload) exit 0 ;;\n"
                "  list-unit-files) exit 0 ;;\n"
                "  enable) exit 0 ;;\n"
                "  status) exit 0 ;;\n"
                "esac\n"
                "exit 0\n",
            )

            result = run_bash_script(
                REPO_ROOT / "scripts" / "deploy.sh",
                cwd=workdir,
                env={"HOME": str(home_dir), "TEST_EXTRA_PATH": str(bin_dir)},
            )

            self.assertEqual(0, result.returncode, msg=result.stderr or result.stdout)
            service_file = home_dir / ".config" / "systemd" / "user" / "remote-proxy.service"
            self.assertTrue(service_file.exists(), msg=result.stdout)
            service_text = service_file.read_text(encoding="utf-8")
            self.assertIn("ghcr.io/sagernet/sing-box:v1.13.2", service_text)
            self.assertIn("--memory 64M", service_text)
            self.assertIn("ENABLE_DEPRECATED_LEGACY_DNS_SERVERS=true", service_text)


if __name__ == "__main__":
    unittest.main()
