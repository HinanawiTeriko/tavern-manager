from pathlib import Path
import json
import unittest

from PIL import Image, ImageChops


ROOT = Path(__file__).resolve().parents[2]
GENERATED_RAW = ROOT / "art_sources" / "generated_raw" / "daymap_markers"
SOURCE = ROOT / "assets" / "source" / "daymap" / "markers"
RUNTIME = ROOT / "assets" / "textures" / "daymap" / "markers"
MANIFEST = SOURCE / "daymap_market_shop_marker_manifest.json"
PROMPT = GENERATED_RAW / "market_shop_marker_prompt_v1.txt"
SOURCE_IMAGE = GENERATED_RAW / "market_shop_marker_source_v1.png"
CONTACT_SHEET = ROOT / "docs" / "art" / "daymap_market_shop_marker_contact_sheet.png"
EXPORTER = ROOT / "scripts" / "tools" / "export_daymap_market_shop_marker_assets.py"
NATIVE_SIZE = (24, 24)
RUNTIME_SIZE = (96, 96)


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


class DayMapMarketShopMarkerAssetPipelineTest(unittest.TestCase):
    def test_ai_source_and_prompt_are_retained(self) -> None:
        self.assertTrue(SOURCE_IMAGE.exists(), f"{SOURCE_IMAGE}: missing retained AI source")
        self.assertGreater(SOURCE_IMAGE.stat().st_size, 0, "retained AI source is empty")
        self.assertTrue(PROMPT.exists(), f"{PROMPT}: missing retained generation prompt")
        prompt = PROMPT.read_text(encoding="utf-8").lower()
        self.assertIn("market shop", prompt)
        self.assertIn("flat solid #ff00ff", prompt)
        self.assertIn("no readable text", prompt)
        self.assertIn("24x24", prompt)
        self.assertIn("clearly distinct from a guild counter", prompt)

    def test_exporter_uses_manifest_and_retained_source(self) -> None:
        self.assertTrue(EXPORTER.exists(), f"{EXPORTER}: missing exporter")
        source = EXPORTER.read_text(encoding="utf-8")
        self.assertIn("MANIFEST_PATH", source)
        self.assertIn("source_crop", source)
        self.assertIn("market_shop_marker_source_v1.png", source)
        self.assertNotIn("ImageDraw", source, "market shop marker silhouette must come from retained source art")

    def test_manifest_describes_market_shop_marker(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest.get("source_image"), "art_sources/generated_raw/daymap_markers/market_shop_marker_source_v1.png")
        assets = manifest.get("assets", {})
        self.assertEqual(["market_shop"], list(assets.keys()))
        entry = assets["market_shop"]
        self.assertEqual(entry.get("source_file"), "art_sources/generated_raw/daymap_markers/market_shop_marker_source_v1.png")
        self.assertEqual(entry.get("native_file"), "assets/source/daymap/markers/market_shop_native.png")
        self.assertEqual(entry.get("output_file"), "assets/textures/daymap/markers/market_shop.png")
        self.assertEqual(entry.get("size"), [96, 96])
        self.assertEqual(entry.get("safe_area"), [8, 8, 80, 80])
        self.assertEqual(entry.get("intended_godot_use"), "DayMap marker icon for market shop")
        crop = entry.get("source_crop")
        self.assertIsInstance(crop, list, "source_crop must be a fixed rectangle")
        self.assertEqual(len(crop), 4, "source_crop must have four values")
        self.assertTrue(all(isinstance(value, int) for value in crop), "source_crop values must be ints")
        self.assertLess(crop[0], crop[2], "source_crop has invalid width")
        self.assertLess(crop[1], crop[3], "source_crop has invalid height")

    def test_market_shop_marker_is_a_native_grid_export(self) -> None:
        native_path = SOURCE / "market_shop_native.png"
        runtime_path = RUNTIME / "market_shop.png"
        self.assertTrue(native_path.exists(), f"{native_path}: missing native marker")
        self.assertTrue(runtime_path.exists(), f"{runtime_path}: missing runtime marker")
        native = load_rgba(native_path)
        runtime = load_rgba(runtime_path)
        self.assertEqual(native.size, NATIVE_SIZE)
        self.assertEqual(runtime.size, RUNTIME_SIZE)
        alpha_min, alpha_max = native.getchannel("A").getextrema()
        self.assertEqual(alpha_min, 0, "marker needs transparent padding")
        self.assertGreater(alpha_max, 0, "marker is empty")
        self.assertGreaterEqual(len(visible_pixels(native)), 35, "marker is too sparse")
        self.assertLessEqual(len(native.getcolors(maxcolors=65536) or []), 10, "marker has too many colors")
        self.assertGreaterEqual(marker_amber_ratio(native), 0.05, "marker needs amber shop accents")
        expected_runtime = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
        self.assertEqual(runtime.tobytes(), expected_runtime.tobytes(), "runtime is not exact 4x nearest")

    def test_market_shop_marker_is_not_reused_guild_or_stall_art(self) -> None:
        market_shop = load_rgba(SOURCE / "market_shop_native.png")
        for existing_id in ["guild_counter", "mira_stall"]:
            with self.subTest(existing_id=existing_id):
                existing = load_rgba(SOURCE / f"{existing_id}_native.png")
                diff = ImageChops.difference(market_shop, existing)
                self.assertIsNotNone(diff.getbbox(), f"market_shop must not reuse {existing_id} art")

    def test_runtime_code_references_only_runtime_marker(self) -> None:
        marker_source = (ROOT / "scripts" / "ui" / "map_point_marker.gd").read_text(encoding="utf-8")
        locations_source = (ROOT / "data" / "locations.json").read_text(encoding="utf-8")
        self.assertIn('"market_shop": "res://assets/textures/daymap/markers/market_shop.png"', marker_source)
        self.assertIn('"marker": "market_shop"', locations_source)
        self.assertNotIn("art_sources/generated_raw", marker_source)
        self.assertNotIn("market_shop_marker_source_v1.png", marker_source)
        self.assertNotIn("art_sources/generated_raw", locations_source)
        self.assertNotIn("market_shop_marker_source_v1.png", locations_source)

    def test_contact_sheet_exists(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing contact sheet")
        self.assertGreater(CONTACT_SHEET.stat().st_size, 0, "contact sheet is empty")


if __name__ == "__main__":
    unittest.main(verbosity=2)
