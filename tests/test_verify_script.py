from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path

from tests.test_support import REPO_ROOT, run_bash_script, write_executable


class VerifyScriptTests(unittest.TestCase):
    def test_verify_output_does_not_print_raw_proxy_credentials(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workdir = Path(tmp)
            (workdir / "config.env").write_text(
                "PROXY_USER=user1\nPROXY_PASS=s3cr3t\nBASE_PORT=10000\n",
                encoding="utf-8",
                newline="\n",
            )

            bin_dir = workdir / "bin"
            bin_dir.mkdir()
            write_executable(
                bin_dir / "ss",
                "#!/bin/sh\n"
                "cat <<'EOF'\n"
                "tcp LISTEN 0 4096 0.0.0.0:10000 0.0.0.0:*\n"
                "tcp LISTEN 0 4096 0.0.0.0:10001 0.0.0.0:*\n"
                "tcp LISTEN 0 4096 0.0.0.0:10002 0.0.0.0:*\n"
                "tcp LISTEN 0 4096 0.0.0.0:10003 0.0.0.0:*\n"
                "tcp LISTEN 0 4096 0.0.0.0:10004 0.0.0.0:*\n"
                "EOF\n",
            )
            write_executable(bin_dir / "curl", "#!/bin/sh\necho '127.0.0.1'\n")

            result = run_bash_script(
                REPO_ROOT / "scripts" / "verify.sh",
                cwd=workdir,
                env={"TEST_EXTRA_PATH": str(bin_dir)},
            )

            self.assertEqual(0, result.returncode, msg=result.stderr or result.stdout)
            self.assertNotIn("user1:s3cr3t@", result.stdout)
            self.assertNotIn("s3cr3t", result.stdout)


if __name__ == "__main__":
    unittest.main()
