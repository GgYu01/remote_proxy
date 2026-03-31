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
                "  show) exit 1 ;;\n"
                "  enable) exit 0 ;;\n"
                "  restart) exit 0 ;;\n"
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

    def test_quadlet_mode_removes_stale_fallback_unit_before_restart(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workdir = Path(tmp)
            (workdir / "config.env").write_text(
                "\n".join(
                    [
                        "BASE_PORT=10000",
                        "MEMORY_LIMIT=256M",
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
            stale_unit = home_dir / ".config" / "systemd" / "user" / "remote-proxy.service"
            stale_unit.parent.mkdir(parents=True)
            stale_unit.write_text("[Unit]\nDescription=stale fallback\n", encoding="utf-8")

            bin_dir = workdir / "bin"
            bin_dir.mkdir()
            systemctl_log = workdir / "systemctl.log"
            generator_bin = workdir / "podman-system-generator"
            write_executable(bin_dir / "podman", "#!/bin/sh\nexit 0\n")
            write_executable(bin_dir / "journalctl", "#!/bin/sh\nexit 0\n")
            write_executable(bin_dir / "sleep", "#!/bin/sh\nexit 0\n")
            write_executable(
                generator_bin,
                "#!/bin/sh\n"
                "cat <<'EOF'\n"
                "quadlet-generator[1]: Loading source unit file /tmp/remote-proxy.container\n"
                "---remote-proxy.service---\n"
                "[Install]\n"
                "WantedBy=default.target\n"
                "EOF\n",
            )
            write_executable(
                bin_dir / "systemctl",
                "#!/bin/sh\n"
                "if [ \"$1\" = \"--user\" ]; then\n"
                "  shift\n"
                "fi\n"
                f"echo \"$@\" >> '{systemctl_log.as_posix()}'\n"
                "case \"$1\" in\n"
                "  daemon-reload) exit 0 ;;\n"
                "  show)\n"
                "    if printf '%s' \"$@\" | grep -q 'FragmentPath'; then\n"
                f"      if [ -f '{stale_unit.as_posix()}' ]; then\n"
                f"        printf '{stale_unit.as_posix()}\\n'\n"
                "      else\n"
                "        printf '/run/user/1000/systemd/generator/remote-proxy.service\\n'\n"
                "      fi\n"
                "      exit 0\n"
                "    fi\n"
                "    exit 0\n"
                "    ;;\n"
                "  restart) exit 0 ;;\n"
                "  status) exit 0 ;;\n"
                "esac\n"
                "exit 0\n",
            )

            result = run_bash_script(
                REPO_ROOT / "scripts" / "deploy.sh",
                cwd=workdir,
                env={
                    "HOME": str(home_dir),
                    "TEST_EXTRA_PATH": str(bin_dir),
                    "PODMAN_SYSTEM_GENERATOR_BIN": str(generator_bin),
                },
            )

            self.assertEqual(0, result.returncode, msg=result.stderr or result.stdout)
            self.assertFalse(stale_unit.exists(), msg=result.stdout)
            systemctl_calls = systemctl_log.read_text(encoding="utf-8")
            self.assertIn("restart remote-proxy", systemctl_calls)
            self.assertNotIn("enable remote-proxy", systemctl_calls)
            quadlet_text = (home_dir / ".config" / "containers" / "systemd" / "remote-proxy.container").read_text(
                encoding="utf-8"
            )
            self.assertIn("PodmanArgs=--memory 256M", quadlet_text)
            self.assertIn("[Install]", quadlet_text)
            self.assertIn("WantedBy=default.target", quadlet_text)


if __name__ == "__main__":
    unittest.main()
