import json
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "intro"
REFERENCE = SOURCE / "reference"
RUNTIME = ROOT / "assets" / "textures" / "intro"
INTRO_DATA = ROOT / "data" / "intro.json"
NATIVE_SIZE = (320, 180)
RUNTIME_SIZE = (1280, 720)
SCALE = 4
STILLS = [
    "intro_descent",
    "intro_hearth_memory",
    "intro_tavern_dark",
    "intro_rusted_key",
    "intro_threshold",
]
REFERENCE_FILES = [*STILLS, "tavern_continuity_master"]
MIN_DARK_PIXELS = 18_000
MIN_COOL_PIXELS = 4_000
MIN_WARM_PIXELS = {
    "intro_descent": 20,
    "intro_hearth_memory": 200,
    "intro_tavern_dark": 0,
    "intro_rusted_key": 10,
    "intro_threshold": 0,
}
MAX_NATIVE_COLORS = 64


def load_image(path: Path) -> Image.Image:
    if not path.exists():
        raise AssertionError(f"{path}: missing image")
    with Image.open(path) as image:
        return image.copy()


def rgba_pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    return [
        pixels[x, y]
        for y in range(rgba.height)
        for x in range(rgba.width)
    ]


def color_count(image: Image.Image) -> int:
    colors = image.convert("RGB").getcolors(maxcolors=65536)
    return len(colors) if colors is not None else 65536


def edge_change_ratio(image: Image.Image) -> float:
    rgb = image.convert("RGB")
    pixels = rgb.load()
    changes = 0
    total = 0
    for y in range(rgb.height):
        for x in range(rgb.width - 1):
            total += 1
            changes += pixels[x, y] != pixels[x + 1, y]
    for y in range(rgb.height - 1):
        for x in range(rgb.width):
            total += 1
            changes += pixels[x, y] != pixels[x, y + 1]
    return changes / total


class IntroAssetPipelineTest(unittest.TestCase):
    def test_approved_references_exist(self) -> None:
        for name in REFERENCE_FILES:
            path = REFERENCE / f"{name}.png"
            self.assertTrue(path.exists(), f"{path}: missing approved reference")
            image = load_image(path)
            self.assertGreaterEqual(image.width, RUNTIME_SIZE[0], f"{name}: reference is too narrow")
            self.assertGreaterEqual(image.height, RUNTIME_SIZE[1], f"{name}: reference is too short")

    def test_native_and_runtime_files_exist_at_expected_sizes(self) -> None:
        self.assertEqual(
            RUNTIME_SIZE,
            (NATIVE_SIZE[0] * SCALE, NATIVE_SIZE[1] * SCALE),
            "runtime size must be an integer-scale export of the native grid",
        )
        for name in STILLS:
            native_path = SOURCE / f"{name}_native.png"
            runtime_path = RUNTIME / f"{name}.png"
            self.assertTrue(native_path.exists(), f"{native_path}: missing native source")
            self.assertTrue(runtime_path.exists(), f"{runtime_path}: missing runtime texture")

            native = load_image(native_path)
            runtime = load_image(runtime_path)
            self.assertEqual(native.size, NATIVE_SIZE, f"{name}: wrong native size")
            self.assertEqual(runtime.size, RUNTIME_SIZE, f"{name}: wrong runtime size")

    def test_native_stills_match_visual_guardrails(self) -> None:
        for name in STILLS:
            path = SOURCE / f"{name}_native.png"
            image = load_image(path).convert("RGBA")
            pixels = rgba_pixels(image)
            dark = sum(1 for r, g, b, a in pixels if a >= 250 and max(r, g, b) <= 58)
            cool = sum(
                1
                for r, g, b, a in pixels
                if a >= 250 and b >= 38 and g >= 36 and b >= r * 1.05 and g >= r * 0.85
            )
            warm = sum(
                1
                for r, g, b, a in pixels
                if a >= 250 and r >= 95 and g >= 42 and r >= b * 1.6 and g >= b * 1.1
            )
            self.assertGreaterEqual(dark, MIN_DARK_PIXELS, f"{name}: insufficient dark mass")
            self.assertGreaterEqual(cool, MIN_COOL_PIXELS, f"{name}: insufficient teal depth")
            self.assertGreaterEqual(
                warm,
                MIN_WARM_PIXELS[name],
                f"{name}: missing warm focal accents",
            )
            self.assertLessEqual(
                color_count(image),
                MAX_NATIVE_COLORS,
                f"{name}: too many colors",
            )
            self.assertGreaterEqual(
                edge_change_ratio(image),
                0.08,
                f"{name}: likely over-smoothed",
            )

    def test_vignette_is_native_alpha_art(self) -> None:
        path = SOURCE / "intro_vignette_native.png"
        vignette = load_image(path).convert("RGBA")
        self.assertEqual(vignette.size, NATIVE_SIZE)
        alpha = vignette.getchannel("A")
        self.assertEqual(alpha.getextrema()[0], 0)
        self.assertGreater(alpha.getextrema()[1], 0)
        self.assertLess(alpha.getpixel((160, 90)), 40)
        self.assertGreater(alpha.getpixel((0, 0)), 80)

    def test_contact_sheet_contains_all_five_native_stills(self) -> None:
        path = SOURCE / "intro_contact_sheet.png"
        sheet = load_image(path)
        self.assertEqual(sheet.size, (960, 360))

    def test_runtime_manifest_uses_the_five_pipeline_textures_in_order(self) -> None:
        with INTRO_DATA.open(encoding="utf-8") as handle:
            intro_data = json.load(handle)

        actual = [beat["image"] for beat in intro_data["beats"]]
        expected = [f"res://assets/textures/intro/{name}.png" for name in STILLS]
        self.assertEqual(actual, expected)


if __name__ == "__main__":
    unittest.main(verbosity=2)
