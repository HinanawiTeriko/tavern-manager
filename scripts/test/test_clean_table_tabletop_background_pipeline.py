import json
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW_REFERENCE = ROOT / "art_sources" / "generated_raw" / "clean_table_inference" / "clean_table_tabletop_reference_v1.png"
RAW_PROMPT = ROOT / "art_sources" / "generated_raw" / "clean_table_inference" / "clean_table_tabletop_prompt_v1.txt"
SOURCE = ROOT / "assets" / "source" / "ui" / "clean_table_inference"
RUNTIME = ROOT / "assets" / "textures" / "ui" / "clean_table_inference"
NATIVE = SOURCE / "clean_table_tabletop_native.png"
RUNTIME_IMAGE = RUNTIME / "clean_table_tabletop.png"
MANIFEST = SOURCE / "clean_table_tabletop_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "clean_table_tabletop_contact_sheet.png"
NATIVE_SIZE = (320, 180)
RUNTIME_SIZE = (1280, 720)


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def rgb_pixels(image: Image.Image) -> list[tuple[int, int, int]]:
    rgb = image.convert("RGB")
    if hasattr(rgb, "get_flattened_data"):
        return list(rgb.get_flattened_data())
    return list(rgb.getdata())


class CleanTableTabletopBackgroundPipelineTest(unittest.TestCase):
    def test_source_prompt_manifest_and_contact_sheet_are_retained(self) -> None:
        for path in (RAW_REFERENCE, RAW_PROMPT, MANIFEST, CONTACT_SHEET):
            self.assertTrue(path.exists(), f"{path}: missing tabletop pipeline artifact")
            self.assertGreater(path.stat().st_size, 0, f"{path}: empty tabletop pipeline artifact")

        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["id"], "clean_table_tabletop_background")
        self.assertEqual(manifest["scale"], 4)
        self.assertEqual(manifest["source"], "art_sources/generated_raw/clean_table_inference/clean_table_tabletop_reference_v1.png")
        asset = manifest["assets"]["clean_table_tabletop"]
        self.assertEqual(asset["native_size"], list(NATIVE_SIZE))
        self.assertEqual(asset["size"], list(RUNTIME_SIZE))
        self.assertEqual(asset["output_file"], "assets/textures/ui/clean_table_inference/clean_table_tabletop.png")
        self.assertEqual(asset["nine_slice_margins"], [0, 0, 0, 0])

    def test_runtime_is_exact_nearest_export_from_native(self) -> None:
        native = load_rgba(NATIVE)
        runtime = load_rgba(RUNTIME_IMAGE)
        self.assertEqual(native.size, NATIVE_SIZE)
        self.assertEqual(runtime.size, RUNTIME_SIZE)
        expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
        self.assertEqual(runtime.tobytes(), expected.tobytes())

    def test_background_is_simple_low_ui_risk_surface(self) -> None:
        native = load_rgba(NATIVE)
        colors = native.convert("RGB").getcolors(maxcolors=1024)
        self.assertIsNotNone(colors, "native background palette must stay bounded")
        self.assertLessEqual(len(colors), 40, "native background should read as chunky pixel art, not a soft photo resample")

        pixels = rgb_pixels(native)
        dark_edge = sum(1 for red, green, blue in pixels if red <= 55 and green <= 75 and blue <= 78)
        warm_wood = sum(1 for red, green, blue in pixels if 55 <= red <= 150 and 35 <= green <= 105 and 20 <= blue <= 80)
        high_contrast = sum(1 for red, green, blue in pixels if max(red, green, blue) - min(red, green, blue) >= 110)
        self.assertGreaterEqual(dark_edge, 3000, "background needs dark edge framing")
        self.assertGreaterEqual(warm_wood, 12000, "background needs readable wooden table coverage")
        self.assertLessEqual(high_contrast, 900, "background should stay quiet behind movable UI")

    def test_runtime_ui_references_approved_tabletop_runtime_texture(self) -> None:
        scanned = [
            ROOT / "scripts" / "ui" / "clean_table_inference_screen.gd",
            ROOT / "scenes" / "ui" / "CleanTableInferenceScreen.tscn",
        ]
        combined = "\n".join(path.read_text(encoding="utf-8", errors="ignore").replace("\\", "/") for path in scanned)
        self.assertIn("clean_table_tabletop.png", combined)
        self.assertNotIn("clean_table_tabletop_native.png", combined)


if __name__ == "__main__":
    unittest.main(verbosity=2)
