from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "intro"
RUNTIME = ROOT / "assets" / "textures" / "intro"
NATIVE_SIZE = (320, 180)
RUNTIME_SIZE = (1280, 720)
MAX_NATIVE_COLORS = 48
INTRO_SCENES = [
    "arrival_dungeon_overlook",
    "arrival_tavern_exterior",
    "arrival_tavern_door",
]
# Generous superset of the NarrationLabel rect in native coords; front must be clear here.
TEXT_BAND = (40, 100, 280, 156)


def load_image(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.copy()


class IntroAssetPipelineTest(unittest.TestCase):
    def _assert_native_grid_export(self, name: str) -> None:
        native_path = SOURCE / f"{name}_native.png"
        runtime_path = RUNTIME / f"{name}.png"
        self.assertTrue(native_path.exists(), f"{native_path}: missing native source")
        self.assertTrue(runtime_path.exists(), f"{runtime_path}: missing runtime texture")
        native = load_image(native_path)
        runtime = load_image(runtime_path)
        self.assertEqual(native.size, NATIVE_SIZE, f"{name}: wrong native size")
        self.assertEqual(runtime.size, RUNTIME_SIZE, f"{name}: wrong runtime size")
        expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
        self.assertEqual(runtime.mode, expected.mode, f"{name}: wrong runtime mode")
        self.assertEqual(runtime.tobytes(), expected.tobytes(), f"{name}: not a 4x nearest export")

    def test_back_front_composite_are_native_grid_exports(self) -> None:
        for scene in INTRO_SCENES:
            self._assert_native_grid_export(f"{scene}_back")
            self._assert_native_grid_export(f"{scene}_front")
            self._assert_native_grid_export(scene)

    def test_back_layer_is_full_opaque_painted_plate(self) -> None:
        for scene in INTRO_SCENES:
            back = load_image(SOURCE / f"{scene}_back_native.png").convert("RGBA")
            pixels = list(back.getdata())
            total = len(pixels)
            opaque = sum(1 for p in pixels if p[3] >= 200)
            warm = sum(1 for r, g, b, a in pixels if a >= 200 and r >= 120 and g >= 50 and b <= 100)
            cool = sum(1 for r, g, b, a in pixels if a >= 200 and g >= 65 and b >= 60 and r <= 90)
            self.assertGreaterEqual(opaque / total, 0.95, f"{scene}: back must be a full opaque plate")
            self.assertGreaterEqual(warm, 40, f"{scene}: back missing amber accents (not real art?)")
            self.assertGreaterEqual(cool, 200, f"{scene}: back missing teal tones (not real art?)")
            self.assertLessEqual(
                len(back.convert("RGB").getcolors(maxcolors=65536)),
                MAX_NATIVE_COLORS,
                f"{scene}: back has too many native colors / painterly noise",
            )

    def test_front_layer_clears_the_text_band(self) -> None:
        x0, y0, x1, y1 = TEXT_BAND
        for scene in INTRO_SCENES:
            front = load_image(SOURCE / f"{scene}_front_native.png").convert("RGBA")
            for y in range(y0, y1):
                for x in range(x0, x1):
                    self.assertEqual(
                        front.getpixel((x, y))[3],
                        0,
                        f"{scene}: front must be fully transparent over the text band at ({x},{y})",
                    )

    def test_front_layer_is_an_edge_frame_not_empty_not_full(self) -> None:
        total = NATIVE_SIZE[0] * NATIVE_SIZE[1]
        for scene in INTRO_SCENES:
            front = load_image(SOURCE / f"{scene}_front_native.png").convert("RGBA")
            opaque = sum(1 for p in front.getdata() if p[3] >= 200)
            self.assertGreaterEqual(opaque, int(total * 0.08), f"{scene}: front frame is too empty")
            self.assertLessEqual(opaque, int(total * 0.60), f"{scene}: front frame is too dense / a full wall")
            self.assertLessEqual(opaque, int(total * 0.30), f"{scene}: front frame should stay low-coverage")

    def test_front_layer_is_not_a_closed_frame(self) -> None:
        bottom_band = (0, 142, 320, 180)
        center_top_band = (92, 0, 228, 32)
        for scene in INTRO_SCENES:
            front = load_image(SOURCE / f"{scene}_front_native.png").convert("RGBA")
            bottom = front.crop(bottom_band)
            top_center = front.crop(center_top_band)
            bottom_opaque = sum(1 for p in bottom.getdata() if p[3] >= 200)
            top_center_opaque = sum(1 for p in top_center.getdata() if p[3] >= 200)
            self.assertLessEqual(
                bottom_opaque,
                int(bottom.width * bottom.height * 0.22),
                f"{scene}: bottom foreground closes the frame too much",
            )
            self.assertGreaterEqual(
                top_center_opaque,
                int(top_center.width * top_center.height * 0.08),
                f"{scene}: top foreground needs enough overhang to sell depth",
            )

    def test_scrim_darkens_center_and_clears_top(self) -> None:
        scrim_path = RUNTIME / "intro_text_scrim.png"
        self.assertTrue(scrim_path.exists(), f"{scrim_path}: missing narration scrim")
        scrim = load_image(scrim_path).convert("RGBA")
        self.assertEqual(scrim.size, RUNTIME_SIZE, "scrim must be full runtime size")
        self.assertGreater(scrim.getpixel((640, 520))[3], 60, "scrim must darken the text center")
        self.assertLess(scrim.getpixel((640, 40))[3], 20, "scrim must leave the top clear")


if __name__ == "__main__":
    unittest.main(verbosity=2)
