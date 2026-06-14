from pathlib import Path
import json
import unittest

from PIL import Image, ImageStat


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_sources" / "generated_raw" / "toby_contract_document" / "toby_contract_document_source_v1.png"
PROMPT = ROOT / "art_sources" / "generated_raw" / "toby_contract_document" / "toby_contract_document_prompt_v1.txt"
SOURCE_DIR = ROOT / "assets" / "source" / "tavern" / "documents"
MANIFEST = SOURCE_DIR / "toby_contract_document_manifest.json"
NATIVE = SOURCE_DIR / "toby_contract_document_native.png"
RUNTIME = ROOT / "assets" / "textures" / "tavern" / "documents" / "toby_contract_document.png"
CONTACT_SHEET = ROOT / "docs" / "art" / "toby_contract_document_contact_sheet.png"
NATIVE_SIZE = (200, 140)
RUNTIME_SIZE = (800, 560)
SCALE = 4
COLOR_LIMIT = 64


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def unique_rgb_colors(image: Image.Image) -> int:
    rgb = image.convert("RGB")
    data = rgb.get_flattened_data() if hasattr(rgb, "get_flattened_data") else rgb.getdata()
    return len(set(data))


class TobyContractDocumentAssetPipelineTest(unittest.TestCase):
    def test_ai_source_prompt_and_manifest_exist(self) -> None:
        self.assertTrue(RAW.exists(), "Toby completed contract AI source is missing")
        self.assertTrue(PROMPT.exists(), "Toby completed contract prompt record is missing")
        prompt = PROMPT.read_text(encoding="utf-8").lower()
        for phrase in (
            "completed toby commission",
            "assembled torn contract",
            "no readable text",
            "native 200x140",
            "dark teal dungeon tavern",
            "parchment",
        ):
            self.assertIn(phrase, prompt)

        self.assertTrue(MANIFEST.exists(), "Toby completed contract manifest is missing")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest.get("id"), "toby_contract_document_art")
        self.assertEqual(manifest.get("source"), RAW.relative_to(ROOT).as_posix())
        self.assertEqual(manifest.get("native"), NATIVE.relative_to(ROOT).as_posix())
        self.assertEqual(manifest.get("runtime"), RUNTIME.relative_to(ROOT).as_posix())
        self.assertEqual(manifest.get("native_size"), list(NATIVE_SIZE))
        self.assertEqual(manifest.get("runtime_size"), list(RUNTIME_SIZE))
        self.assertEqual(manifest.get("scale"), SCALE)
        self.assertEqual(manifest.get("color_limit"), COLOR_LIMIT)
        self.assertEqual(manifest.get("safe_area"), [48, 26, 152, 98])
        self.assertIn("DocumentOverlay", manifest.get("intended_godot_use", ""))
        source_rect = manifest.get("source_rect")
        self.assertIsInstance(source_rect, list, "source_rect must be fixed, not inferred")
        self.assertEqual(len(source_rect), 4, "source_rect must have four values")

    def test_native_and_runtime_exports(self) -> None:
        self.assertTrue(NATIVE.exists(), "Toby completed contract native source is missing")
        self.assertTrue(RUNTIME.exists(), "Toby completed contract runtime texture is missing")
        native = load_rgba(NATIVE)
        runtime = load_rgba(RUNTIME)
        self.assertEqual(native.size, NATIVE_SIZE)
        self.assertEqual(runtime.size, RUNTIME_SIZE)
        expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
        self.assertEqual(runtime.tobytes(), expected.tobytes(), "runtime must be exact 4x nearest export")
        self.assertGreater(unique_rgb_colors(native), 12, "native document art looks blank or under-detailed")
        self.assertLessEqual(unique_rgb_colors(native), COLOR_LIMIT, "native document art exceeds the pixel color budget")
        variance = sum(ImageStat.Stat(native.convert("L")).var)
        self.assertGreater(variance, 120.0, "native document art needs readable value contrast")

    def test_contact_sheet_exists(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), "Toby completed contract contact sheet is missing")
        contact = load_rgba(CONTACT_SHEET)
        self.assertGreaterEqual(contact.width, 900)
        self.assertGreaterEqual(contact.height, 360)


if __name__ == "__main__":
    unittest.main(verbosity=2)
