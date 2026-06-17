from __future__ import annotations

import json
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = ROOT / "art_sources" / "generated_raw" / "rare_gathering"
SOURCE_DIR = ROOT / "assets" / "source" / "rare_gathering"
MANIFEST = SOURCE_DIR / "rare_gathering_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "rare_gathering_contact_sheet.png"
OUTLINE = (20, 16, 12, 255)

ITEMS = [
    ("cave_mushroom", "assets/textures/tavern/icons/cave_mushroom.png"),
    ("rock_lizard_meat", "assets/textures/tavern/icons/rock_lizard_meat.png"),
    ("north_sour_grape", "assets/textures/tavern/icons/north_sour_grape.png"),
    ("black_malt", "assets/textures/tavern/icons/black_malt.png"),
]
UPGRADED_PRODUCT_IDS = {
    "cave_mushroom_stew",
    "rock_lizard_steak",
    "old_road_wine",
    "miner_dark_ale",
}


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def rgba_pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    raw = image.tobytes()
    return [tuple(raw[index:index + 4]) for index in range(0, len(raw), 4)]


class RareGatheringAssetPipelineTest(unittest.TestCase):
    def test_raw_sources_and_manifest_are_retained(self) -> None:
        self.assertTrue(RAW_DIR.exists(), f"{RAW_DIR}: missing raw rare gathering source directory")
        for filename in [
            "rare_material_icons_sheet_v1.png",
            "rare_gathering_icon_sheets_prompt_v1.txt",
        ]:
            with self.subTest(filename=filename):
                path = RAW_DIR / filename
                self.assertTrue(path.exists(), f"{path}: missing retained raw source")
                self.assertGreater(path.stat().st_size, 0, f"{path}: retained raw source is empty")

        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing rare gathering manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["id"], "rare_gathering_icons")
        self.assertEqual(manifest["scale"], 4)
        self.assertEqual(manifest["source_files"], ["art_sources/generated_raw/rare_gathering/rare_material_icons_sheet_v1.png"])
        self.assertEqual(set(manifest["assets"].keys()), {item_id for item_id, _runtime in ITEMS})
        self.assertTrue(UPGRADED_PRODUCT_IDS.isdisjoint(manifest["assets"].keys()))

        for item_id, runtime_rel in ITEMS:
            with self.subTest(item_id=item_id):
                asset = manifest["assets"][item_id]
                self.assertEqual(asset["native"], f"assets/source/rare_gathering/{item_id}.png")
                self.assertEqual(asset["runtime"], runtime_rel)
                self.assertEqual(asset["native_size"], [24, 24])
                self.assertEqual(asset["runtime_size"], [96, 96])
                self.assertEqual(asset["source"], "art_sources/generated_raw/rare_gathering/rare_material_icons_sheet_v1.png")
                self.assertEqual(len(asset["crop_rect"]), 4)
                self.assertEqual(len(asset["safe_area"]), 4)
                self.assertIn("intended_godot_use", asset)

    def test_runtime_icons_are_exact_nearest_exports(self) -> None:
        for item_id, runtime_rel in ITEMS:
            native_path = SOURCE_DIR / f"{item_id}.png"
            runtime_path = ROOT / runtime_rel
            with self.subTest(item_id=item_id):
                self.assertTrue(native_path.exists(), f"{native_path}: missing cleaned native icon")
                self.assertTrue(runtime_path.exists(), f"{runtime_path}: missing runtime icon")
                native = load_rgba(native_path)
                runtime = load_rgba(runtime_path)
                self.assertEqual(native.size, (24, 24))
                self.assertEqual(runtime.size, (96, 96))
                expected = native.resize((96, 96), Image.Resampling.NEAREST)
                self.assertEqual(runtime.tobytes(), expected.tobytes(), f"{item_id}: runtime must be exact 4x nearest export")

    def test_upgraded_product_natives_are_not_owned_by_rare_gathering_pipeline(self) -> None:
        for item_id in UPGRADED_PRODUCT_IDS:
            with self.subTest(item_id=item_id):
                self.assertFalse(
                    (SOURCE_DIR / f"{item_id}.png").exists(),
                    f"{item_id}: upgraded dish natives should be owned by tavern missing item icon pipeline",
                )

    def test_icons_are_visible_and_restrained_pixel_assets(self) -> None:
        for item_id, _runtime_rel in ITEMS:
            with self.subTest(item_id=item_id):
                native = load_rgba(SOURCE_DIR / f"{item_id}.png")
                visible = [pixel for pixel in rgba_pixels(native) if pixel[3] > 0]
                self.assertGreater(len(visible), 72, f"{item_id}: icon has too little visible mass")
                self.assertLess(len(visible), 560, f"{item_id}: icon overfills the 24x24 icon area")
                self.assertLessEqual(len(set(visible)), 16, f"{item_id}: palette should match tavern item icon restraint")
                self.assertGreaterEqual(visible.count(OUTLINE), 8, f"{item_id}: needs the shared tavern item outline color")
                self.assertGreater(
                    sum(1 for r, g, b, _a in visible if r + g + b <= 150),
                    14,
                    f"{item_id}: needs dark outline/body pixels for readability",
                )
                self.assertEqual(native.getpixel((0, 0))[3], 0, f"{item_id}: top-left corner should be transparent")

    def test_contact_sheet_exists(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing rare gathering contact sheet")
        self.assertGreater(CONTACT_SHEET.stat().st_size, 0, "rare gathering contact sheet is empty")


if __name__ == "__main__":
    unittest.main(verbosity=2)
