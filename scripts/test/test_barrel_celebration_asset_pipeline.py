from __future__ import annotations

import json
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "source" / "barrel_celebration" / "barrel_celebration_manifest.json"
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "barrel_celebration" / "barrel_celebration_source_v1.png"
PROMPT = ROOT / "art_sources" / "generated_raw" / "barrel_celebration" / "barrel_celebration_prompt_v1.txt"
NATIVE_ATLAS = ROOT / "assets" / "source" / "barrel_celebration" / "barrel_celebration_native.png"
RUNTIME_ATLAS = ROOT / "assets" / "textures" / "barrel_celebration" / "barrel_celebration.png"
CONTACT_SHEET = ROOT / "docs" / "art" / "barrel_celebration_contact_sheet.png"
ELEMENTS = ("ring", "beam", "star", "gold_bubble", "aroma", "trail")
VARIANTS_PER_ELEMENT = 4
NATIVE_SLOT_SIZE = (24, 32)
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


def alpha_component_sizes(image: Image.Image) -> list[int]:
    alpha = image.getchannel("A")
    visible = {
        (x, y)
        for y in range(image.height)
        for x in range(image.width)
        if alpha.getpixel((x, y)) > 0
    }
    sizes: list[int] = []
    while visible:
        start = visible.pop()
        stack = [start]
        size = 1
        while stack:
            x, y = stack.pop()
            for ny in range(max(0, y - 1), min(image.height, y + 2)):
                for nx in range(max(0, x - 1), min(image.width, x + 2)):
                    if (nx, ny) not in visible:
                        continue
                    visible.remove((nx, ny))
                    stack.append((nx, ny))
                    size += 1
        sizes.append(size)
    return sorted(sizes, reverse=True)


class BarrelCelebrationAssetPipelineTest(unittest.TestCase):
    def test_manifest_uses_generated_source_and_fixed_rectangles(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["raw_source"], RAW_SOURCE.relative_to(ROOT).as_posix())
        self.assertEqual(manifest["prompt"], PROMPT.relative_to(ROOT).as_posix())
        self.assertEqual(manifest["native_atlas"], NATIVE_ATLAS.relative_to(ROOT).as_posix())
        self.assertEqual(manifest["runtime_atlas"], RUNTIME_ATLAS.relative_to(ROOT).as_posix())
        self.assertEqual(manifest["native_slot_size"], list(NATIVE_SLOT_SIZE))
        self.assertEqual(manifest["scale"], RUNTIME_SCALE)
        self.assertIn("Brewery GoodBrewCelebration", manifest["intended_godot_use"])
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
                    self.assertEqual(len(rect), 4, "source_rect must be explicit [left, top, right, bottom]")
                    left, top, right, bottom = rect
                    self.assertLess(left, right)
                    self.assertLess(top, bottom)

    def test_generated_raw_source_and_prompt_are_retained(self) -> None:
        self.assertTrue(RAW_SOURCE.exists(), f"{RAW_SOURCE}: missing generated raw source")
        self.assertGreater(RAW_SOURCE.stat().st_size, 100_000, "generated source is unexpectedly small")
        self.assertTrue(PROMPT.exists(), f"{PROMPT}: missing prompt record")
        prompt_text = PROMPT.read_text(encoding="utf-8").lower()
        self.assertIn("single", prompt_text)
        self.assertIn("no full light column", prompt_text)

    def test_native_and_runtime_atlases_are_exact_nearest_exports(self) -> None:
        native = load_rgba(NATIVE_ATLAS)
        runtime = load_rgba(RUNTIME_ATLAS)
        self.assertEqual(native.size, (NATIVE_SLOT_SIZE[0] * VARIANTS_PER_ELEMENT, NATIVE_SLOT_SIZE[1] * len(ELEMENTS)))
        self.assertEqual(runtime.size, (native.width * RUNTIME_SCALE, native.height * RUNTIME_SCALE))
        expected = native.resize(runtime.size, Image.Resampling.NEAREST)
        self.assertEqual(runtime.tobytes(), expected.tobytes(), "runtime atlas must be exact 4x nearest export")

    def test_each_sprite_is_one_celebration_element_not_baked_burst(self) -> None:
        native = load_rgba(NATIVE_ATLAS)
        coverage_limits = {
            "ring": (20, 220),
            "beam": (20, 210),
            "star": (8, 90),
            "gold_bubble": (16, 150),
            "aroma": (18, 180),
            "trail": (8, 100),
        }
        warm_pixels_by_element: dict[str, int] = {}
        for element_index, element in enumerate(ELEMENTS):
            warm_pixels = 0
            min_pixels, max_pixels = coverage_limits[element]
            for variant_index in range(VARIANTS_PER_ELEMENT):
                slot = crop_native_slot(native, element_index, variant_index)
                pixels = visible_pixels(slot)
                self.assertGreaterEqual(len(pixels), min_pixels, f"{element} {variant_index} is too sparse")
                self.assertLessEqual(len(pixels), max_pixels, f"{element} {variant_index} is a baked burst, not one element")
                components = alpha_component_sizes(slot)
                self.assertGreaterEqual(
                    components[0] / len(pixels),
                    0.45,
                    f"{element} {variant_index} should read as one effect element",
                )
                self.assertLessEqual(
                    len([size for size in components if size >= 4]),
                    4,
                    f"{element} {variant_index} has too many separate islands",
                )
                warm_pixels += sum(1 for r, g, b, _a in pixels if r >= 190 and g >= 115 and b <= 85)
            warm_pixels_by_element[element] = warm_pixels
        self.assertGreaterEqual(warm_pixels_by_element["ring"], 10, "ring needs warm gold pixels")
        self.assertGreaterEqual(warm_pixels_by_element["beam"], 10, "beam needs warm gold pixels")
        self.assertGreaterEqual(warm_pixels_by_element["star"], 6, "stars need warm gold pixels")
        self.assertGreaterEqual(warm_pixels_by_element["trail"], 6, "trail needs warm gold pixels")

    def test_contact_sheet_exists_for_review(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing contact sheet")
        sheet = load_rgba(CONTACT_SHEET)
        self.assertGreaterEqual(sheet.width, 320)
        self.assertGreaterEqual(sheet.height, 160)


if __name__ == "__main__":
    unittest.main(verbosity=2)
