from __future__ import annotations

import json
import re
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "source" / "tavern" / "missing_item_icons" / "tavern_missing_item_icons_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_missing_item_icons_contact_sheet.png"
ITEM_IDS = (
    "dough",
    "bread_burnt",
    "meat_burnt",
    "ale_roasted",
    "ale_burnt",
    "grape_juice",
    "dough_meat",
    "ale_herb",
    "grape_herb",
    "meat_stew_raw",
    "herb_tea",
    "meat_sand",
    "herbal_ale",
    "spiced_wine",
    "meat_stew",
    "malt_porridge",
    "toby_contract",
    "wine",
    "ale_beer",
    "bread",
    "meat_cooked",
    "herb_broth",
    "cave_mushroom_stew",
    "rock_lizard_steak",
    "old_road_wine",
    "miner_dark_ale",
    "bloodied_contract",
    "alternative_contract",
    "failed_brew",
    "failed_stew",
)
QUALITY_DRINK_IDS = (
    "ale_beer_good",
    "wine_good",
    "herbal_ale_good",
    "spiced_wine_good",
)
FAILED_PRODUCT_IDS = ("failed_brew", "failed_stew")
UPGRADED_PRODUCT_IDS = ("cave_mushroom_stew", "rock_lizard_steak", "old_road_wine", "miner_dark_ale")
UPGRADED_PRODUCT_SHEET = "assets/source/tavern/missing_item_icons/reference/rare_upgrade_items_sheet_v1.png"


def pipeline_icons(manifest: dict) -> dict:
    return manifest["icons"] | manifest["quality_icons"]


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixel_count(image: Image.Image) -> int:
    data = image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()
    return sum(1 for pixel in data if pixel[3] > 0)


def material_icon_paths() -> dict[str, str]:
    text = (ROOT / "scripts" / "game_manager.gd").read_text(encoding="utf-8")
    block = text.split("const MATERIAL_ICON_PATHS: Dictionary = {", 1)[1].split("\n}", 1)[0]
    return dict(re.findall(r'"([^"]+)"\s*:\s*"res://([^"]+)"', block))


class TavernMissingItemIconPipelineTest(unittest.TestCase):
    def test_manifest_declares_all_missing_item_icons(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["id"], "tavern_missing_item_icons")
        self.assertEqual(set(manifest["icons"].keys()), set(ITEM_IDS))
        generated = manifest["generated_sources"]["missing_item_icons_sheet_v3"]
        self.assertEqual(
            generated["source_file"],
            "art_sources/generated_raw/tavern_missing_item_icons/missing_item_icons_sheet_v3.png",
        )
        self.assertEqual(
            generated["production_reference"],
            "assets/source/tavern/missing_item_icons/reference/missing_item_icons_sheet_v3.png",
        )
        self.assertEqual(generated["grid"], [6, 4])
        quality_generated = manifest["generated_sources"]["quality_drinks_good_sheet_v1"]
        self.assertEqual(
            quality_generated["source_file"],
            "art_sources/generated_raw/tavern_missing_item_icons/quality_drinks_good_sheet_v1.png",
        )
        self.assertEqual(
            quality_generated["production_reference"],
            "assets/source/tavern/missing_item_icons/reference/quality_drinks_good_sheet_v1.png",
        )
        self.assertEqual(quality_generated["grid"], [4, 1])
        failed_generated = manifest["generated_sources"]["failed_products_sheet_v1"]
        self.assertEqual(
            failed_generated["source_file"],
            "art_sources/generated_raw/tavern_missing_item_icons/failed_products_sheet_v1.png",
        )
        self.assertEqual(
            failed_generated["production_reference"],
            "assets/source/tavern/missing_item_icons/reference/failed_products_sheet_v1.png",
        )
        self.assertEqual(failed_generated["grid"], [2, 1])
        upgraded_generated = manifest["generated_sources"]["rare_upgrade_items_sheet_v1"]
        self.assertEqual(
            upgraded_generated["source_file"],
            "art_sources/generated_raw/rare_gathering/rare_upgrade_items_sheet_v1.png",
        )
        self.assertEqual(upgraded_generated["production_reference"], UPGRADED_PRODUCT_SHEET)
        self.assertEqual(upgraded_generated["grid"], [4, 1])
        for icon_id in ITEM_IDS:
            with self.subTest(icon_id=icon_id):
                spec = manifest["icons"][icon_id]
                if icon_id in FAILED_PRODUCT_IDS:
                    expected_sheet = "assets/source/tavern/missing_item_icons/reference/failed_products_sheet_v1.png"
                elif icon_id in UPGRADED_PRODUCT_IDS:
                    expected_sheet = UPGRADED_PRODUCT_SHEET
                else:
                    expected_sheet = "assets/source/tavern/missing_item_icons/reference/missing_item_icons_sheet_v3.png"
                self.assertEqual(spec["source_sheet"], expected_sheet)
                self.assertEqual(spec["native"], f"assets/source/tavern/missing_item_icons/{icon_id}_native.png")
                self.assertEqual(spec["runtime"], f"assets/textures/tavern/items/{icon_id}.png")
                self.assertEqual(spec["native_size"], [24, 24])
                self.assertEqual(spec["scale"], 4)
                self.assertEqual(len(spec["source_rect"]), 4)
                left, top, right, bottom = spec["source_rect"]
                self.assertLess(left, right)
                self.assertLess(top, bottom)
                if icon_id in FAILED_PRODUCT_IDS:
                    min_source_size = 700
                elif icon_id in UPGRADED_PRODUCT_IDS:
                    min_source_size = 200
                else:
                    min_source_size = 280
                self.assertGreaterEqual(right - left, min_source_size)
                self.assertGreaterEqual(bottom - top, min_source_size)
        self.assertEqual(set(manifest["quality_icons"].keys()), set(QUALITY_DRINK_IDS))
        for icon_id in QUALITY_DRINK_IDS:
            with self.subTest(icon_id=icon_id):
                spec = manifest["quality_icons"][icon_id]
                self.assertEqual(
                    spec["source_sheet"],
                    "assets/source/tavern/missing_item_icons/reference/quality_drinks_good_sheet_v1.png",
                )
                self.assertEqual(spec["native"], f"assets/source/tavern/missing_item_icons/{icon_id}_native.png")
                self.assertEqual(spec["runtime"], f"assets/textures/tavern/items/{icon_id}.png")
                self.assertEqual(spec["native_size"], [24, 24])
                self.assertEqual(spec["scale"], 4)
                self.assertEqual(len(spec["source_rect"]), 4)
                left, top, right, bottom = spec["source_rect"]
                self.assertLess(left, right)
                self.assertLess(top, bottom)
                self.assertGreaterEqual(right - left, 700)
                self.assertGreaterEqual(bottom - top, 700)

    def test_sources_references_and_contact_sheet_exist(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        for generated_id in (
            "missing_item_icons_sheet_v3",
            "quality_drinks_good_sheet_v1",
            "failed_products_sheet_v1",
            "rare_upgrade_items_sheet_v1",
        ):
            generated = manifest["generated_sources"][generated_id]
            for key in ("source_file", "production_reference"):
                with self.subTest(generated=generated_id, key=key):
                    path = ROOT / generated[key]
                    self.assertTrue(path.exists(), f"{path}: missing generated sheet")
                    self.assertGreater(path.stat().st_size, 100_000)
        for icon_id, spec in pipeline_icons(manifest).items():
            with self.subTest(icon_id=icon_id):
                reference = ROOT / spec["reference"]
                self.assertTrue(reference.exists(), f"{reference}: missing reference crop")
                self.assertGreater(reference.stat().st_size, 0)
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing contact sheet")
        self.assertGreater(CONTACT_SHEET.stat().st_size, 0)

    def test_native_and_runtime_are_exact_nearest_exports(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        for icon_id, spec in pipeline_icons(manifest).items():
            with self.subTest(icon_id=icon_id):
                native = load_rgba(ROOT / spec["native"])
                runtime = load_rgba(ROOT / spec["runtime"])
                self.assertEqual(native.size, (24, 24))
                self.assertEqual(runtime.size, (96, 96))
                expected = native.resize((96, 96), Image.Resampling.NEAREST)
                self.assertEqual(runtime.tobytes(), expected.tobytes(), "runtime must be exact 4x nearest export")

    def test_native_icons_have_clean_alpha_and_readable_coverage(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        for icon_id, spec in pipeline_icons(manifest).items():
            with self.subTest(icon_id=icon_id):
                native = load_rgba(ROOT / spec["native"])
                corners = [
                    native.getpixel((0, 0)),
                    native.getpixel((23, 0)),
                    native.getpixel((0, 23)),
                    native.getpixel((23, 23)),
                ]
                self.assertTrue(all(pixel[3] == 0 for pixel in corners), "native icon corners must be transparent")
                visible = visible_pixel_count(native)
                self.assertGreaterEqual(visible, 45, "native icon is too sparse to read")
                self.assertLessEqual(visible, 460, "native icon fills too much of the canvas")

    def test_game_manager_maps_every_item_to_existing_icon(self) -> None:
        paths = material_icon_paths()
        item_keys = set(json.loads((ROOT / "data" / "items.json").read_text(encoding="utf-8")).keys())
        self.assertEqual(item_keys - set(paths.keys()), set(), "every item key should have a mapped icon")
        for item_key in item_keys:
            with self.subTest(item_key=item_key):
                path = ROOT / paths[item_key]
                self.assertTrue(path.exists(), f"{item_key}: mapped icon missing at {path}")

    def test_failed_products_have_dedicated_item_art(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        paths = material_icon_paths()
        for icon_id in ("failed_brew", "failed_stew"):
            with self.subTest(icon_id=icon_id):
                spec = manifest["icons"][icon_id]
                self.assertEqual(spec["native"], f"assets/source/tavern/missing_item_icons/{icon_id}_native.png")
                self.assertEqual(spec["runtime"], f"assets/textures/tavern/items/{icon_id}.png")
                self.assertEqual(paths[icon_id], f"assets/textures/tavern/items/{icon_id}.png")
                native = load_rgba(ROOT / spec["native"])
                runtime = load_rgba(ROOT / spec["runtime"])
                expected = native.resize((96, 96), Image.Resampling.NEAREST)
                self.assertEqual(runtime.tobytes(), expected.tobytes(), "runtime must be exact 4x nearest export")


if __name__ == "__main__":
    unittest.main(verbosity=2)
