from __future__ import annotations

import json
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "tavern_background" / "tavern_background_no_people_reference_v1.png"
PROMPT = ROOT / "art_sources" / "generated_raw" / "tavern_background" / "tavern_background_no_people_prompt_v1.txt"
MANIFEST = ROOT / "assets" / "source" / "tavern" / "background" / "tavern_background_manifest.json"
NATIVE = ROOT / "assets" / "source" / "tavern" / "background" / "tavern_bg_native.png"
RUNTIME = ROOT / "assets" / "textures" / "tavern" / "background" / "tavern_bg.png"
CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_background_contact_sheet.png"
NATIVE_SIZE = (320, 180)
RUNTIME_SIZE = (1280, 720)


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    rgba = image.convert("RGBA")
    if hasattr(rgba, "get_flattened_data"):
        return list(rgba.get_flattened_data())
    return list(rgba.getdata())


class TavernBackgroundAssetPipelineTest(unittest.TestCase):
    def test_generated_reference_and_prompt_are_retained(self) -> None:
        self.assertTrue(RAW_SOURCE.exists(), f"{RAW_SOURCE}: missing generated reference")
        self.assertGreater(RAW_SOURCE.stat().st_size, 1_000_000, "generated reference is unexpectedly small")
        self.assertTrue(PROMPT.exists(), f"{PROMPT}: missing prompt record")
        prompt = PROMPT.read_text(encoding="utf-8").lower()
        for phrase in ("no people", "left", "fireplace", "tables", "chairs"):
            self.assertIn(phrase, prompt)

    def test_manifest_records_background_contract(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["id"], "tavern_no_people_background")
        self.assertEqual(
            manifest["source"],
            "art_sources/generated_raw/tavern_background/tavern_background_no_people_reference_v1.png",
        )
        self.assertEqual(manifest["native"], "assets/source/tavern/background/tavern_bg_native.png")
        self.assertEqual(manifest["runtime"], "assets/textures/tavern/background/tavern_bg.png")
        self.assertEqual(manifest["native_size"], list(NATIVE_SIZE))
        self.assertEqual(manifest["runtime_size"], list(RUNTIME_SIZE))
        self.assertEqual(manifest["scale"], 4)
        self.assertEqual(manifest["safe_area"], [0, 0, 320, 180])
        self.assertEqual(
            manifest["intended_godot_use"],
            "Tavern service scene visual-only no-people background Sprite2D layer",
        )

    def test_native_runtime_and_contact_sheet_exist(self) -> None:
        for path in (NATIVE, RUNTIME, CONTACT_SHEET):
            self.assertTrue(path.exists(), f"{path}: missing output")
            self.assertGreater(path.stat().st_size, 0, f"{path}: empty output")
        self.assertEqual(load_rgba(NATIVE).size, NATIVE_SIZE)
        self.assertEqual(load_rgba(RUNTIME).size, RUNTIME_SIZE)

    def test_runtime_is_exact_four_x_nearest_export(self) -> None:
        self.assertTrue(NATIVE.exists(), f"{NATIVE}: missing native output")
        self.assertTrue(RUNTIME.exists(), f"{RUNTIME}: missing runtime output")
        native = load_rgba(NATIVE)
        runtime = load_rgba(RUNTIME)
        expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
        self.assertEqual(runtime.tobytes(), expected.tobytes(), "runtime must be exact 4x nearest export")

    def test_background_palette_and_furniture_density(self) -> None:
        self.assertTrue(NATIVE.exists(), f"{NATIVE}: missing native output")
        native = load_rgba(NATIVE)
        data = pixels(native)
        dark = sum(1 for r, g, b, a in data if a == 255 and max(r, g, b) <= 58)
        teal = sum(1 for r, g, b, a in data if a == 255 and b >= 30 and g >= 26 and b >= r * 0.9)
        amber = sum(1 for r, g, b, a in data if a == 255 and r >= 92 and g >= 38 and b <= 58 and r >= b * 1.5)
        bright = sum(1 for r, g, b, a in data if a == 255 and max(r, g, b) >= 210)
        self.assertGreaterEqual(dark, 22_000, "background needs enough dark dungeon mass")
        self.assertGreaterEqual(teal, 4_500, "background needs visible teal stone depth")
        self.assertGreaterEqual(amber, 450, "background needs readable amber fireplace/candle accents")
        self.assertLessEqual(amber, 10_000, "background amber accents are flooding the frame")
        self.assertLessEqual(bright, 160, "background should avoid bright noisy pixels")

        midground = native.crop((24, 72, 296, 152)).convert("RGBA")
        mid_pixels = pixels(midground)
        wood_dark = sum(1 for r, g, b, a in mid_pixels if a == 255 and 30 <= r <= 125 and 18 <= g <= 86 and 8 <= b <= 72)
        horizontal_edges = 0
        for y in range(midground.height):
            for x in range(midground.width - 1):
                r1, g1, b1, a1 = midground.getpixel((x, y))
                r2, g2, b2, a2 = midground.getpixel((x + 1, y))
                if a1 == 255 and a2 == 255 and abs((r1 + g1 + b1) - (r2 + g2 + b2)) >= 36:
                    horizontal_edges += 1
        self.assertGreaterEqual(wood_dark, 3_200, "midground needs enough empty table/chair wood mass")
        self.assertGreaterEqual(horizontal_edges, 1_000, "midground needs readable table/chair structure")


if __name__ == "__main__":
    unittest.main(verbosity=2)
