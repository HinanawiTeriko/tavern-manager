from __future__ import annotations

import json
from pathlib import Path
import colorsys
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "source" / "barrel_bubbles" / "barrel_bubble_manifest.json"
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "barrel_bubbles" / "barrel_bubble_source_v3.png"
NATIVE_ATLAS = ROOT / "assets" / "source" / "barrel_bubbles" / "barrel_bubbles_native.png"
RUNTIME_ATLAS = ROOT / "assets" / "textures" / "barrel_bubbles" / "barrel_bubbles.png"
CONTACT_SHEET = ROOT / "docs" / "art" / "barrel_bubble_contact_sheet.png"
TIERS = ("pending", "normal", "good")
VARIANTS_PER_TIER = 4
NATIVE_SLOT_SIZE = (20, 20)
RUNTIME_SCALE = 4


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    data = image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()
    return [pixel for pixel in data if pixel[3] > 0]


def vivid_hue_bucket(pixel: tuple[int, int, int, int]) -> int | None:
    red, green, blue, alpha = pixel
    if alpha == 0:
        return None
    value = max(red, green, blue) / 255.0
    saturation = (max(red, green, blue) - min(red, green, blue)) / 255.0
    if value < 0.38 or saturation < 0.32:
        return None
    hue, _sat, _val = colorsys.rgb_to_hsv(red / 255.0, green / 255.0, blue / 255.0)
    return int(hue * 6.0) % 6


def crop_native_slot(atlas: Image.Image, tier_index: int, variant_index: int) -> Image.Image:
    width, height = NATIVE_SLOT_SIZE
    left = variant_index * width
    top = tier_index * height
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


class BarrelBubbleAssetPipelineTest(unittest.TestCase):
    def test_manifest_uses_generated_source_and_fixed_rectangles(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["raw_source"], RAW_SOURCE.relative_to(ROOT).as_posix())
        self.assertEqual(manifest["native_atlas"], NATIVE_ATLAS.relative_to(ROOT).as_posix())
        self.assertEqual(manifest["runtime_atlas"], RUNTIME_ATLAS.relative_to(ROOT).as_posix())
        self.assertEqual(manifest["native_slot_size"], list(NATIVE_SLOT_SIZE))
        self.assertEqual(manifest["scale"], RUNTIME_SCALE)
        sprites = manifest["sprites"]
        self.assertEqual(len(sprites), len(TIERS) * VARIANTS_PER_TIER)
        for tier_index, tier in enumerate(TIERS):
            for variant_index in range(VARIANTS_PER_TIER):
                sprite_id = f"{tier}_{variant_index}"
                with self.subTest(sprite=sprite_id):
                    sprite = sprites[sprite_id]
                    self.assertEqual(sprite["tier"], tier)
                    self.assertEqual(sprite["atlas_cell"], [variant_index, tier_index])
                    rect = sprite["source_rect"]
                    self.assertEqual(len(rect), 4, "source_rect must be explicit [left, top, right, bottom]")
                    left, top, right, bottom = rect
                    self.assertLess(left, right)
                    self.assertLess(top, bottom)

    def test_generated_raw_source_is_retained(self) -> None:
        self.assertTrue(RAW_SOURCE.exists(), f"{RAW_SOURCE}: missing generated raw source")
        self.assertGreater(RAW_SOURCE.stat().st_size, 100_000, "generated source is unexpectedly small")

    def test_native_and_runtime_atlases_are_exact_nearest_exports(self) -> None:
        native = load_rgba(NATIVE_ATLAS)
        runtime = load_rgba(RUNTIME_ATLAS)
        self.assertEqual(native.size, (NATIVE_SLOT_SIZE[0] * VARIANTS_PER_TIER, NATIVE_SLOT_SIZE[1] * len(TIERS)))
        self.assertEqual(runtime.size, (native.width * RUNTIME_SCALE, native.height * RUNTIME_SCALE))
        expected = native.resize(runtime.size, Image.Resampling.NEAREST)
        self.assertEqual(runtime.tobytes(), expected.tobytes(), "runtime atlas must be exact 4x nearest export")

    def test_tiers_have_readable_density_and_quality_color_language(self) -> None:
        native = load_rgba(NATIVE_ATLAS)
        coverage_by_tier: dict[str, int] = {}
        hue_buckets_by_tier: dict[str, set[int]] = {}
        max_visible_by_tier = {
            "pending": 220,
            "normal": 220,
            "good": 220,
        }
        for tier_index, tier in enumerate(TIERS):
            tier_visible = 0
            tier_hue_buckets: set[int] = set()
            for variant_index in range(VARIANTS_PER_TIER):
                slot = crop_native_slot(native, tier_index, variant_index)
                pixels = visible_pixels(slot)
                self.assertGreaterEqual(len(pixels), 24, f"{tier} bubble {variant_index} is too sparse")
                self.assertLessEqual(
                    len(pixels),
                    max_visible_by_tier[tier],
                    f"{tier} bubble {variant_index} fills too much slot",
                )
                components = alpha_component_sizes(slot)
                self.assertGreaterEqual(
                    components[0] / len(pixels),
                    0.72,
                    f"{tier} bubble {variant_index} must read as one bubble, not a foam cluster",
                )
                self.assertLessEqual(
                    len([size for size in components if size >= 4]),
                    2,
                    f"{tier} bubble {variant_index} has too many separate bubble islands",
                )
                tier_visible += len(pixels)
                for pixel in pixels:
                    bucket = vivid_hue_bucket(pixel)
                    if bucket is not None:
                        tier_hue_buckets.add(bucket)
            coverage_by_tier[tier] = tier_visible
            hue_buckets_by_tier[tier] = tier_hue_buckets

        self.assertLess(coverage_by_tier["pending"], coverage_by_tier["normal"])
        self.assertLessEqual(
            len(hue_buckets_by_tier["pending"]),
            2,
            "pending bubbles should not imply the rainbow good-quality tier",
        )
        self.assertLessEqual(
            len(hue_buckets_by_tier["normal"]),
            3,
            "normal bubbles should stay visually calmer than rainbow good bubbles",
        )
        self.assertGreaterEqual(
            len(hue_buckets_by_tier["good"]),
            5,
            "good bubbles need multiple vivid hue families for the rainbow quality read",
        )

    def test_contact_sheet_exists_for_review(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing contact sheet")
        sheet = load_rgba(CONTACT_SHEET)
        self.assertGreaterEqual(sheet.width, 320)
        self.assertGreaterEqual(sheet.height, 160)


if __name__ == "__main__":
    unittest.main(verbosity=2)
