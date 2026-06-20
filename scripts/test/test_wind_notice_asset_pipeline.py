from __future__ import annotations

import json
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = ROOT / "art_sources" / "generated_raw" / "wind_notice"
RAW_SOURCE = RAW_DIR / "wind_notice_source_v1.png"
PROMPT = RAW_DIR / "wind_notice_prompt_v1.txt"
EXPORTER = ROOT / "scripts" / "tools" / "export_wind_notice_assets.py"
SOURCE = ROOT / "assets" / "source" / "ui" / "wind_notice"
RUNTIME = ROOT / "assets" / "textures" / "ui" / "wind_notice"
MANIFEST = SOURCE / "wind_notice_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "ui" / "previews" / "wind_notice_contact_sheet.png"
SCALE = 4

ASSETS = {
    "wind_notice_panel": ((150, 60), (600, 240)),
    "wind_notice_icon": ((24, 24), (96, 96)),
    "wind_notice_stamp": ((32, 32), (128, 128)),
    "wind_notice_spark": ((24, 24), (96, 96)),
}

MIN_VISIBLE_PIXELS = {
    "wind_notice_panel": 1100,
    "wind_notice_icon": 90,
    "wind_notice_stamp": 120,
    "wind_notice_spark": 32,
}


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    return [
        (red, green, blue, alpha)
        for red, green, blue, alpha in image.get_flattened_data()
        if alpha > 0
    ]


def red_residue_pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    return [
        (red, green, blue, alpha)
        for red, green, blue, alpha in visible_pixels(image)
        if alpha >= 160
        and red >= 90
        and red > green * 1.55
        and red > blue * 1.25
        and green <= 90
        and blue <= 90
    ]


class WindNoticeAssetPipelineTest(unittest.TestCase):
    def test_raw_imagegen_source_and_prompt_are_retained(self) -> None:
        self.assertTrue(RAW_SOURCE.exists(), f"{RAW_SOURCE}: missing extracted imagegen source")
        self.assertGreater(RAW_SOURCE.stat().st_size, 0, "wind notice raw source is empty")
        self.assertTrue(PROMPT.exists(), f"{PROMPT}: missing prompt record")
        prompt = PROMPT.read_text(encoding="utf-8")
        self.assertIn("wind-rumor notice", prompt)
        self.assertIn("no readable text", prompt.lower())

    def test_exporter_uses_fixed_contract_rectangles(self) -> None:
        self.assertTrue(EXPORTER.exists(), f"{EXPORTER}: missing wind notice exporter")
        source = EXPORTER.read_text(encoding="utf-8")
        self.assertIn("SOURCE_RECTS", source)
        self.assertNotIn("getbbox()", source, "wind notice crops must come from fixed rectangles, not alpha guessing")
        self.assertNotIn("connected", source.lower(), "wind notice crops must not use connected component guessing")

    def test_native_and_runtime_assets_are_exact_nearest_exports(self) -> None:
        for asset_id, (native_size, runtime_size) in ASSETS.items():
            with self.subTest(asset_id=asset_id):
                native_path = SOURCE / f"{asset_id}_native.png"
                runtime_path = RUNTIME / f"{asset_id}.png"
                self.assertTrue(native_path.exists(), f"{native_path}: missing native asset")
                self.assertTrue(runtime_path.exists(), f"{runtime_path}: missing runtime asset")
                native = load_rgba(native_path)
                runtime = load_rgba(runtime_path)
                self.assertEqual(native.size, native_size)
                self.assertEqual(runtime.size, runtime_size)
                self.assertEqual(
                    runtime.tobytes(),
                    native.resize(runtime_size, Image.Resampling.NEAREST).tobytes(),
                    f"{asset_id}: runtime must be exact {SCALE}x nearest export",
                )
                self.assertGreaterEqual(
                    len(visible_pixels(native)),
                    MIN_VISIBLE_PIXELS[asset_id],
                    f"{asset_id}: has too few visible native pixels",
                )

    def test_panel_reads_as_dark_tavern_notice_with_amber_reward_accent(self) -> None:
        panel = load_rgba(SOURCE / "wind_notice_panel_native.png")
        pixels = visible_pixels(panel)
        dark_pixels = sum(1 for r, g, b, a in pixels if a >= 180 and r <= 55 and 15 <= g <= 95 and 15 <= b <= 100)
        parchment_pixels = sum(1 for r, g, b, a in pixels if a >= 180 and 85 <= r <= 240 and 45 <= g <= 190 and 20 <= b <= 150 and r >= g)
        amber_pixels = sum(1 for r, g, b, a in pixels if a >= 160 and r >= 130 and 45 <= g <= 190 and b <= 110)
        self.assertGreaterEqual(dark_pixels, 420, "wind notice needs dark teal tavern backing")
        self.assertGreaterEqual(parchment_pixels, 1100, "wind notice needs a readable parchment body")
        self.assertGreaterEqual(amber_pixels, 28, "wind notice needs amber reward accents")

    def test_runtime_assets_do_not_keep_magenta_or_purple_fringe(self) -> None:
        for asset_id in ["wind_notice_panel", "wind_notice_stamp"]:
            with self.subTest(asset_id=asset_id):
                native = load_rgba(SOURCE / f"{asset_id}_native.png")
                bad_pixels = [
                    (r, g, b, a)
                    for r, g, b, a in visible_pixels(native)
                    if a >= 80 and (
                        (r >= 80 and b >= 45 and g <= 65 and b >= g * 1.25 and r >= g * 1.2 and abs(r - b) <= 130)
                        or (r >= 120 and b >= 110 and g <= 40)
                        or (b >= 24 and g <= 12 and b > r * 1.25 and r <= 70)
                    )
                ]
                self.assertEqual(
                    len(bad_pixels),
                    0,
                    f"{asset_id}: purple/magenta fringe remains in normalized art",
                )

    def test_daymap_notice_panel_and_icon_do_not_keep_red_source_residue(self) -> None:
        for asset_id in ["wind_notice_panel", "wind_notice_icon"]:
            with self.subTest(asset_id=asset_id):
                native = load_rgba(SOURCE / f"{asset_id}_native.png")
                runtime = load_rgba(RUNTIME / f"{asset_id}.png")
                self.assertEqual(
                    len(red_residue_pixels(native)),
                    0,
                    f"{asset_id}: native art retains red source residue",
                )
                self.assertEqual(
                    len(red_residue_pixels(runtime)),
                    0,
                    f"{asset_id}: runtime art magnifies red source residue",
                )

    def test_manifest_records_runtime_contract(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest.get("id"), "wind_notice")
        self.assertEqual(manifest.get("raw_source"), RAW_SOURCE.relative_to(ROOT).as_posix())
        self.assertEqual(manifest.get("prompt"), PROMPT.relative_to(ROOT).as_posix())
        self.assertEqual(manifest.get("scale"), SCALE)
        assets = manifest.get("assets", {})
        self.assertEqual(set(assets.keys()), set(ASSETS.keys()))
        for asset_id, (native_size, runtime_size) in ASSETS.items():
            with self.subTest(asset_id=asset_id):
                entry = assets[asset_id]
                self.assertEqual(entry.get("native_size"), list(native_size))
                self.assertEqual(entry.get("runtime_size"), list(runtime_size))
                self.assertEqual(entry.get("native_file"), f"assets/source/ui/wind_notice/{asset_id}_native.png")
                self.assertEqual(entry.get("runtime_file"), f"assets/textures/ui/wind_notice/{asset_id}.png")
                self.assertEqual(len(entry.get("source_rect", [])), 4)
                self.assertIn("WindNotice", entry.get("intended_godot_use", ""))

    def test_contact_sheet_exists_for_visual_review(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing contact sheet")
        self.assertGreater(CONTACT_SHEET.stat().st_size, 0, "wind notice contact sheet is empty")


if __name__ == "__main__":
    unittest.main(verbosity=2)
