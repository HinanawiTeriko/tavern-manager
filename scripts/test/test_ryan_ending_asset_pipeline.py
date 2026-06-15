from __future__ import annotations

import json
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_sources" / "generated_raw" / "ryan_endings"
RAW_MANIFEST = RAW / "ryan_ending_reference_manifest.json"
SOURCE = ROOT / "assets" / "source" / "endings" / "ryan"
REFERENCE = SOURCE / "reference"
RUNTIME = ROOT / "assets" / "textures" / "endings" / "ryan"
MANIFEST = SOURCE / "ryan_ending_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "ryan_ending_backgrounds_contact_sheet.png"
REFERENCE_VERSION = "v3"
NATIVE_SIZE = (320, 140)
RUNTIME_SIZE = (1280, 560)
SCALE = 4
ROUTES = [
    "uninformed_fallen",
    "drugged_survivor",
    "informed_fallen",
    "alternative_survivor",
]


def load_image(path: Path) -> Image.Image:
    if not path.exists():
        raise AssertionError(f"{path}: missing image")
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_color_count(image: Image.Image) -> int:
    rgba = image.convert("RGBA")
    pixels = rgba.get_flattened_data() if hasattr(rgba, "get_flattened_data") else rgba.getdata()
    return len({pixel for pixel in pixels if pixel[3] > 0})


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


class RyanEndingAssetPipelineTest(unittest.TestCase):
    def test_raw_v3_references_are_retained(self) -> None:
        self.assertTrue(RAW_MANIFEST.exists(), f"{RAW_MANIFEST}: missing raw reference manifest")
        manifest = json.loads(RAW_MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["id"], "ryan_ending_wide_references_v3")
        self.assertEqual(manifest["target_native_size"], list(NATIVE_SIZE))
        self.assertEqual(manifest["target_runtime_size"], list(RUNTIME_SIZE))
        entries = manifest["entries"]
        self.assertEqual({entry["route"] for entry in entries}, set(ROUTES))
        for entry in entries:
            route = entry["route"]
            self.assertEqual(entry["id"], f"ryan_{route}_reference_{REFERENCE_VERSION}")
            self.assertEqual(entry["output_file"], f"art_sources/generated_raw/ryan_endings/ryan_{route}_reference_{REFERENCE_VERSION}.png")
            self.assertIn("prompt_file", entry)
            path = RAW / f"ryan_{route}_reference_{REFERENCE_VERSION}.png"
            self.assertTrue(path.exists(), f"{path}: missing raw V3 reference")
            self.assertGreater(path.stat().st_size, 0, f"{path}: raw V3 reference is empty")
            prompt_path = RAW / f"ryan_{route}_reference_{REFERENCE_VERSION}_prompt.txt"
            self.assertTrue(prompt_path.exists(), f"{prompt_path}: missing prompt record")

    def test_approved_references_exist(self) -> None:
        for route in ROUTES:
            path = REFERENCE / f"ryan_{route}_reference_{REFERENCE_VERSION}.png"
            image = load_image(path)
            self.assertGreaterEqual(image.width, RUNTIME_SIZE[0], f"{route}: reference is too narrow")
            self.assertGreaterEqual(image.height, RUNTIME_SIZE[1], f"{route}: reference is too short")

    def test_manifest_describes_all_routes(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["id"], "ryan_ending_backgrounds")
        self.assertEqual(manifest["native_size"], list(NATIVE_SIZE))
        self.assertEqual(manifest["runtime_size"], list(RUNTIME_SIZE))
        self.assertEqual(manifest["scale"], SCALE)
        self.assertEqual(set(manifest["routes"].keys()), set(ROUTES))
        for route in ROUTES:
            entry = manifest["routes"][route]
            self.assertEqual(entry["reference"], f"assets/source/endings/ryan/reference/ryan_{route}_reference_{REFERENCE_VERSION}.png")
            self.assertEqual(entry["native"], f"assets/source/endings/ryan/ryan_{route}_native.png")
            self.assertEqual(entry["runtime"], f"assets/textures/endings/ryan/ryan_{route}.png")
            self.assertIn("Future Ryan fate cinematic", entry["intended_godot_use"])

    def test_native_and_runtime_exports_are_exact_nearest(self) -> None:
        for route in ROUTES:
            with self.subTest(route=route):
                native = load_image(SOURCE / f"ryan_{route}_native.png")
                runtime = load_image(RUNTIME / f"ryan_{route}.png")
                self.assertEqual(native.size, NATIVE_SIZE)
                self.assertEqual(runtime.size, RUNTIME_SIZE)
                expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
                self.assertEqual(runtime.tobytes(), expected.tobytes(), f"{route}: runtime is not exact nearest export")
                self.assertLessEqual(visible_color_count(native), 72, f"{route}: native palette is too dense")
                self.assertGreaterEqual(edge_change_ratio(native), 0.06, f"{route}: native image is likely too smooth")

    def test_contact_sheet_exists(self) -> None:
        sheet = load_image(CONTACT_SHEET)
        self.assertEqual(sheet.size, (640, 280))


if __name__ == "__main__":
    unittest.main(verbosity=2)
