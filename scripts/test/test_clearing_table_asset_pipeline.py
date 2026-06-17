from __future__ import annotations

import json
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = ROOT / "art_sources" / "generated_raw" / "clearing_table"
RAW_BACKGROUND = RAW_DIR / "clearing_table_background_source_v2.png"
RAW_BACKGROUND_PROMPT = RAW_DIR / "clearing_table_background_prompt_v2.txt"
RAW_PROPS = RAW_DIR / "clearing_table_props_source_v1.png"
RAW_PROPS_PROMPT = RAW_DIR / "clearing_table_props_prompt_v1.txt"
RAW_BLACKTOOTH_BATCH = RAW_DIR / "clearing_blacktooth_batch_source_v1.png"
RAW_BLACKTOOTH_BATCH_PROMPT = RAW_DIR / "clearing_blacktooth_batch_prompt_v1.txt"
RAW_STAMP_STATION = RAW_DIR / "clearing_table_stamp_station_source_v1.png"
RAW_STAMP_STATION_PROMPT = RAW_DIR / "clearing_table_stamp_station_prompt_v1.txt"
SOURCE = ROOT / "assets" / "source" / "investigation" / "clearing_table"
RUNTIME = ROOT / "assets" / "ui" / "generated" / "investigation" / "clearing_table"
MANIFEST = SOURCE / "clearing_table_art_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "clearing_table_investigation_contact_sheet.png"
SCENE_PREVIEW = ROOT / "docs" / "art" / "clearing_table_investigation_scene_preview.png"
SCALE = 4
BACKGROUND_NATIVE_SIZE = (320, 180)
BACKGROUND_RUNTIME_SIZE = (1280, 720)
BUTTON_NATIVE_SIZE = (70, 25)
BUTTON_RUNTIME_SIZE = (280, 100)
EXPECTED_ITEMS = {
    "clearing_ryan_name": (56, 26),
    "clearing_north_mine": (56, 36),
    "clearing_unreturned": (44, 28),
    "clearing_payout_slip": (42, 28),
    "clearing_toby_name": (56, 26),
    "clearing_blacktooth_batch": (56, 36),
    "clearing_high_pay": (44, 28),
    "clearing_temp_name": (56, 26),
    "clearing_mira_name": (44, 28),
    "clearing_supply_contract": (42, 48),
    "clearing_deposit_token": (34, 42),
}
EXPECTED_RUNTIME_ITEMS = {
    item_id: (size[0] * SCALE, size[1] * SCALE)
    for item_id, size in EXPECTED_ITEMS.items()
}
EXPECTED_STAMP_STATION_PARTS = {
    "stamp_station_base": (82, 70),
    "stamp_station_handle": (34, 54),
    "stamp_station_head": (42, 32),
    "stamp_station_imprint": (32, 20),
    "stamp_station_socket_idle": (60, 36),
    "stamp_station_socket_ready": (60, 36),
    "stamp_station_socket_blocked": (60, 36),
    "stamp_station_pin": (28, 20),
}
EXPECTED_RUNTIME_STAMP_STATION_PARTS = {
    part_id: (size[0] * SCALE, size[1] * SCALE)
    for part_id, size in EXPECTED_STAMP_STATION_PARTS.items()
}
EXPECTED_BUTTON_STATES = ("normal", "hover", "pressed")


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    rgba = image.convert("RGBA")
    if hasattr(rgba, "get_flattened_data"):
        return list(rgba.get_flattened_data())
    return list(rgba.getdata())


def visible_pixel_count(image: Image.Image) -> int:
    alpha = image.getchannel("A")
    return sum(alpha.histogram()[1:])


def color_count(image: Image.Image) -> int:
    colors = image.convert("RGBA").getcolors(maxcolors=65536)
    return len(colors) if colors is not None else 65536


def chroma_fringe_pixels(image: Image.Image) -> int:
    count = 0
    for red, green, blue, alpha in pixels(image):
        if alpha == 0:
            continue
        if red >= 12 and blue >= 12 and blue >= red * 0.70 and red >= blue * 0.50 and green <= min(red, blue) * 0.45:
            count += 1
    return count


def bright_pixel_count(image: Image.Image) -> int:
    return sum(1 for red, green, blue, alpha in pixels(image) if alpha > 0 and max(red, green, blue) >= 212)


class ClearingTableAssetPipelineTest(unittest.TestCase):
    def test_raw_generated_sources_and_prompts_exist(self) -> None:
        for path in (RAW_BACKGROUND, RAW_PROPS, RAW_BLACKTOOTH_BATCH, RAW_STAMP_STATION):
            self.assertTrue(path.exists(), f"{path}: missing raw generated source")
            self.assertGreater(path.stat().st_size, 10_000, f"{path}: raw source is unexpectedly small")

        prompt_expectations = {
            RAW_BACKGROUND_PROMPT: (
                "clean guild clearing table background",
                "no stamp press machine",
                "blank empty mounting area",
                "no readable text",
            ),
            RAW_PROPS_PROMPT: (
                "strict 4 by 4 grid",
                "flat solid #ff00ff",
                "no readable text",
                "no labels",
            ),
            RAW_BLACKTOOTH_BATCH_PROMPT: (
                "blacktooth transfer ledger case card",
                "flat solid #ff00ff",
                "single isolated prop",
                "no readable text",
            ),
            RAW_STAMP_STATION_PROMPT: (
                "manual accounting stamp press machine",
                "strict 4 columns by 2 rows",
                "flat solid #ff00ff",
                "no readable text",
            ),
        }
        for prompt_path, phrases in prompt_expectations.items():
            self.assertTrue(prompt_path.exists(), f"{prompt_path}: missing prompt record")
            prompt = prompt_path.read_text(encoding="utf-8").lower()
            for phrase in phrases:
                self.assertIn(phrase, prompt)

    def test_manifest_records_all_runtime_contracts(self) -> None:
        self.assertTrue(MANIFEST.exists(), "clearing table art manifest is missing")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest.get("scale"), SCALE)
        self.assertEqual(manifest.get("style_profile"), "clearing_table_scene_v2")

        background = manifest["background"]
        self.assertEqual(background["source"], "art_sources/generated_raw/clearing_table/clearing_table_background_source_v2.png")
        self.assertEqual(background["native"], "assets/source/investigation/clearing_table/background_native.png")
        self.assertEqual(background["runtime"], "assets/ui/generated/investigation/clearing_table/background.png")
        self.assertEqual(background["native_size"], list(BACKGROUND_NATIVE_SIZE))
        self.assertEqual(background["runtime_size"], list(BACKGROUND_RUNTIME_SIZE))
        self.assertEqual(background["safe_area"], [0, 0, 320, 180])

        entries = {entry["id"]: entry for entry in manifest["items"]}
        self.assertEqual(set(EXPECTED_ITEMS), set(entries))
        source_sizes: dict[str, tuple[int, int]] = {}
        for item_id, native_size in EXPECTED_ITEMS.items():
            entry = entries[item_id]
            if item_id == "clearing_blacktooth_batch":
                self.assertEqual(entry["source"], "art_sources/generated_raw/clearing_table/clearing_blacktooth_batch_source_v1.png")
                self.assertEqual(entry["reference"], "assets/source/investigation/clearing_table/reference/clearing_blacktooth_batch_reference_v1.png")
                north_entry = entries["clearing_north_mine"]
                self.assertNotEqual(entry["source"], north_entry["source"],
                    "Blacktooth batch card must not reuse Ryan's north-mine source art")
                self.assertNotEqual(entry["source_rect"], north_entry["source_rect"],
                    "Blacktooth batch card must not reuse Ryan's north-mine crop")
            else:
                self.assertEqual(entry["source"], "art_sources/generated_raw/clearing_table/clearing_table_props_source_v1.png")
            self.assertEqual(entry["native"], f"assets/source/investigation/clearing_table/items/{item_id}_native.png")
            self.assertEqual(entry["runtime"], f"assets/ui/generated/investigation/clearing_table/items/{item_id}.png")
            self.assertEqual(entry["native_size"], list(native_size), f"{item_id}: wrong native size")
            self.assertEqual(entry["runtime_size"], list(EXPECTED_RUNTIME_ITEMS[item_id]), f"{item_id}: wrong runtime size")
            self.assertEqual(len(entry.get("source_rect", [])), 4, f"{item_id}: source_rect must be explicit")
            if entry["source"] not in source_sizes:
                with Image.open(ROOT / entry["source"]) as source:
                    source_sizes[entry["source"]] = source.size
            source_size = source_sizes[entry["source"]]
            x, y, width, height = entry["source_rect"]
            self.assertGreater(width, 0, f"{item_id}: source_rect width must be positive")
            self.assertGreater(height, 0, f"{item_id}: source_rect height must be positive")
            self.assertLessEqual(x + width, source_size[0], f"{item_id}: source_rect must fit source width")
            self.assertLessEqual(y + height, source_size[1], f"{item_id}: source_rect must fit source height")
            self.assertEqual(len(entry.get("safe_area", [])), 4, f"{item_id}: safe_area must be explicit")
            self.assertIn("intended_godot_use", entry)

        station = manifest["stamp_station"]
        self.assertEqual(station["source"], "art_sources/generated_raw/clearing_table/clearing_table_stamp_station_source_v1.png")
        station_entries = {entry["id"]: entry for entry in station["parts"]}
        self.assertEqual(set(EXPECTED_STAMP_STATION_PARTS), set(station_entries))
        with Image.open(RAW_STAMP_STATION) as source:
            station_source_size = source.size
        for part_id, native_size in EXPECTED_STAMP_STATION_PARTS.items():
            entry = station_entries[part_id]
            self.assertEqual(entry["source"], "art_sources/generated_raw/clearing_table/clearing_table_stamp_station_source_v1.png")
            self.assertEqual(entry["native"], f"assets/source/investigation/clearing_table/stamp_station/{part_id}_native.png")
            self.assertEqual(entry["runtime"], f"assets/ui/generated/investigation/clearing_table/stamp_station/{part_id}.png")
            self.assertEqual(entry["native_size"], list(native_size), f"{part_id}: wrong native size")
            self.assertEqual(entry["runtime_size"], list(EXPECTED_RUNTIME_STAMP_STATION_PARTS[part_id]), f"{part_id}: wrong runtime size")
            self.assertEqual(len(entry.get("source_rect", [])), 4, f"{part_id}: source_rect must be explicit")
            x, y, width, height = entry["source_rect"]
            self.assertGreater(width, 0, f"{part_id}: source_rect width must be positive")
            self.assertGreater(height, 0, f"{part_id}: source_rect height must be positive")
            self.assertLessEqual(x + width, station_source_size[0], f"{part_id}: source_rect must fit source width")
            self.assertLessEqual(y + height, station_source_size[1], f"{part_id}: source_rect must fit source height")
            self.assertEqual(len(entry.get("safe_area", [])), 4, f"{part_id}: safe_area must be explicit")
            self.assertIn("intended_godot_use", entry)

        button_entries = {entry["state"]: entry for entry in manifest["leave_button"]["states"]}
        self.assertEqual(set(EXPECTED_BUTTON_STATES), set(button_entries))
        for state in EXPECTED_BUTTON_STATES:
            entry = button_entries[state]
            self.assertEqual(entry["native_size"], list(BUTTON_NATIVE_SIZE))
            self.assertEqual(entry["runtime_size"], list(BUTTON_RUNTIME_SIZE))
            self.assertEqual(entry["native"], f"assets/source/investigation/clearing_table/ui/leave_button_{state}_native.png")
            self.assertEqual(entry["runtime"], f"assets/ui/generated/investigation/clearing_table/ui/leave_button_{state}.png")

    def test_native_runtime_and_review_outputs_exist(self) -> None:
        required = [
            SOURCE / "reference" / "clearing_table_background_reference_v2.png",
            SOURCE / "reference" / "clearing_table_props_reference_v1.png",
            SOURCE / "reference" / "clearing_table_stamp_station_reference_v1.png",
            SOURCE / "background_native.png",
            RUNTIME / "background.png",
            CONTACT_SHEET,
            SCENE_PREVIEW,
        ]
        for item_id in EXPECTED_ITEMS:
            required.append(SOURCE / "items" / f"{item_id}_native.png")
            required.append(RUNTIME / "items" / f"{item_id}.png")
        for part_id in EXPECTED_STAMP_STATION_PARTS:
            required.append(SOURCE / "stamp_station" / f"{part_id}_native.png")
            required.append(RUNTIME / "stamp_station" / f"{part_id}.png")
        for state in EXPECTED_BUTTON_STATES:
            required.append(SOURCE / "ui" / f"leave_button_{state}_native.png")
            required.append(RUNTIME / "ui" / f"leave_button_{state}.png")
        for path in required:
            self.assertTrue(path.exists(), f"{path}: missing output")
            self.assertGreater(path.stat().st_size, 0, f"{path}: empty output")

        self.assertEqual(load_rgba(SOURCE / "background_native.png").size, BACKGROUND_NATIVE_SIZE)
        self.assertEqual(load_rgba(RUNTIME / "background.png").size, BACKGROUND_RUNTIME_SIZE)
        self.assertEqual(load_rgba(SCENE_PREVIEW).size, BACKGROUND_RUNTIME_SIZE)
        contact = load_rgba(CONTACT_SHEET)
        self.assertGreaterEqual(contact.width, 900, "contact sheet is too narrow for review")
        self.assertGreaterEqual(contact.height, 650, "contact sheet is too short for review")

    def test_runtime_outputs_are_exact_four_x_nearest_exports(self) -> None:
        pairs: list[tuple[Path, Path, tuple[int, int]]] = [
            (SOURCE / "background_native.png", RUNTIME / "background.png", BACKGROUND_RUNTIME_SIZE),
        ]
        for item_id, runtime_size in EXPECTED_RUNTIME_ITEMS.items():
            pairs.append((SOURCE / "items" / f"{item_id}_native.png", RUNTIME / "items" / f"{item_id}.png", runtime_size))
        for part_id, runtime_size in EXPECTED_RUNTIME_STAMP_STATION_PARTS.items():
            pairs.append((SOURCE / "stamp_station" / f"{part_id}_native.png", RUNTIME / "stamp_station" / f"{part_id}.png", runtime_size))
        for state in EXPECTED_BUTTON_STATES:
            pairs.append((SOURCE / "ui" / f"leave_button_{state}_native.png", RUNTIME / "ui" / f"leave_button_{state}.png", BUTTON_RUNTIME_SIZE))

        for native_path, runtime_path, runtime_size in pairs:
            native = load_rgba(native_path)
            runtime = load_rgba(runtime_path)
            expected = native.resize(runtime_size, Image.Resampling.NEAREST)
            self.assertEqual(runtime.tobytes(), expected.tobytes(), f"{runtime_path.name}: runtime is not exact nearest-neighbor export")

    def test_background_palette_is_dark_accounting_table_pixel_art(self) -> None:
        native = load_rgba(SOURCE / "background_native.png")
        data = pixels(native)
        dark = sum(1 for red, green, blue, alpha in data if alpha == 255 and max(red, green, blue) <= 76)
        cold = sum(1 for red, green, blue, alpha in data if alpha == 255 and blue >= red * 0.50 and green >= 18)
        amber = sum(1 for red, green, blue, alpha in data if alpha == 255 and red >= 52 and green >= 28 and blue <= 56 and red >= blue * 1.15)
        bright = sum(1 for red, green, blue, alpha in data if alpha == 255 and max(red, green, blue) >= 220)
        self.assertGreaterEqual(dark, 18_000, "background needs enough dark table mass")
        self.assertGreaterEqual(cold, 3_000, "background needs cold stone/metal integration colors")
        self.assertGreaterEqual(amber, 500, "background needs small muted brass/candle accents")
        self.assertLessEqual(amber, 5_500, "warm brass should not flood the whole scene")
        self.assertLessEqual(bright, 100, "background should avoid bright noisy pixels")
        self.assertGreaterEqual(color_count(native), 36, "background should preserve authored color nuance")

    def test_item_and_button_alpha_contracts(self) -> None:
        for item_id, native_size in EXPECTED_ITEMS.items():
            native = load_rgba(SOURCE / "items" / f"{item_id}_native.png")
            runtime = load_rgba(RUNTIME / "items" / f"{item_id}.png")
            self.assertEqual(native.size, native_size, f"{item_id}: native size mismatch")
            self.assertEqual(runtime.size, EXPECTED_RUNTIME_ITEMS[item_id], f"{item_id}: runtime size mismatch")
            alpha = native.getchannel("A")
            self.assertEqual(alpha.getextrema()[0], 0, f"{item_id}: native needs transparent pixels")
            self.assertGreater(alpha.getextrema()[1], 0, f"{item_id}: native has no visible pixels")
            self.assertGreaterEqual(visible_pixel_count(native), max(16, native.width * native.height // 8), f"{item_id}: too few visible pixels")
            self.assertIsNotNone(alpha.getbbox(), f"{item_id}: empty alpha bbox")
            self.assertEqual(chroma_fringe_pixels(native), 0, f"{item_id}: visible magenta chroma-key fringe")
            self.assertLessEqual(bright_pixel_count(native), 16, f"{item_id}: too many bright pixels for clearing table scene")

        for state in EXPECTED_BUTTON_STATES:
            native = load_rgba(SOURCE / "ui" / f"leave_button_{state}_native.png")
            self.assertEqual(native.size, BUTTON_NATIVE_SIZE, f"{state}: button native size mismatch")
            alpha = native.getchannel("A")
            self.assertEqual(alpha.getextrema()[0], 0, f"{state}: button native needs transparent edge pixels")
            self.assertGreater(alpha.getextrema()[1], 0, f"{state}: button native has no visible pixels")
            self.assertEqual(chroma_fringe_pixels(native), 0, f"{state}: button has visible magenta fringe")

    def test_stamp_station_alpha_contracts(self) -> None:
        for part_id, native_size in EXPECTED_STAMP_STATION_PARTS.items():
            native = load_rgba(SOURCE / "stamp_station" / f"{part_id}_native.png")
            runtime = load_rgba(RUNTIME / "stamp_station" / f"{part_id}.png")
            self.assertEqual(native.size, native_size, f"{part_id}: native size mismatch")
            self.assertEqual(runtime.size, EXPECTED_RUNTIME_STAMP_STATION_PARTS[part_id], f"{part_id}: runtime size mismatch")
            alpha = native.getchannel("A")
            self.assertEqual(alpha.getextrema()[0], 0, f"{part_id}: native needs transparent pixels")
            self.assertGreater(alpha.getextrema()[1], 0, f"{part_id}: native has no visible pixels")
            self.assertGreaterEqual(visible_pixel_count(native), max(12, native.width * native.height // 10), f"{part_id}: too few visible pixels")
            self.assertIsNotNone(alpha.getbbox(), f"{part_id}: empty alpha bbox")
            self.assertEqual(chroma_fringe_pixels(native), 0, f"{part_id}: visible magenta chroma-key fringe")

    def test_runtime_files_do_not_reference_raw_or_reference_art(self) -> None:
        forbidden = [
            "art_sources/generated_raw/clearing_table",
            "assets/source/investigation/clearing_table/reference",
            "clearing_table_background_source_v2.png",
            "clearing_table_props_source_v1.png",
            "clearing_table_stamp_station_source_v1.png",
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
