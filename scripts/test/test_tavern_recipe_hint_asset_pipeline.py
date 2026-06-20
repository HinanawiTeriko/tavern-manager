from __future__ import annotations

import json
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = ROOT / "art_sources" / "generated_raw" / "recipe_hint_strip"
PROMPT = RAW_DIR / "recipe_hint_strip_prompt_v1.txt"
RAW_SOURCE = RAW_DIR / "recipe_hint_strip_source_v1.png"
EXPORTER = ROOT / "scripts" / "tools" / "export_tavern_recipe_hint_assets.py"
SOURCE_DIR = ROOT / "assets" / "source" / "ui" / "recipe_hint_strip"
RUNTIME_DIR = ROOT / "assets" / "textures" / "ui" / "recipe_hint_strip"
MANIFEST = SOURCE_DIR / "recipe_hint_strip_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "recipe_hint_strip_contact_sheet.png"

ASSET_ID = "recipe_hint_strip_panel"
NATIVE_SIZE = (118, 14)
RUNTIME_SIZE = (472, 56)
SCALE = 4


def load_rgba(path: Path) -> Image.Image:
    if not path.exists():
        raise AssertionError(f"{path}: missing image")
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    return [
        (red, green, blue, alpha)
        for red, green, blue, alpha in image.get_flattened_data()
        if alpha > 0
    ]


class TavernRecipeHintAssetPipelineTest(unittest.TestCase):
    def test_raw_imagegen_source_and_prompt_are_retained(self) -> None:
        self.assertTrue(RAW_SOURCE.exists(), f"{RAW_SOURCE}: missing extracted imagegen source")
        self.assertTrue(PROMPT.exists(), f"{PROMPT}: missing prompt record")
        self.assertGreater(RAW_SOURCE.stat().st_size, 0, "recipe hint raw source is empty")
        prompt = PROMPT.read_text(encoding="utf-8")
        self.assertIn("recipe hint strip", prompt)
        self.assertIn("no readable text", prompt.lower())

    def test_exporter_uses_fixed_manifest_rectangles(self) -> None:
        self.assertTrue(EXPORTER.exists(), f"{EXPORTER}: missing recipe hint exporter")
        source = EXPORTER.read_text(encoding="utf-8")
        self.assertIn("SOURCE_RECTS", source)
        self.assertNotIn("getbbox()", source, "recipe hint crops must use fixed rectangles")
        self.assertNotIn("connected", source.lower(), "recipe hint crops must not use connected component guessing")

    def test_native_and_runtime_assets_are_exact_nearest_exports(self) -> None:
        native = load_rgba(SOURCE_DIR / f"{ASSET_ID}_native.png")
        runtime = load_rgba(RUNTIME_DIR / f"{ASSET_ID}.png")
        self.assertEqual(native.size, NATIVE_SIZE)
        self.assertEqual(runtime.size, RUNTIME_SIZE)
        expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
        self.assertEqual(runtime.tobytes(), expected.tobytes())
        self.assertGreater(len(visible_pixels(native)), 900, "recipe hint strip has too few visible pixels")
        self.assertLess(len(visible_pixels(native)), native.width * native.height, "recipe hint strip should keep transparent outside pixels")

    def test_runtime_asset_uses_warm_paper_and_wood_palette(self) -> None:
        native = load_rgba(SOURCE_DIR / f"{ASSET_ID}_native.png")
        pixels = visible_pixels(native)
        paper_pixels = sum(
            1
            for red, green, blue, alpha in pixels
            if alpha >= 180 and red >= 145 and green >= 92 and blue <= 132 and red > green >= blue
        )
        dark_wood_pixels = sum(
            1
            for red, green, blue, alpha in pixels
            if alpha >= 180 and red <= 92 and green <= 62 and blue <= 44
        )
        cyan_pixels = sum(
            1
            for red, green, blue, alpha in pixels
            if alpha >= 120 and green >= 90 and blue >= 85 and red <= 85
        )
        chroma_pixels = sum(
            1
            for red, green, blue, alpha in pixels
            if alpha > 0 and green >= 180 and green > red * 1.4 and green > blue * 1.4
        )
        self.assertGreaterEqual(paper_pixels, 520, "recipe hint needs a readable warm paper center")
        self.assertGreaterEqual(dark_wood_pixels, 120, "recipe hint needs dark wood or ink edge pixels")
        self.assertEqual(cyan_pixels, 0, "recipe hint should not read as the old cyan menu panel")
        self.assertEqual(chroma_pixels, 0, "recipe hint should not retain chroma-key green pixels")

    def test_manifest_records_runtime_contract(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest.get("id"), "recipe_hint_strip")
        self.assertEqual(manifest.get("raw_source"), RAW_SOURCE.relative_to(ROOT).as_posix())
        self.assertEqual(manifest.get("prompt"), PROMPT.relative_to(ROOT).as_posix())
        self.assertEqual(manifest.get("scale"), SCALE)
        self.assertEqual(manifest.get("contact_sheet"), CONTACT_SHEET.relative_to(ROOT).as_posix())
        asset = manifest.get("assets", {}).get(ASSET_ID, {})
        self.assertEqual(asset.get("source_file"), RAW_SOURCE.relative_to(ROOT).as_posix())
        self.assertEqual(len(asset.get("source_rect", [])), 4)
        self.assertEqual(asset.get("native_size"), list(NATIVE_SIZE))
        self.assertEqual(asset.get("runtime_size"), list(RUNTIME_SIZE))
        self.assertEqual(asset.get("native_file"), f"assets/source/ui/recipe_hint_strip/{ASSET_ID}_native.png")
        self.assertEqual(asset.get("runtime_file"), f"assets/textures/ui/recipe_hint_strip/{ASSET_ID}.png")
        self.assertEqual(asset.get("safe_area"), [96, 10, 400, 34])
        self.assertEqual(asset.get("nine_slice_margins"), [56, 20, 56, 20])
        self.assertIn("RecipeHintPanel", asset.get("intended_godot_use", ""))

    def test_contact_sheet_exists_for_visual_review(self) -> None:
        sheet = load_rgba(CONTACT_SHEET)
        self.assertGreaterEqual(sheet.width, RUNTIME_SIZE[0])
        self.assertGreaterEqual(sheet.height, RUNTIME_SIZE[1])


if __name__ == "__main__":
    unittest.main(verbosity=2)
