import json
import tempfile
import unittest
from pathlib import Path

from PIL import Image

from scripts.tools.export_meme_guest_portraits import export_manifest


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "art_sources/generated_raw/characters/meme_guests/meme_guest_portraits_manifest.json"


class MemeGuestPortraitPipelineTest(unittest.TestCase):
    def test_manifest_shape(self):
        data = json.loads(MANIFEST.read_text(encoding="utf-8"))
        ids = [asset["id"] for asset in data["assets"]]
        self.assertEqual(len(ids), 6)
        self.assertEqual(len(ids), len(set(ids)))
        for asset in data["assets"]:
            self.assertEqual(asset["native_size"], [96, 96])
            self.assertEqual(asset["runtime_scale"], 4)
            self.assertTrue(asset["runtime_output"].startswith("assets/textures/characters/"))
            self.assertFalse(asset["source"].startswith("assets/textures/"))

    def test_runtime_is_exact_nearest_neighbor_scale(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            export_manifest(MANIFEST, ROOT, output_root=Path(temp_dir))
            data = json.loads(MANIFEST.read_text(encoding="utf-8"))
            for asset in data["assets"]:
                native = Image.open(Path(temp_dir) / asset["native_output"]).convert("RGBA")
                runtime = Image.open(Path(temp_dir) / asset["runtime_output"]).convert("RGBA")
                scale = int(asset["runtime_scale"])
                expected = native.resize((native.width * scale, native.height * scale), Image.Resampling.NEAREST)
                self.assertEqual(runtime.size, expected.size)
                self.assertEqual(runtime.tobytes(), expected.tobytes())


if __name__ == "__main__":
    unittest.main()
