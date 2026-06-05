from pathlib import Path
import unittest

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "daymap"
REFERENCE = SOURCE / "reference"
RUNTIME = ROOT / "assets" / "textures" / "daymap"
NATIVE_BG_SIZE = (320, 180)
RUNTIME_BG_SIZE = (1280, 720)
NATIVE_MARKER_SIZE = (24, 24)
RUNTIME_MARKER_SIZE = (96, 96)
NATIVE_MARKER_STATE_SIZE = (32, 32)
RUNTIME_MARKER_STATE_SIZE = (128, 128)
SCALE = 4
MAX_MARKER_COLORS = 16
MIN_BG_COLORS = 1000
MIN_BG_EDGE_CHANGE_RATIO = 0.18
MIN_COOL_DARK_PIXELS = 4000
MIN_PARCHMENT_PIXELS = 12000
MIN_AMBER_PIXELS = 400
REFERENCE_IMAGE = REFERENCE / "daymap_reference.png"
MARKERS = [
    "home",
    "mushroom_forest",
    "dark_river",
    "grape_trellis",
    "mill_farm",
    "mercenary_board",
    "abandoned_mine",
    "guild_counter",
]
MARKER_STATES = [
    "marker_base",
    "marker_hover_ring",
    "marker_selected_ring",
    "marker_reveal_burst",
]


def load_image(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.copy()


def visible_pixel_count(image: Image.Image) -> int:
    alpha = image.convert("RGBA").getchannel("A")
    return sum(alpha.histogram()[1:])


def rgba_pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    rgba = image.convert("RGBA")
    data = rgba.load()
    return [data[x, y] for y in range(rgba.height) for x in range(rgba.width)]


def edge_change_ratio(image: Image.Image) -> float:
    rgba = image.convert("RGBA")
    data = rgba.load()
    changes = 0
    total = 0
    for y in range(rgba.height):
        for x in range(rgba.width - 1):
            total += 1
            if data[x, y][:3] != data[x + 1, y][:3]:
                changes += 1
    for y in range(rgba.height - 1):
        for x in range(rgba.width):
            total += 1
            if data[x, y][:3] != data[x, y + 1][:3]:
                changes += 1
    return changes / total


def expected_native_background_from_reference() -> Image.Image:
    with Image.open(REFERENCE_IMAGE) as image:
        return ImageOps.fit(
            image.convert("RGBA"),
            NATIVE_BG_SIZE,
            method=Image.Resampling.NEAREST,
            centering=(0.5, 0.5),
        )


class DayMapAssetPipelineTest(unittest.TestCase):
    def _assert_exact_nearest_export(self, native_path: Path, runtime_path: Path, runtime_size: tuple[int, int]) -> None:
        self.assertTrue(native_path.exists(), f"{native_path}: missing native source")
        self.assertTrue(runtime_path.exists(), f"{runtime_path}: missing runtime texture")
        native = load_image(native_path)
        runtime = load_image(runtime_path)
        self.assertEqual(runtime.size, runtime_size, f"{runtime_path.name}: wrong runtime size")
        expected = native.resize(runtime_size, Image.Resampling.NEAREST)
        self.assertEqual(runtime.mode, expected.mode, f"{runtime_path.name}: wrong runtime mode")
        self.assertEqual(runtime.tobytes(), expected.tobytes(), f"{runtime_path.name}: not an exact nearest export")

    def test_background_is_native_grid_export(self) -> None:
        native_path = SOURCE / "daymap_bg_native.png"
        runtime_path = RUNTIME / "daymap_bg.png"
        self.assertTrue(native_path.exists(), f"{native_path}: missing native source")
        native = load_image(native_path).convert("RGBA")
        self.assertEqual(native.size, NATIVE_BG_SIZE, "daymap background has wrong native size")
        alpha_values = native.getchannel("A").getextrema()
        self.assertGreaterEqual(alpha_values[0], 250, "daymap background must be effectively opaque")
        expected = expected_native_background_from_reference()
        self.assertEqual(
            native.tobytes(),
            expected.tobytes(),
            "daymap native background must be a nearest-neighbor normalization of the retained reference",
        )
        self._assert_exact_nearest_export(native_path, runtime_path, RUNTIME_BG_SIZE)

    def test_background_uses_title_style_dark_table_and_amber_accents(self) -> None:
        native_path = SOURCE / "daymap_bg_native.png"
        self.assertTrue(native_path.exists(), f"{native_path}: missing native source")
        native = load_image(native_path).convert("RGBA")
        pixels = rgba_pixels(native)
        light_pixels = sum(1 for r, g, b, a in pixels if a >= 250 and r >= 210 and g >= 210 and b >= 210)
        cool_dark_pixels = sum(
            1
            for r, g, b, a in pixels
            if a >= 250 and r < 80 and g < 100 and b < 110 and g >= r * 0.65 and b >= r * 0.8
        )
        parchment_pixels = sum(
            1
            for r, g, b, a in pixels
            if a >= 250 and 70 <= r <= 180 and 55 <= g <= 150 and 35 <= b <= 115
        )
        amber_pixels = sum(1 for r, g, b, a in pixels if a >= 250 and r >= 120 and 50 <= g <= 160 and b <= 100)
        self.assertLess(light_pixels, 180, "daymap background should not contain large white placeholder text")
        self.assertGreaterEqual(
            cool_dark_pixels,
            MIN_COOL_DARK_PIXELS,
            "daymap background needs title-style dark cool table/river tones",
        )
        self.assertGreaterEqual(
            parchment_pixels,
            MIN_PARCHMENT_PIXELS,
            "daymap background needs a readable parchment map plate",
        )
        self.assertGreaterEqual(
            amber_pixels,
            MIN_AMBER_PIXELS,
            "daymap background needs sparse amber light accents",
        )

    def test_background_is_not_a_low_complexity_procedural_placeholder(self) -> None:
        native_path = SOURCE / "daymap_bg_native.png"
        self.assertTrue(native_path.exists(), f"{native_path}: missing native source")
        native = load_image(native_path).convert("RGBA")
        colors = native.convert("RGB").getcolors(maxcolors=65536)
        self.assertIsNotNone(colors, "daymap background has too many native colors to count")
        assert colors is not None
        self.assertGreaterEqual(
            len(colors),
            MIN_BG_COLORS,
            "daymap background is too low-complexity; likely a procedural placeholder",
        )
        self.assertGreaterEqual(
            edge_change_ratio(native),
            MIN_BG_EDGE_CHANGE_RATIO,
            "daymap background lacks source-art texture/detail; likely a procedural placeholder",
        )

    def test_marker_icons_are_native_grid_exports_with_alpha(self) -> None:
        for marker in MARKERS:
            with self.subTest(marker=marker):
                native_path = SOURCE / "markers" / f"{marker}_native.png"
                runtime_path = RUNTIME / "markers" / f"{marker}.png"
                self.assertTrue(native_path.exists(), f"{native_path}: missing native source")
                native = load_image(native_path).convert("RGBA")
                self.assertEqual(native.size, NATIVE_MARKER_SIZE, f"{marker}: wrong native size")
                alpha_values = native.getchannel("A").getextrema()
                self.assertEqual(alpha_values[0], 0, f"{marker}: marker needs transparent pixels")
                self.assertGreater(alpha_values[1], 0, f"{marker}: marker is empty")
                self.assertGreaterEqual(visible_pixel_count(native), 30, f"{marker}: marker is too sparse to read")
                self.assertLessEqual(
                    len(native.convert("RGBA").getcolors(maxcolors=65536)),
                    MAX_MARKER_COLORS,
                    f"{marker}: marker has too many colors / painterly noise",
                )
                self._assert_exact_nearest_export(native_path, runtime_path, RUNTIME_MARKER_SIZE)

    def test_marker_state_textures_are_native_grid_exports_with_alpha(self) -> None:
        for state in MARKER_STATES:
            with self.subTest(state=state):
                native_path = SOURCE / "markers" / f"{state}_native.png"
                runtime_path = RUNTIME / "markers" / f"{state}.png"
                self.assertTrue(native_path.exists(), f"{native_path}: missing native source")
                native = load_image(native_path).convert("RGBA")
                self.assertEqual(native.size, NATIVE_MARKER_STATE_SIZE, f"{state}: wrong native size")
                alpha_values = native.getchannel("A").getextrema()
                self.assertEqual(alpha_values[0], 0, f"{state}: state texture needs transparent pixels")
                self.assertGreater(alpha_values[1], 0, f"{state}: state texture is empty")
                self.assertGreaterEqual(visible_pixel_count(native), 20, f"{state}: state texture is too sparse")
                self._assert_exact_nearest_export(native_path, runtime_path, RUNTIME_MARKER_STATE_SIZE)


if __name__ == "__main__":
    unittest.main(verbosity=2)
