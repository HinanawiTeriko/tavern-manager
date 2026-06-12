from __future__ import annotations

import json
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_sources" / "generated_raw" / "ryan_bust" / "ryan_bust_expression_sheet_v2.png"
PROMPT = ROOT / "art_sources" / "generated_raw" / "ryan_bust" / "ryan_bust_expression_sheet_v2_prompt.txt"
MANIFEST = ROOT / "assets" / "source" / "tavern" / "characters" / "ryan_bust_manifest.json"
SOURCE = ROOT / "assets" / "source" / "tavern" / "characters"
RUNTIME = ROOT / "assets" / "textures" / "characters"
CONTACT_SHEET = ROOT / "docs" / "art" / "ryan_bust_contact_sheet.png"
NATIVE_SIZE = (70, 90)
RUNTIME_SIZE = (280, 360)
SCALE = 4

EXPECTED_CROPS = {
    "ryan_neutral": [18, 100, 430, 760],
    "ryan_excited": [448, 88, 870, 760],
    "ryan_hesitant": [880, 102, 1290, 760],
    "ryan_dejected": [1290, 132, 1722, 760],
}


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_bounds(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A")
    bounds = alpha.getbbox()
    if bounds is None:
        return (0, 0, 0, 0)
    return bounds


class RyanBustAssetPipelineTest(unittest.TestCase):
    def test_generated_source_and_prompt_are_retained(self) -> None:
        self.assertTrue(RAW.exists(), f"{RAW}: missing generated Ryan bust source")
        self.assertGreater(RAW.stat().st_size, 0, "generated Ryan bust source is empty")
        self.assertTrue(PROMPT.exists(), f"{PROMPT}: missing Ryan bust generation prompt")
        self.assertGreater(PROMPT.stat().st_size, 0, "Ryan bust prompt is empty")

    def test_manifest_uses_explicit_crop_rectangles(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing Ryan bust manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["source"], "art_sources/generated_raw/ryan_bust/ryan_bust_expression_sheet_v2.png")
        self.assertEqual(manifest["native_size"], list(NATIVE_SIZE))
        self.assertEqual(manifest["runtime_size"], list(RUNTIME_SIZE))
        entries = manifest["portraits"]
        self.assertEqual(set(entries.keys()), set(EXPECTED_CROPS.keys()))
        for portrait_id, crop_rect in EXPECTED_CROPS.items():
            with self.subTest(portrait_id=portrait_id):
                entry = entries[portrait_id]
                self.assertEqual(entry["crop_rect"], crop_rect)
                self.assertEqual(entry["native"], f"assets/source/tavern/characters/{portrait_id}_native.png")
                self.assertEqual(entry["runtime"], f"assets/textures/characters/{portrait_id}.png")
                self.assertIn("Tavern CustomerSprite", entry["intended_godot_use"])

    def test_native_and_runtime_portraits_are_exact_exports(self) -> None:
        for portrait_id in EXPECTED_CROPS:
            with self.subTest(portrait_id=portrait_id):
                native = load_rgba(SOURCE / f"{portrait_id}_native.png")
                runtime = load_rgba(RUNTIME / f"{portrait_id}.png")
                self.assertEqual(native.size, NATIVE_SIZE)
                self.assertEqual(runtime.size, RUNTIME_SIZE)
                expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
                self.assertEqual(runtime.tobytes(), expected.tobytes(), f"{portrait_id}: runtime is not exact nearest export")

                alpha_min, alpha_max = native.getchannel("A").getextrema()
                self.assertEqual(alpha_min, 0, f"{portrait_id}: needs transparent padding")
                self.assertEqual(alpha_max, 255, f"{portrait_id}: should keep crisp opaque pixels")
                left, top, right, bottom = visible_bounds(native)
                self.assertLessEqual(top, 8, f"{portrait_id}: head sits too low for a readable bust")
                self.assertGreaterEqual(bottom, 78, f"{portrait_id}: bust should extend low enough to be hidden by the bar")
                self.assertGreaterEqual(right - left, 42, f"{portrait_id}: portrait is too narrow")

                raw_pixels = native.tobytes()
                visible_colors = {
                    tuple(raw_pixels[index:index + 4])
                    for index in range(0, len(raw_pixels), 4)
                    if raw_pixels[index + 3] > 0
                }
                self.assertLessEqual(
                    len(visible_colors),
                    36,
                    f"{portrait_id}: palette is too dense and will read like filtered illustration",
                )

    def test_contact_sheet_exists(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing Ryan bust contact sheet")
        self.assertGreater(CONTACT_SHEET.stat().st_size, 0, "Ryan bust contact sheet is empty")


if __name__ == "__main__":
    unittest.main(verbosity=2)
