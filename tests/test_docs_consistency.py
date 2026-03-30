from __future__ import annotations

import unittest
from pathlib import Path

from tests.test_support import REPO_ROOT


class DocsConsistencyTests(unittest.TestCase):
    def test_readme_references_new_topology_docs(self) -> None:
        readme = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
        self.assertIn("docs/deploy/standalone-vps.md", readme)
        self.assertIn("docs/deploy/infra-core-ubuntu-online.md", readme)
        self.assertIn("docs/clients/android.md", readme)

    def test_docs_do_not_use_stale_primary_config_name(self) -> None:
        stale_hits: list[tuple[Path, str]] = []
        for doc in [
            REPO_ROOT / "README.md",
            REPO_ROOT / "docs" / "DESIGN_ARCHITECTURE.md",
            REPO_ROOT / "docs" / "HANDOVER_MANUAL.md",
        ]:
            text = doc.read_text(encoding="utf-8")
            if "deploy_service.sh" in text:
                stale_hits.append((doc, "deploy_service.sh"))
            if "generate_config.sh" in text:
                stale_hits.append((doc, "generate_config.sh"))
            if "proxy-service" in text:
                stale_hits.append((doc, "proxy-service"))
        self.assertEqual([], stale_hits)

    def test_docs_state_config_env_is_the_primary_standalone_config(self) -> None:
        readme = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
        design = (REPO_ROOT / "docs" / "DESIGN_ARCHITECTURE.md").read_text(encoding="utf-8")
        self.assertIn("config.env", readme)
        self.assertIn("config.env", design)


if __name__ == "__main__":
    unittest.main()
