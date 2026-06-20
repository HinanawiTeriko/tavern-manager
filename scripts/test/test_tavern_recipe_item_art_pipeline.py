from __future__ import annotations

import json
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "source" / "tavern" / "items" / "tavern_recipe_item_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_recipe_items_contact_sheet.png"
REQUIRED_ITEM_IDS = (
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
    "herbed_lizard_raw",
    "mushroom_pie_raw",
    "grape_tart_raw",
    "mushroom_meat_pie_raw",
)
GENERATED_PREP_IDS = (
    "herbed_lizard_raw",
    "mushroom_pie_raw",
    "grape_tart_raw",
    "mushroom_meat_pie_raw",
)


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixel_count(image: Image.Image) -> int:
    data = image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()
    return sum(1 for pixel in data if pixel[3] > 0)


class TavernRecipeItemArtPipelineTest(unittest.TestCase):
    def test_manifest_tracks_required_item_art(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(tuple(manifest["items"].keys()), REQUIRED_ITEM_IDS)
        raw = ROOT / manifest["generated_sources"]["prep_item_sheet_v1"]["source_file"]
        prompt = ROOT / manifest["generated_sources"]["prep_item_sheet_v1"]["prompt"]
        self.assertTrue(raw.exists(), f"{raw}: missing extracted imagegen source")
        self.assertTrue(prompt.exists(), f"{prompt}: missing retained imagegen prompt")
        for item_id in REQUIRED_ITEM_IDS:
            with self.subTest(item_id=item_id):
                spec = manifest["items"][item_id]
                self.assertEqual(spec["native"], f"assets/source/tavern/items/{item_id}_native.png")
                self.assertEqual(spec["runtime"], f"assets/textures/tavern/items/{item_id}.png")
                self.assertEqual(spec["native_size"], [24, 24])
                self.assertEqual(spec["scale"], 4)
                self.assertTrue((ROOT / spec["source_file"]).exists(), f"{item_id}: missing source file")

    def test_generated_prep_items_use_fixed_source_rects(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        for item_id in GENERATED_PREP_IDS:
            with self.subTest(item_id=item_id):
                rect = manifest["items"][item_id].get("source_rect", [])
                self.assertEqual(len(rect), 4, "generated prep entries must use fixed source rectangles")
                left, top, right, bottom = [int(value) for value in rect]
                self.assertLess(left, right)
                self.assertLess(top, bottom)
                self.assertEqual(right - left, 627)
                self.assertEqual(bottom - top, 627)

    def test_native_and_runtime_are_exact_nearest_exports(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        for item_id, spec in manifest["items"].items():
            with self.subTest(item_id=item_id):
                native = load_rgba(ROOT / spec["native"])
                runtime = load_rgba(ROOT / spec["runtime"])
                self.assertEqual(native.size, (24, 24))
                self.assertEqual(runtime.size, (96, 96))
                expected = native.resize((96, 96), Image.Resampling.NEAREST)
                self.assertEqual(runtime.tobytes(), expected.tobytes(), f"{item_id}: runtime must be exact 4x nearest export")

    def test_native_items_have_clean_alpha_and_readable_coverage(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        for item_id, spec in manifest["items"].items():
            with self.subTest(item_id=item_id):
                native = load_rgba(ROOT / spec["native"])
                corners = [
                    native.getpixel((0, 0)),
                    native.getpixel((23, 0)),
                    native.getpixel((0, 23)),
                    native.getpixel((23, 23)),
                ]
                self.assertTrue(all(pixel[3] == 0 for pixel in corners), f"{item_id}: native corners must be transparent")
                visible = visible_pixel_count(native)
                self.assertGreaterEqual(visible, 40, f"{item_id}: native icon is too sparse to read")
                self.assertLessEqual(visible, 520, f"{item_id}: native icon fills too much of the canvas")

    def test_contact_sheet_exists(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing review contact sheet")
        sheet = load_rgba(CONTACT_SHEET)
        self.assertGreaterEqual(sheet.width, 400)
        self.assertGreaterEqual(sheet.height, 120)


if __name__ == "__main__":
    unittest.main(verbosity=2)
