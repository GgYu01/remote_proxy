from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path

from tests.test_support import REPO_ROOT, run_bash_command, run_bash_script, write_executable


def write_common_deploy_mocks(bin_dir: Path) -> None:
    write_executable(bin_dir / "podman", "#!/bin/sh\nexit 0\n")
    write_executable(bin_dir / "python3", "#!/bin/sh\nif [ \"$1\" = \"-c\" ]; then echo '3.11.0'; fi\nexit 0\n")
    write_executable(bin_dir / "journalctl", "#!/bin/sh\nexit 0\n")
    write_executable(bin_dir / "sleep", "#!/bin/sh\nexit 0\n")


class DeployScriptTests(unittest.TestCase):
    def test_resource_priority_helpers_emit_root_only_podman_and_oom_policy(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workdir = Path(tmp)
            bin_dir = workdir / "bin"
            bin_dir.mkdir()
            write_executable(
                bin_dir / "id",
                "#!/bin/sh\n"
                "if [ \"$1\" = \"-u\" ]; then echo 0; exit 0; fi\n"
                "exec /usr/bin/id \"$@\"\n",
            )

            result = run_bash_command(
                ". scripts/lib/common.sh; "
                "remote_proxy_systemd_resource_lines CLIPROXY; "
                "printf '%s\\n' '---podman---'; "
                "remote_proxy_podman_run_resource_args CLIPROXY",
                cwd=REPO_ROOT,
                env={"TEST_EXTRA_PATH": str(bin_dir)},
            )

            self.assertEqual(0, result.returncode, msg=result.stderr or result.stdout)
            self.assertIn("CPUWeight=1000", result.stdout)
            self.assertIn("IOWeight=1000", result.stdout)
            self.assertIn("Nice=-5", result.stdout)
            self.assertIn("OOMScoreAdjust=-500", result.stdout)
            self.assertIn("--cpu-shares 2048", result.stdout)
            self.assertIn("--oom-score-adj -500", result.stdout)

    def test_deploy_uses_external_runtime_paths_when_configured(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workdir = Path(tmp)
            external_config_root = workdir / "persist" / "etc"
            external_state_root = workdir / "persist" / "var"
            external_config_root.mkdir(parents=True)
            with (external_config_root / "singbox.env").open("w", encoding="utf-8", newline="\n") as handle:
                handle.write(
                    "\n".join(
                        [
                            "BASE_PORT=10000",
                            "SING_BOX_IMAGE=ghcr.io/sagernet/sing-box:v1.13.2",
                            "ENABLE_DEPRECATED_SING_BOX_FLAGS=true",
                        ]
                    )
                    + "\n"
                )
            external_runtime_dir = external_state_root / "singbox"
            external_runtime_dir.mkdir(parents=True)
            (external_runtime_dir / "config.json").write_text("{}", encoding="utf-8")

            home_dir = workdir / "home"
            home_dir.mkdir()

            bin_dir = workdir / "bin"
            bin_dir.mkdir()
            write_common_deploy_mocks(bin_dir)
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
                env={
                    "HOME": str(home_dir),
                    "TEST_EXTRA_PATH": str(bin_dir),
                    "REMOTE_PROXY_CONFIG_ROOT": str(external_config_root),
                    "REMOTE_PROXY_STATE_ROOT": str(external_state_root),
                },
            )

            self.assertEqual(0, result.returncode, msg=result.stderr or result.stdout)
            service_file = home_dir / ".config" / "systemd" / "user" / "remote-proxy.service"
            self.assertTrue(service_file.exists(), msg=result.stdout)
            service_text = service_file.read_text(encoding="utf-8")
            normalized_service_text = service_text.replace("\\", "/")
            self.assertIn("persist/var/singbox/config.json:/etc/sing-box/config.json:Z", normalized_service_text)
            self.assertFalse((workdir / "singbox.json").exists())

    def test_deploy_regenerates_existing_external_singbox_runtime_config(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workdir = Path(tmp)
            external_config_root = workdir / "persist" / "etc"
            external_state_root = workdir / "persist" / "var"
            external_config_root.mkdir(parents=True)
            with (external_config_root / "singbox.env").open("w", encoding="utf-8", newline="\n") as handle:
                handle.write(
                    "\n".join(
                        [
                            "BASE_PORT=10000",
                            "SING_BOX_IMAGE=ghcr.io/sagernet/sing-box:v1.13.2",
                            "ENABLE_DEPRECATED_SING_BOX_FLAGS=true",
                        ]
                    )
                    + "\n"
                )
            external_runtime_dir = external_state_root / "singbox"
            external_runtime_dir.mkdir(parents=True)
            runtime_config = external_runtime_dir / "config.json"
            runtime_config.write_text("stale-runtime-config", encoding="utf-8")

            home_dir = workdir / "home"
            home_dir.mkdir()

            bin_dir = workdir / "bin"
            bin_dir.mkdir()
            write_common_deploy_mocks(bin_dir)
            gen_config_log = workdir / "gen_config.log"
            write_executable(
                bin_dir / "python3",
                "#!/bin/sh\n"
                "if [ \"$1\" = \"-c\" ]; then echo '3.11.0'; exit 0; fi\n"
                "printf 'script=%s env=%s out=%s\\n' \"$1\" \"$REMOTE_PROXY_SINGBOX_ENV_FILE\" \"$REMOTE_PROXY_SINGBOX_RENDERED_CONFIG\" >> \"$GEN_CONFIG_LOG\"\n"
                "printf '{\"generated\":true}\\n' > \"$REMOTE_PROXY_SINGBOX_RENDERED_CONFIG\"\n"
                "exit 0\n",
            )
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
                env={
                    "HOME": str(home_dir),
                    "TEST_EXTRA_PATH": str(bin_dir),
                    "REMOTE_PROXY_CONFIG_ROOT": str(external_config_root),
                    "REMOTE_PROXY_STATE_ROOT": str(external_state_root),
                    "GEN_CONFIG_LOG": str(gen_config_log),
                },
            )

            self.assertEqual(0, result.returncode, msg=result.stderr or result.stdout)
            self.assertEqual('{"generated":true}\n', runtime_config.read_text(encoding="utf-8"))
            normalized_gen_config_log = gen_config_log.read_text(encoding="utf-8").replace("\\", "/")
            self.assertIn(
                f"env={(external_config_root / 'singbox.env')!s} out={runtime_config}".replace("\\", "/"),
                normalized_gen_config_log,
            )

    def test_fallback_service_uses_pinned_image_and_optional_compat_flags(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workdir = Path(tmp)
            with (workdir / "config.env").open("w", encoding="utf-8", newline="\n") as handle:
                handle.write(
                    "\n".join(
                        [
                            "BASE_PORT=10000",
                            "SING_BOX_IMAGE=ghcr.io/sagernet/sing-box:v1.13.2",
                            "ENABLE_DEPRECATED_SING_BOX_FLAGS=true",
                        ]
                    )
                    + "\n"
                )
            (workdir / "singbox.json").write_text("{}", encoding="utf-8")

            home_dir = workdir / "home"
            home_dir.mkdir()

            bin_dir = workdir / "bin"
            bin_dir.mkdir()
            write_common_deploy_mocks(bin_dir)
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
            self.assertNotIn("--memory", service_text)
            self.assertNotIn("Memory=", service_text)
            self.assertIn("CPUWeight=1000", service_text)
            self.assertIn("IOWeight=1000", service_text)
            self.assertIn("ENABLE_DEPRECATED_LEGACY_DNS_SERVERS=true", service_text)
            self.assertIn("--network host", service_text)
            self.assertNotIn("-p 10000:10000", service_text)

    def test_quadlet_mode_removes_stale_fallback_unit_before_restart(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workdir = Path(tmp)
            with (workdir / "config.env").open("w", encoding="utf-8", newline="\n") as handle:
                handle.write(
                    "\n".join(
                        [
                            "BASE_PORT=10000",
                            "SING_BOX_IMAGE=ghcr.io/sagernet/sing-box:v1.13.2",
                            "ENABLE_DEPRECATED_SING_BOX_FLAGS=true",
                        ]
                    )
                    + "\n"
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
            write_common_deploy_mocks(bin_dir)
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
            self.assertIn("enable remote-proxy", systemctl_calls)
            self.assertIn("restart remote-proxy", systemctl_calls)
            quadlet_text = (
                home_dir / ".config" / "containers" / "systemd" / "remote-proxy.container"
            ).read_text(encoding="utf-8")
            self.assertNotIn("PodmanArgs=--memory", quadlet_text)
            self.assertNotIn("Memory=", quadlet_text)
            self.assertIn("CPUWeight=1000", quadlet_text)
            self.assertIn("IOWeight=1000", quadlet_text)
            self.assertIn("Network=host", quadlet_text)
            self.assertNotIn("PublishPort=10000:10000", quadlet_text)
            self.assertIn("[Install]", quadlet_text)
            self.assertIn("WantedBy=default.target", quadlet_text)

    def test_generated_quadlet_enable_failure_falls_back_to_standard_service(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workdir = Path(tmp)
            with (workdir / "config.env").open("w", encoding="utf-8", newline="\n") as handle:
                handle.write(
                    "\n".join(
                        [
                            "BASE_PORT=10000",
                            "SING_BOX_IMAGE=ghcr.io/sagernet/sing-box:v1.13.2",
                            "ENABLE_DEPRECATED_SING_BOX_FLAGS=true",
                        ]
                    )
                    + "\n"
                )
            (workdir / "singbox.json").write_text("{}", encoding="utf-8")

            home_dir = workdir / "home"
            home_dir.mkdir()

            bin_dir = workdir / "bin"
            bin_dir.mkdir()
            systemctl_log = workdir / "systemctl.log"
            generator_bin = workdir / "podman-system-generator"
            write_common_deploy_mocks(bin_dir)
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
                "      printf '/run/user/1000/systemd/generator/remote-proxy.service\\n'\n"
                "      exit 0\n"
                "    fi\n"
                "    exit 0\n"
                "    ;;\n"
                "  enable)\n"
                "    if [ -f \"$HOME/.config/systemd/user/remote-proxy.service\" ]; then\n"
                "      exit 0\n"
                "    fi\n"
                "    echo 'generated unit cannot be enabled' >&2\n"
                "    exit 1\n"
                "    ;;\n"
                "  restart) exit 0 ;;\n"
                "  start) exit 0 ;;\n"
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
            self.assertIn("Quadlet enable failed. Falling back", result.stdout)
            fallback_service = home_dir / ".config" / "systemd" / "user" / "remote-proxy.service"
            self.assertTrue(fallback_service.exists(), msg=result.stdout)
            self.assertFalse(
                (home_dir / ".config" / "containers" / "systemd" / "remote-proxy.container").exists(),
                msg=result.stdout,
            )
            systemctl_calls = systemctl_log.read_text(encoding="utf-8")
            self.assertIn("enable remote-proxy", systemctl_calls)
            self.assertIn("restart remote-proxy", systemctl_calls)

    def test_fallback_service_supports_publish_network_override(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workdir = Path(tmp)
            with (workdir / "config.env").open("w", encoding="utf-8", newline="\n") as handle:
                handle.write(
                    "\n".join(
                        [
                            "BASE_PORT=10000",
                            "SING_BOX_IMAGE=ghcr.io/sagernet/sing-box:v1.13.2",
                            "ENABLE_DEPRECATED_SING_BOX_FLAGS=true",
                            "SING_BOX_NETWORK_MODE=publish",
                        ]
                    )
                    + "\n"
                )
            (workdir / "singbox.json").write_text("{}", encoding="utf-8")

            home_dir = workdir / "home"
            home_dir.mkdir()

            bin_dir = workdir / "bin"
            bin_dir.mkdir()
            write_common_deploy_mocks(bin_dir)
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
            service_text = service_file.read_text(encoding="utf-8")
            self.assertIn("-p 10000:10000", service_text)
            self.assertNotIn("--network host", service_text)

    def test_host_mode_cleans_stale_cni_hostport_rules_for_target_ports(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workdir = Path(tmp)
            with (workdir / "config.env").open("w", encoding="utf-8", newline="\n") as handle:
                handle.write(
                    "\n".join(
                        [
                            "BASE_PORT=10000",
                            "SING_BOX_IMAGE=ghcr.io/sagernet/sing-box:v1.13.2",
                            "ENABLE_DEPRECATED_SING_BOX_FLAGS=true",
                            "SING_BOX_NETWORK_MODE=host",
                        ]
                    )
                    + "\n"
                )
            (workdir / "singbox.json").write_text("{}", encoding="utf-8")

            home_dir = workdir / "home"
            home_dir.mkdir()

            bin_dir = workdir / "bin"
            bin_dir.mkdir()
            iptables_log = workdir / "iptables.log"
            write_common_deploy_mocks(bin_dir)
            write_executable(
                bin_dir / "iptables-save",
                "#!/bin/sh\n"
                "cat <<'EOF'\n"
                "*nat\n"
                "-A CNI-DN-deadbeef -p tcp -m tcp --dport 10000 -j DNAT --to-destination 172.16.16.12:10000\n"
                "-A CNI-DN-deadbeef -p tcp -m tcp --dport 10001 -j DNAT --to-destination 172.16.16.12:10001\n"
                "-A CNI-HOSTPORT-DNAT -p tcp -m comment --comment \"dnat name: \\\"podman\\\" id: \\\"deadbeef\\\"\" -m multiport --dports 10000,10001,10002,10003,10004 -j CNI-DN-deadbeef\n"
                "-A CNI-DN-keepme -p tcp -m tcp --dport 18081 -j DNAT --to-destination 172.16.16.11:8080\n"
                "COMMIT\n"
                "EOF\n",
            )
            write_executable(
                bin_dir / "iptables",
                "#!/bin/sh\n"
                f"echo \"$@\" >> '{iptables_log.as_posix()}'\n"
                "exit 0\n",
            )
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
            iptables_calls = iptables_log.read_text(encoding="utf-8")
            self.assertIn("-t nat -D CNI-DN-deadbeef -p tcp -m tcp --dport 10000", iptables_calls)
            self.assertIn("-t nat -D CNI-DN-deadbeef -p tcp -m tcp --dport 10001", iptables_calls)
            self.assertIn("-t nat -D CNI-HOSTPORT-DNAT -p tcp -m comment --comment dnat name:", iptables_calls)
            self.assertNotIn("18081", iptables_calls)


if __name__ == "__main__":
    unittest.main()
