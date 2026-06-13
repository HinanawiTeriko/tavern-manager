from __future__ import annotations

import json
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCES = [
    ROOT / "art_sources" / "generated_raw" / "regular_customers" / "regular_customer_expression_sheet_v5_a.png",
    ROOT / "art_sources" / "generated_raw" / "regular_customers" / "regular_customer_expression_sheet_v5_b.png",
    ROOT / "art_sources" / "generated_raw" / "regular_customers" / "regular_customer_expression_sheet_v5_c.png",
]
PROMPTS = [
    ROOT / "art_sources" / "generated_raw" / "regular_customers" / "regular_customer_expression_sheet_v5_a_prompt.txt",
    ROOT / "art_sources" / "generated_raw" / "regular_customers" / "regular_customer_expression_sheet_v5_b_prompt.txt",
    ROOT / "art_sources" / "generated_raw" / "regular_customers" / "regular_customer_expression_sheet_v5_c_prompt.txt",
]
MANIFEST = ROOT / "assets" / "source" / "tavern" / "regular_customers" / "regular_customer_portraits_manifest.json"
SOURCE = ROOT / "assets" / "source" / "tavern" / "regular_customers"
RUNTIME = ROOT / "assets" / "textures" / "characters"
CONTACT_SHEET = ROOT / "docs" / "art" / "regular_customer_portraits_contact_sheet.png"
PILOT_SOURCE = ROOT / "art_sources" / "generated_raw" / "regular_customers" / "regular_belta_neutral_pilot_source_v1.png"
PILOT_PROMPT = ROOT / "art_sources" / "generated_raw" / "regular_customers" / "regular_belta_neutral_pilot_prompt_v1.txt"
VERA_REFERENCE = ROOT / "art_sources" / "generated_raw" / "tutorial_narrator" / "female_bartender_scribe_pixel_source_v2.png"
NATIVE_SIZE = (128, 160)
RUNTIME_SIZE = (512, 640)
PILOT_PORTRAIT_ID = "regular_belta_neutral"
SCALE = 4
STYLE_PROFILE = "approved_vera_belta_runtime_matched_regular_portraits_v5"
MIN_UNIFORM_VISIBLE_HEIGHT = 138
MAX_UNIFORM_VISIBLE_HEIGHT = 154
MIN_UNIFORM_BOTTOM_PADDING = 2
MAX_UNIFORM_BOTTOM_PADDING = 5
UNIFORM_VISIBLE_HEIGHT = 154
UNIFORM_MAX_VISIBLE_WIDTH = 128
UNIFORM_BOTTOM_PADDING = 3
MIN_CONTACT_SHEET_SIZE = (1700, 2200)
CONTACT_SHEET_MARGIN = 24
CONTACT_SHEET_TITLE_H = 40
CONTACT_SHEET_PANEL_SIZE = (300, 374)
CONTACT_SHEET_PREVIEW_AREA_H = 326
CONTACT_SHEET_PREVIEW_SCALE = 2
CONTACT_SHEET_CHECKER_TILE = 16

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


def checkerboard(size: tuple[int, int], tile: int = CONTACT_SHEET_CHECKER_TILE) -> Image.Image:
    out = Image.new("RGBA", size, (44, 44, 44, 255))
    pixels = out.load()
    for y in range(size[1]):
        for x in range(size[0]):
            if (x // tile + y // tile) % 2 == 0:
                pixels[x, y] = (58, 58, 58, 255)
    return out


class RegularCustomerPortraitPipelineTest(unittest.TestCase):
    def test_generated_source_and_prompt_are_retained(self) -> None:
        for source in RAW_SOURCES:
            self.assertTrue(source.exists(), f"{source}: missing generated regular customer source")
            self.assertGreater(source.stat().st_size, 0, f"{source}: generated regular customer source is empty")
        self.assertTrue(PILOT_SOURCE.exists(), f"{PILOT_SOURCE}: missing generated pilot source")
        self.assertGreater(PILOT_SOURCE.stat().st_size, 0, "generated pilot source is empty")
        for prompt in PROMPTS:
            self.assertTrue(prompt.exists(), f"{prompt}: missing regular customer generation prompt")
            prompt_text = prompt.read_text(encoding="utf-8").lower()
            self.assertIn("visible reference image of vera", prompt_text)
            self.assertIn("visible reference image of belta", prompt_text)
            self.assertIn("approved vera/belta four panel", prompt_text)
            self.assertIn("runtime-scale locked", prompt_text)
            self.assertIn("4 columns x 3 rows", prompt_text)
            self.assertIn("flat solid #00ff00", prompt_text)
            self.assertIn("no readable text", prompt_text)
            self.assertIn("do not copy vera", prompt_text)
            self.assertIn("do not copy belta", prompt_text)
            self.assertIn("same artist family", prompt_text)
        self.assertTrue(VERA_REFERENCE.exists(), f"{VERA_REFERENCE}: missing accepted Vera style reference")
        self.assertTrue(PILOT_PROMPT.exists(), f"{PILOT_PROMPT}: missing pilot prompt")
        pilot_prompt = PILOT_PROMPT.read_text(encoding="utf-8").lower()
        self.assertIn("visible reference image of vera", pilot_prompt)
        self.assertIn("128x160", pilot_prompt)
        self.assertIn("512x640", pilot_prompt)
        self.assertIn("flat solid #00ff00", pilot_prompt)
        self.assertIn("face must remain readable", pilot_prompt)

    def test_manifest_records_all_fixed_crops(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing regular customer manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["style_profile"], STYLE_PROFILE)
        self.assertEqual(manifest["source"], "art_sources/generated_raw/regular_customers/regular_customer_expression_sheet_v5_a.png")
        self.assertEqual(
            manifest["style_references"],
            [
                "art_sources/generated_raw/tutorial_narrator/female_bartender_scribe_pixel_source_v2.png",
                "art_sources/generated_raw/regular_customers/regular_belta_neutral_pilot_source_v1.png",
            ],
        )
        self.assertEqual(
            manifest["sources"],
            [
                "art_sources/generated_raw/regular_customers/regular_customer_expression_sheet_v5_a.png",
                "art_sources/generated_raw/regular_customers/regular_customer_expression_sheet_v5_b.png",
                "art_sources/generated_raw/regular_customers/regular_customer_expression_sheet_v5_c.png",
                "art_sources/generated_raw/regular_customers/regular_belta_neutral_pilot_source_v1.png",
            ],
        )
        self.assertEqual(
            manifest["prompt_sources"],
            [
                "art_sources/generated_raw/regular_customers/regular_customer_expression_sheet_v5_a_prompt.txt",
                "art_sources/generated_raw/regular_customers/regular_customer_expression_sheet_v5_b_prompt.txt",
                "art_sources/generated_raw/regular_customers/regular_customer_expression_sheet_v5_c_prompt.txt",
                "art_sources/generated_raw/regular_customers/regular_belta_neutral_pilot_prompt_v1.txt",
            ],
        )
        self.assertEqual(manifest["native_size"], list(NATIVE_SIZE))
        self.assertEqual(manifest["runtime_size"], list(RUNTIME_SIZE))
        self.assertEqual(manifest["scale"], SCALE)
        self.assertEqual(manifest["uniform_visible_height"], UNIFORM_VISIBLE_HEIGHT)
        self.assertEqual(manifest["uniform_max_visible_width"], UNIFORM_MAX_VISIBLE_WIDTH)
        self.assertEqual(manifest["uniform_bottom_padding"], UNIFORM_BOTTOM_PADDING)
        self.assertIn("pilot_portraits", manifest)
        self.assertEqual(manifest["pilot_portraits"], [PILOT_PORTRAIT_ID])
        entries = manifest["portraits"]
        self.assertEqual(set(entries.keys()), {f"{cid}_{state}" for cid in EXPECTED_IDS for state in EXPECTED_STATES})
        for portrait_id, entry in entries.items():
            with self.subTest(portrait_id=portrait_id):
                self.assertEqual(len(entry["crop_rect"]), 4)
                self.assertEqual(entry["native"], f"assets/source/tavern/regular_customers/{portrait_id}_native.png")
                self.assertEqual(entry["runtime"], f"assets/textures/characters/{portrait_id}.png")
                self.assertIn(entry["source"], manifest["sources"])
                if portrait_id == PILOT_PORTRAIT_ID:
                    self.assertEqual(entry["source"], "art_sources/generated_raw/regular_customers/regular_belta_neutral_pilot_source_v1.png")
                    self.assertEqual(entry["prompt"], "art_sources/generated_raw/regular_customers/regular_belta_neutral_pilot_prompt_v1.txt")
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
                    self.assertLessEqual(top, 20, f"{portrait_id}: head sits too low compared with approved Vera/Belta runtime")
                    self.assertGreaterEqual(bottom, 146, f"{portrait_id}: bust should extend to the approved bar-front crop depth")
                    self.assertGreaterEqual(
                        bottom - top,
                        MIN_UNIFORM_VISIBLE_HEIGHT,
                        f"{portrait_id}: visible figure is too short for a uniform sheet",
                    )
                    self.assertLessEqual(
                        bottom - top,
                        MAX_UNIFORM_VISIBLE_HEIGHT,
                        f"{portrait_id}: visible figure is too tall for a uniform sheet",
                    )
                    bottom_padding = native.height - bottom
                    self.assertGreaterEqual(
                        bottom_padding,
                        MIN_UNIFORM_BOTTOM_PADDING,
                        f"{portrait_id}: visible figure is too close to the bottom edge for a uniform sheet",
                    )
                    self.assertLessEqual(
                        bottom_padding,
                        MAX_UNIFORM_BOTTOM_PADDING,
                        f"{portrait_id}: visible figure floats too high above the bottom edge for a uniform sheet",
                    )
                    self.assertGreaterEqual(right - left, 64, f"{portrait_id}: portrait is too narrow for readable facial detail")

                    raw_pixels = native.tobytes()
                    visible_colors = {
                        tuple(raw_pixels[index:index + 4])
                        for index in range(0, len(raw_pixels), 4)
                        if raw_pixels[index + 3] > 0
                    }
                    max_visible_colors = 72
                    self.assertLessEqual(
                        len(visible_colors),
                        max_visible_colors,
                        f"{portrait_id}: palette is too dense and will read like filtered illustration",
                    )

    def test_contact_sheet_exists(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing contact sheet")
        self.assertGreater(CONTACT_SHEET.stat().st_size, 0, "regular customer contact sheet is empty")
        with Image.open(CONTACT_SHEET) as sheet:
            self.assertGreaterEqual(sheet.width, MIN_CONTACT_SHEET_SIZE[0])
            self.assertGreaterEqual(sheet.height, MIN_CONTACT_SHEET_SIZE[1])

    def test_contact_sheet_uses_integer_native_preview_for_belta(self) -> None:
        native = load_rgba(SOURCE / "regular_belta_neutral_native.png")
        expected_image = native.resize(
            (NATIVE_SIZE[0] * CONTACT_SHEET_PREVIEW_SCALE, NATIVE_SIZE[1] * CONTACT_SHEET_PREVIEW_SCALE),
            Image.Resampling.NEAREST,
        )
        panel_x = CONTACT_SHEET_MARGIN
        panel_y = CONTACT_SHEET_MARGIN + CONTACT_SHEET_TITLE_H
        preview_offset_x = (CONTACT_SHEET_PANEL_SIZE[0] - expected_image.width) // 2
        preview_offset_y = (CONTACT_SHEET_PREVIEW_AREA_H - expected_image.height) // 2
        preview_x = panel_x + preview_offset_x
        preview_y = panel_y + preview_offset_y
        expected_backing = checkerboard((CONTACT_SHEET_PANEL_SIZE[0], CONTACT_SHEET_PREVIEW_AREA_H))
        expected_backing.alpha_composite(expected_image, (preview_offset_x, preview_offset_y))
        expected_preview = expected_backing.crop((
            preview_offset_x,
            preview_offset_y,
            preview_offset_x + expected_image.width,
            preview_offset_y + expected_image.height,
        )).convert("RGB")

        with Image.open(CONTACT_SHEET) as sheet:
            actual_preview = sheet.convert("RGB").crop((
                preview_x,
                preview_y,
                preview_x + expected_image.width,
                preview_y + expected_image.height,
            ))

        self.assertEqual(
            actual_preview.tobytes(),
            expected_preview.tobytes(),
            "contact sheet should show Belta from native at exact 2x, not a non-integer resized runtime preview",
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
