from pathlib import Path
import json
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_sources" / "generated_raw" / "mercenary_bust" / "mercenary_a_source_v1.png"
PROMPT = ROOT / "art_sources" / "generated_raw" / "mercenary_bust" / "mercenary_a_prompt_v1.txt"
SOURCE_DIR = ROOT / "assets" / "source" / "tavern" / "characters"
MANIFEST = SOURCE_DIR / "mercenary_bust_manifest.json"
NATIVE = SOURCE_DIR / "mercenary_a_native.png"
RUNTIME = ROOT / "assets" / "textures" / "characters" / "mercenary_a.png"
CONTACT_SHEET = ROOT / "docs" / "art" / "mercenary_bust_contact_sheet.png"
RYAN_REFERENCE = ROOT / "assets" / "textures" / "characters" / "ryan_neutral.png"
NATIVE_SIZE = (70, 90)
RUNTIME_SIZE = (280, 360)
SCALE = 4
COLOR_LIMIT = 28
MAX_BLUE_SCARF_RATIO = 0.015


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


class MercenaryBustAssetPipelineTest(unittest.TestCase):
    def test_ai_source_prompt_and_manifest_exist(self) -> None:
        self.assertTrue(RAW.exists(), "Mercenary A AI source is missing")
        self.assertTrue(PROMPT.exists(), "Mercenary A prompt record is missing")
        prompt = PROMPT.read_text(encoding="utf-8").lower()
        for phrase in (
            "flat solid #00ff00",
            "no readable text",
            "mercenary messenger",
            "not ryan",
            "native 70x90",
            "no blue scarf",
            "not a high-resolution illustration",
        ):
            self.assertIn(phrase, prompt)

        self.assertTrue(MANIFEST.exists(), "Mercenary A manifest is missing")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest.get("id"), "mercenary_bust_portrait")
        self.assertEqual(manifest.get("style_profile"), "ryan_distinct_low_detail_pixel_v1")
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
        self.assertGreater(visible_pixel_count(native), 900, "portrait has too few visible pixels")
        self.assertLessEqual(unique_visible_colors(native), COLOR_LIMIT, "native portrait exceeds the 28-color pixel budget")
        self.assertEqual(green_key_fringe_pixels(native), 0, "green chroma-key fringe remains in native portrait")
        self.assertLessEqual(
            blue_scarf_like_ratio(native),
            MAX_BLUE_SCARF_RATIO,
            "Mercenary A still reads too close to Ryan's blue-scarf silhouette",
        )

    def test_contact_sheet_exists(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), "Mercenary A contact sheet is missing")
        contact = load_rgba(CONTACT_SHEET)
        self.assertGreaterEqual(contact.width, 800)
        self.assertGreaterEqual(contact.height, 360)


if __name__ == "__main__":
    unittest.main(verbosity=2)
