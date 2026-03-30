from __future__ import annotations

import os
import shutil
import tempfile
import unittest
from pathlib import Path

from tests.test_support import REPO_ROOT, run_bash_script, write_executable


class GenKeysTests(unittest.TestCase):
    def test_generated_config_contains_single_assignment_for_managed_keys(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workdir = Path(tmp)
            shutil.copy2(REPO_ROOT / "config.env.example", workdir / "config.env")

            bin_dir = workdir / "bin"
            bin_dir.mkdir()
            write_executable(
                bin_dir / "podman",
                "#!/bin/sh\n"
                "echo 'PrivateKey: mock_private_key'\n"
                "echo 'PublicKey: mock_public_key'\n",
            )
            write_executable(bin_dir / "uuidgen", "#!/bin/sh\necho '11111111-2222-3333-4444-555555555555'\n")
            write_executable(bin_dir / "openssl", "#!/bin/sh\nif [ \"$1\" = \"rand\" ]; then echo 'cafebabedeadbeef'; fi\n")

            result = run_bash_script(
                REPO_ROOT / "scripts" / "gen_keys.sh",
                cwd=workdir,
                env={"TEST_EXTRA_PATH": str(bin_dir)},
            )

            self.assertEqual(0, result.returncode, msg=result.stderr or result.stdout)
            content = (workdir / "config.env").read_text(encoding="utf-8")
            for key in [
                "VLESS_UUID",
                "REALITY_PRIVATE_KEY",
                "REALITY_PUBLIC_KEY",
                "REALITY_SHORT_ID",
            ]:
                self.assertEqual(1, sum(1 for line in content.splitlines() if line.startswith(f"{key}=")), msg=content)


if __name__ == "__main__":
    unittest.main()
