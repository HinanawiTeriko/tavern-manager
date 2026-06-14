from __future__ import annotations

import json
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_sources" / "generated_raw" / "characters" / "ryan" / "ryan_bust_expression_sheet_v6.png"
PROMPT = ROOT / "art_sources" / "generated_raw" / "characters" / "ryan" / "ryan_bust_expression_sheet_v6_prompt.txt"
MANIFEST = ROOT / "assets" / "source" / "tavern" / "characters" / "ryan_bust_manifest.json"
SOURCE = ROOT / "assets" / "source" / "tavern" / "characters"
RUNTIME = ROOT / "assets" / "textures" / "characters"
CONTACT_SHEET = ROOT / "docs" / "art" / "characters" / "ryan_contact_sheet.png"
NATIVE_SIZE = (128, 160)
RUNTIME_SIZE = (512, 640)
SCALE = 4
CONTACT_SHEET_SIZE = (1600, 820)
CONTACT_SHEET_NATIVE_SCALE = 2
CONTACT_SHEET_NATIVE_PREVIEW_SIZE = (NATIVE_SIZE[0] * CONTACT_SHEET_NATIVE_SCALE, NATIVE_SIZE[1] * CONTACT_SHEET_NATIVE_SCALE)
CONTACT_SHEET_NATIVE_BG = (24, 20, 16, 255)
CONTACT_SHEET_NATIVE_POSITIONS = [
    (44, 92),
    (462, 92),
    (880, 92),
    (1298, 92),
    (44, 452),
    (462, 452),
    (880, 452),
    (1298, 452),
]
STYLE_PROFILE = "approved_mira_vera_belta_runtime_matched_tiefling_contract_runner_v6"
COLOR_LIMIT = 72
MIN_VISIBLE_HEIGHT = 150
MAX_VISIBLE_HEIGHT = 154
MIN_BOTTOM_PADDING = 2
MAX_BOTTOM_PADDING = 5

EXPECTED_CROPS = {
    "ryan_neutral": [2, 2, 382, 510],
    "ryan_confident": [386, 2, 766, 510],
    "ryan_hesitant": [770, 2, 1150, 510],
    "ryan_alarmed": [1154, 2, 1534, 510],
    "ryan_resolved": [2, 514, 382, 1022],
    "ryan_relieved": [386, 514, 766, 1022],
    "ryan_wary": [770, 514, 1150, 1022],
    "ryan_broken": [1154, 514, 1534, 1022],
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


def expected_backed_native_preview(native: Image.Image) -> Image.Image:
    preview = native.resize(CONTACT_SHEET_NATIVE_PREVIEW_SIZE, Image.Resampling.NEAREST)
    out = Image.new("RGBA", CONTACT_SHEET_NATIVE_PREVIEW_SIZE, CONTACT_SHEET_NATIVE_BG)
    out.alpha_composite(preview, (0, 0))
    return out.convert("RGB")


class RyanBustAssetPipelineTest(unittest.TestCase):
    def test_generated_source_and_prompt_are_retained(self) -> None:
        self.assertTrue(RAW.exists(), f"{RAW}: missing generated Ryan bust source")
        self.assertGreater(RAW.stat().st_size, 0, "generated Ryan bust source is empty")
        with Image.open(RAW) as source:
            self.assertEqual(source.size, (1536, 1024), "Ryan v6 source must remain the approved 4x2 sheet")
        self.assertTrue(PROMPT.exists(), f"{PROMPT}: missing Ryan bust generation prompt")
        self.assertGreater(PROMPT.stat().st_size, 0, "Ryan bust prompt is empty")
        prompt = PROMPT.read_text(encoding="utf-8").lower()
        for phrase in (
            "approved mira/vera/belta",
            "same artist family",
            "tiefling contract runner",
            "head including horns",
            "belt and upper hips",
            "128x160",
            "512x640",
            "4 columns x 2 rows",
            "eight expressions",
            "flat solid #00ff00",
            "no readable text",
        ):
            self.assertIn(phrase, prompt)

    def test_manifest_uses_explicit_crop_rectangles(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing Ryan bust manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["style_profile"], STYLE_PROFILE)
        self.assertEqual(manifest["source"], "art_sources/generated_raw/characters/ryan/ryan_bust_expression_sheet_v6.png")
        self.assertEqual(manifest["prompt"], "art_sources/generated_raw/characters/ryan/ryan_bust_expression_sheet_v6_prompt.txt")
        self.assertEqual(manifest["normalization"]["mode"], "explicit_crop_visible_subject_v6")
        self.assertEqual(manifest["native_size"], list(NATIVE_SIZE))
        self.assertEqual(manifest["runtime_size"], list(RUNTIME_SIZE))
        self.assertEqual(manifest["scale"], SCALE)
        entries = manifest["portraits"]
        self.assertEqual(set(entries.keys()), set(EXPECTED_CROPS.keys()))
        for portrait_id, crop_rect in EXPECTED_CROPS.items():
            with self.subTest(portrait_id=portrait_id):
                entry = entries[portrait_id]
                self.assertEqual(entry["crop_rect"], crop_rect)
                self.assertEqual(entry["normalization"]["mode"], "explicit_crop_visible_subject_v6")
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
                self.assertLessEqual(top, 20, f"{portrait_id}: head sits too low for a readable bust")
                self.assertGreaterEqual(bottom, 146, f"{portrait_id}: bust should extend low enough to be hidden by the bar")
                self.assertGreaterEqual(bottom - top, MIN_VISIBLE_HEIGHT, f"{portrait_id}: visible figure is too short")
                self.assertLessEqual(bottom - top, MAX_VISIBLE_HEIGHT, f"{portrait_id}: visible figure is too tall")
                bottom_padding = native.height - bottom
                self.assertGreaterEqual(bottom_padding, MIN_BOTTOM_PADDING, f"{portrait_id}: touches bottom edge")
                self.assertLessEqual(bottom_padding, MAX_BOTTOM_PADDING, f"{portrait_id}: floats too high")
                self.assertGreaterEqual(right - left, 64, f"{portrait_id}: portrait is too narrow")

                raw_pixels = native.tobytes()
                visible_colors = {
                    tuple(raw_pixels[index:index + 4])
                    for index in range(0, len(raw_pixels), 4)
                    if raw_pixels[index + 3] > 0
                }
                self.assertLessEqual(
                    len(visible_colors),
                    COLOR_LIMIT,
                    f"{portrait_id}: palette is too dense and will read like filtered illustration",
                )

    def test_contact_sheet_exists(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing Ryan bust contact sheet")
        self.assertGreater(CONTACT_SHEET.stat().st_size, 0, "Ryan bust contact sheet is empty")
        contact = load_rgba(CONTACT_SHEET)
        self.assertEqual(contact.size, CONTACT_SHEET_SIZE, "Ryan contact sheet defines the official important NPC preview size")

    def test_contact_sheet_uses_integer_native_previews(self) -> None:
        contact = load_rgba(CONTACT_SHEET).convert("RGB")
        for index, portrait_id in enumerate(EXPECTED_CROPS):
            with self.subTest(portrait_id=portrait_id):
                native = load_rgba(SOURCE / f"{portrait_id}_native.png")
                x, y = CONTACT_SHEET_NATIVE_POSITIONS[index]
                actual_native = contact.crop((
                    x,
                    y,
                    x + CONTACT_SHEET_NATIVE_PREVIEW_SIZE[0],
                    y + CONTACT_SHEET_NATIVE_PREVIEW_SIZE[1],
                ))
                self.assertEqual(
                    actual_native.tobytes(),
                    expected_backed_native_preview(native).tobytes(),
                    f"{portrait_id}: contact sheet native preview must be exact 2x native pixels",
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
