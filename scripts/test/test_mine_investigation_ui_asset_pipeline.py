from __future__ import annotations

import json
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = ROOT / "art_sources" / "generated_raw" / "mine_investigation_ui"
RAW_BUTTON = RAW_DIR / "mine_leave_button_source_v1.png"
RAW_PROMPT = RAW_DIR / "mine_leave_button_prompt_v1.txt"
SOURCE = ROOT / "assets" / "source" / "investigation" / "mine_ui"
REFERENCE = SOURCE / "reference" / "mine_leave_button_source_v1.png"
MANIFEST = SOURCE / "mine_ui_manifest.json"
RUNTIME = ROOT / "assets" / "ui" / "generated" / "investigation" / "mine_ui"
CONTACT_SHEET = ROOT / "docs" / "art" / "mine_investigation_ui_contact_sheet.png"
SCENE_PREVIEW = ROOT / "docs" / "art" / "mine_investigation_ui_scene_preview.png"
SCALE = 4
NATIVE_SIZE = (70, 25)
RUNTIME_SIZE = (280, 100)
STATES = ("normal", "hover", "pressed")


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixel_count(image: Image.Image) -> int:
    return sum(image.convert("RGBA").getchannel("A").histogram()[1:])


def pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    rgba = image.convert("RGBA")
    if hasattr(rgba, "get_flattened_data"):
        return list(rgba.get_flattened_data())
    return list(rgba.getdata())


def luminance_sum(image: Image.Image) -> int:
    gray = image.convert("L")
    if hasattr(gray, "get_flattened_data"):
        return sum(gray.get_flattened_data())
    return sum(gray.getdata())


def chroma_fringe_pixels(image: Image.Image) -> int:
    count = 0
    for red, green, blue, alpha in pixels(image):
        if alpha == 0:
            continue
        if red >= 150 and blue >= 150 and green <= 80 and abs(red - blue) <= 90:
            count += 1
    return count


class MineInvestigationUiAssetPipelineTest(unittest.TestCase):
    def test_ai_source_prompt_and_manifest_are_retained(self) -> None:
        self.assertTrue(RAW_BUTTON.exists(), f"{RAW_BUTTON}: missing AI button source")
        self.assertTrue(RAW_PROMPT.exists(), f"{RAW_PROMPT}: missing AI button prompt")
        self.assertGreater(RAW_BUTTON.stat().st_size, 100_000, "AI button source is unexpectedly small")
        prompt = RAW_PROMPT.read_text(encoding="utf-8").lower()
        for phrase in ("mine", "button", "no text", "chroma-key", "no logos"):
            self.assertIn(phrase, prompt)

        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["scale"], SCALE)
        self.assertEqual(manifest["source"], "art_sources/generated_raw/mine_investigation_ui/mine_leave_button_source_v1.png")
        self.assertEqual(manifest["reference"], "assets/source/investigation/mine_ui/reference/mine_leave_button_source_v1.png")
        self.assertEqual(manifest["source_rect"], [132, 202, 1400, 500])
        self.assertEqual(manifest["native_size"], list(NATIVE_SIZE))
        self.assertEqual(manifest["runtime_size"], list(RUNTIME_SIZE))
        self.assertEqual(manifest["safe_area"], [12, 6, 58, 19])
        self.assertEqual(manifest["nine_slice_margins"], [28, 28, 18, 18])
        self.assertEqual([state["id"] for state in manifest["states"]], list(STATES))

    def test_native_runtime_and_contact_sheet_exist(self) -> None:
        self.assertTrue(REFERENCE.exists(), f"{REFERENCE}: missing source reference")
        for state in STATES:
            native = SOURCE / f"mine_leave_button_{state}_native.png"
            runtime = RUNTIME / f"mine_leave_button_{state}.png"
            self.assertTrue(native.exists(), f"{native}: missing native output")
            self.assertTrue(runtime.exists(), f"{runtime}: missing runtime output")
            self.assertEqual(load_rgba(native).size, NATIVE_SIZE, f"{state}: wrong native size")
            self.assertEqual(load_rgba(runtime).size, RUNTIME_SIZE, f"{state}: wrong runtime size")
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing contact sheet")
        self.assertGreaterEqual(load_rgba(CONTACT_SHEET).width, 900, "contact sheet is too narrow for review")
        self.assertTrue(SCENE_PREVIEW.exists(), f"{SCENE_PREVIEW}: missing in-scene button preview")
        self.assertEqual(load_rgba(SCENE_PREVIEW).size, (1280, 720), "scene preview should use the runtime scene size")

    def test_runtime_outputs_are_exact_nearest_exports(self) -> None:
        for state in STATES:
            native = load_rgba(SOURCE / f"mine_leave_button_{state}_native.png")
            runtime = load_rgba(RUNTIME / f"mine_leave_button_{state}.png")
            expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
            self.assertEqual(runtime.tobytes(), expected.tobytes(), f"{state}: runtime is not exact 4x nearest")

    def test_button_alpha_and_state_readability_contract(self) -> None:
        normal = load_rgba(SOURCE / "mine_leave_button_normal_native.png")
        hover = load_rgba(SOURCE / "mine_leave_button_hover_native.png")
        pressed = load_rgba(SOURCE / "mine_leave_button_pressed_native.png")
        for state, image in (("normal", normal), ("hover", hover), ("pressed", pressed)):
            alpha_min, alpha_max = image.getchannel("A").getextrema()
            self.assertEqual(alpha_min, 0, f"{state}: needs transparent boundary pixels")
            self.assertGreater(alpha_max, 0, f"{state}: visible pixels missing")
            self.assertGreaterEqual(visible_pixel_count(image), 900, f"{state}: button silhouette too sparse")
            self.assertEqual(chroma_fringe_pixels(image), 0, f"{state}: contains visible chroma-key fringe")
        self.assertGreater(luminance_sum(hover), luminance_sum(normal), "hover should read brighter than normal")
        self.assertLess(luminance_sum(pressed), luminance_sum(normal), "pressed should read darker than normal")

    def test_runtime_files_do_not_reference_raw_sources(self) -> None:
        forbidden = [
            "art_sources/generated_raw/mine_investigation_ui",
            "assets/source/investigation/mine_ui/reference",
            "mine_leave_button_source_v1.png",
        ]
        for root in (ROOT / "scripts" / "ui", ROOT / "scenes" / "ui"):
            for path in root.rglob("*"):
                if path.suffix not in {".gd", ".tscn", ".tres"}:
                    continue
                text = path.read_text(encoding="utf-8", errors="ignore").replace("\\", "/")
                for marker in forbidden:
                    self.assertNotIn(marker, text, f"{path.relative_to(ROOT)} references raw/reference button art")


if __name__ == "__main__":
    unittest.main(verbosity=2)
