from pathlib import Path
import json
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = ROOT / "art_sources" / "generated_raw" / "today_intel_tab"
PROMPT = RAW_DIR / "today_intel_tab_prompt_v1.txt"
RAW_SOURCE = RAW_DIR / "today_intel_tab_source_v1.png"
SOURCE_DIR = ROOT / "assets" / "source" / "ui" / "today_intel_tab"
MANIFEST = SOURCE_DIR / "today_intel_tab_manifest.json"
RUNTIME_DIR = ROOT / "assets" / "textures" / "ui"
CONTACT_SHEET = ROOT / "docs" / "art" / "today_intel_tab_contact_sheet.png"
STATES = ["normal", "hover", "pressed", "unread"]
NATIVE_SIZE = (56, 24)
RUNTIME_SIZE = (224, 96)


def load_rgba(path: Path) -> Image.Image:
    if not path.exists():
        raise AssertionError(f"{path}: missing image")
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixels(image: Image.Image) -> int:
    return sum(image.getchannel("A").histogram()[1:])


class TodayIntelTabAssetPipelineTest(unittest.TestCase):
    def test_manifest_tracks_extracted_imagegen_source(self) -> None:
        self.assertTrue(PROMPT.exists(), f"{PROMPT}: missing prompt record")
        self.assertTrue(RAW_SOURCE.exists(), f"{RAW_SOURCE}: missing extracted raw source")
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["id"], "today_intel_tab")
        self.assertEqual(manifest["raw_source"], RAW_SOURCE.relative_to(ROOT).as_posix())
        self.assertEqual(manifest["prompt"], PROMPT.relative_to(ROOT).as_posix())
        self.assertEqual(manifest["scale"], 4)
        self.assertEqual(manifest["native_size"], list(NATIVE_SIZE))
        self.assertEqual(manifest["runtime_size"], list(RUNTIME_SIZE))
        self.assertEqual(manifest["contact_sheet"], CONTACT_SHEET.relative_to(ROOT).as_posix())
        self.assertEqual(sorted(manifest["states"].keys()), sorted(STATES))
        for state in STATES:
            state_data = manifest["states"][state]
            self.assertEqual(len(state_data["source_rect"]), 4)
            self.assertEqual(state_data["native_file"], f"assets/source/ui/today_intel_tab/today_intel_tab_{state}_native.png")
            self.assertEqual(state_data["runtime_file"], f"assets/textures/ui/today_intel_tab_{state}.png")
            self.assertEqual(state_data["safe_area"], [82, 18, 120, 60])
            self.assertEqual(state_data["nine_slice_margins"], [34, 28, 34, 28])

    def test_runtime_textures_are_nearest_neighbor_exports(self) -> None:
        for state in STATES:
            with self.subTest(state=state):
                native = load_rgba(SOURCE_DIR / f"today_intel_tab_{state}_native.png")
                runtime = load_rgba(RUNTIME_DIR / f"today_intel_tab_{state}.png")
                self.assertEqual(native.size, NATIVE_SIZE)
                self.assertEqual(runtime.size, RUNTIME_SIZE)
                expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
                self.assertEqual(runtime.tobytes(), expected.tobytes())
                self.assertGreater(visible_pixels(native), 620)
                self.assertLess(visible_pixels(native), native.width * native.height)
                self.assertIsNotNone(native.getchannel("A").getbbox())

    def test_chroma_background_does_not_survive_runtime_assets(self) -> None:
        for state in STATES:
            with self.subTest(state=state):
                runtime = load_rgba(RUNTIME_DIR / f"today_intel_tab_{state}.png")
                raw = runtime.tobytes()
                chroma_pixels = sum(
                    1
                    for index in range(0, len(raw), 4)
                    for red, green, blue, alpha in [raw[index : index + 4]]
                    if alpha > 0 and green >= 190 and green > red * 1.5 and green > blue * 1.5
                )
                self.assertEqual(chroma_pixels, 0, "runtime tab retains chroma-key green pixels")

    def test_contact_sheet_exists_for_visual_review(self) -> None:
        sheet = load_rgba(CONTACT_SHEET)
        self.assertGreaterEqual(sheet.width, RUNTIME_SIZE[0] * len(STATES))
        self.assertGreaterEqual(sheet.height, RUNTIME_SIZE[1])


if __name__ == "__main__":
    unittest.main(verbosity=2)
