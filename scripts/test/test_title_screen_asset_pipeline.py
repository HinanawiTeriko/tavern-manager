from hashlib import sha256
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "title"
REFERENCE = SOURCE / "reference"
RUNTIME = ROOT / "assets" / "textures" / "title"
TOOLS = ROOT / "scripts" / "tools"
SCALE = 4
MARKER_SCALE = 2
FULL_LAYERS = [
    "title_pixel_bg_clean",
    "title_pixel_glow_mask",
    "title_pixel_logo",
    "title_pixel_menu_bands",
]
CROPPED_LAYERS = ["title_pixel_menu_marker"]
TRANSPARENT_LAYERS = [
    "title_pixel_glow_mask",
    "title_pixel_logo",
    "title_pixel_menu_bands",
    "title_pixel_menu_marker",
]
DIAGNOSTIC_LAYERS = [
    "title_pixel_logo_extracted",
    "title_pixel_menu_bands_extracted",
]
OBSOLETE_DIAGNOSTIC_LAYERS = [
    "title_pixel_logo_cutout",
    "title_pixel_menu_bands_cutout",
]
EXPECTED_NATIVE_BAND_TOPS = [36, 62, 88, 114]
EXPECTED_RUNTIME_BAND_TOPS = [top * SCALE for top in EXPECTED_NATIVE_BAND_TOPS]
LOGO_MIN_VISIBLE_PIXELS = 5_500
LOGO_MIN_BBOX_WIDTH = 175
LOGO_MIN_BBOX_HEIGHT = 85
MENU_BAND_MIN_VISIBLE_PIXELS = 1_300
MENU_BAND_MIN_BBOX_WIDTH = 70
MENU_BAND_MIN_BBOX_HEIGHT = 20
GLOW_MIN_VISIBLE_PIXELS = 8_000
GLOW_MAX_VISIBLE_PIXELS = 20_000
GLOW_MIN_BBOX_WIDTH = 180
GLOW_MIN_BBOX_HEIGHT = 120
GLOW_MAX_BBOX_WIDTH = 240
GLOW_MAX_BBOX_HEIGHT = 170
MARKER_SIZE = (122, 14)
MARKER_MIN_VISIBLE_PIXELS = 900
MARKER_MIN_BBOX_WIDTH = 100
MARKER_MIN_BBOX_HEIGHT = 10
MARKER_MIN_VISIBLE_COLORS = 64
EXTRACTED_LOGO_MIN_VISIBLE_PIXELS = 150_000
EXTRACTED_LOGO_MIN_BBOX_WIDTH = 900
EXTRACTED_LOGO_MIN_BBOX_HEIGHT = 450
EXTRACTED_MENU_BAND_MIN_VISIBLE_PIXELS = 37_000
EXTRACTED_MENU_BAND_MIN_BBOX_WIDTH = 370
EXTRACTED_MENU_BAND_MIN_BBOX_HEIGHT = 100


def visible_pixel_count(image: Image.Image) -> int:
    histogram = image.convert("RGBA").getchannel("A").histogram()
    return sum(histogram[1:])


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    return image.convert("RGBA").getchannel("A").getbbox()


def bbox_size(box: tuple[int, int, int, int] | None) -> tuple[int, int]:
    if box is None:
        return (0, 0)
    return (box[2] - box[0], box[3] - box[1])


def visible_row_groups(image: Image.Image) -> list[tuple[int, int]]:
    alpha = image.convert("RGBA").getchannel("A")
    rows = [
        y
        for y in range(alpha.height)
        if alpha.crop((0, y, alpha.width, y + 1)).getbbox() is not None
    ]
    groups: list[tuple[int, int]] = []
    for row in rows:
        if not groups or row != groups[-1][1] + 1:
            groups.append((row, row))
        else:
            groups[-1] = (groups[-1][0], row)
    return groups


def isolated_alpha_pixels(image: Image.Image) -> int:
    alpha = image.convert("RGBA").getchannel("A")
    pixels = alpha.load()
    isolated = 0
    for y in range(alpha.height):
        for x in range(alpha.width):
            if pixels[x, y] == 0:
                continue
            neighbors = [
                (neighbor_x, neighbor_y)
                for neighbor_y in range(max(0, y - 1), min(alpha.height, y + 2))
                for neighbor_x in range(max(0, x - 1), min(alpha.width, x + 2))
                if (neighbor_x, neighbor_y) != (x, y)
            ]
            if all(pixels[neighbor_x, neighbor_y] == 0 for neighbor_x, neighbor_y in neighbors):
                isolated += 1
    return isolated


def file_hash(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


def visible_color_count(image: Image.Image) -> int:
    rgba = image.convert("RGBA")
    pixels = rgba.get_flattened_data() if hasattr(rgba, "get_flattened_data") else rgba.getdata()
    return len({pixel for pixel in pixels if pixel[3] > 0})


def load_image(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.copy()


def seed_destinations(paths: list[Path]) -> dict[Path, str]:
    for index, path in enumerate(paths):
        path.parent.mkdir(parents=True, exist_ok=True)
        Image.new("RGBA", (3, 3), (index + 1, 2, 3, 255)).save(path)
    return {path: file_hash(path) for path in paths}


def assert_destinations_unchanged(test_case: unittest.TestCase, hashes: dict[Path, str]) -> None:
    for path, expected_hash in hashes.items():
        test_case.assertEqual(file_hash(path), expected_hash, f"{path.name}: replaced before validation completed")


class TitleScreenAssetPipelineTest(unittest.TestCase):
    def assert_transparent_layer(self, path: Path) -> None:
        image = load_image(path)
        self.assertIn("A", image.getbands(), f"{path.name}: needs an alpha channel")
        alpha_extrema = image.getchannel("A").getextrema()
        self.assertEqual(alpha_extrema[0], 0, f"{path.name}: needs transparent pixels")
        self.assertGreater(alpha_extrema[1], 0, f"{path.name}: transparent layer is empty")

    def assert_exact_scale(self, name: str, scale: int = SCALE) -> None:
        native = load_image(SOURCE / f"{name}_native.png")
        runtime = load_image(RUNTIME / f"{name}.png")
        expected_size = (native.width * scale, native.height * scale)
        self.assertEqual(runtime.size, expected_size, f"{name}: wrong runtime size {runtime.size}")
        expected = native.resize(expected_size, Image.Resampling.NEAREST)
        self.assertEqual(runtime.mode, expected.mode, f"{name}: wrong runtime mode {runtime.mode}")
        self.assertEqual(runtime.tobytes(), expected.tobytes(), f"{name}: not an exact nearest-neighbor export")

    def assert_minimum_visual_size(
        self,
        image: Image.Image,
        label: str,
        min_pixels: int,
        min_width: int,
        min_height: int,
    ) -> None:
        width, height = bbox_size(alpha_bbox(image))
        self.assertGreaterEqual(visible_pixel_count(image), min_pixels, f"{label}: too few visible pixels")
        self.assertGreaterEqual(width, min_width, f"{label}: alpha bbox is too narrow")
        self.assertGreaterEqual(height, min_height, f"{label}: alpha bbox is too short")

    def test_native_and_runtime_assets_match_pipeline_contract(self) -> None:
        for name in FULL_LAYERS:
            native = load_image(SOURCE / f"{name}_native.png")
            self.assertEqual(native.size, (320, 180), f"{name}: wrong native size {native.size}")

        marker = load_image(SOURCE / "title_pixel_menu_marker_native.png")
        self.assertEqual(marker.size, MARKER_SIZE, f"title_pixel_menu_marker: wrong native size {marker.size}")

        for name in TRANSPARENT_LAYERS:
            native_path = SOURCE / f"{name}_native.png"
            self.assert_transparent_layer(native_path)
            self.assertEqual(
                isolated_alpha_pixels(load_image(native_path)),
                0,
                f"{name}: native source contains isolated authored alpha pixels",
            )

        native_band_groups = visible_row_groups(load_image(SOURCE / "title_pixel_menu_bands_native.png"))
        runtime_band_groups = visible_row_groups(load_image(RUNTIME / "title_pixel_menu_bands.png"))
        self.assertEqual(len(native_band_groups), 4, f"title_pixel_menu_bands: expected 4 native bands")
        self.assertEqual(len(runtime_band_groups), 4, f"title_pixel_menu_bands: expected 4 runtime bands")
        self.assertEqual([top for top, _ in native_band_groups], EXPECTED_NATIVE_BAND_TOPS)
        self.assertEqual([top for top, _ in runtime_band_groups], EXPECTED_RUNTIME_BAND_TOPS)

        for name in FULL_LAYERS:
            self.assert_exact_scale(name)
        self.assert_exact_scale("title_pixel_menu_marker", MARKER_SCALE)

    def test_generated_diagnostics_have_clear_names_and_alpha(self) -> None:
        for name in DIAGNOSTIC_LAYERS:
            self.assert_transparent_layer(REFERENCE / f"{name}.png")
        for name in OBSOLETE_DIAGNOSTIC_LAYERS:
            self.assertFalse((REFERENCE / f"{name}.png").exists(), f"{name}.png: obsolete diagnostic remains")

        logo = load_image(REFERENCE / "title_pixel_logo_extracted.png")
        self.assert_minimum_visual_size(
            logo,
            "title_pixel_logo_extracted",
            EXTRACTED_LOGO_MIN_VISIBLE_PIXELS,
            EXTRACTED_LOGO_MIN_BBOX_WIDTH,
            EXTRACTED_LOGO_MIN_BBOX_HEIGHT,
        )
        bands = load_image(REFERENCE / "title_pixel_menu_bands_extracted.png").convert("RGBA")
        groups = visible_row_groups(bands)
        self.assertEqual(len(groups), 4, f"title_pixel_menu_bands_extracted: expected 4 bands")
        for index, (top, bottom) in enumerate(groups, start=1):
            self.assert_minimum_visual_size(
                bands.crop((0, top, bands.width, bottom + 1)),
                f"title_pixel_menu_bands_extracted[{index}]",
                EXTRACTED_MENU_BAND_MIN_VISIBLE_PIXELS,
                EXTRACTED_MENU_BAND_MIN_BBOX_WIDTH,
                EXTRACTED_MENU_BAND_MIN_BBOX_HEIGHT,
            )

    def test_native_visuals_have_reasonable_coverage(self) -> None:
        logo = load_image(SOURCE / "title_pixel_logo_native.png")
        self.assert_minimum_visual_size(
            logo,
            "title_pixel_logo",
            LOGO_MIN_VISIBLE_PIXELS,
            LOGO_MIN_BBOX_WIDTH,
            LOGO_MIN_BBOX_HEIGHT,
        )

        bands = load_image(SOURCE / "title_pixel_menu_bands_native.png").convert("RGBA")
        for index, (top, bottom) in enumerate(visible_row_groups(bands), start=1):
            band = bands.crop((0, top, bands.width, bottom + 1))
            self.assert_minimum_visual_size(
                band,
                f"title_pixel_menu_bands[{index}]",
                MENU_BAND_MIN_VISIBLE_PIXELS,
                MENU_BAND_MIN_BBOX_WIDTH,
                MENU_BAND_MIN_BBOX_HEIGHT,
            )

        glow = load_image(SOURCE / "title_pixel_glow_mask_native.png")
        self.assert_minimum_visual_size(
            glow,
            "title_pixel_glow_mask",
            GLOW_MIN_VISIBLE_PIXELS,
            GLOW_MIN_BBOX_WIDTH,
            GLOW_MIN_BBOX_HEIGHT,
        )
        self.assertLessEqual(visible_pixel_count(glow), GLOW_MAX_VISIBLE_PIXELS, "title_pixel_glow_mask: coverage is too broad")
        glow_width, glow_height = bbox_size(alpha_bbox(glow))
        self.assertLessEqual(glow_width, GLOW_MAX_BBOX_WIDTH, "title_pixel_glow_mask: alpha bbox is too wide")
        self.assertLessEqual(glow_height, GLOW_MAX_BBOX_HEIGHT, "title_pixel_glow_mask: alpha bbox is too tall")

        marker = load_image(SOURCE / "title_pixel_menu_marker_native.png")
        self.assert_minimum_visual_size(
            marker,
            "title_pixel_menu_marker",
            MARKER_MIN_VISIBLE_PIXELS,
            MARKER_MIN_BBOX_WIDTH,
            MARKER_MIN_BBOX_HEIGHT,
        )
        self.assertGreaterEqual(
            visible_color_count(marker),
            MARKER_MIN_VISIBLE_COLORS,
            "title_pixel_menu_marker must keep the hand-painted brush variation",
        )

    def test_prepare_does_not_replace_outputs_when_late_validation_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            tool = root / "scripts" / "tools" / "prepare_title_screen_sources.py"
            tool.parent.mkdir(parents=True)
            shutil.copy2(TOOLS / tool.name, tool)
            reference = root / "assets" / "source" / "title" / "reference"
            reference.mkdir(parents=True)
            shutil.copy2(REFERENCE / "title_pixel_bg_clean_reference.png", reference)
            blank = Image.new("RGB", (1672, 941), (0, 0, 0))
            blank.save(reference / "title_pixel_composite_reference.png")

            destinations = [
                root / "assets" / "source" / "title" / f"{name}_native.png"
                for name in FULL_LAYERS + CROPPED_LAYERS
            ] + [
                reference / f"{name}.png"
                for name in DIAGNOSTIC_LAYERS
            ]
            hashes = seed_destinations(destinations)
            result = subprocess.run([sys.executable, str(tool)], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0, "prepare accepted malformed extracted visuals")
            assert_destinations_unchanged(self, hashes)

    def test_export_does_not_replace_outputs_when_marker_visual_is_tiny(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            tool = root / "scripts" / "tools" / "export_title_screen_assets.py"
            tool.parent.mkdir(parents=True)
            shutil.copy2(TOOLS / tool.name, tool)
            source = root / "assets" / "source" / "title"
            source.mkdir(parents=True)
            for name in FULL_LAYERS + CROPPED_LAYERS:
                shutil.copy2(SOURCE / f"{name}_native.png", source)

            tiny_marker = Image.new("RGBA", MARKER_SIZE, (0, 0, 0, 0))
            ImageDraw.Draw(tiny_marker).rectangle((2, 2, 3, 3), fill=(255, 184, 24, 255))
            tiny_marker.save(source / "title_pixel_menu_marker_native.png")

            destinations = [
                root / "assets" / "textures" / "title" / f"{name}.png"
                for name in FULL_LAYERS + CROPPED_LAYERS
            ]
            hashes = seed_destinations(destinations)
            result = subprocess.run([sys.executable, str(tool)], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0, "export accepted a malformed tiny marker")
            assert_destinations_unchanged(self, hashes)

    def test_export_rejects_glow_with_unreasonably_broad_bbox(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            tool = root / "scripts" / "tools" / "export_title_screen_assets.py"
            tool.parent.mkdir(parents=True)
            shutil.copy2(TOOLS / tool.name, tool)
            source = root / "assets" / "source" / "title"
            source.mkdir(parents=True)
            for name in FULL_LAYERS + CROPPED_LAYERS:
                shutil.copy2(SOURCE / f"{name}_native.png", source)

            broad_glow = Image.new("RGBA", (320, 180), (255, 138, 32, 0))
            draw = ImageDraw.Draw(broad_glow)
            draw.rectangle((110, 50, 209, 129), fill=(255, 138, 32, 64))
            draw.line((0, 90, 319, 90), fill=(255, 138, 32, 64), width=2)
            draw.line((160, 0, 160, 179), fill=(255, 138, 32, 64), width=2)
            broad_glow.save(source / "title_pixel_glow_mask_native.png")

            destinations = [
                root / "assets" / "textures" / "title" / f"{name}.png"
                for name in FULL_LAYERS + CROPPED_LAYERS
            ]
            hashes = seed_destinations(destinations)
            result = subprocess.run([sys.executable, str(tool)], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0, "export accepted a glow spanning the full native canvas")
            assert_destinations_unchanged(self, hashes)


if __name__ == "__main__":
    unittest.main(verbosity=2)
