from pathlib import Path
import sys
import unittest

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "tools"))

from prepare_daymap_sources import harmonize_full_map

SOURCE = ROOT / "assets" / "source" / "daymap"
REFERENCE = SOURCE / "reference"
RUNTIME = ROOT / "assets" / "textures" / "daymap"
NATIVE_BG_SIZE = (320, 180)
RUNTIME_BG_SIZE = (1280, 720)
FULL_MAP_NATIVE_SIZE = (640, 360)
FULL_MAP_RUNTIME_SIZE = (2560, 1440)
NATIVE_MARKER_SIZE = (24, 24)
RUNTIME_MARKER_SIZE = (96, 96)
NATIVE_MARKER_STATE_SIZE = (32, 32)
RUNTIME_MARKER_STATE_SIZE = (128, 128)
SCALE = 4
MAX_MARKER_COLORS = 10
MAX_MARKER_LEAFY_GREEN_RATIO = 0.20
MIN_MARKER_AMBER_RATIO = 0.05
MIN_BG_COLORS = 1000
MIN_BG_EDGE_CHANGE_RATIO = 0.18
MIN_COOL_DARK_PIXELS = 2000
MIN_PARCHMENT_PIXELS = 12000
MIN_AMBER_PIXELS = 400
FULL_MAP_REFERENCE = REFERENCE / "daymap_full_reference_v2_generated.png"
REFERENCE_IMAGE = FULL_MAP_REFERENCE
FULL_MAP_NATIVE = SOURCE / "daymap_full_native.png"
FULL_MAP_RUNTIME = RUNTIME / "daymap_full.png"
MIN_FULL_MAP_COLORS = 64
MAX_FULL_MAP_COLORS = 160
MIN_FULL_MAP_EDGE_CHANGE_RATIO = 0.10
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


def source_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


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


def expected_full_map_native_from_reference() -> Image.Image:
    with Image.open(FULL_MAP_REFERENCE) as image:
        native = ImageOps.fit(
            image.convert("RGBA"),
            FULL_MAP_NATIVE_SIZE,
            method=Image.Resampling.NEAREST,
            centering=(0.5, 0.5),
        )
    return harmonize_full_map(native)


def raw_full_map_native_from_reference() -> Image.Image:
    with Image.open(FULL_MAP_REFERENCE) as image:
        return ImageOps.fit(
            image.convert("RGBA"),
            FULL_MAP_NATIVE_SIZE,
            method=Image.Resampling.NEAREST,
            centering=(0.5, 0.5),
        )


def brightness_stats(image: Image.Image) -> tuple[float, int]:
    pixels = rgba_pixels(image)
    opaque = [(r, g, b) for r, g, b, a in pixels if a >= 250]
    average = sum((r + g + b) / 3 for r, g, b in opaque) / max(len(opaque), 1)
    bright_pixels = sum(1 for r, g, b in opaque if r >= 210 and g >= 200 and b >= 180)
    return average, bright_pixels


def cool_dark_pixel_count(image: Image.Image) -> int:
    return sum(
        1
        for r, g, b, a in rgba_pixels(image)
        if a >= 250 and r < 90 and g < 115 and b < 120 and g >= r * 0.65 and b >= r * 0.8
    )


def amber_pixel_count(image: Image.Image) -> int:
    return sum(1 for r, g, b, a in rgba_pixels(image) if a >= 250 and r >= 105 and 45 <= g <= 150 and b <= 100)


def visible_rgba_pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    return [pixel for pixel in rgba_pixels(image) if pixel[3] > 0]


def leafy_green_ratio(image: Image.Image) -> float:
    visible = visible_rgba_pixels(image)
    leafy = sum(1 for r, g, b, _a in visible if g >= 70 and g > r * 1.16 and g > b * 1.12)
    return leafy / max(len(visible), 1)


def marker_amber_ratio(image: Image.Image) -> float:
    visible = visible_rgba_pixels(image)
    amber = sum(1 for r, g, b, _a in visible if r >= 100 and 45 <= g <= 145 and b <= 95)
    return amber / max(len(visible), 1)


def alpha_bbox_center_offset(image: Image.Image) -> tuple[float, float]:
    rgba = image.convert("RGBA")
    bbox = rgba.getchannel("A").getbbox()
    if bbox is None:
        return (999.0, 999.0)
    left, top, right, bottom = bbox
    bbox_center_x = (left + right - 1) * 0.5
    bbox_center_y = (top + bottom - 1) * 0.5
    image_center_x = (rgba.width - 1) * 0.5
    image_center_y = (rgba.height - 1) * 0.5
    return (abs(bbox_center_x - image_center_x), abs(bbox_center_y - image_center_y))


class DayMapAssetPipelineTest(unittest.TestCase):
    def test_daymap_marker_exporter_uses_reference_art_not_procedural_drawing(self) -> None:
        source = source_text(ROOT / "scripts" / "tools" / "prepare_daymap_sources.py")
        self.assertNotIn("ImageDraw", source, "marker assets must come from source art sheets, not procedural drawing")
        self.assertNotIn("_draw_marker_", source, "marker icons must not be constructed with procedural draw helpers")
        self.assertNotIn("build_marker_icon", source, "marker icons must not be constructed procedurally")
        self.assertIn("MARKER_SHEET_IMAGE", source, "marker exporter must consume a marker icon reference sheet")
        self.assertIn("MARKER_STATE_SHEET_IMAGE", source, "marker exporter must consume a marker state reference sheet")

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

    def test_full_map_is_native_grid_export(self) -> None:
        self.assertTrue(
            FULL_MAP_REFERENCE.exists(),
            f"{FULL_MAP_REFERENCE}: missing full DayMap reference",
        )
        self.assertTrue(
            FULL_MAP_NATIVE.exists(),
            f"{FULL_MAP_NATIVE}: missing full native map source",
        )
        expected_full = expected_full_map_native_from_reference()
        full_native = load_image(FULL_MAP_NATIVE).convert("RGBA")
        self.assertEqual(full_native.size, FULL_MAP_NATIVE_SIZE, "full map native has wrong size")
        self.assertEqual(
            full_native.tobytes(),
            expected_full.tobytes(),
            "full map native must be a nearest-neighbor normalization of the retained reference",
        )
        alpha_values = full_native.getchannel("A").getextrema()
        self.assertGreaterEqual(alpha_values[0], 250, "full map must be effectively opaque")
        self._assert_exact_nearest_export(FULL_MAP_NATIVE, FULL_MAP_RUNTIME, FULL_MAP_RUNTIME_SIZE)

    def test_full_map_is_opaque_and_not_flat_temporary_art(self) -> None:
        self.assertTrue(FULL_MAP_NATIVE.exists(), f"{FULL_MAP_NATIVE}: missing full native map source")
        native = load_image(FULL_MAP_NATIVE).convert("RGBA")
        alpha_values = native.getchannel("A").getextrema()
        self.assertGreaterEqual(alpha_values[0], 250, "full map must be opaque")
        colors = native.convert("RGB").getcolors(maxcolors=FULL_MAP_NATIVE_SIZE[0] * FULL_MAP_NATIVE_SIZE[1])
        self.assertIsNotNone(colors, "full map has too many colors to count")
        assert colors is not None
        self.assertGreaterEqual(
            len(colors),
            MIN_FULL_MAP_COLORS,
            "full map is too low-complexity for final art",
        )
        self.assertLessEqual(
            len(colors),
            MAX_FULL_MAP_COLORS,
            "full map keeps too many painterly colors; it needs a restrained pixel palette",
        )
        self.assertGreaterEqual(
            edge_change_ratio(native),
            MIN_FULL_MAP_EDGE_CHANGE_RATIO,
            "full map lacks source-art texture/detail",
        )

    def test_full_map_is_harmonized_toward_title_style(self) -> None:
        raw_native = raw_full_map_native_from_reference().convert("RGBA")
        full_native = load_image(FULL_MAP_NATIVE).convert("RGBA")
        raw_average, raw_bright = brightness_stats(raw_native)
        native_average, native_bright = brightness_stats(full_native)
        self.assertLessEqual(
            native_average,
            raw_average - 1.5,
            "full map needs a visible title-style color grade instead of using raw generated art",
        )
        self.assertGreaterEqual(
            native_average,
            42.0,
            "full map color grade should not crush the v2 source into a muddy dark plate",
        )
        self.assertLessEqual(
            native_bright,
            max(8, raw_bright),
            "full map should suppress bright parchment highlights so UI text can sit above it",
        )
        self.assertGreaterEqual(
            cool_dark_pixel_count(full_native),
            120000,
            "full map needs enough title-style cool dark pixels to bind it to the main UI",
        )
        self.assertGreaterEqual(
            amber_pixel_count(full_native),
            9000,
            "full map should preserve amber candle/map accents after palette reduction",
        )

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
                self.assertLessEqual(
                    leafy_green_ratio(native),
                    MAX_MARKER_LEAFY_GREEN_RATIO,
                    f"{marker}: marker still reads as a separate leafy-green illustration",
                )
                self.assertGreaterEqual(
                    marker_amber_ratio(native),
                    MIN_MARKER_AMBER_RATIO,
                    f"{marker}: marker needs a small amber accent to match the DayMap palette",
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

    def test_marker_state_textures_are_centered_on_marker_anchor(self) -> None:
        for state in ["marker_hover_ring", "marker_selected_ring", "marker_reveal_burst"]:
            with self.subTest(state=state):
                native_path = SOURCE / "markers" / f"{state}_native.png"
                native = load_image(native_path).convert("RGBA")
                offset_x, offset_y = alpha_bbox_center_offset(native)
                self.assertLessEqual(offset_x, 1.25, f"{state}: alpha silhouette is horizontally off-center")
                self.assertLessEqual(offset_y, 1.25, f"{state}: alpha silhouette is vertically off-center")


if __name__ == "__main__":
    unittest.main(verbosity=2)
