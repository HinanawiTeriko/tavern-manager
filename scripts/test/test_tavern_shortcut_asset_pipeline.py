from __future__ import annotations

import json
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "tavern_shortcut_bar" / "tavern_shortcut_bar_ui_sheet_v1.png"
PROMPT = ROOT / "art_sources" / "generated_raw" / "tavern_shortcut_bar" / "tavern_shortcut_bar_ui_sheet_v1_prompt.txt"
SOURCE = ROOT / "assets" / "source" / "tavern" / "shortcut"
MANIFEST = SOURCE / "tavern_shortcut_bar_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_shortcut_bar_contact_sheet.png"
ASSETS = {
    "bar_shortcut_bg": ((250, 10), (1000, 40), "bar_shortcut_bg"),
    "shortcut_slot_empty": ((24, 10), (96, 40), "shortcut_slot_empty"),
    "shortcut_slot_filled": ((24, 10), (96, 40), "shortcut_slot_filled"),
    "shortcut_slot_hover": ((24, 10), (96, 40), "shortcut_slot_hover"),
}


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    raw = image.tobytes()
    return [tuple(raw[index:index + 4]) for index in range(0, len(raw), 4)]


class TavernShortcutAssetPipelineTest(unittest.TestCase):
    def test_generated_source_prompt_and_manifest_are_retained(self) -> None:
        self.assertTrue(RAW_SOURCE.exists(), f"{RAW_SOURCE}: missing generated shortcut source")
        self.assertGreater(RAW_SOURCE.stat().st_size, 100_000, "generated shortcut source is unexpectedly small")
        self.assertTrue(PROMPT.exists(), f"{PROMPT}: missing shortcut generation prompt")
        self.assertGreater(PROMPT.stat().st_size, 0, "shortcut prompt is empty")
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing shortcut manifest")

        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["id"], "tavern_shortcut_bar")
        self.assertEqual(manifest["source"], "art_sources/generated_raw/tavern_shortcut_bar/tavern_shortcut_bar_ui_sheet_v1.png")
        self.assertEqual(manifest["prompt"], "art_sources/generated_raw/tavern_shortcut_bar/tavern_shortcut_bar_ui_sheet_v1_prompt.txt")
        self.assertEqual(manifest["scale"], 4)
        self.assertEqual(set(manifest["assets"].keys()), set(ASSETS.keys()))
        for asset_id, (native_size, runtime_size, runtime_id) in ASSETS.items():
            with self.subTest(asset=asset_id):
                asset = manifest["assets"][asset_id]
                self.assertEqual(asset["native"], f"assets/source/tavern/shortcut/{asset_id}_native.png")
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

    def test_shortcut_art_reads_as_dedicated_dark_tavern_ui(self) -> None:
        for asset_id in ASSETS:
            with self.subTest(asset=asset_id):
                native = load_rgba(SOURCE / f"{asset_id}_native.png")
                visible = [pixel for pixel in pixels(native) if pixel[3] > 0]
                self.assertGreater(len(visible), 0, f"{asset_id}: no visible pixels")
                unique_colors = len(set(visible))
                dark_teal = sum(1 for r, g, b, _a in visible if b >= r and g >= r * 0.55 and r + g + b <= 190)
                warm_wood = sum(1 for r, g, b, _a in visible if r >= 30 and 14 <= g <= 90 and b <= 45 and r >= b * 1.6)
                amber_edge = sum(1 for r, g, b, _a in visible if r >= 80 and 35 <= g <= 155 and b <= 95)
                dark_body = sum(1 for r, g, b, _a in visible if r + g + b <= 125)
                self.assertGreaterEqual(unique_colors, 10, f"{asset_id}: must preserve authored pixel texture")
                self.assertLessEqual(unique_colors, 36, f"{asset_id}: palette should stay restrained")
                self.assertGreaterEqual(dark_teal, 25, f"{asset_id}: needs dark teal tavern UI bias")
                self.assertGreaterEqual(warm_wood, 12 if asset_id != "bar_shortcut_bg" else 150,
                    f"{asset_id}: needs warm wood rim pixels")
                if asset_id == "shortcut_slot_hover":
                    self.assertGreaterEqual(amber_edge, 12, f"{asset_id}: hover needs amber edge pixels")
                self.assertGreaterEqual(dark_body, 70 if asset_id != "bar_shortcut_bg" else 700,
                    f"{asset_id}: needs dark body mass")

    def test_shortcut_assets_are_not_menu_brush_reuse(self) -> None:
        old_assets = []
        for old_name in ["menu_brush_panel.png", "menu_brush_tab.png"]:
            old_path = ROOT / "assets" / "textures" / "ui" / old_name
            if old_path.exists():
                old_assets.append(load_rgba(old_path).tobytes())
        self.assertGreater(len(old_assets), 0, "old menu brush references should exist for reuse guard")

        for asset_id, (_native_size, _runtime_size, runtime_id) in ASSETS.items():
            with self.subTest(asset=asset_id):
                runtime = load_rgba(ROOT / "assets" / "textures" / "ui" / f"{runtime_id}.png")
                for old_pixels in old_assets:
                    self.assertNotEqual(runtime.tobytes(), old_pixels, f"{asset_id}: must not reuse menu brush art")

    def test_contact_sheet_exists(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing shortcut contact sheet")
        self.assertGreater(CONTACT_SHEET.stat().st_size, 0, "shortcut contact sheet is empty")


if __name__ == "__main__":
    unittest.main(verbosity=2)
