from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from tests.test_support import REPO_ROOT, run_bash_command, write_executable, write_text_file


class RuntimeCompatibilityTests(unittest.TestCase):
    def runtime_script(self) -> str:
        return str(REPO_ROOT / "scripts" / "lib" / "runtime_compat.sh")

    def command_prefix(self) -> str:
        return f". '{self.runtime_script()}'"

    def write_os_release(self, path: Path, content: str) -> None:
        write_text_file(path, content)

    def write_support_commands(self, bin_dir: Path) -> None:
        write_executable(bin_dir / "curl", "#!/bin/sh\nexit 0\n")
        write_executable(bin_dir / "jq", "#!/bin/sh\nexit 0\n")
        write_executable(bin_dir / "podman", "#!/bin/sh\nexit 0\n")
        write_executable(bin_dir / "systemctl", "#!/bin/sh\nexit 0\n")
        write_executable(bin_dir / "sudo", "#!/bin/sh\n\"$@\"\n")

    def mask_host_python_candidates(self, bin_dir: Path, keep: tuple[str, ...] = ()) -> None:
        for candidate in ("python3.13", "python3.12", "python3.11", "python3.10", "python3.9"):
            if candidate in keep:
                continue
            write_executable(
                bin_dir / candidate,
                "#!/bin/sh\n"
                "if [ \"$1\" = \"-c\" ]; then\n"
                "  echo '0.0.0'\n"
                "  exit 0\n"
                "fi\n"
                "exit 42\n",
            )

    def test_check_mode_prefers_compatible_versioned_python_when_default_python_is_too_old(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workdir = Path(tmp)
            bin_dir = workdir / "bin"
            bin_dir.mkdir()
            os_release = workdir / "os-release"
            self.write_os_release(
                os_release,
                'ID=ubuntu\nVERSION_ID="20.04"\nPRETTY_NAME="Ubuntu 20.04 LTS"\n',
            )
            self.write_support_commands(bin_dir)
            self.mask_host_python_candidates(bin_dir, keep=("python3.10",))
            write_executable(
                bin_dir / "python3",
                "#!/bin/sh\n"
                "if [ \"$1\" = \"-c\" ]; then\n"
                "  echo '3.8.10'\n"
                "  exit 0\n"
                "fi\n"
                "exit 42\n",
            )
            write_executable(
                bin_dir / "python3.10",
                "#!/bin/sh\n"
                "if [ \"$1\" = \"-c\" ]; then\n"
                "  echo '3.10.14'\n"
                "  exit 0\n"
                "fi\n"
                "exit 0\n",
            )

            result = run_bash_command(
                "\n".join(
                    [
                        self.command_prefix(),
                        f"export REMOTE_PROXY_OS_RELEASE_FILE='{os_release.as_posix()}'",
                        "remote_proxy_runtime_preflight check",
                        "printf 'PY=%s\\n' \"$REMOTE_PROXY_PYTHON_BIN\"",
                    ]
                ),
                cwd=workdir,
                env={"TEST_EXTRA_PATH": str(bin_dir)},
            )

            self.assertEqual(0, result.returncode, msg=result.stderr or result.stdout)
            self.assertIn("PY=python3.10", result.stdout)

    def test_hybrid_mode_installs_supported_versioned_python_from_native_repo(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workdir = Path(tmp)
            bin_dir = workdir / "bin"
            bin_dir.mkdir()
            apt_log = workdir / "apt.log"
            os_release = workdir / "os-release"
            self.write_os_release(
                os_release,
                'ID=debian\nVERSION_ID="11"\nPRETTY_NAME="Debian GNU/Linux 11"\n',
            )
            self.write_support_commands(bin_dir)
            self.mask_host_python_candidates(bin_dir)
            write_executable(
                bin_dir / "python3",
                "#!/bin/sh\n"
                "if [ \"$1\" = \"-c\" ]; then\n"
                "  echo '3.8.10'\n"
                "  exit 0\n"
                "fi\n"
                "exit 42\n",
            )
            write_executable(
                bin_dir / "apt-cache",
                "#!/bin/sh\n"
                "if [ \"$1\" = \"show\" ] && [ \"$2\" = \"python3.10\" ]; then\n"
                "  exit 0\n"
                "fi\n"
                "exit 1\n",
            )
            write_executable(
                bin_dir / "apt-get",
                "#!/bin/sh\n"
                f"printf '%s\\n' \"$*\" >> '{apt_log.as_posix()}'\n"
                "if printf '%s' \"$*\" | grep -q 'install -yq python3.10'; then\n"
                "  cat > \"$TEST_RUNTIME_BIN_DIR/python3.10\" <<'EOF'\n"
                "#!/bin/sh\n"
                "if [ \"$1\" = \"-c\" ]; then\n"
                "  echo '3.10.14'\n"
                "  exit 0\n"
                "fi\n"
                "exit 0\n"
                "EOF\n"
                "  chmod +x \"$TEST_RUNTIME_BIN_DIR/python3.10\"\n"
                "fi\n"
                "exit 0\n",
            )

            result = run_bash_command(
                "\n".join(
                    [
                        self.command_prefix(),
                        f"export REMOTE_PROXY_OS_RELEASE_FILE='{os_release.as_posix()}'",
                        "remote_proxy_runtime_preflight ensure",
                        "printf 'PY=%s\\n' \"$REMOTE_PROXY_PYTHON_BIN\"",
                    ]
                ),
                cwd=workdir,
                env={
                    "TEST_EXTRA_PATH": str(bin_dir),
                    "TEST_RUNTIME_BIN_DIR": str(bin_dir),
                },
            )

            self.assertEqual(0, result.returncode, msg=result.stderr or result.stdout)
            self.assertIn("PY=python3.10", result.stdout)
            self.assertIn("install -yq python3.10", apt_log.read_text(encoding="utf-8"))

    def test_hybrid_mode_blocks_old_platform_without_supported_python_candidate(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workdir = Path(tmp)
            bin_dir = workdir / "bin"
            bin_dir.mkdir()
            os_release = workdir / "os-release"
            self.write_os_release(
                os_release,
                'ID=debian\nVERSION_ID="10"\nPRETTY_NAME="Debian GNU/Linux 10"\n',
            )
            self.write_support_commands(bin_dir)
            self.mask_host_python_candidates(bin_dir)
            write_executable(
                bin_dir / "python3",
                "#!/bin/sh\n"
                "if [ \"$1\" = \"-c\" ]; then\n"
                "  echo '3.7.3'\n"
                "  exit 0\n"
                "fi\n"
                "exit 42\n",
            )
            write_executable(bin_dir / "apt-cache", "#!/bin/sh\nexit 1\n")
            write_executable(bin_dir / "apt-get", "#!/bin/sh\nexit 0\n")

            result = run_bash_command(
                "\n".join(
                    [
                        self.command_prefix(),
                        f"export REMOTE_PROXY_OS_RELEASE_FILE='{os_release.as_posix()}'",
                        "remote_proxy_runtime_preflight ensure",
                    ]
                ),
                cwd=workdir,
                env={"TEST_EXTRA_PATH": str(bin_dir)},
            )

            combined_output = f"{result.stdout}\n{result.stderr}"
            self.assertNotEqual(0, result.returncode, msg=combined_output)
            self.assertIn("Debian GNU/Linux 10", combined_output)
            self.assertIn("REMOTE_PROXY_PYTHON_BIN", combined_output)


if __name__ == "__main__":
    unittest.main()
