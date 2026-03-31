from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path

from tests.test_support import REPO_ROOT


class GenConfigTests(unittest.TestCase):
    def run_gen_config(self, config_text: str) -> dict:
        with tempfile.TemporaryDirectory() as tmp:
            workdir = Path(tmp)
            (workdir / "config.env").write_text(config_text, encoding="utf-8", newline="\n")

            result = subprocess.run(
                ["python3", str(REPO_ROOT / "scripts" / "gen_config.py")],
                cwd=workdir,
                text=True,
                encoding="utf-8",
                capture_output=True,
                check=False,
            )

            self.assertEqual(0, result.returncode, msg=result.stderr or result.stdout)
            return json.loads((workdir / "singbox.json").read_text(encoding="utf-8"))

    def test_reality_dest_host_and_port_are_split_for_handshake(self) -> None:
        cfg = self.run_gen_config(
            "\n".join(
                [
                    "VLESS_UUID=11111111-2222-3333-4444-555555555555",
                    "REALITY_PRIVATE_KEY=test_private_key",
                    "REALITY_SHORT_ID=deadbeefcafebabe",
                    "REALITY_DEST=www.microsoft.com:443",
                    "REALITY_SERVER_NAMES=www.microsoft.com,microsoft.com",
                ]
            )
            + "\n"
        )

        vless_in = next(item for item in cfg["inbounds"] if item["type"] == "vless")
        self.assertEqual("www.microsoft.com", vless_in["tls"]["reality"]["handshake"]["server"])
        self.assertEqual(443, vless_in["tls"]["reality"]["handshake"]["server_port"])

    def test_reality_dest_without_explicit_port_keeps_default_443(self) -> None:
        cfg = self.run_gen_config(
            "\n".join(
                [
                    "VLESS_UUID=11111111-2222-3333-4444-555555555555",
                    "REALITY_PRIVATE_KEY=test_private_key",
                    "REALITY_SHORT_ID=deadbeefcafebabe",
                    "REALITY_DEST=www.microsoft.com",
                    "REALITY_SERVER_NAMES=www.microsoft.com,microsoft.com",
                ]
            )
            + "\n"
        )

        vless_in = next(item for item in cfg["inbounds"] if item["type"] == "vless")
        self.assertEqual("www.microsoft.com", vless_in["tls"]["reality"]["handshake"]["server"])
        self.assertEqual(443, vless_in["tls"]["reality"]["handshake"]["server_port"])


if __name__ == "__main__":
    unittest.main()
