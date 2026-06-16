from pathlib import Path
import json
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_sources" / "generated_raw" / "characters" / "toby" / "toby_expression_sheet_source_v5.png"
PROMPT = ROOT / "art_sources" / "generated_raw" / "characters" / "toby" / "toby_expression_sheet_prompt_v5.txt"
SOURCE_DIR = ROOT / "assets" / "source" / "tavern" / "characters"
MANIFEST = SOURCE_DIR / "toby_bust_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "characters" / "toby_contact_sheet.png"
RYAN_REFERENCE = ROOT / "assets" / "textures" / "characters" / "ryan_neutral.png"
MIRA_REFERENCE = ROOT / "assets" / "textures" / "characters" / "mira_neutral.png"
RYAN_NATIVE = SOURCE_DIR / "ryan_neutral_native.png"
NATIVE_SIZE = (128, 160)
RUNTIME_SIZE = (512, 640)
SCALE = 4
CONTACT_SHEET_SIZE = (1180, 820)
CONTACT_SHEET_NATIVE_SCALE = 2
CONTACT_SHEET_NATIVE_PREVIEW_SIZE = (NATIVE_SIZE[0] * CONTACT_SHEET_NATIVE_SCALE, NATIVE_SIZE[1] * CONTACT_SHEET_NATIVE_SCALE)
CONTACT_SHEET_NATIVE_BG = (24, 20, 16, 255)
CONTACT_SHEET_NATIVE_POSITIONS = [(44, 92), (462, 92), (880, 92), (44, 452)]
COLOR_LIMIT = 72
STYLE_PROFILE = "important_npc_close_camera_toby_expression_sheet_v5"
NORMALIZATION_MODE = "fixed_cell_visible_subject_v5"
MAX_BLUE_SCARF_RATIO = 0.02
MAX_RYAN_MATCHED_WIDTH_DELTA = 22
MIN_VISIBLE_HEIGHT = 138
MAX_VISIBLE_HEIGHT = 154
MIN_BOTTOM_PADDING = 2
MAX_BOTTOM_PADDING = 5
EXPECTED_SOURCE_SIZE = (1536, 1024)
EXPECTED_CROPS = {
    "toby_neutral": [0, 0, 768, 512],
    "toby_warmed": [768, 0, 1536, 512],
    "toby_hurt": [0, 512, 768, 1024],
    "toby_afraid": [768, 512, 1536, 1024],
}
EXPECTED_MOODS = {
    "toby_neutral": "stubborn guarded entry",
    "toby_warmed": "softened by a correct hot soup serve",
    "toby_hurt": "hurt but pretending it is fine after a failed serve",
    "toby_afraid": "fear when the Blacktooth commission danger becomes clear",
}


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixel_count(image: Image.Image) -> int:
    return sum(image.getchannel("A").histogram()[1:])


def unique_visible_colors(image: Image.Image) -> int:
    rgba = image.convert("RGBA")
    data = rgba.get_flattened_data() if hasattr(rgba, "get_flattened_data") else rgba.getdata()
    return len({(r, g, b) for r, g, b, a in data if a > 0})


def green_key_fringe_pixels(image: Image.Image) -> int:
    count = 0
    rgba = image.convert("RGBA")
    data = rgba.get_flattened_data() if hasattr(rgba, "get_flattened_data") else rgba.getdata()
    for red, green, blue, alpha in data:
        if alpha == 0:
            continue
        if green >= 80 and green > red * 1.25 and green > blue * 1.25:
            count += 1
    return count


def visible_size(image: Image.Image) -> tuple[int, int]:
    bounds = image.getchannel("A").getbbox()
    if bounds == None:
        return (0, 0)
    return (bounds[2] - bounds[0], bounds[3] - bounds[1])


def blue_scarf_like_ratio(image: Image.Image) -> float:
    rgba = image.convert("RGBA")
    data = rgba.get_flattened_data() if hasattr(rgba, "get_flattened_data") else rgba.getdata()
    visible = 0
    blue_like = 0
    for red, green, blue, alpha in data:
        if alpha <= 0:
            continue
        visible += 1
        if blue >= 52 and blue > red * 1.18 and blue > green * 1.02:
            blue_like += 1
    return blue_like / max(1, visible)


def expected_backed_native_preview(native: Image.Image) -> Image.Image:
    preview = native.resize(CONTACT_SHEET_NATIVE_PREVIEW_SIZE, Image.Resampling.NEAREST)
    out = Image.new("RGBA", CONTACT_SHEET_NATIVE_PREVIEW_SIZE, CONTACT_SHEET_NATIVE_BG)
    out.alpha_composite(preview, (0, 0))
    return out.convert("RGB")


class TobyBustAssetPipelineTest(unittest.TestCase):
    def test_ai_source_prompt_and_manifest_exist(self) -> None:
        self.assertTrue(RAW.exists(), "Toby expression AI source is missing")
        self.assertTrue(PROMPT.exists(), "Toby expression prompt record is missing")
        with Image.open(RAW) as source:
            self.assertEqual(source.size, EXPECTED_SOURCE_SIZE, "Toby v5 source must remain the approved 2x2 sheet")

        prompt = PROMPT.read_text(encoding="utf-8").lower()
        for phrase in (
            "toby expression sheet",
            "important npc camera",
            "2 columns x 2 rows",
            "flat solid #00ff00",
            "no readable text",
            "wandering apprentice",
            "dirty blond bowl-cut hair",
            "ragged gray-green shoulder cape",
            "stubborn guarded entry",
            "softened by a correct hot soup serve",
            "hurt but pretending it is fine",
            "blacktooth commission danger",
            "128x160",
            "512x640",
            "not ryan silhouette",
        ):
            self.assertIn(phrase, prompt)

        self.assertTrue(MANIFEST.exists(), "Toby bust manifest is missing")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest.get("id"), "toby_bust_portrait")
        self.assertEqual(manifest.get("style_profile"), STYLE_PROFILE)
        self.assertEqual(manifest.get("source"), RAW.relative_to(ROOT).as_posix())
        self.assertEqual(manifest.get("prompt"), PROMPT.relative_to(ROOT).as_posix())
        self.assertEqual(manifest.get("comparison_references"), [
            RYAN_REFERENCE.relative_to(ROOT).as_posix(),
            MIRA_REFERENCE.relative_to(ROOT).as_posix(),
        ])
        self.assertEqual(manifest.get("grid"), {"columns": 2, "rows": 2})
        self.assertEqual(manifest.get("normalization", {}).get("mode"), NORMALIZATION_MODE)
        self.assertEqual(manifest.get("native_size"), list(NATIVE_SIZE))
        self.assertEqual(manifest.get("runtime_size"), list(RUNTIME_SIZE))
        self.assertEqual(manifest.get("scale"), SCALE)
        self.assertEqual(manifest.get("safe_area"), [0, 0, NATIVE_SIZE[0], NATIVE_SIZE[1]])
        self.assertEqual(manifest.get("runtime"), "assets/textures/characters/toby_neutral.png")
        self.assertIn("Tavern CustomerSprite", manifest.get("intended_godot_use", ""))

        portraits = manifest.get("portraits", {})
        self.assertEqual(set(EXPECTED_CROPS), set(portraits), "manifest must describe all Toby expression portraits")
        for portrait_id, crop_rect in EXPECTED_CROPS.items():
            with self.subTest(portrait_id=portrait_id):
                entry = portraits[portrait_id]
                self.assertEqual(entry.get("source"), RAW.relative_to(ROOT).as_posix())
                self.assertEqual(entry.get("source_rect"), crop_rect)
                self.assertEqual(entry.get("native"), f"assets/source/tavern/characters/{portrait_id}_native.png")
                self.assertEqual(entry.get("runtime"), f"assets/textures/characters/{portrait_id}.png")
                self.assertEqual(entry.get("native_size"), list(NATIVE_SIZE))
                self.assertEqual(entry.get("runtime_size"), list(RUNTIME_SIZE))
                self.assertEqual(entry.get("scale"), SCALE)
                self.assertEqual(entry.get("normalization", {}).get("mode"), NORMALIZATION_MODE)
                self.assertIn(EXPECTED_MOODS[portrait_id], entry.get("expression_notes", []))
                self.assertIn("Tavern CustomerSprite", entry.get("intended_godot_use", ""))

    def test_native_and_runtime_exports(self) -> None:
        ryan_native = load_rgba(RYAN_NATIVE)
        ryan_width, ryan_height = visible_size(ryan_native)
        for portrait_id in EXPECTED_CROPS:
            with self.subTest(portrait_id=portrait_id):
                native_path = SOURCE_DIR / f"{portrait_id}_native.png"
                runtime_path = ROOT / "assets" / "textures" / "characters" / f"{portrait_id}.png"
                self.assertTrue(native_path.exists(), f"{portrait_id}: native source is missing")
                self.assertTrue(runtime_path.exists(), f"{portrait_id}: runtime texture is missing")
                native = load_rgba(native_path)
                runtime = load_rgba(runtime_path)
                self.assertEqual(native.size, NATIVE_SIZE)
                self.assertEqual(runtime.size, RUNTIME_SIZE)
                expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
                self.assertEqual(runtime.tobytes(), expected.tobytes(), f"{portrait_id}: runtime must be exact 4x nearest export")
                self.assertGreater(visible_pixel_count(native), 3000, f"{portrait_id}: portrait has too few visible pixels")
                self.assertLessEqual(unique_visible_colors(native), COLOR_LIMIT, f"{portrait_id}: native portrait exceeds the color budget")
                self.assertEqual(green_key_fringe_pixels(native), 0, f"{portrait_id}: green chroma-key fringe remains")
                self.assertLessEqual(
                    blue_scarf_like_ratio(native),
                    MAX_BLUE_SCARF_RATIO,
                    f"{portrait_id}: Toby still reads too close to Ryan's blue-scarf silhouette",
                )

                toby_width, toby_height = visible_size(native)
                bounds = native.getchannel("A").getbbox()
                self.assertIsNotNone(bounds, f"{portrait_id}: native should have visible pixels")
                _left, top, _right, bottom = bounds
                self.assertGreaterEqual(bottom - top, MIN_VISIBLE_HEIGHT, f"{portrait_id}: visible figure is too short")
                self.assertLessEqual(bottom - top, MAX_VISIBLE_HEIGHT, f"{portrait_id}: visible figure is too tall")
                bottom_padding = native.height - bottom
                self.assertGreaterEqual(bottom_padding, MIN_BOTTOM_PADDING, f"{portrait_id}: touches bottom edge")
                self.assertLessEqual(bottom_padding, MAX_BOTTOM_PADDING, f"{portrait_id}: floats too high")
                self.assertLessEqual(
                    toby_width,
                    ryan_width + MAX_RYAN_MATCHED_WIDTH_DELTA,
                    f"{portrait_id}: portrait is too wide for the Ryan/Mira-matched tavern customer scale",
                )
                self.assertGreaterEqual(
                    toby_height,
                    ryan_height - 12,
                    f"{portrait_id}: portrait lost too much vertical scale while matching the customer slot",
                )

    def test_contact_sheet_exists(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), "Toby contact sheet is missing")
        contact = load_rgba(CONTACT_SHEET)
        self.assertEqual(contact.size, CONTACT_SHEET_SIZE, "Toby contact sheet must use the official important NPC preview size")

    def test_contact_sheet_uses_integer_native_previews(self) -> None:
        contact = load_rgba(CONTACT_SHEET).convert("RGB")
        for index, portrait_id in enumerate(EXPECTED_CROPS):
            with self.subTest(portrait_id=portrait_id):
                native = load_rgba(SOURCE_DIR / f"{portrait_id}_native.png")
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
