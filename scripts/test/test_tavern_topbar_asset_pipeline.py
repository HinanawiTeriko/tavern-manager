from __future__ import annotations

import json
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "tavern_topbar" / "tavern_topbar_reference_v1.png"
PROMPT = ROOT / "art_sources" / "generated_raw" / "tavern_topbar" / "tavern_topbar_reference_v1_prompt.txt"
SOURCE = ROOT / "assets" / "source" / "tavern" / "topbar"
MANIFEST = SOURCE / "tavern_topbar_manifest.json"
NATIVE = SOURCE / "bar_top_panel_native.png"
RUNTIME = ROOT / "assets" / "textures" / "ui" / "bar_top_panel.png"
CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_topbar_contact_sheet.png"
NATIVE_SIZE = (320, 12)
RUNTIME_SIZE = (1280, 48)


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
        self.assertEqual(manifest["source"], "art_sources/generated_raw/tavern_topbar/tavern_topbar_reference_v1.png")
        self.assertEqual(manifest["native"], "assets/source/tavern/topbar/bar_top_panel_native.png")
        self.assertEqual(manifest["runtime"], "assets/textures/ui/bar_top_panel.png")
        self.assertEqual(manifest["native_size"], list(NATIVE_SIZE))
        self.assertEqual(manifest["runtime_size"], list(RUNTIME_SIZE))
        self.assertEqual(manifest["safe_area"], [8, 1, 312, 11])
        self.assertEqual(manifest["intended_godot_use"], "Tavern TopPanelBg long pixel UI strip")

    def test_runtime_is_exact_four_x_nearest_export(self) -> None:
        self.assertTrue(NATIVE.exists(), f"{NATIVE}: missing topbar native source")
        self.assertTrue(RUNTIME.exists(), f"{RUNTIME}: missing topbar runtime texture")
        native = load_rgba(NATIVE)
        runtime = load_rgba(RUNTIME)
        self.assertEqual(native.size, NATIVE_SIZE)
        self.assertEqual(runtime.size, RUNTIME_SIZE)
        expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
        self.assertEqual(runtime.tobytes(), expected.tobytes(), "topbar runtime must be exact 4x nearest export")

    def test_topbar_reads_as_authored_dark_tavern_ui(self) -> None:
        self.assertTrue(NATIVE.exists(), f"{NATIVE}: missing topbar native source")
        native = load_rgba(NATIVE)
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

    def test_contact_sheet_exists(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing topbar contact sheet")
        self.assertGreater(CONTACT_SHEET.stat().st_size, 0, "topbar contact sheet is empty")


if __name__ == "__main__":
    unittest.main(verbosity=2)
