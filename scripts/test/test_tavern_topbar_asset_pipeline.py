from __future__ import annotations

import json
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "tavern_topbar" / "tavern_topbar_ui_sheet_v2.png"
PROMPT = ROOT / "art_sources" / "generated_raw" / "tavern_topbar" / "tavern_topbar_ui_sheet_v2_prompt.txt"
SOURCE = ROOT / "assets" / "source" / "tavern" / "topbar"
MANIFEST = SOURCE / "tavern_topbar_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_topbar_contact_sheet.png"
ASSETS = {
    "bar_top_panel": ((320, 12), (1280, 48), "bar_top_panel"),
    "topbar_menu_button_normal": ((24, 12), (96, 48), "topbar_menu_button_normal"),
    "topbar_menu_button_hover": ((24, 12), (96, 48), "topbar_menu_button_hover"),
    "topbar_menu_button_pressed": ((24, 12), (96, 48), "topbar_menu_button_pressed"),
    "topbar_end_night_button_normal": ((24, 12), (96, 48), "topbar_end_night_button_normal"),
    "topbar_end_night_button_hover": ((24, 12), (96, 48), "topbar_end_night_button_hover"),
    "topbar_end_night_button_pressed": ((24, 12), (96, 48), "topbar_end_night_button_pressed"),
}


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    raw = image.tobytes()
    return [tuple(raw[index:index + 4]) for index in range(0, len(raw), 4)]


class TavernTopbarAssetPipelineTest(unittest.TestCase):
    def test_generated_source_prompt_and_manifest_are_retained(self) -> None:
        self.assertTrue(RAW_SOURCE.exists(), f"{RAW_SOURCE}: missing generated topbar source")
        self.assertGreater(RAW_SOURCE.stat().st_size, 100_000, "generated topbar source is unexpectedly small")
        self.assertTrue(PROMPT.exists(), f"{PROMPT}: missing topbar generation prompt")
        self.assertGreater(PROMPT.stat().st_size, 0, "topbar prompt is empty")
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing topbar manifest")

        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["id"], "tavern_topbar")
        self.assertEqual(manifest["source"], "art_sources/generated_raw/tavern_topbar/tavern_topbar_ui_sheet_v2.png")
        self.assertEqual(manifest["prompt"], "art_sources/generated_raw/tavern_topbar/tavern_topbar_ui_sheet_v2_prompt.txt")
        self.assertEqual(manifest["scale"], 4)
        self.assertEqual(set(manifest["assets"].keys()), set(ASSETS.keys()))
        for asset_id, (native_size, runtime_size, runtime_id) in ASSETS.items():
            with self.subTest(asset=asset_id):
                asset = manifest["assets"][asset_id]
                self.assertEqual(asset["native"], f"assets/source/tavern/topbar/{asset_id}_native.png")
                self.assertEqual(asset["runtime"], f"assets/textures/ui/{runtime_id}.png")
                self.assertEqual(asset["native_size"], list(native_size))
                self.assertEqual(asset["runtime_size"], list(runtime_size))
                self.assertIn("crop_rect", asset)
                self.assertIn("safe_area", asset)
                self.assertIn("intended_godot_use", asset)

    def test_runtime_is_exact_four_x_nearest_export(self) -> None:
        for asset_id, (native_size, runtime_size, runtime_id) in ASSETS.items():
            native_path = SOURCE / f"{asset_id}_native.png"
            runtime_path = ROOT / "assets" / "textures" / "ui" / f"{runtime_id}.png"
            with self.subTest(asset=asset_id):
                self.assertTrue(native_path.exists(), f"{native_path}: missing native source")
                self.assertTrue(runtime_path.exists(), f"{runtime_path}: missing runtime texture")
                native = load_rgba(native_path)
                runtime = load_rgba(runtime_path)
                self.assertEqual(native.size, native_size)
                self.assertEqual(runtime.size, runtime_size)
                expected = native.resize(runtime_size, Image.Resampling.NEAREST)
                self.assertEqual(runtime.tobytes(), expected.tobytes(), f"{runtime_id}: runtime must be exact 4x nearest export")

    def test_topbar_reads_as_authored_dark_tavern_ui(self) -> None:
        native_path = SOURCE / "bar_top_panel_native.png"
        self.assertTrue(native_path.exists(), f"{native_path}: missing topbar native source")
        native = load_rgba(native_path)
        visible = [pixel for pixel in pixels(native) if pixel[3] > 0]
        self.assertGreater(len(visible), 0, "topbar native image has no visible pixels")

        unique_colors = len(set(visible))
        dark_teal = sum(1 for r, g, b, _a in visible if b >= r and g >= r * 0.65 and r + g + b <= 180)
        amber_edge = sum(1 for r, g, b, _a in visible if r >= 120 and 60 <= g <= 150 and b <= 80)
        dark_body = sum(1 for r, g, b, _a in visible if r + g + b <= 110)

        self.assertGreaterEqual(unique_colors, 12, "topbar should not be a flat procedural rectangle")
        self.assertLessEqual(unique_colors, 36, "topbar palette should stay restrained for pixel UI")
        self.assertGreaterEqual(dark_teal, 500, "topbar needs a dark teal tavern UI bias")
        self.assertGreaterEqual(dark_body, 1800, "topbar should stay dark enough behind HUD text")
        self.assertGreaterEqual(amber_edge, 80, "topbar needs readable amber rim/highlight pixels")

    def test_topbar_buttons_are_authored_not_menu_brush_reuse(self) -> None:
        menu_brush_pixels = None
        menu_brush_path = ROOT / "assets" / "textures" / "ui" / "menu_brush_band.png"
        if menu_brush_path.exists():
            menu_brush_pixels = load_rgba(menu_brush_path).tobytes()

        for asset_id in [asset for asset in ASSETS if asset.startswith("topbar_")]:
            with self.subTest(asset=asset_id):
                native = load_rgba(SOURCE / f"{asset_id}_native.png")
                runtime = load_rgba(ROOT / "assets" / "textures" / "ui" / f"{asset_id}.png")
                visible = [pixel for pixel in pixels(native) if pixel[3] > 0]
                unique_colors = len(set(visible))
                amber_pixels = sum(1 for r, g, b, _a in visible if r >= 110 and 54 <= g <= 150 and b <= 90)
                dark_pixels = sum(1 for r, g, b, _a in visible if r + g + b <= 140)
                self.assertGreaterEqual(unique_colors, 10, f"{asset_id}: button must preserve authored pixel texture")
                self.assertLessEqual(unique_colors, 32, f"{asset_id}: button palette should stay restrained")
                min_amber = 8 if asset_id.endswith("_pressed") else 12
                self.assertGreaterEqual(amber_pixels, min_amber, f"{asset_id}: button needs amber tavern highlight")
                self.assertGreaterEqual(dark_pixels, 90, f"{asset_id}: button needs dark topbar body")
                if menu_brush_pixels is not None:
                    self.assertNotEqual(runtime.tobytes(), menu_brush_pixels, f"{asset_id}: must not reuse menu_brush_band.png")

    def test_contact_sheet_exists(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing topbar contact sheet")
        self.assertGreater(CONTACT_SHEET.stat().st_size, 0, "topbar contact sheet is empty")


if __name__ == "__main__":
    unittest.main(verbosity=2)
