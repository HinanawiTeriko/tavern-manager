from __future__ import annotations

import json
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "source" / "tavern" / "icons" / "tavern_item_icons_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_item_icons_contact_sheet.png"
ICON_IDS = ("flour", "ale", "grape", "meat_raw", "herb")


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixel_count(image: Image.Image) -> int:
    data = image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()
    return sum(1 for pixel in data if pixel[3] > 0)


class TavernItemIconPipelineTest(unittest.TestCase):
    def test_manifest_has_all_base_material_icons_with_explicit_source_rects(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(set(manifest["icons"].keys()), set(ICON_IDS))
        for icon_id in ICON_IDS:
            with self.subTest(icon_id=icon_id):
                spec = manifest["icons"][icon_id]
                self.assertEqual(spec["reference"], f"assets/source/tavern/reference/{icon_id}_icon_reference.png")
                self.assertEqual(spec["native"], f"assets/source/tavern/icons/{icon_id}_native.png")
                self.assertEqual(spec["runtime"], f"assets/textures/tavern/icons/{icon_id}.png")
                self.assertEqual(spec["native_size"], [24, 24])
                self.assertEqual(spec["scale"], 4)
                rect = spec["source_rect"]
                self.assertEqual(len(rect), 4, "source_rect must be [left, top, right, bottom]")
                left, top, right, bottom = rect
                self.assertLess(left, right)
                self.assertLess(top, bottom)
                self.assertGreaterEqual(right - left, 64)
                self.assertGreaterEqual(bottom - top, 64)

    def test_references_are_retained(self) -> None:
        for icon_id in ICON_IDS:
            with self.subTest(icon_id=icon_id):
                reference = ROOT / "assets" / "source" / "tavern" / "reference" / f"{icon_id}_icon_reference.png"
                self.assertTrue(reference.exists(), f"{reference}: missing AI reference")
                self.assertGreater(reference.stat().st_size, 0, "reference image is empty")

    def test_native_and_runtime_are_exact_nearest_exports(self) -> None:
        for icon_id in ICON_IDS:
            with self.subTest(icon_id=icon_id):
                native = load_rgba(ROOT / "assets" / "source" / "tavern" / "icons" / f"{icon_id}_native.png")
                runtime = load_rgba(ROOT / "assets" / "textures" / "tavern" / "icons" / f"{icon_id}.png")
                self.assertEqual(native.size, (24, 24))
                self.assertEqual(runtime.size, (96, 96))
                expected = native.resize((96, 96), Image.Resampling.NEAREST)
                self.assertEqual(runtime.tobytes(), expected.tobytes(), "runtime must be exact 4x nearest export")

    def test_native_icons_have_clean_alpha_and_readable_coverage(self) -> None:
        for icon_id in ICON_IDS:
            with self.subTest(icon_id=icon_id):
                native = load_rgba(ROOT / "assets" / "source" / "tavern" / "icons" / f"{icon_id}_native.png")
                corners = [
                    native.getpixel((0, 0)),
                    native.getpixel((23, 0)),
                    native.getpixel((0, 23)),
                    native.getpixel((23, 23)),
                ]
                self.assertTrue(all(pixel[3] == 0 for pixel in corners), "native icon corners must be transparent")
                visible = visible_pixel_count(native)
                self.assertGreaterEqual(visible, 60, "native icon is too sparse to read")
                self.assertLessEqual(visible, 460, "native icon fills too much of the canvas")

    def test_contact_sheet_exists(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing review contact sheet")
        sheet = load_rgba(CONTACT_SHEET)
        self.assertGreaterEqual(sheet.width, 300)
        self.assertGreaterEqual(sheet.height, 120)


if __name__ == "__main__":
    unittest.main(verbosity=2)
