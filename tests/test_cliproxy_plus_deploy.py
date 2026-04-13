from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

from tests.test_support import REPO_ROOT, run_bash_script, write_executable, write_text_file


class CLIProxyPlusDeployTests(unittest.TestCase):
    def test_deploy_uses_selected_python_interpreter_when_default_python_is_too_old(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workdir = Path(tmp)
            (workdir / "config").mkdir()
            os_release = workdir / "os-release"
            write_text_file(
                os_release,
                'ID=ubuntu\nVERSION_ID="20.04"\nPRETTY_NAME="Ubuntu 20.04 LTS"\n',
            )
            write_text_file(
                workdir / "config" / "cliproxy-plus.env",
                "\n".join(
                    [
                        "CLIPROXY_IMAGE=eceasy/cli-proxy-api-plus:v6.9.15-0",
                        "CLIPROXY_PORT=8317",
                        "CLIPROXY_MEMORY_LIMIT=96M",
                        "CLIPROXY_MANAGEMENT_KEY=test-management-key",
                    ]
                )
                + "\n",
            )

            home_dir = workdir / "home"
            home_dir.mkdir()
            bin_dir = workdir / "bin"
            bin_dir.mkdir()
            runtime_log = workdir / "runtime.log"

            write_executable(
                bin_dir / "python3",
                "#!/bin/sh\n"
                "if [ \"$1\" = \"-c\" ]; then\n"
                "  echo '3.8.10'\n"
                "  exit 0\n"
                "fi\n"
                "echo 'python3-too-old' >&2\n"
                "exit 42\n",
            )
            write_executable(
                bin_dir / "python3.10",
                "#!/bin/sh\n"
                f"printf 'python3.10 %s\\n' \"$*\" >> '{runtime_log.as_posix()}'\n"
                "if [ \"$1\" = \"-c\" ]; then\n"
                "  echo '3.10.14'\n"
                "  exit 0\n"
                "fi\n"
                f"exec '{sys.executable}' \"$@\"\n",
            )
            for candidate in ("python3.13", "python3.12", "python3.11", "python3.9"):
                write_executable(
                    bin_dir / candidate,
                    "#!/bin/sh\n"
                    "if [ \"$1\" = \"-c\" ]; then\n"
                    "  echo '0.0.0'\n"
                    "  exit 0\n"
                    "fi\n"
                    "exit 42\n",
                )
            write_executable(bin_dir / "curl", "#!/bin/sh\nexit 0\n")
            write_executable(bin_dir / "jq", "#!/bin/sh\nexit 0\n")
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
                "  restart) exit 0 ;;\n"
                "  start) exit 0 ;;\n"
                "  status) exit 0 ;;\n"
                "esac\n"
                "exit 0\n",
            )

            result = run_bash_script(
                REPO_ROOT / "scripts" / "services" / "cliproxy_plus" / "deploy.sh",
                cwd=workdir,
                env={
                    "HOME": str(home_dir),
                    "TEST_EXTRA_PATH": str(bin_dir),
                    "REMOTE_PROXY_OS_RELEASE_FILE": str(os_release),
                },
            )

            self.assertEqual(0, result.returncode, msg=result.stderr or result.stdout)
            self.assertTrue((workdir / "state" / "cliproxy-plus" / "config.yaml").exists(), msg=result.stdout)
            self.assertIn("python3.10", runtime_log.read_text(encoding="utf-8"))

    def test_fallback_service_defaults_to_latest_image_when_env_does_not_set_one(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workdir = Path(tmp)
            (workdir / "config").mkdir()
            (workdir / "state" / "cliproxy-plus").mkdir(parents=True)
            write_text_file(
                workdir / "config" / "cliproxy-plus.env",
                "\n".join(
                    [
                        "CLIPROXY_PORT=8317",
                        "CLIPROXY_MEMORY_LIMIT=96M",
                        "CLIPROXY_MANAGEMENT_KEY=test-management-key",
                    ]
                )
                + "\n",
            )
            (workdir / "state" / "cliproxy-plus" / "config.yaml").write_text("port: 8317\n", encoding="utf-8")

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
                "  restart) exit 0 ;;\n"
                "  start) exit 0 ;;\n"
                "  status) exit 0 ;;\n"
                "esac\n"
                "exit 0\n",
            )

            result = run_bash_script(
                REPO_ROOT / "scripts" / "services" / "cliproxy_plus" / "deploy.sh",
                cwd=workdir,
                env={"HOME": str(home_dir), "TEST_EXTRA_PATH": str(bin_dir)},
            )

            self.assertEqual(0, result.returncode, msg=result.stderr or result.stdout)
            service_file = home_dir / ".config" / "systemd" / "user" / "cliproxy-plus.service"
            self.assertTrue(service_file.exists(), msg=result.stdout)
            service_text = service_file.read_text(encoding="utf-8")
            self.assertIn("docker.io/eceasy/cli-proxy-api-plus:latest", service_text)

    def test_fallback_service_uses_host_network_by_default(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workdir = Path(tmp)
            (workdir / "config").mkdir()
            (workdir / "state" / "cliproxy-plus").mkdir(parents=True)
            write_text_file(
                workdir / "config" / "cliproxy-plus.env",
                "\n".join(
                    [
                        "CLIPROXY_IMAGE=eceasy/cli-proxy-api-plus:v6.9.15-0",
                        "CLIPROXY_PORT=8317",
                        "CLIPROXY_MEMORY_LIMIT=96M",
                        "CLIPROXY_MANAGEMENT_KEY=test-management-key",
                    ]
                )
                + "\n",
            )
            (workdir / "state" / "cliproxy-plus" / "config.yaml").write_text("port: 8317\n", encoding="utf-8")

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
                "printf '[systemctl] %s\\n' \"$*\" >> dispatch.log\n"
                "case \"$1\" in\n"
                "  daemon-reload) exit 0 ;;\n"
                "  list-unit-files) exit 0 ;;\n"
                "  enable) exit 0 ;;\n"
                "  restart) exit 0 ;;\n"
                "  start) exit 0 ;;\n"
                "  status) exit 0 ;;\n"
                "esac\n"
                "exit 0\n",
            )

            result = run_bash_script(
                REPO_ROOT / "scripts" / "services" / "cliproxy_plus" / "deploy.sh",
                cwd=workdir,
                env={"HOME": str(home_dir), "TEST_EXTRA_PATH": str(bin_dir)},
            )

            self.assertEqual(0, result.returncode, msg=result.stderr or result.stdout)
            service_file = home_dir / ".config" / "systemd" / "user" / "cliproxy-plus.service"
            self.assertTrue(service_file.exists(), msg=result.stdout)
            service_text = service_file.read_text(encoding="utf-8")
            self.assertIn("eceasy/cli-proxy-api-plus:v6.9.15-0", service_text)
            self.assertIn("/CLIProxyAPI/config.yaml", service_text)
            self.assertIn("/root/.cli-proxy-api", service_text)
            self.assertIn("/CLIProxyAPI/logs", service_text)
            self.assertIn("--network host", service_text)
            self.assertNotIn("-p 8317:8317", service_text)
            self.assertIn("--memory 128M", service_text)
            dispatch_log = (workdir / "dispatch.log").read_text(encoding="utf-8")
            self.assertIn("[systemctl] restart cliproxy-plus", dispatch_log)


if __name__ == "__main__":
    unittest.main()
