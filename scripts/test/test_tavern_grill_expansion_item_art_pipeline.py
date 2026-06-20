from __future__ import annotations

import json
from pathlib import Path
import sys
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "tools"))
import export_tavern_recipe_item_art as export_base

MANIFEST = ROOT / "assets" / "source" / "tavern" / "grill_expansion" / "grill_expansion_item_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_grill_expansion_contact_sheet.png"
REQUIRED_ITEM_IDS = (
    "flour_toasted",
    "flour_burnt",
    "rock_lizard_burnt",
    "black_malt_roasted",
    "black_malt_burnt",
    "grape_roasted",
    "grape_burnt",
    "north_sour_grape_roasted",
    "north_sour_grape_burnt",
    "herb_roasted",
    "herb_ash",
    "cave_mushroom_roasted",
    "cave_mushroom_burnt",
    "roasted_mushroom_broth",
    "toasted_herb_broth",
    "warm_spiced_wine",
    "sour_roast_herb_wine",
    "double_char_black_ale",
    "grape_flour_porridge",
    "ash_flatbread",
    "charred_mushroom_meat_stew",
    "charred_lizard_herb_plate",
    "bitter_grape_dark_ale",
)
SOURCE_SAFE_MARGIN = 4


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixel_count(image: Image.Image) -> int:
    data = image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()
    return sum(1 for pixel in data if pixel[3] > 0)


class TavernGrillExpansionItemArtPipelineTest(unittest.TestCase):
    def test_manifest_tracks_required_item_art(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(tuple(manifest["items"].keys()), REQUIRED_ITEM_IDS)
        for source in manifest["generated_sources"].values():
            raw = ROOT / source["source_file"]
            prompt = ROOT / source["prompt"]
            self.assertTrue(raw.exists(), f"{raw}: missing extracted imagegen source")
            self.assertTrue(prompt.exists(), f"{prompt}: missing retained imagegen prompt")
            self.assertEqual(source["size"], [1254, 1254])
        for item_id in REQUIRED_ITEM_IDS:
            with self.subTest(item_id=item_id):
                spec = manifest["items"][item_id]
                self.assertEqual(spec["native"], f"assets/source/tavern/items/{item_id}_native.png")
                self.assertEqual(spec["runtime"], f"assets/textures/tavern/items/{item_id}.png")
                self.assertEqual(spec["native_size"], [24, 24])
                self.assertEqual(spec["scale"], 4)
                self.assertTrue((ROOT / spec["source_file"]).exists(), f"{item_id}: missing source file")

    def test_generated_items_use_explicit_source_rects_with_safe_margins(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        for item_id in REQUIRED_ITEM_IDS:
            with self.subTest(item_id=item_id):
                spec = manifest["items"][item_id]
                rect = tuple(int(value) for value in spec.get("source_rect", []))
                self.assertEqual(len(rect), 4, "generated entries must use fixed source rectangles")
                source = load_rgba(ROOT / spec["source_file"])
                left, top, right, bottom = rect
                self.assertGreaterEqual(left, 0)
                self.assertGreaterEqual(top, 0)
                self.assertLessEqual(right, source.width)
                self.assertLessEqual(bottom, source.height)
                self.assertLess(left, right)
                self.assertLess(top, bottom)
                crop = source.crop(rect)
                cutout = export_base.remove_chroma(crop, int(spec.get("chroma_threshold", 72)))
                bbox = cutout.getchannel("A").getbbox()
                self.assertIsNotNone(bbox, "source rect should contain visible item pixels")
                if bbox is None:
                    continue
                crop_width, crop_height = crop.size
                item_left, item_top, item_right, item_bottom = bbox
                margins = (
                    item_left,
                    item_top,
                    crop_width - item_right,
                    crop_height - item_bottom,
                )
                self.assertTrue(
                    all(margin >= SOURCE_SAFE_MARGIN for margin in margins),
                    f"{item_id}: source rect clips or includes a neighboring item at the edge; margins={margins}",
                )

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
