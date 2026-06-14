from pathlib import Path
import json
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_sources" / "generated_raw" / "characters" / "mercenary" / "mercenary_a_source_v2.png"
PROMPT = ROOT / "art_sources" / "generated_raw" / "characters" / "mercenary" / "mercenary_a_prompt_v2.txt"
SOURCE_DIR = ROOT / "assets" / "source" / "tavern" / "characters"
MANIFEST = SOURCE_DIR / "mercenary_bust_manifest.json"
NATIVE = SOURCE_DIR / "mercenary_a_native.png"
RUNTIME = ROOT / "assets" / "textures" / "characters" / "mercenary_a.png"
CONTACT_SHEET = ROOT / "docs" / "art" / "characters" / "mercenary_contact_sheet.png"
RYAN_REFERENCE = ROOT / "assets" / "textures" / "characters" / "ryan_neutral.png"
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
MAX_BLUE_SCARF_RATIO = 0.015
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
    return len({(red, green, blue) for red, green, blue, alpha in data if alpha > 0})


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


class MercenaryBustAssetPipelineTest(unittest.TestCase):
    def test_ai_source_prompt_and_manifest_exist(self) -> None:
        self.assertTrue(RAW.exists(), "Mercenary A AI source is missing")
        self.assertTrue(PROMPT.exists(), "Mercenary A prompt record is missing")
        prompt = PROMPT.read_text(encoding="utf-8").lower()
        for phrase in (
            "approved vera/belta",
            "same artist family",
            "flat solid #00ff00",
            "no readable text",
            "mercenary messenger",
            "not ryan",
            "128x160",
            "512x640",
            "no blue scarf",
        ):
            self.assertIn(phrase, prompt)

        self.assertTrue(MANIFEST.exists(), "Mercenary A manifest is missing")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest.get("id"), "mercenary_bust_portrait")
        self.assertEqual(manifest.get("style_profile"), STYLE_PROFILE)
        self.assertEqual(manifest.get("source"), RAW.relative_to(ROOT).as_posix())
        self.assertEqual(manifest.get("comparison_reference"), RYAN_REFERENCE.relative_to(ROOT).as_posix())
        self.assertEqual(manifest.get("native_size"), list(NATIVE_SIZE))
        self.assertEqual(manifest.get("runtime_size"), list(RUNTIME_SIZE))
        self.assertEqual(manifest.get("scale"), SCALE)
        self.assertEqual(manifest.get("safe_area"), [0, 0, NATIVE_SIZE[0], NATIVE_SIZE[1]])
        self.assertEqual(manifest.get("runtime"), RUNTIME.relative_to(ROOT).as_posix())
        self.assertIn("Tavern CustomerSprite", manifest.get("intended_godot_use", ""))

    def test_native_and_runtime_exports(self) -> None:
        self.assertTrue(NATIVE.exists(), "Mercenary A native source is missing")
        self.assertTrue(RUNTIME.exists(), "Mercenary A runtime texture is missing")
        native = load_rgba(NATIVE)
        runtime = load_rgba(RUNTIME)
        self.assertEqual(native.size, NATIVE_SIZE)
        self.assertEqual(runtime.size, RUNTIME_SIZE)
        expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
        self.assertEqual(runtime.tobytes(), expected.tobytes(), "runtime must be exact 4x nearest export")
        self.assertGreater(visible_pixel_count(native), 3000, "portrait has too few visible pixels")
        self.assertLessEqual(unique_visible_colors(native), COLOR_LIMIT, "native portrait exceeds the 28-color pixel budget")
        self.assertEqual(green_key_fringe_pixels(native), 0, "green chroma-key fringe remains in native portrait")
        bounds = native.getchannel("A").getbbox()
        self.assertIsNotNone(bounds, "Mercenary A native should have visible pixels")
        _left, top, _right, bottom = bounds
        self.assertGreaterEqual(bottom - top, MIN_VISIBLE_HEIGHT, "Mercenary A visible figure is too short")
        self.assertLessEqual(bottom - top, MAX_VISIBLE_HEIGHT, "Mercenary A visible figure is too tall")
        bottom_padding = native.height - bottom
        self.assertGreaterEqual(bottom_padding, MIN_BOTTOM_PADDING, "Mercenary A touches bottom edge")
        self.assertLessEqual(bottom_padding, MAX_BOTTOM_PADDING, "Mercenary A floats too high")
        self.assertLessEqual(
            blue_scarf_like_ratio(native),
            MAX_BLUE_SCARF_RATIO,
            "Mercenary A still reads too close to Ryan's blue-scarf silhouette",
        )

    def test_contact_sheet_exists(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), "Mercenary A contact sheet is missing")
        contact = load_rgba(CONTACT_SHEET)
        self.assertEqual(contact.size, CONTACT_SHEET_SIZE, "Mercenary A contact sheet must use the official important NPC preview size")

    def test_contact_sheet_uses_integer_native_previews(self) -> None:
        native = load_rgba(NATIVE)
        contact = load_rgba(CONTACT_SHEET).convert("RGB")
        x, y = CONTACT_SHEET_NATIVE_POSITIONS[0]
        actual_native = contact.crop((
            x,
            y,
            x + CONTACT_SHEET_NATIVE_PREVIEW_SIZE[0],
            y + CONTACT_SHEET_NATIVE_PREVIEW_SIZE[1],
        ))
        self.assertEqual(
            actual_native.tobytes(),
            expected_backed_native_preview(native).tobytes(),
            "Mercenary A contact sheet native preview must be exact 2x native pixels",
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
