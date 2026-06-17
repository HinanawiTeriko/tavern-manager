from pathlib import Path
import json
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_sources" / "generated_raw" / "characters" / "figgy_concepts" / "figgy_expression_sheet_source_v1.png"
PROMPT = ROOT / "art_sources" / "generated_raw" / "characters" / "figgy_concepts" / "figgy_expression_sheet_prompt_v1.txt"
SOURCE_DIR = ROOT / "assets" / "source" / "tavern" / "characters"
RUNTIME_DIR = ROOT / "assets" / "textures" / "characters"
MANIFEST = SOURCE_DIR / "figgy_bust_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "characters" / "figgy_contact_sheet.png"
RYAN_REFERENCE = ROOT / "assets" / "textures" / "characters" / "ryan_neutral.png"
MIRA_REFERENCE = ROOT / "assets" / "textures" / "characters" / "mira_neutral.png"
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
EXPECTED_SOURCE_SIZE = (1536, 1024)
COLOR_LIMIT = 72
STYLE_PROFILE = "figgy_aqua_fae_normal_clothes_expression_sheet_v1"
NORMALIZATION_MODE = "fixed_cell_visible_subject_v1"
MIN_VISIBLE_HEIGHT = 138
MAX_VISIBLE_HEIGHT = 154
MIN_VISIBLE_WIDTH = 72
MAX_VISIBLE_WIDTH = 124
MIN_BOTTOM_PADDING = 2
MAX_BOTTOM_PADDING = 5
EXPECTED_CROPS = {
    "figgy_neutral": [0, 0, 384, 512],
    "figgy_pleased": [384, 0, 768, 512],
    "figgy_innocent": [768, 0, 1152, 512],
    "figgy_shocked": [1152, 0, 1536, 512],
    "figgy_smug": [0, 512, 384, 1024],
    "figgy_confused": [384, 512, 768, 1024],
    "figgy_serious": [768, 512, 1152, 1024],
    "figgy_victorious": [1152, 512, 1536, 1024],
}
EXPECTED_MOODS = {
    "figgy_neutral": "polite cute tavern entry",
    "figgy_pleased": "spotting a loophole",
    "figgy_innocent": "pretending she did nothing",
    "figgy_shocked": "fate says something stupid",
    "figgy_smug": "exploiting wording",
    "figgy_confused": "bad prophecy",
    "figgy_serious": "challenge fate",
    "figgy_victorious": "beating fate by technicality",
}


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


def second_largest_alpha_component(image: Image.Image) -> int:
    alpha = image.getchannel("A")
    pixels = alpha.load()
    width, height = alpha.size
    seen: set[tuple[int, int]] = set()
    sizes: list[int] = []
    for y in range(height):
        for x in range(width):
            if pixels[x, y] == 0 or (x, y) in seen:
                continue
            stack = [(x, y)]
            seen.add((x, y))
            size = 0
            while stack:
                cx, cy = stack.pop()
                size += 1
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx = cx + dx
                    ny = cy + dy
                    if 0 <= nx < width and 0 <= ny < height and pixels[nx, ny] > 0 and (nx, ny) not in seen:
                        seen.add((nx, ny))
                        stack.append((nx, ny))
            sizes.append(size)
    sizes.sort(reverse=True)
    return sizes[1] if len(sizes) > 1 else 0


def expected_backed_native_preview(native: Image.Image) -> Image.Image:
    preview = native.resize(CONTACT_SHEET_NATIVE_PREVIEW_SIZE, Image.Resampling.NEAREST)
    out = Image.new("RGBA", CONTACT_SHEET_NATIVE_PREVIEW_SIZE, CONTACT_SHEET_NATIVE_BG)
    out.alpha_composite(preview, (0, 0))
    return out.convert("RGB")


class FiggyBustAssetPipelineTest(unittest.TestCase):
    def test_ai_source_prompt_and_manifest_exist(self) -> None:
        self.assertTrue(RAW.exists(), "Figgy expression AI source is missing")
        self.assertTrue(PROMPT.exists(), "Figgy expression prompt record is missing")
        with Image.open(RAW) as source:
            self.assertEqual(source.size, EXPECTED_SOURCE_SIZE, "Figgy source must remain the approved 4x2 expression sheet")

        prompt = PROMPT.read_text(encoding="utf-8").lower()
        for phrase in (
            "figgy v7 portrait",
            "raw 4x2 expression sheet",
            "important npc bust pipeline",
            "flat green",
            "no labels",
            "no readable text",
            "aqua fae/sylph",
            "deep teal cropped travel jacket",
            "narrow dark neck tie",
            "no wax seal",
            "no paper tag",
            "neutral - polite cute tavern entry",
            "pleased - cheerful confident grin",
            "innocent - exaggerated harmless face",
            "shocked - comic surprise",
            "smug - sly sideways smile",
            "confused - squinting",
            "serious - focused courtroom-like resolve",
            "victorious - delighted triumphant grin",
            "128x160",
        ):
            self.assertIn(phrase, prompt)

        self.assertTrue(MANIFEST.exists(), "Figgy bust manifest is missing")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest.get("id"), "figgy_bust_portrait")
        self.assertEqual(manifest.get("style_profile"), STYLE_PROFILE)
        self.assertEqual(manifest.get("source"), RAW.relative_to(ROOT).as_posix())
        self.assertEqual(manifest.get("prompt"), PROMPT.relative_to(ROOT).as_posix())
        self.assertEqual(manifest.get("comparison_references"), [
            RYAN_REFERENCE.relative_to(ROOT).as_posix(),
            MIRA_REFERENCE.relative_to(ROOT).as_posix(),
        ])
        self.assertEqual(manifest.get("grid"), {"columns": 4, "rows": 2})
        self.assertEqual(manifest.get("normalization", {}).get("mode"), NORMALIZATION_MODE)
        self.assertEqual(manifest.get("native_size"), list(NATIVE_SIZE))
        self.assertEqual(manifest.get("runtime_size"), list(RUNTIME_SIZE))
        self.assertEqual(manifest.get("scale"), SCALE)
        self.assertEqual(manifest.get("safe_area"), [0, 0, NATIVE_SIZE[0], NATIVE_SIZE[1]])
        self.assertEqual(manifest.get("runtime"), "assets/textures/characters/figgy_neutral.png")
        self.assertIn("Tavern CustomerSprite", manifest.get("intended_godot_use", ""))

        portraits = manifest.get("portraits", {})
        self.assertEqual(set(EXPECTED_CROPS), set(portraits), "manifest must describe all Figgy expression portraits")
        for portrait_id, crop_rect in EXPECTED_CROPS.items():
            with self.subTest(portrait_id=portrait_id):
                entry = portraits[portrait_id]
                self.assertEqual(entry.get("source"), RAW.relative_to(ROOT).as_posix())
                self.assertEqual(entry.get("prompt"), PROMPT.relative_to(ROOT).as_posix())
                self.assertEqual(entry.get("source_rect"), crop_rect)
                self.assertEqual(entry.get("native"), f"assets/source/tavern/characters/{portrait_id}_native.png")
                self.assertEqual(entry.get("runtime"), f"assets/textures/characters/{portrait_id}.png")
                self.assertEqual(entry.get("native_size"), list(NATIVE_SIZE))
                self.assertEqual(entry.get("runtime_size"), list(RUNTIME_SIZE))
                self.assertEqual(entry.get("scale"), SCALE)
                self.assertEqual(entry.get("normalization", {}).get("mode"), NORMALIZATION_MODE)
                self.assertLessEqual(entry.get("visible_color_count", COLOR_LIMIT + 1), COLOR_LIMIT)
                self.assertIn(EXPECTED_MOODS[portrait_id], entry.get("expression_notes", [])[0])
                self.assertIn("Tavern CustomerSprite", entry.get("intended_godot_use", ""))

    def test_native_and_runtime_exports(self) -> None:
        for portrait_id in EXPECTED_CROPS:
            with self.subTest(portrait_id=portrait_id):
                native_path = SOURCE_DIR / f"{portrait_id}_native.png"
                runtime_path = RUNTIME_DIR / f"{portrait_id}.png"
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
                self.assertLessEqual(second_largest_alpha_component(native), 16, f"{portrait_id}: detached fragment remains")

                bounds = native.getchannel("A").getbbox()
                self.assertIsNotNone(bounds, f"{portrait_id}: native should have visible pixels")
                left, top, right, bottom = bounds
                self.assertGreaterEqual(bottom - top, MIN_VISIBLE_HEIGHT, f"{portrait_id}: visible figure is too short")
                self.assertLessEqual(bottom - top, MAX_VISIBLE_HEIGHT, f"{portrait_id}: visible figure is too tall")
                self.assertGreaterEqual(right - left, MIN_VISIBLE_WIDTH, f"{portrait_id}: portrait is too narrow")
                self.assertLessEqual(right - left, MAX_VISIBLE_WIDTH, f"{portrait_id}: portrait is too wide for the customer slot")
                bottom_padding = native.height - bottom
                self.assertGreaterEqual(bottom_padding, MIN_BOTTOM_PADDING, f"{portrait_id}: touches bottom edge")
                self.assertLessEqual(bottom_padding, MAX_BOTTOM_PADDING, f"{portrait_id}: floats too high")

    def test_contact_sheet_exists(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), "Figgy contact sheet is missing")
        contact = load_rgba(CONTACT_SHEET)
        self.assertEqual(contact.size, CONTACT_SHEET_SIZE, "Figgy contact sheet must use the official important NPC preview size")

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
