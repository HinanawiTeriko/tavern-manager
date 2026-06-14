from pathlib import Path
import json
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_sources" / "generated_raw" / "characters" / "mira" / "mira_expression_sheet_source_v2.png"
PROMPT = ROOT / "art_sources" / "generated_raw" / "characters" / "mira" / "mira_expression_sheet_prompt_v2.txt"
EXPRESSION_RAW = RAW
EXPRESSION_PROMPT = PROMPT
SOURCE_DIR = ROOT / "assets" / "source" / "tavern" / "characters"
MANIFEST = SOURCE_DIR / "mira_bust_manifest.json"
NATIVE = SOURCE_DIR / "mira_neutral_native.png"
RUNTIME = ROOT / "assets" / "textures" / "characters" / "mira_neutral.png"
CONTACT_SHEET = ROOT / "docs" / "art" / "characters" / "mira_contact_sheet.png"
RYAN_REFERENCE = ROOT / "assets" / "textures" / "characters" / "ryan_neutral.png"
RYAN_NATIVE = SOURCE_DIR / "ryan_neutral_native.png"
NATIVE_SIZE = (128, 160)
RUNTIME_SIZE = (512, 640)
SCALE = 4
CONTACT_SHEET_SIZE = (1180, 820)
CONTACT_SHEET_NATIVE_SCALE = 2
CONTACT_SHEET_NATIVE_PREVIEW_SIZE = (NATIVE_SIZE[0] * CONTACT_SHEET_NATIVE_SCALE, NATIVE_SIZE[1] * CONTACT_SHEET_NATIVE_SCALE)
CONTACT_SHEET_NATIVE_BG = (24, 20, 16, 255)
CONTACT_SHEET_NATIVE_POSITIONS = [(44, 92), (462, 92), (880, 92), (44, 452), (462, 452), (880, 452)]
COLOR_LIMIT = 72
STYLE_PROFILE = "approved_vera_belta_runtime_matched_important_npc_v1"
MAX_RYAN_MATCHED_WIDTH_DELTA = 18
MIN_VISIBLE_HEIGHT = 138
MAX_VISIBLE_HEIGHT = 154
MIN_BOTTOM_PADDING = 2
MAX_BOTTOM_PADDING = 5
PORTRAITS = {
    "mira_neutral": {
        "source": RAW,
        "prompt": PROMPT,
        "expected_mood": "guarded professional smile",
    },
    "mira_smile": {
        "source": EXPRESSION_RAW,
        "prompt": EXPRESSION_PROMPT,
        "expected_mood": "genuine warm smile",
    },
    "mira_surprised": {
        "source": EXPRESSION_RAW,
        "prompt": EXPRESSION_PROMPT,
        "expected_mood": "surprised raised brows",
    },
    "mira_serious": {
        "source": EXPRESSION_RAW,
        "prompt": EXPRESSION_PROMPT,
        "expected_mood": "serious direct gaze",
    },
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


def expected_backed_native_preview(native: Image.Image) -> Image.Image:
    preview = native.resize(CONTACT_SHEET_NATIVE_PREVIEW_SIZE, Image.Resampling.NEAREST)
    out = Image.new("RGBA", CONTACT_SHEET_NATIVE_PREVIEW_SIZE, CONTACT_SHEET_NATIVE_BG)
    out.alpha_composite(preview, (0, 0))
    return out.convert("RGB")


class MiraBustAssetPipelineTest(unittest.TestCase):
    def test_ai_source_prompt_and_manifest_exist(self) -> None:
        self.assertTrue(RAW.exists(), "Mira AI source is missing")
        self.assertTrue(PROMPT.exists(), "Mira prompt record is missing")
        self.assertTrue(EXPRESSION_RAW.exists(), "Mira expression AI sheet is missing")
        self.assertTrue(EXPRESSION_PROMPT.exists(), "Mira expression prompt record is missing")
        prompt = PROMPT.read_text(encoding="utf-8").lower()
        for phrase in (
            "approved vera/belta",
            "same artist family",
            "flat solid #00ff00",
            "no readable text",
            "traveling merchant",
            "128x160",
            "512x640",
            "4 columns x 1 row",
            "genuine warm smile",
            "surprised raised brows",
            "serious direct gaze",
        ):
            self.assertIn(phrase, prompt)

        self.assertTrue(MANIFEST.exists(), "Mira bust manifest is missing")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest.get("id"), "mira_bust_portrait")
        self.assertEqual(manifest.get("style_profile"), STYLE_PROFILE)
        self.assertEqual(manifest.get("source"), RAW.relative_to(ROOT).as_posix())
        self.assertEqual(manifest.get("comparison_reference"), RYAN_REFERENCE.relative_to(ROOT).as_posix())
        self.assertEqual(manifest.get("native_size"), list(NATIVE_SIZE))
        self.assertEqual(manifest.get("runtime_size"), list(RUNTIME_SIZE))
        self.assertEqual(manifest.get("scale"), SCALE)
        self.assertEqual(manifest.get("safe_area"), [0, 0, NATIVE_SIZE[0], NATIVE_SIZE[1]])
        self.assertEqual(manifest.get("runtime"), RUNTIME.relative_to(ROOT).as_posix())
        self.assertIn("Tavern CustomerSprite", manifest.get("intended_godot_use", ""))
        portraits = manifest.get("portraits", {})
        self.assertEqual(set(PORTRAITS), set(portraits), "manifest must describe all Mira expression portraits")
        for portrait_id, expected in PORTRAITS.items():
            with self.subTest(portrait_id=portrait_id):
                entry = portraits[portrait_id]
                self.assertEqual(entry.get("source"), expected["source"].relative_to(ROOT).as_posix())
                self.assertEqual(entry.get("native"), (SOURCE_DIR / f"{portrait_id}_native.png").relative_to(ROOT).as_posix())
                self.assertEqual(entry.get("runtime"), (ROOT / "assets" / "textures" / "characters" / f"{portrait_id}.png").relative_to(ROOT).as_posix())
                self.assertEqual(entry.get("native_size"), list(NATIVE_SIZE))
                self.assertEqual(entry.get("runtime_size"), list(RUNTIME_SIZE))
                self.assertEqual(entry.get("scale"), SCALE)
                self.assertIn(expected["expected_mood"], entry.get("expression_notes", []))
                source_rect = entry.get("source_rect")
                self.assertIsInstance(source_rect, list, f"{portrait_id}: source_rect must be fixed")
                self.assertEqual(len(source_rect), 4, f"{portrait_id}: source_rect must have four values")

    def test_native_and_runtime_exports(self) -> None:
        for portrait_id in PORTRAITS:
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
                self.assertLessEqual(unique_visible_colors(native), COLOR_LIMIT, f"{portrait_id}: native portrait exceeds the 24-color pixel budget")
                self.assertEqual(green_key_fringe_pixels(native), 0, f"{portrait_id}: green chroma-key fringe remains")
                _left, _top, _right, bottom = native.getchannel("A").getbbox()
                self.assertGreaterEqual(bottom - _top, MIN_VISIBLE_HEIGHT, f"{portrait_id}: visible figure is too short")
                self.assertLessEqual(bottom - _top, MAX_VISIBLE_HEIGHT, f"{portrait_id}: visible figure is too tall")
                bottom_padding = native.height - bottom
                self.assertGreaterEqual(bottom_padding, MIN_BOTTOM_PADDING, f"{portrait_id}: touches bottom edge")
                self.assertLessEqual(bottom_padding, MAX_BOTTOM_PADDING, f"{portrait_id}: floats too high")

        ryan_native = load_rgba(RYAN_NATIVE)
        ryan_width, ryan_height = visible_size(ryan_native)
        for portrait_id in PORTRAITS:
            with self.subTest(scale_match=portrait_id):
                native = load_rgba(SOURCE_DIR / f"{portrait_id}_native.png")
                mira_width, mira_height = visible_size(native)
                self.assertLessEqual(
                    mira_width,
                    ryan_width + MAX_RYAN_MATCHED_WIDTH_DELTA,
                    f"{portrait_id}: portrait is too wide for the Ryan-matched tavern customer scale",
                )
                self.assertGreaterEqual(
                    mira_height,
                    ryan_height - 4,
                    f"{portrait_id}: portrait lost too much vertical scale while matching Ryan",
                )

    def test_contact_sheet_exists(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), "Mira contact sheet is missing")
        contact = load_rgba(CONTACT_SHEET)
        self.assertEqual(contact.size, CONTACT_SHEET_SIZE, "Mira contact sheet must use the official important NPC preview size")

    def test_contact_sheet_uses_integer_native_previews(self) -> None:
        contact = load_rgba(CONTACT_SHEET).convert("RGB")
        for index, portrait_id in enumerate(PORTRAITS):
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
