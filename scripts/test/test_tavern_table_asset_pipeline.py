from __future__ import annotations

import json
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "source" / "tavern" / "table" / "bar_counter_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_bar_counter_contact_sheet.png"
NATIVE_SIZE = (320, 48)
RUNTIME_SIZE = (1280, 192)


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def load_manifest(test_case: unittest.TestCase) -> dict:
    test_case.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing manifest")
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def image_pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    if hasattr(image, "get_flattened_data"):
        return list(image.get_flattened_data())
    return list(image.getdata())


class TavernTableAssetPipelineTest(unittest.TestCase):
    def test_manifest_records_fixed_bar_counter_contract(self) -> None:
        manifest = load_manifest(self)
        self.assertEqual(manifest["id"], "tavern_bar_counter")
        self.assertEqual(manifest["source"], "art_sources/generated_raw/tavern_table/bar_counter_reference_v1.png")
        self.assertEqual(manifest["native"], "assets/source/tavern/table/bar_counter_native.png")
        self.assertEqual(manifest["runtime"], "assets/textures/tavern/table/bar_counter.png")
        self.assertEqual(manifest["native_size"], list(NATIVE_SIZE))
        self.assertEqual(manifest["runtime_size"], list(RUNTIME_SIZE))
        self.assertEqual(manifest["scale"], 4)
        self.assertEqual(manifest["safe_area"], [0, 0, 320, 48])
        self.assertEqual(manifest["intended_godot_use"], "visual-only Tavern bar counter Sprite2D layer")

    def test_source_native_runtime_and_contact_sheet_exist(self) -> None:
        manifest = load_manifest(self)
        for key in ("source", "native", "runtime"):
            path = ROOT / manifest[key]
            self.assertTrue(path.exists(), f"{path}: missing {key} image")
            self.assertGreater(path.stat().st_size, 0, f"{path}: empty {key} image")
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing contact sheet")
        self.assertGreater(CONTACT_SHEET.stat().st_size, 0, "contact sheet is empty")

    def test_runtime_is_exact_nearest_export(self) -> None:
        manifest = load_manifest(self)
        native = load_rgba(ROOT / manifest["native"])
        runtime = load_rgba(ROOT / manifest["runtime"])
        self.assertEqual(native.size, NATIVE_SIZE)
        self.assertEqual(runtime.size, RUNTIME_SIZE)
        expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
        self.assertEqual(runtime.tobytes(), expected.tobytes(), "runtime must be exact 4x nearest export")

    def test_native_bar_counter_is_opaque_and_visually_restrained(self) -> None:
        manifest = load_manifest(self)
        native = load_rgba(ROOT / manifest["native"])
        alpha_min, alpha_max = native.getchannel("A").getextrema()
        self.assertEqual((alpha_min, alpha_max), (255, 255), "bar counter is a rectangular opaque surface")
        pixels = image_pixels(native)
        dark_wood = sum(1 for r, g, b, a in pixels if a == 255 and 20 <= r <= 95 and 14 <= g <= 70 and 8 <= b <= 60)
        teal_shadow = sum(1 for r, g, b, a in pixels if a == 255 and b >= 18 and g >= 16 and b >= r * 0.55)
        amber = sum(1 for r, g, b, a in pixels if a == 255 and r >= 90 and g >= 45 and b <= 45 and r >= b * 2.0)
        bright = sum(1 for r, g, b, a in pixels if a == 255 and max(r, g, b) >= 185)
        self.assertGreaterEqual(dark_wood, 8200, "bar counter needs enough dark wood mass")
        self.assertGreaterEqual(teal_shadow, 2200, "bar counter needs dark teal shadow bias")
        self.assertGreaterEqual(amber, 100, "bar counter needs sparse amber edge highlights")
        self.assertLessEqual(amber, 3600, "amber accents are flooding the bar counter")
        self.assertLessEqual(bright, 80, "bar counter should not contain bright noisy pixels")


if __name__ == "__main__":
    unittest.main(verbosity=2)
