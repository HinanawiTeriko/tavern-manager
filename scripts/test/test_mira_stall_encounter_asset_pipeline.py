from __future__ import annotations

import json
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_sources" / "generated_raw" / "mira_stall_encounter"
RAW_SOURCE = RAW / "mira_stall_encounter_source_v1.png"
PROMPT = RAW / "mira_stall_encounter_prompt_v1.txt"
SOURCE = ROOT / "assets" / "source" / "encounters" / "mira_stall"
MANIFEST = SOURCE / "mira_stall_encounter_manifest.json"
NATIVE = SOURCE / "mira_stall_bg_native.png"
RUNTIME = ROOT / "assets" / "textures" / "encounters" / "mira_stall" / "mira_stall_bg.png"
CONTACT_SHEET = ROOT / "docs" / "art" / "mira_stall_encounter_contact_sheet.png"
EXPORTER = ROOT / "scripts" / "tools" / "export_mira_stall_encounter_assets.py"
NATIVE_SIZE = (320, 180)
RUNTIME_SIZE = (1280, 720)
SCALE = 4


def load_rgba(path: Path) -> Image.Image:
    if not path.exists():
        raise AssertionError(f"{path}: missing image")
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    rgba = image.convert("RGBA")
    if hasattr(rgba, "get_flattened_data"):
        return list(rgba.get_flattened_data())
    return list(rgba.getdata())


def visible_color_count(image: Image.Image) -> int:
    return len({pixel for pixel in pixels(image) if pixel[3] > 0})


def edge_change_ratio(image: Image.Image) -> float:
    rgb = image.convert("RGB")
    data = rgb.load()
    changes = 0
    total = 0
    for y in range(rgb.height):
        for x in range(rgb.width - 1):
            total += 1
            changes += data[x, y] != data[x + 1, y]
    for y in range(rgb.height - 1):
        for x in range(rgb.width):
            total += 1
            changes += data[x, y] != data[x, y + 1]
    return changes / total


class MiraStallEncounterAssetPipelineTest(unittest.TestCase):
    def test_raw_source_and_prompt_are_retained(self) -> None:
        self.assertTrue(RAW_SOURCE.exists(), f"{RAW_SOURCE}: missing generated source")
        self.assertGreater(RAW_SOURCE.stat().st_size, 0, "generated source is empty")
        self.assertTrue(PROMPT.exists(), f"{PROMPT}: missing prompt record")
        prompt = PROMPT.read_text(encoding="utf-8").lower()
        for phrase in ("mira stall", "native-pixel", "no text"):
            self.assertIn(phrase, prompt)
        self.assertIn("no later procedural drawing", prompt)
        self.assertNotIn("reinforces", prompt)

    def test_exporter_does_not_author_background_geometry(self) -> None:
        self.assertTrue(EXPORTER.exists(), f"{EXPORTER}: missing exporter")
        source = EXPORTER.read_text(encoding="utf-8")
        forbidden_tokens = (
            "ImageDraw",
            "draw_stall",
            ".rectangle(",
            ".polygon(",
            ".line(",
            ".ellipse(",
            ".arc(",
        )
        for token in forbidden_tokens:
            self.assertNotIn(token, source, f"exporter must not procedurally author stall art with {token}")

    def test_manifest_records_runtime_contract(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["id"], "mira_stall_encounter_background")
        self.assertEqual(manifest["source"], "art_sources/generated_raw/mira_stall_encounter/mira_stall_encounter_source_v1.png")
        self.assertEqual(manifest["native"], "assets/source/encounters/mira_stall/mira_stall_bg_native.png")
        self.assertEqual(manifest["runtime"], "assets/textures/encounters/mira_stall/mira_stall_bg.png")
        self.assertEqual(manifest["native_size"], list(NATIVE_SIZE))
        self.assertEqual(manifest["runtime_size"], list(RUNTIME_SIZE))
        self.assertEqual(manifest["scale"], SCALE)
        self.assertEqual(manifest["safe_area"], [0, 0, NATIVE_SIZE[0], NATIVE_SIZE[1]])
        self.assertIn("no procedural geometry", manifest["pipeline_note"].lower())
        self.assertIn("DialogueManager", manifest["intended_godot_use"])

    def test_native_runtime_and_contact_sheet_exist(self) -> None:
        native = load_rgba(NATIVE)
        runtime = load_rgba(RUNTIME)
        sheet = load_rgba(CONTACT_SHEET)
        self.assertEqual(native.size, NATIVE_SIZE)
        self.assertEqual(runtime.size, RUNTIME_SIZE)
        self.assertGreater(sheet.width, 0)
        self.assertGreater(sheet.height, 0)

    def test_runtime_is_exact_four_x_nearest_export(self) -> None:
        native = load_rgba(NATIVE)
        runtime = load_rgba(RUNTIME)
        expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
        self.assertEqual(runtime.tobytes(), expected.tobytes(), "runtime must be exact 4x nearest export")

    def test_native_pixel_style_bounds(self) -> None:
        native = load_rgba(NATIVE)
        data = pixels(native)
        dark = sum(1 for r, g, b, a in data if a == 255 and max(r, g, b) <= 66)
        cool = sum(1 for r, g, b, a in data if a == 255 and b >= 18 and g >= 16 and b >= r * 0.58)
        amber = sum(1 for r, g, b, a in data if a == 255 and r >= 82 and g >= 34 and b <= 66 and r >= b * 1.35)
        bright = sum(1 for r, g, b, a in data if a == 255 and max(r, g, b) >= 218)
        self.assertGreaterEqual(dark, 12_000, "stall background needs enough dark dungeon market mass")
        self.assertGreaterEqual(cool, 1_600, "stall background needs cool stone/shadow depth")
        self.assertGreaterEqual(amber, 260, "stall background needs candle/lantern accents")
        self.assertLessEqual(bright, 180, "stall background should avoid bright noisy pixels")
        self.assertLessEqual(visible_color_count(native), 96, "native palette should stay bounded")
        self.assertGreaterEqual(edge_change_ratio(native), 0.045, "native image is likely too smooth")


if __name__ == "__main__":
    unittest.main(verbosity=2)
