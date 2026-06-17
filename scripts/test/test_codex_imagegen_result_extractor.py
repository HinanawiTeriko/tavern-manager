from __future__ import annotations

import base64
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "tools" / "extract_codex_imagegen_results.py"

ONE_PIXEL_PNG = (
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
)


class CodexImagegenResultExtractorTest(unittest.TestCase):
    def test_extracts_image_generation_end_result_from_session_jsonl(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp = Path(tmp_dir)
            session = tmp / "session.jsonl"
            out_dir = tmp / "out"
            session.write_text(
                "\n".join(
                    [
                        json.dumps({"timestamp": "2026-06-16T09:59:59.000Z", "type": "event_msg", "payload": {"type": "token_count"}}),
                        json.dumps(
                            {
                                "timestamp": "2026-06-16T10:03:04.039Z",
                                "type": "event_msg",
                                "payload": {
                                    "type": "image_generation_end",
                                    "call_id": "ig_test",
                                    "result": ONE_PIXEL_PNG,
                                },
                            }
                        ),
                        json.dumps(
                            {
                                "timestamp": "2026-06-16T10:03:04.069Z",
                                "type": "response_item",
                                "payload": {
                                    "type": "image_generation_call",
                                    "id": "ig_test",
                                    "result": ONE_PIXEL_PNG,
                                },
                            }
                        ),
                    ]
                )
                + "\n",
                encoding="utf-8",
            )

            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "--session",
                    str(session),
                    "--out-dir",
                    str(out_dir),
                    "--after",
                    "2026-06-16T10:00:00Z",
                    "--prefix",
                    "evelyn_",
                ],
                check=False,
                capture_output=True,
                text=True,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            images = sorted(out_dir.glob("*.png"))
            self.assertEqual(len(images), 1)
            self.assertTrue(images[0].name.startswith("evelyn_20260616T100304Z_ig_test"))
            self.assertEqual(images[0].read_bytes(), base64.b64decode(ONE_PIXEL_PNG))


if __name__ == "__main__":
    unittest.main(verbosity=2)
