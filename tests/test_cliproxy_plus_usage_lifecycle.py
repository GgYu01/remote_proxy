from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from tests.test_support import REPO_ROOT, run_bash_script, write_executable


class CLIProxyPlusUsageLifecycleTests(unittest.TestCase):
    def test_usage_backup_exports_snapshot_to_host_state(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workdir = Path(tmp)
            (workdir / "config").mkdir()
            (workdir / "state" / "cliproxy-plus" / "usage").mkdir(parents=True)
            (workdir / "config" / "cliproxy-plus.env").write_text(
                "\n".join(
                    [
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
                "printf '%s\n' \"$@\" >> backup-curl.log\n"
                "cat <<'EOF'\n"
                "{\"version\":1,\"usage\":{\"total_requests\":3}}\n"
                "EOF\n",
            )

            result = run_bash_script(
                REPO_ROOT / "scripts" / "services" / "cliproxy_plus" / "usage_backup.sh",
                cwd=workdir,
                env={"TEST_EXTRA_PATH": str(bin_dir)},
            )

            self.assertEqual(0, result.returncode, msg=result.stderr or result.stdout)
            usage_file = workdir / "state" / "cliproxy-plus" / "usage" / "latest.json"
            self.assertTrue(usage_file.exists(), msg=result.stdout)
            self.assertIn("total_requests", usage_file.read_text(encoding="utf-8"))

        # The script must use localhost management API and Bearer auth.

    def test_usage_restore_retries_until_management_api_accepts_snapshot(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workdir = Path(tmp)
            (workdir / "config").mkdir()
            (workdir / "state" / "cliproxy-plus" / "usage").mkdir(parents=True)
            (workdir / "config" / "cliproxy-plus.env").write_text(
                "\n".join(
                    [
                        "CLIPROXY_PORT=8317",
                        "CLIPROXY_MANAGEMENT_KEY=test-management-key",
                    ]
                )
                + "\n",
                encoding="utf-8",
                newline="\n",
            )
            (workdir / "state" / "cliproxy-plus" / "usage" / "latest.json").write_text(
                "{\"version\":1,\"usage\":{\"total_requests\":7}}\n",
                encoding="utf-8",
            )

            bin_dir = workdir / "bin"
            bin_dir.mkdir()
            write_executable(
                bin_dir / "curl",
                "#!/bin/sh\n"
                "printf '%s\n' \"$@\" >> restore-curl.log\n"
                "count_file=restore-attempts.txt\n"
                "count=0\n"
                "if [ -f \"$count_file\" ]; then\n"
                "  count=$(cat \"$count_file\")\n"
                "fi\n"
                "count=$((count + 1))\n"
                "printf '%s' \"$count\" > \"$count_file\"\n"
                "if [ \"$count\" -eq 1 ]; then\n"
                "  exit 7\n"
                "fi\n"
                "cat <<'EOF'\n"
                "{\"added\":7,\"skipped\":0}\n"
                "EOF\n",
            )
            write_executable(bin_dir / "sleep", "#!/bin/sh\nexit 0\n")

            result = run_bash_script(
                REPO_ROOT / "scripts" / "services" / "cliproxy_plus" / "usage_restore.sh",
                cwd=workdir,
                env={"TEST_EXTRA_PATH": str(bin_dir), "CLIPROXY_RESTORE_SLEEP_SECONDS": "0"},
            )

            self.assertEqual(0, result.returncode, msg=result.stderr or result.stdout)
            curl_log = (workdir / "restore-curl.log").read_text(encoding="utf-8")
            self.assertIn("/v0/management/usage/import", curl_log)
            self.assertIn("Authorization:", curl_log)
            self.assertIn("test-management-key", curl_log)
            self.assertEqual("2", (workdir / "restore-attempts.txt").read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
