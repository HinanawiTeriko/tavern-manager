from __future__ import annotations

import json
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "source" / "workspace_style_trial" / "workspace_style_trial_manifest.json"
ITEM_IDS = ("flour", "ale", "barrel", "pot")


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def alpha_bounds(image: Image.Image) -> tuple[int, int]:
    xs: list[int] = []
    ys: list[int] = []
    data = image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()
    for index, pixel in enumerate(data):
        if pixel[3] > 0:
            xs.append(index % image.width)
            ys.append(index // image.width)
    if not xs:
        return (0, 0)
    return (max(xs) - min(xs) + 1, max(ys) - min(ys) + 1)


class WorkspaceStyleTrialPipelineTest(unittest.TestCase):
    def test_manifest_defines_preview_only_scale_tiers(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(
            manifest["source_sheet"],
            "assets/source/workspace_style_trial/reference/exterior_only_pixel_sheet_v3.png",
        )
        self.assertEqual(
            manifest["raw_source"],
            "art_sources/generated_raw/workspace_style_trial/exterior_only_pixel_sheet_v3.png",
        )
        self.assertEqual(tuple(manifest["native_size"]), (48, 48))
        self.assertEqual(manifest["preview_scale"], 2)
        self.assertEqual(tuple(manifest["items"].keys()), ITEM_IDS)
        self.assertEqual(manifest["items"]["flour"]["target_longest"], 34)
        self.assertEqual(manifest["items"]["ale"]["target_longest"], 34)
        self.assertEqual(manifest["items"]["barrel"]["target_longest"], 44)
        self.assertEqual(manifest["items"]["pot"]["target_longest"], 44)

    def test_outputs_are_exact_nearest_previews(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        for item_id, spec in manifest["items"].items():
            with self.subTest(item_id=item_id):
                native = load_rgba(ROOT / spec["native"])
                preview = load_rgba(ROOT / spec["preview"])
                self.assertEqual(native.size, (48, 48))
                self.assertEqual(preview.size, (96, 96))
                expected = native.resize((96, 96), Image.Resampling.NEAREST)
                self.assertEqual(preview.tobytes(), expected.tobytes())

    def test_container_native_sprites_are_larger_than_food_sprites(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        longest_by_id: dict[str, int] = {}
        for item_id, spec in manifest["items"].items():
            native = load_rgba(ROOT / spec["native"])
            bounds = alpha_bounds(native)
            longest_by_id[item_id] = max(bounds)
        self.assertLessEqual(longest_by_id["flour"], 38)
        self.assertLessEqual(longest_by_id["ale"], 38)
        self.assertGreaterEqual(longest_by_id["barrel"], 42)
        self.assertGreaterEqual(longest_by_id["pot"], 42)

    def test_contact_sheet_exists(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        sheet = ROOT / manifest["contact_sheet"]
        self.assertTrue(sheet.exists(), f"{sheet}: missing contact sheet")
        image = load_rgba(sheet)
        self.assertGreaterEqual(image.width, 500)
        self.assertGreaterEqual(image.height, 300)


if __name__ == "__main__":
    unittest.main(verbosity=2)
