from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path

from tests.test_support import REPO_ROOT


class CLIProxyPlusConfigTests(unittest.TestCase):
    def test_generated_config_defaults_to_http_local_management_and_usage_toggle(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workdir = Path(tmp)
            (workdir / "config").mkdir()
            (workdir / "config" / "cliproxy-plus.env").write_text(
                "\n".join(
                    [
                        "CLIPROXY_PORT=8317",
                        "CLIPROXY_MANAGEMENT_KEY=test-management-key",
                        "CLIPROXY_USAGE_STATISTICS_ENABLED=true",
                        "CLIPROXY_PPROF_ENABLE=false",
                    ]
                )
                + "\n",
                encoding="utf-8",
                newline="\n",
            )

            result = subprocess.run(
                [
                    "python",
                    str(REPO_ROOT / "scripts" / "services" / "cliproxy_plus" / "gen_config.py"),
                ],
                cwd=str(workdir),
                text=True,
                encoding="utf-8",
                errors="replace",
                capture_output=True,
                check=False,
            )

            self.assertEqual(0, result.returncode, msg=result.stderr or result.stdout)
            config_yaml = workdir / "state" / "cliproxy-plus" / "config.yaml"
            self.assertTrue(config_yaml.exists(), msg=result.stdout)
            content = config_yaml.read_text(encoding="utf-8")
            self.assertIn("host: ''", content)
            self.assertIn("port: 8317", content)
            self.assertIn("enable: false", content)
            self.assertIn("allow-remote: false", content)
            self.assertIn("usage-statistics-enabled: true", content)
            self.assertIn("auth-dir: '/root/.cli-proxy-api'", content)

    def test_generated_config_uses_repo_default_plaintext_credentials_when_env_missing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workdir = Path(tmp)
            (workdir / "config").mkdir()
            (workdir / "config" / "cliproxy-plus.env").write_text(
                "\n".join(
                    [
                        "CLIPROXY_PORT=8317",
                        "CLIPROXY_USAGE_STATISTICS_ENABLED=true",
                        "CLIPROXY_PPROF_ENABLE=false",
                    ]
                )
                + "\n",
                encoding="utf-8",
                newline="\n",
            )

            result = subprocess.run(
                [
                    "python",
                    str(REPO_ROOT / "scripts" / "services" / "cliproxy_plus" / "gen_config.py"),
                ],
                cwd=str(workdir),
                text=True,
                encoding="utf-8",
                errors="replace",
                capture_output=True,
                check=False,
            )

            self.assertEqual(0, result.returncode, msg=result.stderr or result.stdout)
            content = (workdir / "state" / "cliproxy-plus" / "config.yaml").read_text(encoding="utf-8")
            self.assertIn("secret-key: 'gaoyx123'", content)
            self.assertIn("- 'gaoyx123'", content)


if __name__ == "__main__":
    unittest.main()
