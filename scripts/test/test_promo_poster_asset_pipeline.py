from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import unittest

from PIL import Image

from scripts.tools.export_promo_poster_assets import (
    ASSET_ID,
    CONTACT_SHEET_PATH,
    MANIFEST_PATH,
    MAX_NATIVE_COLORS,
    MAX_RUNTIME_BYTES,
    NATIVE_PATH,
    NATIVE_SIZE,
    RAW,
    RUNTIME_PATH,
    RUNTIME_SIZE,
    validate_native,
)


ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / "scripts" / "tools" / "export_promo_poster_assets.py"


def load_image(path: Path) -> Image.Image:
    if not path.exists():
        raise AssertionError(f"{path}: missing image")
    with Image.open(path) as image:
        return image.copy()


def color_count(image: Image.Image) -> int:
    colors = image.convert("RGB").getcolors(maxcolors=65536)
    return len(colors) if colors is not None else 65536


class PromoPosterAssetPipelineTest(unittest.TestCase):
    def test_exporter_runs_successfully(self) -> None:
        result = subprocess.run(
            [sys.executable, str(TOOL)],
            capture_output=True,
            text=True,
        )
        output = f"{result.stdout}\n{result.stderr}"
        self.assertEqual(result.returncode, 0, output)
        self.assertIn(ASSET_ID, result.stdout)

    def test_raw_native_runtime_and_contact_sheet_exist_at_expected_sizes(self) -> None:
        self.assertTrue(RAW.exists(), f"{RAW}: missing raw source")
        with Image.open(RAW) as raw:
            self.assertGreaterEqual(raw.width, 1280)
            self.assertGreaterEqual(raw.height, 720)

        native = load_image(NATIVE_PATH)
        runtime = load_image(RUNTIME_PATH)
        contact_sheet = load_image(CONTACT_SHEET_PATH)

        self.assertEqual(native.size, NATIVE_SIZE)
        self.assertEqual(runtime.size, RUNTIME_SIZE)
        self.assertEqual(contact_sheet.size, (NATIVE_SIZE[0] * 3, NATIVE_SIZE[1]))

    def test_runtime_is_exact_nearest_neighbor_export_under_five_mb(self) -> None:
        native = load_image(NATIVE_PATH)
        runtime = load_image(RUNTIME_PATH)
        expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)

        self.assertEqual(runtime.mode, expected.mode)
        self.assertEqual(runtime.tobytes(), expected.tobytes())
        self.assertLessEqual(RUNTIME_PATH.stat().st_size, MAX_RUNTIME_BYTES)

    def test_native_visuals_match_project_pixel_guardrails(self) -> None:
        native = load_image(NATIVE_PATH)
        validate_native(native)
        self.assertLessEqual(color_count(native), MAX_NATIVE_COLORS)

    def test_manifest_describes_the_generated_asset_contract(self) -> None:
        with MANIFEST_PATH.open(encoding="utf-8") as handle:
            manifest = json.load(handle)

        self.assertIn("assets", manifest)
        self.assertEqual(len(manifest["assets"]), 1)
        entry = manifest["assets"][0]
        self.assertEqual(entry["id"], ASSET_ID)
        self.assertEqual(entry["source_file"], "art_sources/generated_raw/promo_poster/promo_poster_source.png")
        self.assertEqual(entry["native_file"], f"assets/source/promo_poster/{ASSET_ID}_native.png")
        self.assertEqual(entry["output_file"], f"assets/textures/promo_poster/{ASSET_ID}.png")
        self.assertEqual(entry["size"], list(RUNTIME_SIZE))
        self.assertEqual(entry["native_size"], list(NATIVE_SIZE))
        self.assertEqual(
            entry["intended_godot_use"],
            "external_promo_only_not_referenced_by_runtime_scenes",
        )
        self.assertEqual(
            entry["safe_area"],
            {"x": 96, "y": 54, "width": 1728, "height": 972},
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
