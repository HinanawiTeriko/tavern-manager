from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "tutorial_ui"
REFERENCE = SOURCE / "reference"
RUNTIME = ROOT / "assets" / "textures" / "tutorial" / "ui"
DOCS = ROOT / "docs" / "art"
SCALE = 4
ASSETS = {
    "tutorial_panel": {"native_size": (116, 48), "min_visible_ratio": 0.45},
    "tutorial_highlight_frame": {"native_size": (72, 40), "min_visible_ratio": 0.10},
}


def load_image(path: Path) -> Image.Image:
    if not path.exists():
        raise AssertionError(f"{path}: missing image")
    with Image.open(path) as image:
        return image.copy()


def is_magenta_key_fringe(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, _a = pixel
    return r > 48 and b > 48 and abs(r - b) < 80 and g < min(r, b) * 0.58


class TutorialUiAssetPipelineTest(unittest.TestCase):
    def test_reference_art_is_kept_for_review(self) -> None:
        reference = REFERENCE / "tutorial_ui_reference.png"
        self.assertTrue(reference.exists(), f"{reference}: missing generated reference")
        image = load_image(reference)
        self.assertGreaterEqual(image.width, 512)
        self.assertGreaterEqual(image.height, 512)

    def test_native_and_runtime_assets_exist_at_integer_scale(self) -> None:
        for name, spec in ASSETS.items():
            native_size = spec["native_size"]
            native_path = SOURCE / f"{name}_native.png"
            runtime_path = RUNTIME / f"{name}.png"
            native = load_image(native_path)
            runtime = load_image(runtime_path)
            self.assertEqual(native.size, native_size, f"{name}: wrong native size")
            self.assertEqual(
                runtime.size,
                (native_size[0] * SCALE, native_size[1] * SCALE),
                f"{name}: wrong runtime size",
            )
            expected = native.resize(runtime.size, Image.Resampling.NEAREST)
            self.assertEqual(
                runtime.tobytes(),
                expected.tobytes(),
                f"{name}: runtime is not exact nearest-neighbor export",
            )

    def test_alpha_layers_are_visible_and_transparent(self) -> None:
        for name, spec in ASSETS.items():
            native = load_image(SOURCE / f"{name}_native.png").convert("RGBA")
            alpha = native.getchannel("A")
            self.assertEqual(alpha.getextrema()[0], 0, f"{name}: needs transparent pixels")
            self.assertGreater(alpha.getextrema()[1], 0, f"{name}: needs visible pixels")
            visible = sum(alpha.histogram()[1:])
            self.assertGreater(
                visible,
                native.width * native.height * spec["min_visible_ratio"],
                f"{name}: too sparse",
            )

    def test_chroma_key_is_fully_cleaned_from_cutouts(self) -> None:
        for path in [
            *(SOURCE / f"{name}_native.png" for name in ASSETS),
            *(RUNTIME / f"{name}.png" for name in ASSETS),
        ]:
            image = load_image(path).convert("RGBA")
            pixels = [
                image.getpixel((x, y))
                for y in range(image.height)
                for x in range(image.width)
            ]
            visible_fringe = sum(
                1 for pixel in pixels if pixel[3] > 0 and is_magenta_key_fringe(pixel)
            )
            transparent_key_rgb = sum(
                1 for pixel in pixels if pixel[3] == 0 and is_magenta_key_fringe(pixel)
            )
            self.assertEqual(visible_fringe, 0, f"{path}: visible magenta key fringe remains")
            self.assertEqual(
                transparent_key_rgb,
                0,
                f"{path}: transparent pixels still retain magenta key RGB",
            )

    def test_contact_sheet_exists(self) -> None:
        sheet = DOCS / "tutorial_ui_contact_sheet.png"
        self.assertTrue(sheet.exists(), f"{sheet}: missing contact sheet")
        image = load_image(sheet)
        self.assertGreaterEqual(image.width, 464)
        self.assertGreaterEqual(image.height, 192)


if __name__ == "__main__":
    unittest.main(verbosity=2)
