import json
import tempfile
import unittest
from pathlib import Path

from PIL import Image

from scripts.tools.export_chaos_ghost_sprite import (
    ASSET_ID,
    MANIFEST_PATH,
    NATIVE_SIZE,
    VARIANT_SPECS,
    RUNTIME_SCALE,
    export_assets,
)


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / MANIFEST_PATH
CONTACT = ROOT / f"docs/art/characters/{ASSET_ID}_contact_sheet.png"


class ChaosGhostSpritePipelineTest(unittest.TestCase):
    def test_manifest_tracks_selected_imagegen_source(self):
        data = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(len(data["assets"]), len(VARIANT_SPECS))
        entries = {entry["id"]: entry for entry in data["assets"]}
        self.assertEqual(set(entries.keys()), set(VARIANT_SPECS.keys()))
        for asset_id, spec in VARIANT_SPECS.items():
            entry = entries[asset_id]
            self.assertEqual(entry["source"], spec["source"].as_posix())
            self.assertEqual(entry["native_output"], f"assets/source/characters/chaos_ghost/{asset_id}.png")
            self.assertEqual(entry["runtime_output"], f"assets/textures/characters/{asset_id}.png")
            self.assertEqual(entry["native_size"], list(NATIVE_SIZE))
            self.assertEqual(entry["runtime_scale"], RUNTIME_SCALE)
            self.assertEqual(entry["safe_area"], spec["safe_area"])
            self.assertIn(spec["state"], entry["intended_godot_use"])

    def test_runtime_is_exact_nearest_neighbor_export(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_root = Path(temp_dir)
            for spec in VARIANT_SPECS.values():
                raw = temp_root / spec["source"]
                raw.parent.mkdir(parents=True, exist_ok=True)
                raw.write_bytes((ROOT / spec["source"]).read_bytes())
            export_assets(temp_root)
            for asset_id in VARIANT_SPECS.keys():
                native = Image.open(temp_root / f"assets/source/characters/chaos_ghost/{asset_id}.png").convert("RGBA")
                runtime = Image.open(temp_root / f"assets/textures/characters/{asset_id}.png").convert("RGBA")
                expected = native.resize(
                    (native.width * RUNTIME_SCALE, native.height * RUNTIME_SCALE),
                    Image.Resampling.NEAREST,
                )
                self.assertEqual(native.size, NATIVE_SIZE)
                self.assertEqual(runtime.size, expected.size)
                self.assertEqual(runtime.tobytes(), expected.tobytes())

    def test_sprite_is_cut_out_and_readable(self):
        for asset_id in VARIANT_SPECS.keys():
            native = Image.open(ROOT / f"assets/source/characters/chaos_ghost/{asset_id}.png").convert("RGBA")
            runtime = Image.open(ROOT / f"assets/textures/characters/{asset_id}.png").convert("RGBA")
            self.assertEqual(native.size, NATIVE_SIZE)
            self.assertEqual(runtime.size, (NATIVE_SIZE[0] * RUNTIME_SCALE, NATIVE_SIZE[1] * RUNTIME_SCALE))
            alpha = native.getchannel("A")
            bounds = alpha.getbbox()
            self.assertIsNotNone(bounds)
            left, top, right, bottom = bounds
            self.assertLessEqual(left, 8)
            self.assertLessEqual(top, 8)
            self.assertGreaterEqual(right, 84)
            self.assertGreaterEqual(bottom, 84)
            self.assertEqual(alpha.getpixel((0, 0)), 0)
            self.assertEqual(alpha.getpixel((95, 95)), 0)
            visible_pixels = sum(alpha.histogram()[1:])
            self.assertGreater(visible_pixels, 2800)
            self.assertLessEqual(len(native.getcolors(maxcolors=512) or []), 70)
        self.assertTrue(CONTACT.exists())


if __name__ == "__main__":
    unittest.main()
