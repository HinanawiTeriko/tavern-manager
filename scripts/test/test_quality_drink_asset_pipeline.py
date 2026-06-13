from __future__ import annotations

import json
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
ITEM_ICON_MANIFEST = ROOT / "assets" / "source" / "tavern" / "missing_item_icons" / "tavern_missing_item_icons_manifest.json"
OLD_QUALITY_MANIFEST = ROOT / "assets" / "source" / "tavern" / "quality_drinks" / "quality_drink_manifest.json"
OLD_QUALITY_RUNTIME_DIR = ROOT / "assets" / "textures" / "tavern" / "quality_drinks"
CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_missing_item_icons_contact_sheet.png"
DRINK_KEYS = ("ale_beer", "wine", "herbal_ale", "spiced_wine")
QUALITY_ICON_IDS = tuple(f"{key}_good" for key in DRINK_KEYS)


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def image_pixels(image: Image.Image):
    return image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()


def visible_pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    return [pixel for pixel in image_pixels(image) if pixel[3] > 0]


def visible_color_count(image: Image.Image) -> int:
    return len({(red, green, blue) for red, green, blue, alpha in image_pixels(image) if alpha > 0})


def alpha_values(image: Image.Image) -> set[int]:
    return set(image_pixels(image.getchannel("A")))


def luma(pixel: tuple[int, int, int, int]) -> float:
    red, green, blue, _alpha = pixel
    return (0.299 * red + 0.587 * green + 0.114 * blue) / 255.0


def bright_pixel_count(image: Image.Image) -> int:
    return sum(1 for pixel in visible_pixels(image) if luma(pixel) > 0.58)


class QualityDrinkAssetPipelineRegressionTest(unittest.TestCase):
    def test_quality_drinks_are_not_a_separate_asset_pipeline(self) -> None:
        self.assertFalse(OLD_QUALITY_MANIFEST.exists(), f"{OLD_QUALITY_MANIFEST}: quality drinks must use item icon pipeline")
        self.assertFalse(OLD_QUALITY_RUNTIME_DIR.exists(), f"{OLD_QUALITY_RUNTIME_DIR}: stale separate runtime directory")

    def test_quality_drinks_use_tavern_item_icon_pipeline_contract(self) -> None:
        manifest = json.loads(ITEM_ICON_MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(set(manifest["quality_icons"].keys()), set(QUALITY_ICON_IDS))
        for icon_id in QUALITY_ICON_IDS:
            with self.subTest(icon_id=icon_id):
                spec = manifest["quality_icons"][icon_id]
                self.assertEqual(
                    spec["source_sheet"],
                    "assets/source/tavern/missing_item_icons/reference/quality_drinks_good_sheet_v1.png",
                )
                self.assertEqual(spec["reference"], f"assets/source/tavern/missing_item_icons/reference/{icon_id}_reference.png")
                self.assertEqual(spec["native"], f"assets/source/tavern/missing_item_icons/{icon_id}_native.png")
                self.assertEqual(spec["runtime"], f"assets/textures/tavern/items/{icon_id}.png")
                self.assertEqual(spec["native_size"], [24, 24])
                self.assertEqual(spec["scale"], 4)
                self.assertEqual(spec["padding"], 2)
                self.assertEqual(spec["safe_area"], [1, 1, 22, 22])

    def test_good_quality_runtime_icons_keep_item_icon_contract(self) -> None:
        manifest = json.loads(ITEM_ICON_MANIFEST.read_text(encoding="utf-8"))
        for drink_key, icon_id in zip(DRINK_KEYS, QUALITY_ICON_IDS):
            with self.subTest(icon_id=icon_id):
                spec = manifest["quality_icons"][icon_id]
                native = load_rgba(ROOT / spec["native"])
                runtime = load_rgba(ROOT / spec["runtime"])
                base = load_rgba(ROOT / manifest["icons"][drink_key]["runtime"])
                self.assertEqual(native.size, (24, 24))
                self.assertEqual(runtime.size, (96, 96))
                expected = native.resize((96, 96), Image.Resampling.NEAREST)
                self.assertEqual(runtime.tobytes(), expected.tobytes(), "runtime must be exact 4x nearest export")
                self.assertEqual(alpha_values(native), {0, 255}, "native item art must use hard pixel alpha")
                self.assertLessEqual(visible_color_count(native), 18, "quality icon must keep the normal item palette budget")
                self.assertGreaterEqual(bright_pixel_count(native), 2, "good quality needs readable premium highlights")
                self.assertNotEqual(runtime.tobytes(), base.tobytes(), "good quality icon should read differently from normal")

    def test_contact_sheet_exists_for_visual_review(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing tavern item icon contact sheet")
        sheet = load_rgba(CONTACT_SHEET)
        self.assertGreaterEqual(sheet.width, 520)
        self.assertGreaterEqual(sheet.height, 220)


if __name__ == "__main__":
    unittest.main(verbosity=2)
