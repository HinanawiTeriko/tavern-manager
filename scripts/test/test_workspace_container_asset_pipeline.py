from __future__ import annotations

import json
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "source" / "workspace" / "workspace_container_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "workspace_container_contact_sheet.png"
PROP_IDS = ("barrel", "grill", "pot", "spoon", "seasoning_shaker", "seasoning_shaker_closed")


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixel_count(image: Image.Image) -> int:
    data = image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()
    return sum(1 for pixel in data if pixel[3] > 0)


class WorkspaceContainerAssetPipelineTest(unittest.TestCase):
    def test_manifest_keeps_generated_source_and_fixed_rects(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertIn("container_sheet_v1", manifest["generated_sources"])
        self.assertIn("spoon_source_v1", manifest["generated_sources"])
        self.assertIn("seasoning_shaker_states_source_v4", manifest["generated_sources"])
        self.assertEqual(set(manifest["props"].keys()), set(PROP_IDS))
        for prop_id in PROP_IDS:
            with self.subTest(prop_id=prop_id):
                spec = manifest["props"][prop_id]
                self.assertEqual(
                    spec["reference"],
                    f"assets/source/workspace/reference/{prop_id}_reference.png",
                )
                self.assertEqual(spec["native"], f"assets/source/workspace/{prop_id}_native.png")
                self.assertEqual(spec["runtime"], f"assets/textures/workspace/{prop_id}.png")
                self.assertEqual(spec["scale"], 2)
                rect = spec["source_rect"]
                self.assertEqual(len(rect), 4, "source_rect must be [left, top, right, bottom]")
                left, top, right, bottom = rect
                self.assertLess(left, right)
                self.assertLess(top, bottom)

    def test_sources_and_references_are_retained(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        for source_id, generated in manifest["generated_sources"].items():
            for key in ("source_file", "production_reference"):
                with self.subTest(source_id=source_id, key=key):
                    path = ROOT / generated[key]
                    self.assertTrue(path.exists(), f"{path}: missing generated source")
                    self.assertGreater(path.stat().st_size, 0, "generated source is empty")
        for prop_id in PROP_IDS:
            with self.subTest(prop_id=prop_id):
                reference = ROOT / "assets" / "source" / "workspace" / "reference" / f"{prop_id}_reference.png"
                self.assertTrue(reference.exists(), f"{reference}: missing reference crop")
                self.assertGreater(reference.stat().st_size, 0, "reference crop is empty")

    def test_native_and_runtime_are_exact_nearest_exports(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        for prop_id in PROP_IDS:
            with self.subTest(prop_id=prop_id):
                spec = manifest["props"][prop_id]
                native = load_rgba(ROOT / spec["native"])
                runtime = load_rgba(ROOT / spec["runtime"])
                native_size = tuple(spec["native_size"])
                self.assertEqual(native.size, native_size)
                self.assertEqual(runtime.size, (native_size[0] * 2, native_size[1] * 2))
                expected = native.resize(runtime.size, Image.Resampling.NEAREST)
                self.assertEqual(runtime.tobytes(), expected.tobytes(), "runtime must be exact 2x nearest export")

    def test_native_props_have_clean_alpha_and_readable_coverage(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        minimum_visible = {
            "barrel": 160,
            "grill": 160,
            "pot": 160,
            "spoon": 80,
            "seasoning_shaker": 110,
            "seasoning_shaker_closed": 110,
        }
        for prop_id in PROP_IDS:
            with self.subTest(prop_id=prop_id):
                native = load_rgba(ROOT / manifest["props"][prop_id]["native"])
                corners = [
                    native.getpixel((0, 0)),
                    native.getpixel((native.width - 1, 0)),
                    native.getpixel((0, native.height - 1)),
                    native.getpixel((native.width - 1, native.height - 1)),
                ]
                self.assertTrue(all(pixel[3] == 0 for pixel in corners), "native corners must be transparent")
                visible = visible_pixel_count(native)
                self.assertGreaterEqual(visible, minimum_visible[prop_id], "native prop is too sparse to read")
                self.assertLessEqual(visible, native.width * native.height - 12, "native prop fills too much canvas")

    def test_seasoning_shaker_states_are_smaller_than_barrel(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        barrel_size = tuple(manifest["props"]["barrel"]["native_size"])
        open_size = tuple(manifest["props"]["seasoning_shaker"]["native_size"])
        closed_size = tuple(manifest["props"]["seasoning_shaker_closed"]["native_size"])
        self.assertEqual(open_size, closed_size, "open and closed shaker states must share dimensions")
        self.assertIn(
            "seasoning_shaker_states_source_v4.png",
            manifest["props"]["seasoning_shaker"]["source_sheet"],
            "open shaker should use the opaque steel two-state source",
        )
        self.assertIn(
            "seasoning_shaker_states_source_v4.png",
            manifest["props"]["seasoning_shaker_closed"]["source_sheet"],
            "closed shaker should use the opaque steel two-state source",
        )
        self.assertLess(open_size[0], barrel_size[0], "seasoning shaker should be narrower than the barrel")
        self.assertLess(open_size[1], barrel_size[1], "seasoning shaker should be shorter than the barrel")
        self.assertLessEqual(open_size[0], 34, "seasoning shaker native width should stay compact")
        self.assertLessEqual(open_size[1], 40, "seasoning shaker native height should stay compact")

    def test_contact_sheet_exists(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing review contact sheet")
        sheet = load_rgba(CONTACT_SHEET)
        self.assertGreaterEqual(sheet.width, 300)
        self.assertGreaterEqual(sheet.height, 120)


if __name__ == "__main__":
    unittest.main(verbosity=2)
