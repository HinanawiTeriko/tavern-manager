import json
import math
from hashlib import sha256
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image

from scripts.tools.export_intro_assets import validate_source
from scripts.tools.prepare_intro_sources import prepare_named_outputs


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
RUNTIME_EXPORTS = [*STILLS, "intro_vignette"]
REFERENCE_FILES = [*STILLS, "tavern_continuity_master"]
NATIVE_NAMES = RUNTIME_EXPORTS
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
TOOLS = ROOT / "scripts" / "tools"
PREPARE_TOOL = TOOLS / "prepare_intro_sources.py"
EXPORT_TOOL = TOOLS / "export_intro_assets.py"
CONTACT_SHEET_POSITIONS = [(0, 0), (320, 0), (640, 0), (160, 180), (480, 180)]


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


def file_hash(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


def seed_destinations(paths: list[Path]) -> dict[Path, str]:
    for index, path in enumerate(paths):
        path.parent.mkdir(parents=True, exist_ok=True)
        Image.new(
            "RGBA",
            (2, 2),
            (17 + index, 31 + index, 47 + index, 255),
        ).save(path)
    return {path: file_hash(path) for path in paths}


def assert_destinations_unchanged(
    test_case: unittest.TestCase,
    expected_hashes: dict[Path, str],
) -> None:
    for path, expected_hash in expected_hashes.items():
        test_case.assertTrue(path.exists(), f"{path}: seeded destination was removed")
        test_case.assertEqual(
            file_hash(path),
            expected_hash,
            f"{path}: destination changed after failed pipeline run",
        )


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


def run_prepare_with_continuity_reference(reference: Image.Image) -> subprocess.CompletedProcess[str]:
    with tempfile.TemporaryDirectory() as temporary:
        temporary_root = Path(temporary)
        tool = temporary_root / "scripts" / "tools" / PREPARE_TOOL.name
        tool.parent.mkdir(parents=True)
        shutil.copy2(PREPARE_TOOL, tool)

        temporary_reference = (
            temporary_root / "assets" / "source" / "intro" / "reference"
        )
        shutil.copytree(REFERENCE, temporary_reference)
        reference.convert("RGB").save(
            temporary_reference / "tavern_continuity_master.png"
        )
        return subprocess.run(
            [sys.executable, str(tool)],
            capture_output=True,
            text=True,
        )


class IntroAssetPipelineTest(unittest.TestCase):
    def test_prepare_named_outputs_builds_only_requested_still(self) -> None:
        sentinel = Image.new("RGBA", NATIVE_SIZE, (12, 24, 36, 255))
        with patch(
            "scripts.tools.prepare_intro_sources.build_native",
            return_value=sentinel,
        ) as build_native_mock, patch(
            "scripts.tools.prepare_intro_sources.validate_still",
        ) as validate_still_mock:
            outputs = prepare_named_outputs(["intro_hearth_memory"])

        self.assertEqual(
            list(outputs),
            [SOURCE / "intro_hearth_memory_native.png"],
        )
        self.assertIs(outputs[SOURCE / "intro_hearth_memory_native.png"], sentinel)
        build_native_mock.assert_called_once_with("intro_hearth_memory")
        validate_still_mock.assert_called_once_with("intro_hearth_memory", sentinel)

    def test_prepare_named_outputs_rejects_unknown_still(self) -> None:
        with self.assertRaisesRegex(ValueError, "Unknown intro stills: missing"):
            prepare_named_outputs(["missing"])

    def test_approved_references_exist(self) -> None:
        for name in REFERENCE_FILES:
            path = REFERENCE / f"{name}.png"
            self.assertTrue(path.exists(), f"{path}: missing approved reference")
            image = load_image(path)
            self.assertGreaterEqual(image.width, RUNTIME_SIZE[0], f"{name}: reference is too narrow")
            self.assertGreaterEqual(image.height, RUNTIME_SIZE[1], f"{name}: reference is too short")

    def test_prepare_rejects_smooth_gradient_reference(self) -> None:
        gradient = Image.new("L", (1672, 941))
        gradient_pixels = gradient.load()
        for y in range(gradient.height):
            for x in range(gradient.width):
                gradient_pixels[x, y] = round(x / (gradient.width - 1) * 255)
        result = run_prepare_with_continuity_reference(gradient)

        self.assertNotEqual(
            result.returncode,
            0,
            "prepare accepted a smooth grayscale gradient reference",
        )
        self.assertIn("blank or low-complexity", result.stderr)

    def test_prepare_rejects_regular_stripes_reference(self) -> None:
        stripes = Image.new("L", (1672, 941))
        pixels = stripes.load()
        for y in range(stripes.height):
            for x in range(stripes.width):
                pixels[x, y] = 36 if (x // 24) % 2 == 0 else 196
        result = run_prepare_with_continuity_reference(stripes)

        self.assertNotEqual(
            result.returncode,
            0,
            "prepare accepted a regular stripes reference",
        )
        self.assertIn("blank or low-complexity", result.stderr)

    def test_prepare_rejects_smooth_periodic_reference(self) -> None:
        periodic = Image.new("L", (1672, 941))
        pixels = periodic.load()
        for y in range(periodic.height):
            for x in range(periodic.width):
                horizontal = math.sin(x * math.tau / 140)
                vertical = math.sin(y * math.tau / 96)
                pixels[x, y] = round(128 + 58 * horizontal + 48 * vertical)
        result = run_prepare_with_continuity_reference(periodic)

        self.assertNotEqual(
            result.returncode,
            0,
            "prepare accepted a smooth periodic reference",
        )
        self.assertIn("blank or low-complexity", result.stderr)

    def test_prepare_does_not_replace_outputs_when_validation_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            temporary_root = Path(temporary)
            temporary_tool = (
                temporary_root / "scripts" / "tools" / PREPARE_TOOL.name
            )
            temporary_tool.parent.mkdir(parents=True)
            shutil.copy2(PREPARE_TOOL, temporary_tool)

            temporary_source = temporary_root / "assets" / "source" / "intro"
            temporary_reference = temporary_source / "reference"
            temporary_reference.mkdir(parents=True)
            for name in REFERENCE_FILES:
                shutil.copy2(
                    REFERENCE / f"{name}.png",
                    temporary_reference / f"{name}.png",
                )
            Image.new("RGB", (1672, 941), (0, 0, 0)).save(
                temporary_reference / "intro_threshold.png"
            )

            destinations = [
                *(temporary_source / f"{name}_native.png" for name in STILLS),
                temporary_source / "intro_vignette_native.png",
                temporary_source / "intro_contact_sheet.png",
            ]
            original_hashes = seed_destinations(destinations)

            result = subprocess.run(
                [sys.executable, str(temporary_tool)],
                capture_output=True,
                text=True,
            )
            output = f"{result.stdout}\n{result.stderr}"

            self.assertNotEqual(result.returncode, 0)
            self.assertIn(
                "intro_threshold: approved reference is blank or low-complexity",
                output,
            )
            assert_destinations_unchanged(self, original_hashes)

    def test_export_does_not_replace_outputs_when_validation_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            temporary_root = Path(temporary)
            temporary_tool = (
                temporary_root / "scripts" / "tools" / EXPORT_TOOL.name
            )
            temporary_tool.parent.mkdir(parents=True)
            shutil.copy2(EXPORT_TOOL, temporary_tool)

            temporary_source = temporary_root / "assets" / "source" / "intro"
            temporary_source.mkdir(parents=True)
            for name in NATIVE_NAMES:
                shutil.copy2(
                    SOURCE / f"{name}_native.png",
                    temporary_source / f"{name}_native.png",
                )
            Image.new("RGBA", (3, 3), (0, 0, 0, 255)).save(
                temporary_source / "intro_threshold_native.png"
            )

            temporary_runtime = temporary_root / "assets" / "textures" / "intro"
            destinations = [
                temporary_runtime / f"{name}.png" for name in NATIVE_NAMES
            ]
            original_hashes = seed_destinations(destinations)

            result = subprocess.run(
                [sys.executable, str(temporary_tool)],
                capture_output=True,
                text=True,
            )
            output = f"{result.stdout}\n{result.stderr}"

            self.assertNotEqual(result.returncode, 0)
            self.assertIn(
                "intro_threshold: native source must be (320, 180), got (3, 3)",
                output,
            )
            assert_destinations_unchanged(self, original_hashes)

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

    def test_export_rejects_still_with_partial_alpha(self) -> None:
        partial_alpha = Image.new("RGBA", NATIVE_SIZE, (12, 24, 36, 254))

        with self.assertRaisesRegex(ValueError, "fully opaque"):
            validate_source(STILLS[0], partial_alpha)

    def test_export_rejects_binary_alpha_vignette(self) -> None:
        binary_alpha = Image.new("RGBA", NATIVE_SIZE, (0, 0, 0, 0))
        binary_alpha.putpixel((0, 0), (0, 0, 0, 255))

        with self.assertRaisesRegex(ValueError, "intermediate alpha"):
            validate_source("intro_vignette", binary_alpha)

    def test_export_rejects_nearly_invisible_vignette(self) -> None:
        nearly_invisible = Image.new("RGBA", NATIVE_SIZE, (0, 0, 0, 0))
        nearly_invisible.putpixel((0, 0), (0, 0, 0, 1))

        with self.assertRaisesRegex(ValueError, "maximum alpha"):
            validate_source("intro_vignette", nearly_invisible)

    def test_runtime_stills_are_exact_nearest_exports(self) -> None:
        for name in RUNTIME_EXPORTS:
            native_path = SOURCE / f"{name}_native.png"
            runtime_path = RUNTIME / f"{name}.png"
            self.assertTrue(native_path.exists(), f"{native_path}: missing native source")
            self.assertTrue(runtime_path.exists(), f"{runtime_path}: missing runtime texture")

            native = load_image(native_path)
            runtime = load_image(runtime_path)
            expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)

            self.assertEqual(runtime.size, RUNTIME_SIZE, f"{name}: wrong runtime size")
            self.assertEqual(
                runtime.mode,
                expected.mode,
                f"{name}: runtime mode differs from nearest export",
            )
            self.assertEqual(
                runtime.tobytes(),
                expected.tobytes(),
                f"{name}: runtime pixels differ from exact nearest export",
            )

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
        sheet = load_image(path).convert("RGB")
        self.assertEqual(sheet.size, (960, 360))
        for name, position in zip(STILLS, CONTACT_SHEET_POSITIONS):
            left, top = position
            region = sheet.crop((left, top, left + 320, top + 180))
            native = load_image(SOURCE / f"{name}_native.png").convert("RGB")
            self.assertEqual(
                region.tobytes(),
                native.tobytes(),
                f"{name}: contact sheet region differs from native still",
            )

    def test_runtime_manifest_uses_the_five_pipeline_textures_in_order(self) -> None:
        with INTRO_DATA.open(encoding="utf-8") as handle:
            intro_data = json.load(handle)

        actual = [beat["image"] for beat in intro_data["beats"]]
        expected = [f"res://assets/textures/intro/{name}.png" for name in STILLS]
        self.assertEqual(actual, expected)


if __name__ == "__main__":
    unittest.main(verbosity=2)
