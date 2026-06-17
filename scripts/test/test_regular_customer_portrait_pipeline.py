from __future__ import annotations

import json
import unittest
from pathlib import Path
import colorsys

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCES = [
    ROOT / "art_sources" / "generated_raw" / "characters" / "regular_customers" / "regular_customer_expression_sheet_v5_a.png",
    ROOT / "art_sources" / "generated_raw" / "characters" / "regular_customers" / "regular_customer_expression_sheet_v5_b.png",
    ROOT / "art_sources" / "generated_raw" / "characters" / "regular_customers" / "regular_customer_expression_sheet_v5_c.png",
]
PROMPTS = [
    ROOT / "art_sources" / "generated_raw" / "characters" / "regular_customers" / "regular_customer_expression_sheet_v5_a_prompt.txt",
    ROOT / "art_sources" / "generated_raw" / "characters" / "regular_customers" / "regular_customer_expression_sheet_v5_b_prompt.txt",
    ROOT / "art_sources" / "generated_raw" / "characters" / "regular_customers" / "regular_customer_expression_sheet_v5_c_prompt.txt",
]
MANIFEST = ROOT / "assets" / "source" / "tavern" / "regular_customers" / "regular_customer_portraits_manifest.json"
SOURCE = ROOT / "assets" / "source" / "tavern" / "regular_customers"
RUNTIME = ROOT / "assets" / "textures" / "characters"
CONTACT_SHEET_DIR = ROOT / "docs" / "art" / "characters"
BELTA_STYLE_REFERENCE = ROOT / "art_sources" / "generated_raw" / "characters" / "regular_customers" / "regular_belta_style_reference_v1.png"
BELTA_STYLE_REFERENCE_PROMPT = ROOT / "art_sources" / "generated_raw" / "characters" / "regular_customers" / "regular_belta_style_reference_prompt_v1.txt"
VERA_REFERENCE = ROOT / "art_sources" / "generated_raw" / "characters" / "vera" / "reference" / "vera_approved_reference_v2.png"
NATIVE_SIZE = (128, 160)
RUNTIME_SIZE = (512, 640)
CONTACT_SHEET_SIZE = (1180, 460)
CONTACT_SHEET_NATIVE_SCALE = 2
CONTACT_SHEET_NATIVE_PREVIEW_SIZE = (
    NATIVE_SIZE[0] * CONTACT_SHEET_NATIVE_SCALE,
    NATIVE_SIZE[1] * CONTACT_SHEET_NATIVE_SCALE,
)
CONTACT_SHEET_NATIVE_BG = (24, 20, 16, 255)
CONTACT_SHEET_NATIVE_POSITIONS = [(44, 92), (462, 92), (880, 92), (44, 452), (462, 452), (880, 452)]
BELTA_NEUTRAL_ID = "regular_belta_neutral"
SCALE = 4
STYLE_PROFILE = "approved_vera_belta_runtime_matched_regular_portraits_v5"
SOURCE_LEVEL_MATTE_PROFILE = "source_flood_fill_green_screen_v1"
MIN_UNIFORM_VISIBLE_HEIGHT = 138
MAX_UNIFORM_VISIBLE_HEIGHT = 154
MIN_UNIFORM_BOTTOM_PADDING = 2
MAX_UNIFORM_BOTTOM_PADDING = 5
UNIFORM_VISIBLE_HEIGHT = 154
UNIFORM_MAX_VISIBLE_WIDTH = 128
UNIFORM_BOTTOM_PADDING = 3
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


def contact_sheet_path(customer_id: str) -> Path:
    return CONTACT_SHEET_DIR / f"{customer_id}_contact_sheet.png"


def expected_backed_native_preview(native: Image.Image) -> Image.Image:
    preview = native.resize(CONTACT_SHEET_NATIVE_PREVIEW_SIZE, Image.Resampling.NEAREST)
    out = Image.new("RGBA", CONTACT_SHEET_NATIVE_PREVIEW_SIZE, CONTACT_SHEET_NATIVE_BG)
    out.alpha_composite(preview, (0, 0))
    return out.convert("RGB")


def is_low_saturation_green_spill(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    if alpha == 0:
        return False
    hue, lightness, saturation = colorsys.rgb_to_hls(red / 255, green / 255, blue / 255)
    return 75 <= hue * 360 <= 190 and saturation >= 0.12 and lightness <= 0.42 and green >= red and green >= blue


def distance_to_transparency(image: Image.Image, x: int, y: int, max_distance: int = 2) -> int | None:
    pixels = image.load()
    for distance in range(1, max_distance + 1):
        for yy in range(max(0, y - distance), min(image.height, y + distance + 1)):
            for xx in range(max(0, x - distance), min(image.width, x + distance + 1)):
                if abs(xx - x) != distance and abs(yy - y) != distance:
                    continue
                if pixels[xx, yy][3] == 0:
                    return distance
    return None


def marco_hair_near_edge_green_spill_count(native: Image.Image) -> int:
    head_crop = (24, 0, 104, 62)
    count = 0
    pixels = native.load()
    for y in range(head_crop[1], head_crop[3]):
        for x in range(head_crop[0], head_crop[2]):
            if is_low_saturation_green_spill(pixels[x, y]) and distance_to_transparency(native, x, y, 2) is not None:
                count += 1
    return count


class RegularCustomerPortraitPipelineTest(unittest.TestCase):
    def test_generated_source_and_prompt_are_retained(self) -> None:
        for source in RAW_SOURCES:
            self.assertTrue(source.exists(), f"{source}: missing generated regular customer source")
            self.assertGreater(source.stat().st_size, 0, f"{source}: generated regular customer source is empty")
        self.assertTrue(BELTA_STYLE_REFERENCE.exists(), f"{BELTA_STYLE_REFERENCE}: missing Belta style reference")
        self.assertGreater(BELTA_STYLE_REFERENCE.stat().st_size, 0, "Belta style reference is empty")
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
        self.assertTrue(BELTA_STYLE_REFERENCE_PROMPT.exists(), f"{BELTA_STYLE_REFERENCE_PROMPT}: missing Belta style reference prompt")
        reference_prompt = BELTA_STYLE_REFERENCE_PROMPT.read_text(encoding="utf-8").lower()
        self.assertIn("visible reference image of vera", reference_prompt)
        self.assertIn("128x160", reference_prompt)
        self.assertIn("512x640", reference_prompt)
        self.assertIn("flat solid #00ff00", reference_prompt)
        self.assertIn("face must remain readable", reference_prompt)

    def test_manifest_records_all_fixed_crops(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing regular customer manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["style_profile"], STYLE_PROFILE)
        self.assertEqual(manifest["source"], "art_sources/generated_raw/characters/regular_customers/regular_customer_expression_sheet_v5_a.png")
        self.assertEqual(
            manifest["style_references"],
            [
                "art_sources/generated_raw/characters/vera/reference/vera_approved_reference_v2.png",
                "art_sources/generated_raw/characters/regular_customers/regular_belta_style_reference_v1.png",
            ],
        )
        self.assertEqual(
            manifest["sources"],
            [
                "art_sources/generated_raw/characters/regular_customers/regular_customer_expression_sheet_v5_a.png",
                "art_sources/generated_raw/characters/regular_customers/regular_customer_expression_sheet_v5_b.png",
                "art_sources/generated_raw/characters/regular_customers/regular_customer_expression_sheet_v5_c.png",
            ],
        )
        self.assertEqual(
            manifest["prompt_sources"],
            [
                "art_sources/generated_raw/characters/regular_customers/regular_customer_expression_sheet_v5_a_prompt.txt",
                "art_sources/generated_raw/characters/regular_customers/regular_customer_expression_sheet_v5_b_prompt.txt",
                "art_sources/generated_raw/characters/regular_customers/regular_customer_expression_sheet_v5_c_prompt.txt",
            ],
        )
        self.assertEqual(manifest["native_size"], list(NATIVE_SIZE))
        self.assertEqual(manifest["runtime_size"], list(RUNTIME_SIZE))
        self.assertEqual(manifest["scale"], SCALE)
        self.assertEqual(manifest["uniform_visible_height"], UNIFORM_VISIBLE_HEIGHT)
        self.assertEqual(manifest["uniform_max_visible_width"], UNIFORM_MAX_VISIBLE_WIDTH)
        self.assertEqual(manifest["uniform_bottom_padding"], UNIFORM_BOTTOM_PADDING)
        self.assertNotIn("pilot_portraits", manifest)
        self.assertEqual(manifest["source_level_matte_profile"], SOURCE_LEVEL_MATTE_PROFILE)
        self.assertEqual(manifest["source_level_matte_customers"], EXPECTED_IDS)
        self.assertEqual(
            manifest["contact_sheets"],
            {
                customer_id: f"docs/art/characters/{customer_id}_contact_sheet.png"
                for customer_id in EXPECTED_IDS
            },
        )
        entries = manifest["portraits"]
        self.assertNotIn("pilot", json.dumps(manifest, ensure_ascii=False))
        self.assertEqual(set(entries.keys()), {f"{cid}_{state}" for cid in EXPECTED_IDS for state in EXPECTED_STATES})
        for portrait_id, entry in entries.items():
            with self.subTest(portrait_id=portrait_id):
                self.assertEqual(len(entry["crop_rect"]), 4)
                self.assertEqual(entry["native"], f"assets/source/tavern/regular_customers/{portrait_id}_native.png")
                self.assertEqual(entry["runtime"], f"assets/textures/characters/{portrait_id}.png")
                self.assertIn(entry["source"], manifest["sources"])
                self.assertEqual(entry["matte"], SOURCE_LEVEL_MATTE_PROFILE)
                self.assertIn("Tavern CustomerSprite", entry["intended_godot_use"])

    def test_belta_states_share_one_expression_sheet_source(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        entries = manifest["portraits"]
        expected_source = "art_sources/generated_raw/characters/regular_customers/regular_customer_expression_sheet_v5_a.png"
        for state in EXPECTED_STATES:
            portrait_id = f"regular_belta_{state}"
            with self.subTest(portrait_id=portrait_id):
                entry = entries[portrait_id]
                self.assertEqual(entry["source"], expected_source)
                self.assertNotIn("prompt", entry)
                self.assertEqual(entry["matte"], SOURCE_LEVEL_MATTE_PROFILE)
        self.assertEqual(entries[BELTA_NEUTRAL_ID]["crop_rect"], [9, 8, 353, 354])

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

    def test_each_customer_has_id_named_contact_sheet(self) -> None:
        for customer_id in EXPECTED_IDS:
            with self.subTest(customer_id=customer_id):
                sheet_path = contact_sheet_path(customer_id)
                self.assertTrue(sheet_path.exists(), f"{sheet_path}: missing customer contact sheet")
                contact = load_rgba(sheet_path)
                self.assertEqual(contact.size, CONTACT_SHEET_SIZE)

    def test_customer_contact_sheets_use_integer_native_previews(self) -> None:
        for customer_id in EXPECTED_IDS:
            contact = load_rgba(contact_sheet_path(customer_id)).convert("RGB")
            for index, state in enumerate(EXPECTED_STATES):
                portrait_id = f"{customer_id}_{state}"
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
                        f"{portrait_id}: contact sheet preview must be exact 2x native pixels",
                    )

    def test_marco_hair_source_level_matte_removes_near_edge_green_spill(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        for state in EXPECTED_STATES:
            portrait_id = f"regular_marco_{state}"
            with self.subTest(portrait_id=portrait_id):
                entry = manifest["portraits"][portrait_id]
                self.assertEqual(entry["matte"], SOURCE_LEVEL_MATTE_PROFILE)
                native = load_rgba(SOURCE / f"{portrait_id}_native.png")
                spill_count = marco_hair_near_edge_green_spill_count(native)
                self.assertLessEqual(spill_count, 12, f"{portrait_id}: green spill remains in Marco hair edge")


if __name__ == "__main__":
    unittest.main(verbosity=2)
