from __future__ import annotations

import json
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_sources" / "generated_raw" / "regular_customers" / "regular_customer_expression_sheet_v1.png"
PROMPT = ROOT / "art_sources" / "generated_raw" / "regular_customers" / "regular_customer_expression_sheet_v1_prompt.txt"
NEW_SOURCES = [
    ROOT / "art_sources" / "generated_raw" / "regular_customers" / "regular_customer_expression_sheet_v2_a.png",
    ROOT / "art_sources" / "generated_raw" / "regular_customers" / "regular_customer_expression_sheet_v2_b.png",
]
NEW_PROMPTS = [
    ROOT / "art_sources" / "generated_raw" / "regular_customers" / "regular_customer_expression_sheet_v2_a_prompt.txt",
    ROOT / "art_sources" / "generated_raw" / "regular_customers" / "regular_customer_expression_sheet_v2_b_prompt.txt",
]
MANIFEST = ROOT / "assets" / "source" / "tavern" / "regular_customers" / "regular_customer_portraits_manifest.json"
SOURCE = ROOT / "assets" / "source" / "tavern" / "regular_customers"
RUNTIME = ROOT / "assets" / "textures" / "characters"
CONTACT_SHEET = ROOT / "docs" / "art" / "regular_customer_portraits_contact_sheet.png"
NATIVE_SIZE = (70, 90)
RUNTIME_SIZE = (280, 360)
SCALE = 4

EXPECTED_IDS = [
    "regular_belta",
    "regular_noel",
    "regular_masha",
    "regular_coen",
    "regular_dorin",
    "regular_elira",
    "regular_marco",
    "regular_nix",
    "regular_selene",
    "regular_gareth",
    "regular_lyra",
    "regular_oma",
]
EXPECTED_STATES = ["neutral", "satisfied", "dissatisfied"]


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_bounds(image: Image.Image) -> tuple[int, int, int, int]:
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        return (0, 0, 0, 0)
    return bounds


class RegularCustomerPortraitPipelineTest(unittest.TestCase):
    def test_generated_source_and_prompt_are_retained(self) -> None:
        self.assertTrue(RAW.exists(), f"{RAW}: missing generated regular customer source")
        self.assertGreater(RAW.stat().st_size, 0, "generated regular customer source is empty")
        self.assertTrue(PROMPT.exists(), f"{PROMPT}: missing regular customer generation prompt")
        self.assertGreater(PROMPT.stat().st_size, 0, "regular customer prompt is empty")
        for source in NEW_SOURCES:
            self.assertTrue(source.exists(), f"{source}: missing generated regular customer source")
            self.assertGreater(source.stat().st_size, 0, f"{source}: generated regular customer source is empty")
        for prompt in NEW_PROMPTS:
            self.assertTrue(prompt.exists(), f"{prompt}: missing regular customer generation prompt")
            prompt_text = prompt.read_text(encoding="utf-8").lower()
            self.assertIn("4 columns x 3 rows", prompt_text)
            self.assertIn("flat solid #00ff00", prompt_text)
            self.assertIn("no readable text", prompt_text)

    def test_manifest_records_all_fixed_crops(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing regular customer manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["source"], "art_sources/generated_raw/regular_customers/regular_customer_expression_sheet_v1.png")
        self.assertEqual(
            manifest["sources"],
            [
                "art_sources/generated_raw/regular_customers/regular_customer_expression_sheet_v1.png",
                "art_sources/generated_raw/regular_customers/regular_customer_expression_sheet_v2_a.png",
                "art_sources/generated_raw/regular_customers/regular_customer_expression_sheet_v2_b.png",
            ],
        )
        self.assertEqual(manifest["native_size"], list(NATIVE_SIZE))
        self.assertEqual(manifest["runtime_size"], list(RUNTIME_SIZE))
        self.assertEqual(manifest["scale"], SCALE)
        entries = manifest["portraits"]
        self.assertEqual(set(entries.keys()), {f"{cid}_{state}" for cid in EXPECTED_IDS for state in EXPECTED_STATES})
        for portrait_id, entry in entries.items():
            with self.subTest(portrait_id=portrait_id):
                self.assertEqual(len(entry["crop_rect"]), 4)
                self.assertEqual(entry["native"], f"assets/source/tavern/regular_customers/{portrait_id}_native.png")
                self.assertEqual(entry["runtime"], f"assets/textures/characters/{portrait_id}.png")
                self.assertIn("Tavern CustomerSprite", entry["intended_godot_use"])

    def test_native_and_runtime_portraits_are_exact_exports(self) -> None:
        for customer_id in EXPECTED_IDS:
            for state in EXPECTED_STATES:
                portrait_id = f"{customer_id}_{state}"
                with self.subTest(portrait_id=portrait_id):
                    native = load_rgba(SOURCE / f"{portrait_id}_native.png")
                    runtime = load_rgba(RUNTIME / f"{portrait_id}.png")
                    self.assertEqual(native.size, NATIVE_SIZE)
                    self.assertEqual(runtime.size, RUNTIME_SIZE)
                    expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
                    self.assertEqual(runtime.tobytes(), expected.tobytes(), f"{portrait_id}: runtime is not nearest export")

                    alpha_min, alpha_max = native.getchannel("A").getextrema()
                    self.assertEqual(alpha_min, 0, f"{portrait_id}: needs transparent padding")
                    self.assertEqual(alpha_max, 255, f"{portrait_id}: should keep opaque visible pixels")
                    left, top, right, bottom = visible_bounds(native)
                    self.assertLessEqual(top, 10, f"{portrait_id}: head sits too low")
                    self.assertGreaterEqual(bottom, 76, f"{portrait_id}: bust should extend low enough for bar occlusion")
                    self.assertGreaterEqual(right - left, 38, f"{portrait_id}: portrait is too narrow")

                    raw_pixels = native.tobytes()
                    visible_colors = {
                        tuple(raw_pixels[index:index + 4])
                        for index in range(0, len(raw_pixels), 4)
                        if raw_pixels[index + 3] > 0
                    }
                    self.assertLessEqual(
                        len(visible_colors),
                        40,
                        f"{portrait_id}: palette is too dense and will read like filtered illustration",
                    )

    def test_contact_sheet_exists(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing contact sheet")
        self.assertGreater(CONTACT_SHEET.stat().st_size, 0, "regular customer contact sheet is empty")


if __name__ == "__main__":
    unittest.main(verbosity=2)
