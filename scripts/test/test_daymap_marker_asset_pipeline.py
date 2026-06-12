from pathlib import Path
import json
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
GENERATED_RAW = ROOT / "art_sources" / "generated_raw" / "daymap_markers"
SOURCE = ROOT / "assets" / "source" / "daymap" / "markers"
RUNTIME = ROOT / "assets" / "textures" / "daymap" / "markers"
MANIFEST = SOURCE / "daymap_story_marker_manifest.json"
PROMPT = GENERATED_RAW / "daymap_story_markers_prompt_v1.txt"
SOURCE_IMAGE = GENERATED_RAW / "daymap_story_markers_source_v1.png"
CONTACT_SHEET = ROOT / "docs" / "art" / "daymap_story_marker_contact_sheet.png"
EXPORTER = ROOT / "scripts" / "tools" / "export_daymap_marker_assets.py"
NATIVE_SIZE = (24, 24)
RUNTIME_SIZE = (96, 96)
EXPECTED_MARKERS = {
    "mira_stall": "DayMap marker icon for Mira market stall",
    "toby_lodging": "DayMap marker icon for Toby lodging lane",
    "fixer_den": "DayMap marker icon for fixer den",
}


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    return [pixels[x, y] for y in range(rgba.height) for x in range(rgba.width) if pixels[x, y][3] > 0]


def marker_amber_ratio(image: Image.Image) -> float:
    pixels = visible_pixels(image)
    amber = sum(1 for red, green, blue, _alpha in pixels if red >= 100 and 45 <= green <= 145 and blue <= 95)
    return amber / max(len(pixels), 1)


def leafy_green_ratio(image: Image.Image) -> float:
    pixels = visible_pixels(image)
    leafy = sum(1 for red, green, blue, _alpha in pixels if green >= 70 and green > red * 1.16 and green > blue * 1.12)
    return leafy / max(len(pixels), 1)


class DayMapMarkerAssetPipelineTest(unittest.TestCase):
    def test_ai_source_and_prompt_are_retained(self) -> None:
        self.assertTrue(SOURCE_IMAGE.exists(), f"{SOURCE_IMAGE}: missing retained AI source sheet")
        self.assertGreater(SOURCE_IMAGE.stat().st_size, 0, "retained AI source sheet is empty")
        self.assertTrue(PROMPT.exists(), f"{PROMPT}: missing retained generation prompt")
        prompt = PROMPT.read_text(encoding="utf-8")
        self.assertIn("3 columns x 1 row", prompt)
        self.assertIn("flat solid #ff00ff", prompt)
        self.assertIn("no labels", prompt)
        self.assertIn("no readable text", prompt)
        self.assertIn("match the existing daymap marker icons", prompt.lower())

    def test_exporter_uses_manifest_crops_and_retained_source(self) -> None:
        self.assertTrue(EXPORTER.exists(), f"{EXPORTER}: missing marker exporter")
        source = EXPORTER.read_text(encoding="utf-8")
        self.assertIn("MANIFEST_PATH", source)
        self.assertIn("source_crop", source)
        self.assertIn("daymap_story_markers_source_v1.png", source)
        self.assertNotIn("ImageDraw", source, "marker icon silhouettes must come from generated source art")

    def test_manifest_has_explicit_story_marker_entries(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        assets = manifest.get("assets", {})
        self.assertEqual(set(EXPECTED_MARKERS), set(assets), "manifest should only describe the new story markers")
        for marker_id, intended_use in EXPECTED_MARKERS.items():
            with self.subTest(marker=marker_id):
                entry = assets[marker_id]
                self.assertEqual(entry.get("source_file"), "art_sources/generated_raw/daymap_markers/daymap_story_markers_source_v1.png")
                self.assertEqual(entry.get("native_file"), f"assets/source/daymap/markers/{marker_id}_native.png")
                self.assertEqual(entry.get("output_file"), f"assets/textures/daymap/markers/{marker_id}.png")
                self.assertEqual(entry.get("size"), [96, 96])
                self.assertEqual(entry.get("safe_area"), [8, 8, 80, 80])
                self.assertEqual(entry.get("intended_godot_use"), intended_use)
                crop = entry.get("source_crop")
                self.assertIsInstance(crop, list, f"{marker_id}: source_crop must be a fixed rectangle")
                self.assertEqual(len(crop), 4, f"{marker_id}: source_crop must have four values")
                self.assertTrue(all(isinstance(value, int) for value in crop), f"{marker_id}: source_crop values must be ints")
                self.assertLess(crop[0], crop[2], f"{marker_id}: source_crop has invalid width")
                self.assertLess(crop[1], crop[3], f"{marker_id}: source_crop has invalid height")

    def test_story_markers_are_native_grid_exports(self) -> None:
        for marker_id in EXPECTED_MARKERS:
            with self.subTest(marker=marker_id):
                native_path = SOURCE / f"{marker_id}_native.png"
                runtime_path = RUNTIME / f"{marker_id}.png"
                self.assertTrue(native_path.exists(), f"{native_path}: missing native marker")
                self.assertTrue(runtime_path.exists(), f"{runtime_path}: missing runtime marker")
                native = load_rgba(native_path)
                runtime = load_rgba(runtime_path)
                self.assertEqual(native.size, NATIVE_SIZE, f"{marker_id}: wrong native size")
                self.assertEqual(runtime.size, RUNTIME_SIZE, f"{marker_id}: wrong runtime size")
                alpha_min, alpha_max = native.getchannel("A").getextrema()
                self.assertEqual(alpha_min, 0, f"{marker_id}: marker needs transparent padding")
                self.assertGreater(alpha_max, 0, f"{marker_id}: marker is empty")
                self.assertGreaterEqual(len(visible_pixels(native)), 35, f"{marker_id}: marker is too sparse")
                self.assertLessEqual(
                    len(native.getcolors(maxcolors=65536) or []),
                    10,
                    f"{marker_id}: marker has too many colors for the existing marker style",
                )
                self.assertGreaterEqual(marker_amber_ratio(native), 0.05, f"{marker_id}: needs amber marker accents")
                self.assertLessEqual(leafy_green_ratio(native), 0.20, f"{marker_id}: marker should not read as leafy green art")
                expected_runtime = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
                self.assertEqual(runtime.tobytes(), expected_runtime.tobytes(), f"{marker_id}: runtime is not exact 4x nearest")

    def test_contact_sheet_exists(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing contact sheet")
        self.assertGreater(CONTACT_SHEET.stat().st_size, 0, "contact sheet is empty")

    def test_runtime_code_does_not_reference_raw_ai_source(self) -> None:
        for path in [
            ROOT / "scripts" / "ui" / "map_point_marker.gd",
            ROOT / "data" / "locations.json",
        ]:
            with self.subTest(path=path.name):
                source = path.read_text(encoding="utf-8")
                self.assertNotIn("art_sources/generated_raw", source)
                self.assertNotIn("daymap_story_markers_source_v1.png", source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
