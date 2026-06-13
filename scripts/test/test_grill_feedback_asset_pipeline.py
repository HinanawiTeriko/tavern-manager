from __future__ import annotations

import json
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "source" / "grill_feedback" / "grill_feedback_manifest.json"
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "grill_feedback" / "grill_feedback_source_v1.png"
NATIVE_ATLAS = ROOT / "assets" / "source" / "grill_feedback" / "grill_feedback_native.png"
RUNTIME_ATLAS = ROOT / "assets" / "textures" / "grill_feedback" / "grill_feedback.png"
CONTACT_SHEET = ROOT / "docs" / "art" / "grill_feedback_contact_sheet.png"
ELEMENTS = ("oil_spark", "done_spark", "char_spark", "heat_glow", "flame")
VARIANTS_PER_ELEMENT = 4
NATIVE_SLOT_SIZE = (48, 40)
RUNTIME_SCALE = 4


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    data = image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()
    return [pixel for pixel in data if pixel[3] > 0]


def crop_native_slot(atlas: Image.Image, element_index: int, variant_index: int) -> Image.Image:
    width, height = NATIVE_SLOT_SIZE
    left = variant_index * width
    top = element_index * height
    return atlas.crop((left, top, left + width, top + height))


class GrillFeedbackAssetPipelineTest(unittest.TestCase):
    def test_manifest_uses_generated_source_and_fixed_rectangles(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["raw_source"], RAW_SOURCE.relative_to(ROOT).as_posix())
        self.assertEqual(manifest["native_atlas"], NATIVE_ATLAS.relative_to(ROOT).as_posix())
        self.assertEqual(manifest["runtime_atlas"], RUNTIME_ATLAS.relative_to(ROOT).as_posix())
        self.assertEqual(manifest["native_slot_size"], list(NATIVE_SLOT_SIZE))
        self.assertEqual(manifest["scale"], RUNTIME_SCALE)
        sprites = manifest["sprites"]
        self.assertEqual(len(sprites), len(ELEMENTS) * VARIANTS_PER_ELEMENT)
        for element_index, element in enumerate(ELEMENTS):
            for variant_index in range(VARIANTS_PER_ELEMENT):
                sprite_id = f"{element}_{variant_index}"
                with self.subTest(sprite=sprite_id):
                    sprite = sprites[sprite_id]
                    self.assertEqual(sprite["element"], element)
                    self.assertEqual(sprite["atlas_cell"], [variant_index, element_index])
                    rect = sprite["source_rect"]
                    self.assertEqual(len(rect), 4)
                    left, top, right, bottom = rect
                    self.assertLess(left, right)
                    self.assertLess(top, bottom)

    def test_generated_raw_source_is_retained(self) -> None:
        self.assertTrue(RAW_SOURCE.exists(), f"{RAW_SOURCE}: missing generated raw source")
        self.assertGreater(RAW_SOURCE.stat().st_size, 500_000, "generated source is unexpectedly small")

    def test_native_and_runtime_atlases_are_exact_nearest_exports(self) -> None:
        native = load_rgba(NATIVE_ATLAS)
        runtime = load_rgba(RUNTIME_ATLAS)
        self.assertEqual(native.size, (NATIVE_SLOT_SIZE[0] * VARIANTS_PER_ELEMENT, NATIVE_SLOT_SIZE[1] * len(ELEMENTS)))
        self.assertEqual(runtime.size, (native.width * RUNTIME_SCALE, native.height * RUNTIME_SCALE))
        expected = native.resize(runtime.size, Image.Resampling.NEAREST)
        self.assertEqual(runtime.tobytes(), expected.tobytes(), "runtime atlas must be exact 4x nearest export")

    def test_each_slot_is_a_single_effect_element(self) -> None:
        native = load_rgba(NATIVE_ATLAS)
        visible_by_element: dict[str, int] = {}
        orange_by_element: dict[str, int] = {}
        for element_index, element in enumerate(ELEMENTS):
            element_visible = 0
            element_orange = 0
            for variant_index in range(VARIANTS_PER_ELEMENT):
                slot = crop_native_slot(native, element_index, variant_index)
                pixels = visible_pixels(slot)
                with self.subTest(element=element, variant=variant_index):
                    self.assertGreaterEqual(len(pixels), 22, f"{element} {variant_index} is too sparse")
                    self.assertLessEqual(len(pixels), 360, f"{element} {variant_index} is too dense for one effect element")
                element_visible += len(pixels)
                element_orange += sum(1 for r, g, b, _a in pixels if r >= 190 and g >= 75 and b <= 95)
            visible_by_element[element] = element_visible
            orange_by_element[element] = element_orange
        self.assertGreater(orange_by_element["oil_spark"], 8)
        self.assertGreater(orange_by_element["done_spark"], 8)
        self.assertGreater(orange_by_element["flame"], 12)
        self.assertGreater(visible_by_element["heat_glow"], visible_by_element["oil_spark"])
        self.assertLess(visible_by_element["char_spark"], visible_by_element["heat_glow"])

    def test_contact_sheet_exists_for_review(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing contact sheet")
        sheet = load_rgba(CONTACT_SHEET)
        self.assertGreaterEqual(sheet.width, 320)
        self.assertGreaterEqual(sheet.height, 160)


if __name__ == "__main__":
    unittest.main(verbosity=2)
