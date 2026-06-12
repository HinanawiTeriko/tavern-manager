from __future__ import annotations

import json
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "source" / "tavern" / "seasonings" / "seasoning_icons_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "seasoning_icons_contact_sheet.png"
SEASONING_IDS = ("spice", "herb_spice", "salt", "sleep_powder")


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixel_count(image: Image.Image) -> int:
    data = image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()
    return sum(1 for pixel in data if pixel[3] > 0)


class SeasoningIconPipelineTest(unittest.TestCase):
    def test_manifest_declares_all_seasoning_icons(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(set(manifest["icons"].keys()), set(SEASONING_IDS))
        self.assertIn("seasoning_icons_sheet_v1", manifest["generated_sources"])
        generated = manifest["generated_sources"]["seasoning_icons_sheet_v1"]
        self.assertEqual(
            generated["source_file"],
            "art_sources/generated_raw/seasoning_icons/seasoning_icons_sheet_v1.png",
        )
        self.assertEqual(
            generated["production_reference"],
            "assets/source/tavern/seasonings/reference/seasoning_icons_sheet_v1.png",
        )
        for seasoning_id in SEASONING_IDS:
            with self.subTest(seasoning_id=seasoning_id):
                spec = manifest["icons"][seasoning_id]
                self.assertEqual(spec["reference"], f"assets/source/tavern/seasonings/reference/{seasoning_id}_reference.png")
                self.assertEqual(spec["native"], f"assets/source/tavern/seasonings/{seasoning_id}_native.png")
                self.assertEqual(spec["runtime"], f"assets/textures/icons/items/{seasoning_id}.png")
                self.assertEqual(spec["native_size"], [32, 32])
                self.assertEqual(spec["scale"], 2)
                self.assertEqual(len(spec["source_rect"]), 4)

    def test_sources_and_references_are_retained(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        generated = manifest["generated_sources"]["seasoning_icons_sheet_v1"]
        for key in ("source_file", "production_reference"):
            with self.subTest(key=key):
                path = ROOT / generated[key]
                self.assertTrue(path.exists(), f"{path}: missing generated source")
                self.assertGreater(path.stat().st_size, 0)
        for seasoning_id in SEASONING_IDS:
            with self.subTest(seasoning_id=seasoning_id):
                reference = ROOT / "assets" / "source" / "tavern" / "seasonings" / "reference" / f"{seasoning_id}_reference.png"
                self.assertTrue(reference.exists(), f"{reference}: missing reference crop")
                self.assertGreater(reference.stat().st_size, 0)

    def test_native_and_runtime_are_exact_nearest_exports(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        for seasoning_id in SEASONING_IDS:
            with self.subTest(seasoning_id=seasoning_id):
                spec = manifest["icons"][seasoning_id]
                native = load_rgba(ROOT / spec["native"])
                runtime = load_rgba(ROOT / spec["runtime"])
                self.assertEqual(native.size, (32, 32))
                self.assertEqual(runtime.size, (64, 64))
                expected = native.resize((64, 64), Image.Resampling.NEAREST)
                self.assertEqual(runtime.tobytes(), expected.tobytes(), "runtime must be exact 2x nearest export")

    def test_native_icons_have_clean_alpha_and_small_readable_coverage(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        for seasoning_id in SEASONING_IDS:
            with self.subTest(seasoning_id=seasoning_id):
                native = load_rgba(ROOT / manifest["icons"][seasoning_id]["native"])
                corners = [
                    native.getpixel((0, 0)),
                    native.getpixel((31, 0)),
                    native.getpixel((0, 31)),
                    native.getpixel((31, 31)),
                ]
                self.assertTrue(all(pixel[3] == 0 for pixel in corners), "native icon corners must be transparent")
                visible = visible_pixel_count(native)
                self.assertGreaterEqual(visible, 35, "native seasoning icon is too sparse to read")
                self.assertLessEqual(visible, 260, "native seasoning icon fills too much of the small canvas")

    def test_contact_sheet_exists(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing review contact sheet")
        sheet = load_rgba(CONTACT_SHEET)
        self.assertGreaterEqual(sheet.width, 300)
        self.assertGreaterEqual(sheet.height, 120)


if __name__ == "__main__":
    unittest.main(verbosity=2)
