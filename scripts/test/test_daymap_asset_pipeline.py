from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "daymap"
RUNTIME = ROOT / "assets" / "textures" / "daymap"
NATIVE_BG_SIZE = (320, 180)
RUNTIME_BG_SIZE = (1280, 720)
NATIVE_MARKER_SIZE = (24, 24)
RUNTIME_MARKER_SIZE = (96, 96)
SCALE = 4
MAX_BG_COLORS = 64
MAX_MARKER_COLORS = 16
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
        self.assertLessEqual(
            len(native.convert("RGB").getcolors(maxcolors=65536)),
            MAX_BG_COLORS,
            "daymap background has too many colors / painterly noise",
        )
        self._assert_exact_nearest_export(native_path, runtime_path, RUNTIME_BG_SIZE)

    def test_background_is_not_the_old_text_placeholder(self) -> None:
        native_path = SOURCE / "daymap_bg_native.png"
        self.assertTrue(native_path.exists(), f"{native_path}: missing native source")
        native = load_image(native_path).convert("RGBA")
        pixels = rgba_pixels(native)
        light_pixels = sum(1 for r, g, b, a in pixels if a >= 250 and r >= 210 and g >= 210 and b >= 210)
        teal_pixels = sum(1 for r, g, b, a in pixels if a >= 250 and g >= 45 and b >= 45 and b >= r * 1.05)
        amber_pixels = sum(1 for r, g, b, a in pixels if a >= 250 and r >= 120 and 50 <= g <= 160 and b <= 100)
        self.assertLess(light_pixels, 180, "daymap background should not contain large white placeholder text")
        self.assertGreaterEqual(teal_pixels, 350, "daymap background needs title-style dark teal tones")
        self.assertGreaterEqual(amber_pixels, 80, "daymap background needs sparse amber light accents")

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


if __name__ == "__main__":
    unittest.main(verbosity=2)
