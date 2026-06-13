from pathlib import Path
import json
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_sources" / "generated_raw" / "toby_bust" / "toby_neutral_source_v3.png"
PROMPT = ROOT / "art_sources" / "generated_raw" / "toby_bust" / "toby_neutral_prompt_v3.txt"
SOURCE_DIR = ROOT / "assets" / "source" / "tavern" / "characters"
MANIFEST = SOURCE_DIR / "toby_bust_manifest.json"
NATIVE = SOURCE_DIR / "toby_neutral_native.png"
RUNTIME = ROOT / "assets" / "textures" / "characters" / "toby_neutral.png"
CONTACT_SHEET = ROOT / "docs" / "art" / "toby_bust_contact_sheet.png"
RYAN_REFERENCE = ROOT / "assets" / "textures" / "characters" / "ryan_neutral.png"
MIRA_REFERENCE = ROOT / "assets" / "textures" / "characters" / "mira_neutral.png"
RYAN_NATIVE = SOURCE_DIR / "ryan_neutral_native.png"
NATIVE_SIZE = (128, 160)
RUNTIME_SIZE = (512, 640)
SCALE = 4
COLOR_LIMIT = 72
STYLE_PROFILE = "approved_vera_belta_runtime_matched_important_npc_v1"
MAX_BLUE_SCARF_RATIO = 0.02
MAX_RYAN_MATCHED_WIDTH_DELTA = 22
MIN_VISIBLE_HEIGHT = 138
MAX_VISIBLE_HEIGHT = 154
MIN_BOTTOM_PADDING = 2
MAX_BOTTOM_PADDING = 5


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


class TobyBustAssetPipelineTest(unittest.TestCase):
    def test_ai_source_prompt_and_manifest_exist(self) -> None:
        self.assertTrue(RAW.exists(), "Toby AI source is missing")
        self.assertTrue(PROMPT.exists(), "Toby prompt record is missing")
        prompt = PROMPT.read_text(encoding="utf-8").lower()
        for phrase in (
            "approved vera/belta",
            "same artist family",
            "flat solid #00ff00",
            "no readable text",
            "wandering apprentice",
            "128x160",
            "512x640",
            "dirty blond bowl-cut hair",
            "no blue scarf",
            "not ryan silhouette",
        ):
            self.assertIn(phrase, prompt)

        self.assertTrue(MANIFEST.exists(), "Toby bust manifest is missing")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest.get("id"), "toby_bust_portrait")
        self.assertEqual(manifest.get("style_profile"), STYLE_PROFILE)
        self.assertEqual(manifest.get("source"), RAW.relative_to(ROOT).as_posix())
        self.assertEqual(manifest.get("comparison_references"), [
            RYAN_REFERENCE.relative_to(ROOT).as_posix(),
            MIRA_REFERENCE.relative_to(ROOT).as_posix(),
        ])
        self.assertEqual(manifest.get("native_size"), list(NATIVE_SIZE))
        self.assertEqual(manifest.get("runtime_size"), list(RUNTIME_SIZE))
        self.assertEqual(manifest.get("scale"), SCALE)
        self.assertEqual(manifest.get("safe_area"), [0, 0, NATIVE_SIZE[0], NATIVE_SIZE[1]])
        self.assertEqual(manifest.get("runtime"), RUNTIME.relative_to(ROOT).as_posix())
        self.assertIn("Tavern CustomerSprite", manifest.get("intended_godot_use", ""))

    def test_native_and_runtime_exports(self) -> None:
        self.assertTrue(NATIVE.exists(), "Toby native source is missing")
        self.assertTrue(RUNTIME.exists(), "Toby runtime texture is missing")
        native = load_rgba(NATIVE)
        runtime = load_rgba(RUNTIME)
        self.assertEqual(native.size, NATIVE_SIZE)
        self.assertEqual(runtime.size, RUNTIME_SIZE)
        expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
        self.assertEqual(runtime.tobytes(), expected.tobytes(), "runtime must be exact 4x nearest export")
        self.assertGreater(visible_pixel_count(native), 3000, "portrait has too few visible pixels")
        self.assertLessEqual(unique_visible_colors(native), COLOR_LIMIT, "native portrait exceeds the 24-color pixel budget")
        self.assertEqual(green_key_fringe_pixels(native), 0, "green chroma-key fringe remains in native portrait")
        self.assertLessEqual(
            blue_scarf_like_ratio(native),
            MAX_BLUE_SCARF_RATIO,
            "Toby still reads too close to Ryan's blue-scarf silhouette",
        )

        ryan_native = load_rgba(RYAN_NATIVE)
        ryan_width, ryan_height = visible_size(ryan_native)
        toby_width, toby_height = visible_size(native)
        bounds = native.getchannel("A").getbbox()
        self.assertIsNotNone(bounds, "Toby native should have visible pixels")
        _left, top, _right, bottom = bounds
        self.assertGreaterEqual(bottom - top, MIN_VISIBLE_HEIGHT, "Toby visible figure is too short")
        self.assertLessEqual(bottom - top, MAX_VISIBLE_HEIGHT, "Toby visible figure is too tall")
        bottom_padding = native.height - bottom
        self.assertGreaterEqual(bottom_padding, MIN_BOTTOM_PADDING, "Toby touches bottom edge")
        self.assertLessEqual(bottom_padding, MAX_BOTTOM_PADDING, "Toby floats too high")
        self.assertLessEqual(
            toby_width,
            ryan_width + MAX_RYAN_MATCHED_WIDTH_DELTA,
            "Toby portrait is too wide for the Ryan/Mira-matched tavern customer scale",
        )
        self.assertGreaterEqual(
            toby_height,
            ryan_height - 6,
            "Toby portrait lost too much vertical scale while matching the customer slot",
        )

    def test_contact_sheet_exists(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), "Toby contact sheet is missing")
        contact = load_rgba(CONTACT_SHEET)
        self.assertGreaterEqual(contact.width, 1000)
        self.assertGreaterEqual(contact.height, 360)


if __name__ == "__main__":
    unittest.main(verbosity=2)
