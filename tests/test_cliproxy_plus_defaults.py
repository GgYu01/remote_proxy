from __future__ import annotations

import unittest
from pathlib import Path

from tests.test_support import REPO_ROOT


def load_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        key, _, value = stripped.partition("=")
        values[key.strip()] = value.strip()
    return values


class CLIProxyPlusDefaultsTests(unittest.TestCase):
    def test_committed_default_configs_match_direct_use_contract(self) -> None:
        for rel_path in [
            Path("config/cliproxy-plus.env"),
            Path("config/cliproxy-plus.env.example"),
        ]:
            env = load_env_file(REPO_ROOT / rel_path)
            self.assertEqual("docker.io/eceasy/cli-proxy-api-plus:latest", env.get("CLIPROXY_IMAGE"))
            self.assertEqual("gaoyx123", env.get("CLIPROXY_MANAGEMENT_KEY"))
            self.assertEqual("true", env.get("CLIPROXY_MANAGEMENT_ALLOW_REMOTE"))
            self.assertEqual("gaoyx123", env.get("CLIPROXY_API_KEY"))
            self.assertEqual("8317", env.get("CLIPROXY_PORT"))


if __name__ == "__main__":
    unittest.main()
