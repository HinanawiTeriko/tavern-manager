from __future__ import annotations

import json
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "source" / "tavern" / "table" / "tabletop_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_table_contact_sheet.png"
NATIVE_SIZE = (320, 80)
RUNTIME_SIZE = (1280, 320)
SPRITE_POSITION_RUNTIME = (640, 600)
SURFACE_TOP_Y_RUNTIME = 455
FRONT_LIP_Y_RUNTIME = 655
GROUND_Y_RUNTIME = 556
CUTOUT_POLYGON_NATIVE = [[10, 4], [310, 4], [320, 64], [320, 73], [0, 73], [0, 64]]


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def load_manifest(test_case: unittest.TestCase) -> dict:
    test_case.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing manifest")
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def image_pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    if hasattr(image, "get_flattened_data"):
        return list(image.get_flattened_data())
    return list(image.getdata())


def luma(pixel: tuple[int, int, int, int]) -> int:
    r, g, b, _a = pixel
    return int(0.2126 * r + 0.7152 * g + 0.0722 * b)


class TavernTableAssetPipelineTest(unittest.TestCase):
    def test_manifest_records_fixed_physics_aligned_work_surface_contract(self) -> None:
        manifest = load_manifest(self)
        self.assertEqual(manifest["id"], "tavern_bar_work_surface")
        self.assertEqual(
            manifest["source"],
            "art_sources/generated_raw/tavern_background/tavern_background_no_people_reference_v1.png",
        )
        self.assertEqual(manifest["native"], "assets/source/tavern/table/tabletop_native.png")
        self.assertEqual(manifest["runtime"], "assets/textures/tavern/table/tabletop.png")
        self.assertEqual(manifest["native_size"], list(NATIVE_SIZE))
        self.assertEqual(manifest["runtime_size"], list(RUNTIME_SIZE))
        self.assertEqual(manifest["scale"], 4)
        self.assertEqual(manifest["safe_area"], [0, 0, 320, 80])
        self.assertEqual(manifest["cutout_polygon_native"], CUTOUT_POLYGON_NATIVE)
        self.assertEqual(
            manifest["physics_alignment"],
            {
                "sprite_position_runtime": list(SPRITE_POSITION_RUNTIME),
                "surface_top_y_runtime": SURFACE_TOP_Y_RUNTIME,
                "front_lip_y_runtime": FRONT_LIP_Y_RUNTIME,
                "ground_y_runtime": GROUND_Y_RUNTIME,
                "playable_x_range_runtime": [150, 1130],
            },
        )
        self.assertEqual(
            manifest["intended_godot_use"],
            "visual-only Tavern physics-aligned bar work surface Sprite2D layer",
        )

    def test_source_native_runtime_and_contact_sheet_exist(self) -> None:
        manifest = load_manifest(self)
        for key in ("source", "native", "runtime"):
            path = ROOT / manifest[key]
            self.assertTrue(path.exists(), f"{path}: missing {key} image")
            self.assertGreater(path.stat().st_size, 0, f"{path}: empty {key} image")
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing contact sheet")
        self.assertGreater(CONTACT_SHEET.stat().st_size, 0, "contact sheet is empty")

    def test_runtime_is_exact_nearest_export(self) -> None:
        manifest = load_manifest(self)
        native = load_rgba(ROOT / manifest["native"])
        runtime = load_rgba(ROOT / manifest["runtime"])
        self.assertEqual(native.size, NATIVE_SIZE)
        self.assertEqual(runtime.size, RUNTIME_SIZE)
        expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
        self.assertEqual(runtime.tobytes(), expected.tobytes(), "runtime must be exact 4x nearest export")

    def test_native_work_surface_is_cleanly_cut_out_and_visually_restrained(self) -> None:
        manifest = load_manifest(self)
        native = load_rgba(ROOT / manifest["native"])
        alpha_min, alpha_max = native.getchannel("A").getextrema()
        self.assertEqual((alpha_min, alpha_max), (0, 255), "work surface should be a transparent cutout, not an opaque rectangle")
        pixels = image_pixels(native)
        transparent = sum(1 for _r, _g, _b, a in pixels if a == 0)
        opaque = sum(1 for _r, _g, _b, a in pixels if a == 255)
        self.assertGreaterEqual(transparent, 3600, "work surface still has too much uncut dark background")
        self.assertGreaterEqual(opaque, 18000, "cutout removed too much of the playable table surface")
        for x, y in ((0, 0), (319, 0), (0, 79), (319, 79), (160, 0), (160, 79)):
            self.assertEqual(native.getpixel((x, y))[3], 0, "outer padding should be transparent at %s" % ((x, y),))
        for x, y in ((20, 14), (160, 24), (300, 14), (24, 64), (160, 64), (296, 64)):
            self.assertEqual(native.getpixel((x, y))[3], 255, "table body should remain opaque at %s" % ((x, y),))
        dark_wood = sum(1 for r, g, b, a in pixels if a == 255 and 20 <= r <= 120 and 12 <= g <= 82 and 8 <= b <= 70)
        teal_shadow = sum(1 for r, g, b, a in pixels if a == 255 and b >= 18 and g >= 14 and b >= r * 0.45)
        amber = sum(1 for r, g, b, a in pixels if a == 255 and r >= 88 and g >= 40 and b <= 46 and r >= b * 1.8)
        bright = sum(1 for r, g, b, a in pixels if a == 255 and max(r, g, b) >= 185)
        self.assertGreaterEqual(dark_wood, 11000, "work surface needs enough dark wood mass")
        self.assertGreaterEqual(teal_shadow, 2600, "work surface needs dark teal shadow bias")
        self.assertGreaterEqual(amber, 250, "work surface needs sparse amber edge highlights")
        self.assertLessEqual(amber, 5200, "amber accents are flooding the work surface")
        self.assertLessEqual(bright, 120, "work surface should not contain bright noisy pixels")

    def test_native_work_surface_aligns_readable_edges_with_physics(self) -> None:
        manifest = load_manifest(self)
        native = load_rgba(ROOT / manifest["native"])
        pixels = image_pixels(native)
        sorted_luma = sorted(luma(pixel) for pixel in pixels)
        p10 = sorted_luma[int((len(sorted_luma) - 1) * 0.10)]
        p90 = sorted_luma[int((len(sorted_luma) - 1) * 0.90)]
        self.assertGreaterEqual(p90 - p10, 28, "work surface is too flat to read")
        self.assertGreaterEqual(p90, 58, "work surface highlights are too dim to read in scene")

        width, height = native.size
        grid_luma = [luma(pixel) for pixel in pixels]

        def at(x: int, y: int) -> int:
            return grid_luma[y * width + x]

        runtime_top_y = SPRITE_POSITION_RUNTIME[1] - RUNTIME_SIZE[1] // 2
        surface_row = round((SURFACE_TOP_Y_RUNTIME - runtime_top_y) / 4)
        ground_row = round((GROUND_Y_RUNTIME - runtime_top_y) / 4)
        front_lip_row = round((FRONT_LIP_Y_RUNTIME - runtime_top_y) / 4)
        self.assertEqual(surface_row, 4, "surface top guide row should document the shifted visual alignment")
        self.assertEqual(ground_row, 29, "ground collision should land near the middle of the playable table surface")
        self.assertEqual(front_lip_row, 54, "front lip guide should stay on the visible counter edge")
        self.assertGreater(ground_row, surface_row, "physics baseline must sit inside the wooden table plane")
        self.assertLess(ground_row, front_lip_row, "physics baseline should stay above the front lip")
        self.assertLessEqual(abs(GROUND_Y_RUNTIME - ((SURFACE_TOP_Y_RUNTIME + FRONT_LIP_Y_RUNTIME) / 2.0)), 5)

        def edge_strength(row: int) -> float:
            return sum(abs(at(x, row) - at(x, row - 1)) for x in range(12, width - 12)) / float(width - 24)

        def row_texture(row_start: int, row_end: int) -> int:
            return sum(
                1
                for y in range(row_start, row_end + 1)
                for x in range(1, width)
                if abs(at(x, y) - at(x - 1, y)) >= 9
            )

        surface_alpha = sum(1 for x in range(24, width - 24) if native.getpixel((x, surface_row))[3] == 255)
        ground_alpha = sum(1 for x in range(24, width - 24) if native.getpixel((x, ground_row))[3] == 255)
        front_lip_alpha = sum(1 for x in range(24, width - 24) if native.getpixel((x, front_lip_row))[3] == 255)
        self.assertGreaterEqual(surface_alpha, 250, "documented surface top should land on opaque counter pixels")
        self.assertGreaterEqual(ground_alpha, 260, "physics baseline should land on opaque playable tabletop pixels")
        self.assertGreaterEqual(front_lip_alpha, 260, "front lip guide should land on opaque counter-front pixels")
        self.assertGreaterEqual(row_texture(14, ground_row), 900, "playable table plane needs readable wood grain above the physics baseline")


if __name__ == "__main__":
    unittest.main(verbosity=2)
