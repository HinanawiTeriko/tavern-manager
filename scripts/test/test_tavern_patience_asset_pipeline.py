from __future__ import annotations

from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "tavern_patience" / "patience_meter_reference.png"
SOURCE = ROOT / "assets" / "source" / "ui"
RUNTIME = ROOT / "assets" / "textures" / "ui"
CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_patience_ui_contact_sheet.png"
EXPECTED = {
    "patience_bar_bg": ((75, 7), (300, 28), "bar_patience_bg"),
    "patience_bar_fill": ((75, 7), (300, 28), "bar_patience_fill"),
    "icon_patience": ((8, 8), (32, 32), "icon_patience"),
}


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def load_rgba_checked(test_case: unittest.TestCase, path: Path) -> Image.Image:
    test_case.assertTrue(path.exists(), f"{path}: missing image")
    return load_rgba(path)


def visible_pixel_count(image: Image.Image) -> int:
    alpha = image.getchannel("A")
    return sum(alpha.histogram()[1:])


def image_pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    if hasattr(image, "get_flattened_data"):
        return list(image.get_flattened_data())
    return list(image.getdata())


class TavernPatienceAssetPipelineTest(unittest.TestCase):
    def test_assets_are_derived_from_generated_reference_source(self) -> None:
        self.assertTrue(RAW_SOURCE.exists(), f"{RAW_SOURCE}: missing generated raw reference")
        self.assertGreater(RAW_SOURCE.stat().st_size, 100_000, "generated reference is unexpectedly small")

    def test_native_and_runtime_assets_exist_with_expected_sizes(self) -> None:
        for native_id, (native_size, runtime_size, runtime_id) in EXPECTED.items():
            native_path = SOURCE / f"{native_id}_native.png"
            runtime_path = RUNTIME / f"{runtime_id}.png"
            with self.subTest(asset=native_id):
                self.assertTrue(native_path.exists(), f"{native_path}: missing native source")
                self.assertTrue(runtime_path.exists(), f"{runtime_path}: missing runtime texture")
                native = load_rgba_checked(self, native_path)
                runtime = load_rgba_checked(self, runtime_path)
                self.assertEqual(native.size, native_size)
                self.assertEqual(runtime.size, runtime_size)
                self.assertGreater(visible_pixel_count(native), 0, f"{native_id}: native image has no visible pixels")
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing contact sheet")
        self.assertGreater(CONTACT_SHEET.stat().st_size, 0, "contact sheet is empty")

    def test_runtime_assets_are_exact_four_x_nearest_exports(self) -> None:
        for native_id, (native_size, runtime_size, runtime_id) in EXPECTED.items():
            native_path = SOURCE / f"{native_id}_native.png"
            runtime_path = RUNTIME / f"{runtime_id}.png"
            with self.subTest(asset=native_id):
                native = load_rgba_checked(self, native_path)
                runtime = load_rgba_checked(self, runtime_path)
                self.assertEqual(native.size, native_size)
                self.assertEqual(runtime.size, runtime_size)
                expected = native.resize(runtime_size, Image.Resampling.NEAREST)
                self.assertEqual(runtime.tobytes(), expected.tobytes(), f"{runtime_id}: runtime must be exact 4x nearest export")

    def test_patience_bar_palette_is_dark_teal_with_amber_fill(self) -> None:
        bg = load_rgba_checked(self, SOURCE / "patience_bar_bg_native.png")
        fill = load_rgba_checked(self, SOURCE / "patience_bar_fill_native.png")
        icon = load_rgba_checked(self, SOURCE / "icon_patience_native.png")
        bg_pixels = [pixel for pixel in image_pixels(bg) if pixel[3] > 0]
        fill_pixels = [pixel for pixel in image_pixels(fill) if pixel[3] > 0]
        icon_pixels = [pixel for pixel in image_pixels(icon) if pixel[3] > 0]

        teal_pixels = sum(1 for r, g, b, _a in bg_pixels if b >= r and g >= r * 0.7 and b >= 24)
        dark_pixels = sum(1 for r, g, b, _a in bg_pixels if r + g + b <= 120)
        amber_pixels = sum(1 for r, g, b, _a in fill_pixels + icon_pixels if r >= 120 and g >= 64 and b <= 56)
        bg_colors = len(set(bg_pixels))
        fill_colors = len(set(fill_pixels))
        icon_colors = len(set(icon_pixels))

        self.assertGreaterEqual(teal_pixels, 18, "patience slot needs visible dark teal bias")
        self.assertGreaterEqual(dark_pixels, 90, "patience slot should stay dark enough for Tavern UI")
        self.assertGreaterEqual(amber_pixels, 24, "patience fill/icon need readable amber pixels")
        self.assertGreaterEqual(bg_colors, 14, "patience slot should preserve generated art texture, not flat geometry")
        self.assertGreaterEqual(fill_colors, 14, "patience fill should preserve generated art texture, not flat geometry")
        self.assertGreaterEqual(icon_colors, 8, "patience icon should preserve generated art texture, not flat geometry")


if __name__ == "__main__":
    unittest.main(verbosity=2)
