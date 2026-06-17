from pathlib import Path
import json
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_sources" / "generated_raw" / "night_settlement"
SOURCE = ROOT / "assets" / "source" / "ui" / "night_settlement"
RUNTIME = ROOT / "assets" / "textures" / "ui" / "night_settlement"
MANIFEST = SOURCE / "night_settlement_manifest.json"
EXPORTER = ROOT / "scripts" / "tools" / "export_night_settlement_assets.py"
CONTACT_SHEET = ROOT / "docs" / "art" / "night_settlement_contact_sheet.png"

BACKDROP_NATIVE_SIZE = (320, 180)
BACKDROP_RUNTIME_SIZE = (1280, 720)
PANEL_STATS_NATIVE_SIZE = (120, 66)
PANEL_STATS_RUNTIME_SIZE = (480, 264)
PANEL_FATES_NATIVE_SIZE = (120, 66)
PANEL_FATES_RUNTIME_SIZE = (480, 264)
BUTTON_NATIVE_SIZE = (34, 24)
BUTTON_RUNTIME_SIZE = (136, 96)
ICON_NATIVE_SIZE = (14, 14)
ICON_RUNTIME_SIZE = (56, 56)
STATES = ("normal", "hover", "pressed")
ICONS = ("gold", "reputation", "guests", "success", "failed", "fate")


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixel_count(image: Image.Image) -> int:
    return sum(image.getchannel("A").histogram()[1:])


def assert_exact_native_export(
    test_case: unittest.TestCase,
    native_path: Path,
    runtime_path: Path,
    native_size: tuple[int, int],
    runtime_size: tuple[int, int],
) -> Image.Image:
    test_case.assertTrue(native_path.exists(), f"{native_path}: missing native source")
    test_case.assertTrue(runtime_path.exists(), f"{runtime_path}: missing runtime texture")
    native = load_rgba(native_path)
    runtime = load_rgba(runtime_path)
    test_case.assertEqual(native.size, native_size, f"{native_path.name}: wrong native size")
    test_case.assertEqual(runtime.size, runtime_size, f"{runtime_path.name}: wrong runtime size")
    test_case.assertGreater(visible_pixel_count(native), 0, f"{native_path.name}: transparent or empty")
    expected = native.resize(runtime_size, Image.Resampling.NEAREST)
    test_case.assertEqual(runtime.tobytes(), expected.tobytes(), f"{runtime_path.name}: not exact nearest export")
    return native


def alpha_bbox_size(image: Image.Image) -> tuple[int, int]:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        return (0, 0)
    left, top, right, bottom = bbox
    return (right - left, bottom - top)


class NightSettlementAssetPipelineTest(unittest.TestCase):
    def test_raw_ai_sources_and_prompts_are_retained(self) -> None:
        required = [
            RAW / "night_settlement_backdrop_prompt_v5.txt",
            RAW / "night_settlement_backdrop_source_v5.png",
            RAW / "night_settlement_controls_prompt_v1.txt",
            RAW / "night_settlement_controls_source_v1.png",
            RAW / "night_settlement_stats_panel_prompt_v3.txt",
            RAW / "night_settlement_stats_panel_source_v3.png",
            MANIFEST,
        ]
        for path in required:
            self.assertTrue(path.exists(), f"{path}: required source contract missing")
            self.assertGreater(path.stat().st_size, 0, f"{path}: empty source contract")
        self.assertGreaterEqual(load_rgba(RAW / "night_settlement_backdrop_source_v5.png").width, 1280)
        self.assertGreaterEqual(load_rgba(RAW / "night_settlement_backdrop_source_v5.png").height, 720)
        self.assertGreaterEqual(load_rgba(RAW / "night_settlement_controls_source_v1.png").width, 1024)
        self.assertGreaterEqual(load_rgba(RAW / "night_settlement_controls_source_v1.png").height, 1024)
        self.assertGreaterEqual(load_rgba(RAW / "night_settlement_stats_panel_source_v3.png").width, 1024)
        self.assertGreaterEqual(load_rgba(RAW / "night_settlement_stats_panel_source_v3.png").height, 720)

    def test_manifest_declares_fixed_crops_safe_areas_and_runtime_paths(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["id"], "night_settlement_v1")
        self.assertEqual(manifest["backdrop"]["source"], "art_sources/generated_raw/night_settlement/night_settlement_backdrop_source_v5.png")
        self.assertEqual(manifest["backdrop"]["prompt"], "art_sources/generated_raw/night_settlement/night_settlement_backdrop_prompt_v5.txt")
        self.assertEqual(manifest["backdrop"]["runtime"], "assets/textures/ui/night_settlement/night_settlement_backdrop.png")
        self.assertEqual(manifest["backdrop"]["native_size"], list(BACKDROP_NATIVE_SIZE))
        self.assertEqual(manifest["backdrop"]["runtime_size"], list(BACKDROP_RUNTIME_SIZE))
        self.assertEqual(
            manifest["text_safe_zones_native"],
            {
                "title": [88, 11, 232, 27],
                "guest_lineup": [12, 34, 232, 104],
                "score": [96, 106, 224, 164],
                "continue": [276, 152, 314, 174],
            },
        )
        self.assertEqual(set(manifest["panels"].keys()), {"stats", "fates"})
        self.assertEqual(
            manifest["panels"]["stats"]["source"],
            "art_sources/generated_raw/night_settlement/night_settlement_stats_panel_source_v3.png",
            "stats panel must use its own neutral AI-generated source instead of duplicating the fate panel or baking labels",
        )
        self.assertNotEqual(
            manifest["panels"]["stats"]["runtime"],
            manifest["panels"]["fates"]["runtime"],
            "stats and fates panels must remain separate runtime assets",
        )
        self.assertEqual(set(manifest["icons"].keys()), set(ICONS))
        self.assertEqual(set(manifest["continue_button"]["states"].keys()), set(STATES))
        for state, entry in manifest["continue_button"]["states"].items():
            self.assertEqual(entry["runtime"], f"assets/textures/ui/night_settlement/night_settlement_continue_{state}.png")
            self.assertEqual(len(entry["source_rect"]), 4)

    def test_exporter_derives_from_ai_sources_not_procedural_decoration(self) -> None:
        source = EXPORTER.read_text(encoding="utf-8")
        self.assertIn("night_settlement_backdrop_source_v5.png", source)
        self.assertIn("night_settlement_controls_source_v1.png", source)
        self.assertIn("night_settlement_stats_panel_source_v3.png", source)
        self.assertIn("night_settlement_manifest.json", source)
        self.assertNotIn("ImageDraw", source)
        self.assertNotIn("ImageEnhance", source)
        self.assertNotIn("fill_rect", source)
        self.assertNotIn("set_pixel", source)
        self.assertNotIn("lift_silhouette_stage_band", source)
        self.assertNotIn("SILHOUETTE_STAGE_BAND_NATIVE", source)

    def test_backdrop_is_exact_native_export_and_has_readable_value_range(self) -> None:
        native = assert_exact_native_export(
            self,
            SOURCE / "night_settlement_backdrop_native.png",
            RUNTIME / "night_settlement_backdrop.png",
            BACKDROP_NATIVE_SIZE,
            BACKDROP_RUNTIME_SIZE,
        )
        pixels = list(native.getdata())
        dark_pixels = sum(1 for r, g, b, a in pixels if a >= 220 and r <= 55 and g <= 75 and b <= 80)
        amber_pixels = sum(1 for r, g, b, a in pixels if a >= 220 and r >= 54 and 30 <= g <= 70 and b <= 40 and r > g > b)
        self.assertGreaterEqual(dark_pixels, 18000, "settlement backdrop needs mostly dark closing-tavern values")
        self.assertGreaterEqual(amber_pixels, 90, "settlement backdrop needs sparse candle amber accents")
        queue_backdrop = native.crop((12, 38, 132, 104))
        queue_pixels = [pixel for pixel in queue_backdrop.getdata() if pixel[3] >= 220]
        queue_dark_pixels = sum(1 for r, g, b, _a in queue_pixels if r <= 20 and g <= 28 and b <= 30)
        queue_cool_pixels = sum(
            1
            for r, g, b, _a in queue_pixels
            if 18 <= r <= 70 and 24 <= g <= 90 and 28 <= b <= 98 and b >= r and g >= r
        )
        queue_avg = sum((r + g + b) / 3 for r, g, b, _a in queue_pixels) / len(queue_pixels)
        self.assertGreaterEqual(queue_avg, 22.0, "guest silhouette queue backdrop must not collapse into near-black values")
        self.assertLessEqual(queue_dark_pixels, 4400, "guest silhouette queue backdrop must avoid dark doorway-like masses")
        self.assertGreaterEqual(queue_cool_pixels, 1500, "guest silhouette queue backdrop needs authored cool stone texture behind black figures")

    def test_panels_buttons_and_icons_are_exact_native_exports(self) -> None:
        assert_exact_native_export(
            self,
            SOURCE / "night_settlement_panel_stats_native.png",
            RUNTIME / "night_settlement_panel_stats.png",
            PANEL_STATS_NATIVE_SIZE,
            PANEL_STATS_RUNTIME_SIZE,
        )
        assert_exact_native_export(
            self,
            SOURCE / "night_settlement_panel_fates_native.png",
            RUNTIME / "night_settlement_panel_fates.png",
            PANEL_FATES_NATIVE_SIZE,
            PANEL_FATES_RUNTIME_SIZE,
        )
        stats_bytes = (RUNTIME / "night_settlement_panel_stats.png").read_bytes()
        fates_bytes = (RUNTIME / "night_settlement_panel_fates.png").read_bytes()
        self.assertNotEqual(stats_bytes, fates_bytes, "stats panel art should not be a duplicate of fates panel art")
        bbox_sizes: set[tuple[int, int]] = set()
        previous_bytes: bytes | None = None
        for state in STATES:
            native = assert_exact_native_export(
                self,
                SOURCE / f"night_settlement_continue_{state}_native.png",
                RUNTIME / f"night_settlement_continue_{state}.png",
                BUTTON_NATIVE_SIZE,
                BUTTON_RUNTIME_SIZE,
            )
            bbox_sizes.add(alpha_bbox_size(native))
            if previous_bytes is not None:
                self.assertNotEqual(native.tobytes(), previous_bytes, f"continue {state} matches previous state")
            previous_bytes = native.tobytes()
        self.assertEqual(len(bbox_sizes), 1, "continue button alpha bounds must not shift between states")
        for icon in ICONS:
            assert_exact_native_export(
                self,
                SOURCE / f"night_settlement_icon_{icon}_native.png",
                RUNTIME / f"night_settlement_icon_{icon}.png",
                ICON_NATIVE_SIZE,
                ICON_RUNTIME_SIZE,
            )

    def test_contact_sheet_exists(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), "night settlement contact sheet must be exported")
        self.assertGreater(CONTACT_SHEET.stat().st_size, 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
