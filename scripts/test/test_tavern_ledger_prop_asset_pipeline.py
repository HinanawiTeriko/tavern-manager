from __future__ import annotations

import json
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_sources" / "generated_raw" / "tavern_ledger" / "ledger_prop_reference_v2.png"
PROMPT = ROOT / "art_sources" / "generated_raw" / "tavern_ledger" / "ledger_prop_prompt_v2.txt"
MANIFEST = ROOT / "assets" / "source" / "tavern" / "props" / "tavern_ledger_prop_manifest.json"
NATIVE = ROOT / "assets" / "source" / "tavern" / "props" / "ledger_native.png"
RUNTIME = ROOT / "assets" / "textures" / "tavern" / "props" / "ledger.png"
CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_ledger_prop_contact_sheet.png"
NATIVE_SIZE = (40, 28)
RUNTIME_SIZE = (160, 112)
SCALE = 4


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def image_pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    if hasattr(image, "get_flattened_data"):
        return list(image.get_flattened_data())
    return list(image.getdata())


class TavernLedgerPropAssetPipelineTest(unittest.TestCase):
    def test_manifest_records_ledger_prop_contract(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["id"], "tavern_ledger_prop")
        self.assertEqual(manifest["source"], "art_sources/generated_raw/tavern_ledger/ledger_prop_reference_v2.png")
        self.assertEqual(manifest["prompt"], "art_sources/generated_raw/tavern_ledger/ledger_prop_prompt_v2.txt")
        self.assertEqual(manifest["native"], "assets/source/tavern/props/ledger_native.png")
        self.assertEqual(manifest["runtime"], "assets/textures/tavern/props/ledger.png")
        self.assertEqual(manifest["native_size"], list(NATIVE_SIZE))
        self.assertEqual(manifest["runtime_size"], list(RUNTIME_SIZE))
        self.assertEqual(manifest["scale"], SCALE)
        self.assertEqual(manifest["chroma_key"], "#ff00ff")
        self.assertEqual(manifest["safe_area"], [0, 0, 40, 28])

    def test_source_native_runtime_and_contact_sheet_exist(self) -> None:
        for path in [RAW, PROMPT, MANIFEST, NATIVE, RUNTIME, CONTACT_SHEET]:
            self.assertTrue(path.exists(), f"{path}: missing")
            self.assertGreater(path.stat().st_size, 0, f"{path}: empty")

    def test_runtime_is_exact_nearest_export(self) -> None:
        native = load_rgba(NATIVE)
        runtime = load_rgba(RUNTIME)
        self.assertEqual(native.size, NATIVE_SIZE)
        self.assertEqual(runtime.size, RUNTIME_SIZE)
        expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
        self.assertEqual(runtime.tobytes(), expected.tobytes(), "runtime must be exact 4x nearest export")

    def test_native_ledger_has_clean_alpha_and_readable_shape(self) -> None:
        native = load_rgba(NATIVE)
        alpha = native.getchannel("A")
        alpha_min, alpha_max = alpha.getextrema()
        self.assertEqual(alpha_min, 0, "ledger needs transparent pixels")
        self.assertEqual(alpha_max, 255, "ledger needs opaque pixels")
        visible = [(r, g, b, a) for r, g, b, a in image_pixels(native) if a >= 240]
        self.assertGreaterEqual(len(visible), 280, "ledger prop is too sparse at native size")
        self.assertLessEqual(len(visible), 900, "ledger prop overfills its native frame")
        dark_cover = sum(1 for r, g, b, _a in visible if b >= 18 and g >= 18 and r <= 82 and max(r, g, b) <= 96)
        parchment = sum(1 for r, g, b, _a in visible if r >= 86 and g >= 55 and b <= 62)
        amber = sum(1 for r, g, b, _a in visible if r >= 110 and 55 <= g <= 165 and b <= 120 and r >= g)
        self.assertGreaterEqual(dark_cover, 80, "ledger needs a readable dark leather cover")
        self.assertGreaterEqual(parchment, 35, "ledger needs readable page edges")
        self.assertGreaterEqual(amber, 16, "ledger needs sparse brass/amber accents")
        bbox = alpha.getbbox()
        self.assertIsNotNone(bbox, "ledger needs a visible alpha bbox")
        if bbox != None:
            left, top, right, bottom = bbox
            self.assertGreaterEqual(right - left, 30, "ledger should read as a tabletop ledger, not a tiny square book")
            self.assertGreaterEqual(bottom - top, 18, "ledger needs enough height for readable page/cover layers")
        unique_visible_colors = {pixel for pixel in visible}
        self.assertGreaterEqual(len(unique_visible_colors), 9, "ledger needs richer pixel detail than the old simple prop")


if __name__ == "__main__":
    unittest.main(verbosity=2)
