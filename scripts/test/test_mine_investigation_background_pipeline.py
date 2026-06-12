from __future__ import annotations

import json
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = ROOT / "art_sources" / "generated_raw" / "mine_investigation_background"
RAW_BACKGROUND = RAW_DIR / "mine_background_reference_v1.png"
RAW_BACKGROUND_PROMPT = RAW_DIR / "mine_background_prompt_v1.txt"
RAW_SHADOW = RAW_DIR / "mine_item_shadow_source_v1.png"
RAW_SHADOW_PROMPT = RAW_DIR / "mine_item_shadow_prompt_v1.txt"
SOURCE = ROOT / "assets" / "source" / "investigation" / "mine_background"
REFERENCE_BACKGROUND = SOURCE / "reference" / "mine_background_reference_v1.png"
REFERENCE_SHADOW = SOURCE / "reference" / "mine_item_shadow_source_v1.png"
MANIFEST = SOURCE / "mine_background_manifest.json"
BACKGROUND_NATIVE = SOURCE / "mine_background_native.png"
SHADOW_NATIVE = SOURCE / "mine_item_shadow_native.png"
RUNTIME = ROOT / "assets" / "ui" / "generated" / "investigation" / "mine_background"
BACKGROUND_RUNTIME = RUNTIME / "mine_background.png"
SHADOW_RUNTIME = RUNTIME / "mine_item_shadow.png"
CONTACT_SHEET = ROOT / "docs" / "art" / "mine_investigation_background_contact_sheet.png"
SCALE = 4
BACKGROUND_NATIVE_SIZE = (320, 180)
BACKGROUND_RUNTIME_SIZE = (1280, 720)
SHADOW_NATIVE_SIZE = (40, 14)
SHADOW_RUNTIME_SIZE = (160, 56)


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    rgba = image.convert("RGBA")
    if hasattr(rgba, "get_flattened_data"):
        return list(rgba.get_flattened_data())
    return list(rgba.getdata())


def color_count(image: Image.Image) -> int:
    colors = image.convert("RGBA").getcolors(maxcolors=65536)
    return len(colors) if colors is not None else 65536


def visible_pixel_count(image: Image.Image) -> int:
    alpha = image.convert("RGBA").getchannel("A")
    return sum(alpha.histogram()[1:])


def chroma_fringe_pixels(image: Image.Image) -> int:
    count = 0
    for red, green, blue, alpha in pixels(image):
        if alpha == 0:
            continue
        if red >= 10 and blue >= 10 and blue >= red * 0.70 and red >= blue * 0.50 and green <= min(red, blue) * 0.45:
            count += 1
    return count


class MineInvestigationBackgroundPipelineTest(unittest.TestCase):
    def test_ai_sources_and_prompts_are_retained(self) -> None:
        self.assertTrue(RAW_BACKGROUND.exists(), f"{RAW_BACKGROUND}: missing AI background source")
        self.assertTrue(RAW_SHADOW.exists(), f"{RAW_SHADOW}: missing AI shadow source")
        self.assertGreater(RAW_BACKGROUND.stat().st_size, 100_000, "AI background source is unexpectedly small")
        self.assertGreater(RAW_SHADOW.stat().st_size, 10_000, "AI shadow source is unexpectedly small")
        for prompt_path, phrases in {
            RAW_BACKGROUND_PROMPT: ("abandoned mine", "landing zones", "no text", "no labels", "without drawing complete interactive props"),
            RAW_SHADOW_PROMPT: ("contact shadow", "pure magenta", "no text", "no object"),
        }.items():
            self.assertTrue(prompt_path.exists(), f"{prompt_path}: missing prompt record")
            prompt = prompt_path.read_text(encoding="utf-8").lower()
            for phrase in phrases:
                self.assertIn(phrase, prompt)

    def test_manifest_records_background_and_shadow_contracts(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["scale"], SCALE)
        background = manifest["background"]
        shadow = manifest["shadow"]
        self.assertEqual(background["id"], "mine_investigation_background")
        self.assertEqual(background["source"], "art_sources/generated_raw/mine_investigation_background/mine_background_reference_v1.png")
        self.assertEqual(background["reference"], "assets/source/investigation/mine_background/reference/mine_background_reference_v1.png")
        self.assertEqual(background["native"], "assets/source/investigation/mine_background/mine_background_native.png")
        self.assertEqual(background["runtime"], "assets/ui/generated/investigation/mine_background/mine_background.png")
        self.assertEqual(background["native_size"], list(BACKGROUND_NATIVE_SIZE))
        self.assertEqual(background["runtime_size"], list(BACKGROUND_RUNTIME_SIZE))
        self.assertEqual(background["safe_area"], [0, 0, 320, 180])
        self.assertEqual(shadow["id"], "mine_item_shadow")
        self.assertEqual(shadow["source"], "art_sources/generated_raw/mine_investigation_background/mine_item_shadow_source_v1.png")
        self.assertEqual(shadow["reference"], "assets/source/investigation/mine_background/reference/mine_item_shadow_source_v1.png")
        self.assertEqual(shadow["native"], "assets/source/investigation/mine_background/mine_item_shadow_native.png")
        self.assertEqual(shadow["runtime"], "assets/ui/generated/investigation/mine_background/mine_item_shadow.png")
        self.assertEqual(shadow["native_size"], list(SHADOW_NATIVE_SIZE))
        self.assertEqual(shadow["runtime_size"], list(SHADOW_RUNTIME_SIZE))
        self.assertEqual(shadow["source_rect"], [0, 0, 512, 256])
        self.assertEqual(shadow["safe_area"], [2, 2, 38, 12])

    def test_references_native_runtime_and_contact_sheet_exist(self) -> None:
        for path in (REFERENCE_BACKGROUND, REFERENCE_SHADOW, BACKGROUND_NATIVE, SHADOW_NATIVE, BACKGROUND_RUNTIME, SHADOW_RUNTIME, CONTACT_SHEET):
            self.assertTrue(path.exists(), f"{path}: missing output")
            self.assertGreater(path.stat().st_size, 0, f"{path}: empty output")
        self.assertEqual(load_rgba(REFERENCE_BACKGROUND).size, BACKGROUND_RUNTIME_SIZE)
        self.assertGreaterEqual(load_rgba(REFERENCE_SHADOW).width, 256)
        self.assertEqual(load_rgba(BACKGROUND_NATIVE).size, BACKGROUND_NATIVE_SIZE)
        self.assertEqual(load_rgba(BACKGROUND_RUNTIME).size, BACKGROUND_RUNTIME_SIZE)
        self.assertEqual(load_rgba(SHADOW_NATIVE).size, SHADOW_NATIVE_SIZE)
        self.assertEqual(load_rgba(SHADOW_RUNTIME).size, SHADOW_RUNTIME_SIZE)
        contact = load_rgba(CONTACT_SHEET)
        self.assertGreaterEqual(contact.width, 900, "contact sheet is too narrow for review")
        self.assertGreaterEqual(contact.height, 700, "contact sheet is too short for review")

    def test_runtime_outputs_are_exact_four_x_nearest_exports(self) -> None:
        for native_path, runtime_path, runtime_size in (
            (BACKGROUND_NATIVE, BACKGROUND_RUNTIME, BACKGROUND_RUNTIME_SIZE),
            (SHADOW_NATIVE, SHADOW_RUNTIME, SHADOW_RUNTIME_SIZE),
        ):
            native = load_rgba(native_path)
            runtime = load_rgba(runtime_path)
            expected = native.resize(runtime_size, Image.Resampling.NEAREST)
            self.assertEqual(runtime.tobytes(), expected.tobytes(), f"{runtime_path.name}: not exact 4x nearest export")

    def test_background_palette_is_dark_cold_and_not_flat(self) -> None:
        native = load_rgba(BACKGROUND_NATIVE)
        data = pixels(native)
        dark = sum(1 for red, green, blue, alpha in data if alpha == 255 and max(red, green, blue) <= 70)
        cool = sum(1 for red, green, blue, alpha in data if alpha == 255 and green >= 18 and blue >= 20 and blue >= red * 0.62)
        blood = sum(1 for red, green, blue, alpha in data if alpha == 255 and red >= 50 and green <= 48 and blue <= 50 and red >= green * 1.25)
        amber = sum(1 for red, green, blue, alpha in data if alpha == 255 and red >= 82 and green >= 38 and blue <= 62 and red >= blue * 1.45)
        bright = sum(1 for red, green, blue, alpha in data if alpha == 255 and max(red, green, blue) >= 215)
        histogram = native.convert("RGBA").getcolors(maxcolors=65536)
        self.assertIsNotNone(histogram, "background color count should stay bounded")
        assert histogram is not None
        self.assertGreaterEqual(dark, 18_000, "background needs enough dark cave mass")
        self.assertGreaterEqual(cool, 5_000, "background needs visible cold stone color")
        self.assertGreaterEqual(blood, 35, "background needs a small dark red blood trail")
        self.assertLessEqual(amber, 3_800, "amber accents should not flood the mine background")
        self.assertLessEqual(bright, 120, "background should avoid bright noisy pixels")
        self.assertGreaterEqual(color_count(native), 36, "background should preserve authored color nuance")
        self.assertLessEqual(max(count for count, _pixel in histogram), 22_000, "background should not collapse into one flat color")

    def test_shadow_alpha_and_chroma_contract(self) -> None:
        native = load_rgba(SHADOW_NATIVE)
        alpha = native.getchannel("A")
        alpha_min, alpha_max = alpha.getextrema()
        self.assertEqual(alpha_min, 0, "shadow needs transparent boundary pixels")
        self.assertGreater(alpha_max, 0, "shadow needs visible pixels")
        self.assertGreaterEqual(visible_pixel_count(native), 80, "shadow has too few visible pixels")
        self.assertLessEqual(visible_pixel_count(native), 360, "shadow covers too much of its native canvas")
        self.assertIsNotNone(alpha.getbbox(), "shadow alpha bbox is empty")
        self.assertEqual(chroma_fringe_pixels(native), 0, "shadow contains visible magenta chroma-key fringe")

    def test_ui_scene_files_do_not_reference_raw_or_reference_art(self) -> None:
        forbidden = [
            "art_sources/generated_raw/mine_investigation_background",
            "assets/source/investigation/mine_background/reference",
            "mine_background_reference_v1.png",
            "mine_item_shadow_source_v1.png",
        ]
        for root in (ROOT / "scripts" / "ui", ROOT / "scenes" / "ui"):
            for path in root.rglob("*"):
                if path.suffix not in {".gd", ".tscn", ".tres"}:
                    continue
                text = path.read_text(encoding="utf-8", errors="ignore").replace("\\", "/")
                for marker in forbidden:
                    self.assertNotIn(marker, text, f"{path.relative_to(ROOT)} references raw/reference art")


if __name__ == "__main__":
    unittest.main(verbosity=2)
