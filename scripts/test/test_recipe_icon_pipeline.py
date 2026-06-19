from __future__ import annotations

import json
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "source" / "recipes" / "recipe_icon_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "recipe_icons_contact_sheet.png"
ICON_IDS = (
    "charred_crust_broth",
    "charred_meat_plate",
    "bitter_black_ale",
    "ash_pot_stew",
    "sour_herb_wine",
    "black_malt_porridge",
    "herbal_lizard_roast",
    "mushroom_pie",
    "grape_tart",
    "wakeful_herb_juice",
    "roasted_malt_porridge",
    "mushroom_meat_pie",
)


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixel_count(image: Image.Image) -> int:
    data = image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()
    return sum(1 for pixel in data if pixel[3] > 0)


class RecipeIconPipelineTest(unittest.TestCase):
    def test_manifest_tracks_every_new_recipe_icon(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(set(manifest["icons"].keys()), set(ICON_IDS))
        for icon_id in ICON_IDS:
            with self.subTest(icon_id=icon_id):
                spec = manifest["icons"][icon_id]
                self.assertEqual(spec["source"], "art_sources/generated_raw/recipes/recipe_icon_sheet_v1.png")
                self.assertEqual(spec["native"], f"assets/source/recipes/{icon_id}_native.png")
                self.assertEqual(spec["runtime"], f"assets/textures/recipes/{icon_id}.png")
                self.assertEqual(spec["native_size"], [24, 24])
                self.assertEqual(spec["scale"], 4)
                rect = spec["source_rect"]
                self.assertEqual(len(rect), 4)
                left, top, right, bottom = rect
                self.assertLess(left, right)
                self.assertLess(top, bottom)

    def test_runtime_icons_are_exact_nearest_exports(self) -> None:
        for icon_id in ICON_IDS:
            with self.subTest(icon_id=icon_id):
                native = load_rgba(ROOT / "assets" / "source" / "recipes" / f"{icon_id}_native.png")
                runtime = load_rgba(ROOT / "assets" / "textures" / "recipes" / f"{icon_id}.png")
                self.assertEqual(native.size, (24, 24))
                self.assertEqual(runtime.size, (96, 96))
                expected = native.resize((96, 96), Image.Resampling.NEAREST)
                self.assertEqual(runtime.tobytes(), expected.tobytes())

    def test_native_icons_have_readable_coverage(self) -> None:
        for icon_id in ICON_IDS:
            with self.subTest(icon_id=icon_id):
                native = load_rgba(ROOT / "assets" / "source" / "recipes" / f"{icon_id}_native.png")
                corners = [
                    native.getpixel((0, 0)),
                    native.getpixel((23, 0)),
                    native.getpixel((0, 23)),
                    native.getpixel((23, 23)),
                ]
                self.assertTrue(all(pixel[3] == 0 for pixel in corners))
                visible = visible_pixel_count(native)
                self.assertGreaterEqual(visible, 60)
                self.assertLessEqual(visible, 460)

    def test_contact_sheet_exists(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing review contact sheet")
        sheet = load_rgba(CONTACT_SHEET)
        self.assertGreaterEqual(sheet.width, 300)
        self.assertGreaterEqual(sheet.height, 120)


if __name__ == "__main__":
    unittest.main(verbosity=2)
