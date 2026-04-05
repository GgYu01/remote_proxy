from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from tests.test_support import REPO_ROOT, run_bash_script, write_executable


class ManageSwapTests(unittest.TestCase):
    def test_existing_swap_is_reused_non_interactively(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workdir = Path(tmp)
            bin_dir = workdir / "bin"
            bin_dir.mkdir()

            write_executable(bin_dir / "id", "#!/bin/sh\necho 0\n")
            write_executable(
                bin_dir / "swapon",
                "#!/bin/sh\n"
                "if [ \"$1\" = \"--show\" ] && [ \"$2\" = \"--noheadings\" ]; then\n"
                "  echo '/existing/swapfile file 1073741824 0 -2'\n"
                "  exit 0\n"
                "fi\n"
                "echo 'NAME      TYPE SIZE USED PRIO'\n"
                "echo '/existing/swapfile file   1G   0B   -2'\n",
            )
            write_executable(
                bin_dir / "free",
                "#!/bin/sh\n"
                "echo '               total        used        free      shared  buff/cache   available'\n"
                "echo 'Mem:           960Mi       200Mi       500Mi         2Mi       260Mi       700Mi'\n"
                "echo 'Swap:            1Gi          0B         1Gi'\n",
            )

            result = run_bash_script(
                REPO_ROOT / "scripts" / "manage_swap.sh",
                cwd=workdir,
                env={"TEST_EXTRA_PATH": str(bin_dir)},
            )

            self.assertEqual(0, result.returncode, msg=result.stderr or result.stdout)
            self.assertIn("Reusing existing swap", result.stdout)
            self.assertIn("/existing/swapfile", result.stdout)


if __name__ == "__main__":
    unittest.main()
