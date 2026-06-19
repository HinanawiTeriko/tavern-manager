from __future__ import annotations

import json
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = ROOT / "art_sources" / "generated_raw" / "toby_lodging"
RAW_BACKGROUND = RAW_DIR / "toby_lodging_background_source_v1.png"
RAW_BACKGROUND_PROMPT = RAW_DIR / "toby_lodging_background_prompt_v1.txt"
RAW_ITEMS = RAW_DIR / "toby_lodging_items_source_v1.png"
RAW_ITEMS_PROMPT = RAW_DIR / "toby_lodging_items_prompt_v1.txt"
RAW_FRAGMENTS = RAW_DIR / "toby_lodging_contract_fragments_source_v1.png"
RAW_FRAGMENTS_PROMPT = RAW_DIR / "toby_lodging_contract_fragments_prompt_v1.txt"
RAW_ASSEMBLED = RAW_DIR / "toby_lodging_contract_assembled_source_v1.png"
RAW_ASSEMBLED_PROMPT = RAW_DIR / "toby_lodging_contract_assembled_prompt_v1.txt"
RAW_BUTTON = RAW_DIR / "toby_lodging_leave_button_source_v1.png"
RAW_BUTTON_PROMPT = RAW_DIR / "toby_lodging_leave_button_prompt_v1.txt"
SOURCE = ROOT / "assets" / "source" / "investigation" / "toby_lodging"
RUNTIME = ROOT / "assets" / "ui" / "generated" / "investigation" / "toby_lodging"
MANIFEST = SOURCE / "toby_lodging_art_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "toby_lodging_investigation_contact_sheet.png"
SCENE_PREVIEW = ROOT / "docs" / "art" / "toby_lodging_investigation_scene_preview.png"
SCALE = 4
BACKGROUND_NATIVE_SIZE = (320, 180)
BACKGROUND_RUNTIME_SIZE = (1280, 720)
BUTTON_NATIVE_SIZE = (70, 25)
BUTTON_RUNTIME_SIZE = (280, 100)
EXPECTED_ITEMS = {
    "oil_lamp": (18, 24),
    "hard_bread": (20, 12),
    "oversized_coat": (44, 28),
    "contract_fragment_a": (17, 13),
    "contract_fragment_b": (16, 14),
    "contract_fragment_c": (19, 12),
    "contract_fragment_pair": (28, 18),
    "contract_complete": (36, 24),
}
EXPECTED_RUNTIME_ITEMS = {
    item_id: (size[0] * SCALE, size[1] * SCALE)
    for item_id, size in EXPECTED_ITEMS.items()
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
        if red >= 8 and blue >= 8 and blue >= red * 0.70 and red >= blue * 0.50 and green <= min(red, blue) * 0.45:
            count += 1
    return count


def bright_pixel_count(image: Image.Image) -> int:
    return sum(1 for red, green, blue, alpha in pixels(image) if alpha > 0 and max(red, green, blue) >= 210)


class TobyLodgingArtPipelineTest(unittest.TestCase):
    def test_ai_sources_and_prompt_records_exist(self) -> None:
        for path in (RAW_BACKGROUND, RAW_ITEMS, RAW_FRAGMENTS, RAW_ASSEMBLED, RAW_BUTTON):
            self.assertTrue(path.exists(), f"{path}: missing AI source image")
            self.assertGreater(path.stat().st_size, 10_000, f"{path}: source image is unexpectedly small")

        prompts = {
            RAW_BACKGROUND_PROMPT: ("toby lodging", "poor rented room", "no readable text", "no labels", "pixel-art"),
            RAW_ITEMS_PROMPT: ("four isolated props", "flat solid #ff00ff", "no labels", "2 columns x 2 rows"),
            RAW_FRAGMENTS_PROMPT: ("three different torn contract fragments", "flat solid #ff00ff", "no labels", "1 row x 3 columns"),
            RAW_ASSEMBLED_PROMPT: ("two assembled contract objects", "flat solid #ff00ff", "no labels", "1 row x 2 columns"),
            RAW_BUTTON_PROMPT: ("leave button", "blank wooden sign", "no readable text", "flat solid #ff00ff"),
        }
        for prompt_path, phrases in prompts.items():
            self.assertTrue(prompt_path.exists(), f"{prompt_path}: missing prompt record")
            prompt = prompt_path.read_text(encoding="utf-8").lower()
            for phrase in phrases:
                self.assertIn(phrase, prompt)

    def test_manifest_records_all_runtime_contracts(self) -> None:
        self.assertTrue(MANIFEST.exists(), "toby lodging art manifest is missing")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest.get("scale"), SCALE)
        self.assertEqual(manifest.get("style_profile"), "toby_lodging_scene_v1")

        background = manifest["background"]
        self.assertEqual(background["id"], "toby_lodging_background")
        self.assertEqual(background["source"], "art_sources/generated_raw/toby_lodging/toby_lodging_background_source_v1.png")
        self.assertEqual(background["native"], "assets/source/investigation/toby_lodging/background_native.png")
        self.assertEqual(background["runtime"], "assets/ui/generated/investigation/toby_lodging/background.png")
        self.assertEqual(background["native_size"], list(BACKGROUND_NATIVE_SIZE))
        self.assertEqual(background["runtime_size"], list(BACKGROUND_RUNTIME_SIZE))
        self.assertEqual(background["safe_area"], [0, 0, 320, 180])
        self.assertIn("intended_godot_use", background)

        item_entries = {entry["id"]: entry for entry in manifest["items"]}
        self.assertEqual(set(EXPECTED_ITEMS), set(item_entries))
        for item_id, native_size in EXPECTED_ITEMS.items():
            entry = item_entries[item_id]
            expected_source = "art_sources/generated_raw/toby_lodging/toby_lodging_items_source_v1.png"
            if item_id in {"contract_fragment_a", "contract_fragment_b", "contract_fragment_c"}:
                expected_source = "art_sources/generated_raw/toby_lodging/toby_lodging_contract_fragments_source_v1.png"
            elif item_id in {"contract_fragment_pair", "contract_complete"}:
                expected_source = "art_sources/generated_raw/toby_lodging/toby_lodging_contract_assembled_source_v1.png"
            self.assertEqual(entry["source"], expected_source)
            self.assertEqual(entry["native"], f"assets/source/investigation/toby_lodging/items/{item_id}_native.png")
            self.assertEqual(entry["runtime"], f"assets/ui/generated/investigation/toby_lodging/items/{item_id}.png")
            self.assertEqual(entry["native_size"], list(native_size), f"{item_id}: wrong native size")
            self.assertEqual(entry["runtime_size"], list(EXPECTED_RUNTIME_ITEMS[item_id]), f"{item_id}: wrong runtime size")
            self.assertEqual(len(entry.get("source_rect", [])), 4, f"{item_id}: source_rect must be explicit")
            self.assertEqual(len(entry.get("safe_area", [])), 4, f"{item_id}: safe_area must be explicit")
            self.assertIn("intended_godot_use", entry, f"{item_id}: missing intended Godot use")

        button_entries = {entry["state"]: entry for entry in manifest["leave_button"]["states"]}
        self.assertEqual(set(EXPECTED_BUTTON_STATES), set(button_entries))
        for state in EXPECTED_BUTTON_STATES:
            entry = button_entries[state]
            self.assertEqual(entry["source"], "art_sources/generated_raw/toby_lodging/toby_lodging_leave_button_source_v1.png")
            self.assertEqual(entry["native_size"], list(BUTTON_NATIVE_SIZE))
            self.assertEqual(entry["runtime_size"], list(BUTTON_RUNTIME_SIZE))
            self.assertEqual(entry["native"], f"assets/source/investigation/toby_lodging/ui/leave_button_{state}_native.png")
            self.assertEqual(entry["runtime"], f"assets/ui/generated/investigation/toby_lodging/ui/leave_button_{state}.png")
            self.assertIn("intended_godot_use", entry)

    def test_native_runtime_and_review_outputs_exist(self) -> None:
        required = [
            SOURCE / "reference" / "toby_lodging_background_reference_v1.png",
            SOURCE / "reference" / "toby_lodging_items_reference_v1.png",
            SOURCE / "reference" / "toby_lodging_contract_fragments_reference_v1.png",
            SOURCE / "reference" / "toby_lodging_contract_assembled_reference_v1.png",
            SOURCE / "reference" / "toby_lodging_leave_button_reference_v1.png",
            SOURCE / "background_native.png",
            RUNTIME / "background.png",
            CONTACT_SHEET,
            SCENE_PREVIEW,
        ]
        for state in EXPECTED_BUTTON_STATES:
            required.append(SOURCE / "ui" / f"leave_button_{state}_native.png")
            required.append(RUNTIME / "ui" / f"leave_button_{state}.png")
        for item_id in EXPECTED_ITEMS:
            required.append(SOURCE / "items" / f"{item_id}_native.png")
            required.append(RUNTIME / "items" / f"{item_id}.png")
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
        for state in EXPECTED_BUTTON_STATES:
            pairs.append((SOURCE / "ui" / f"leave_button_{state}_native.png", RUNTIME / "ui" / f"leave_button_{state}.png", BUTTON_RUNTIME_SIZE))

        for native_path, runtime_path, runtime_size in pairs:
            native = load_rgba(native_path)
            runtime = load_rgba(runtime_path)
            expected = native.resize(runtime_size, Image.Resampling.NEAREST)
            self.assertEqual(runtime.tobytes(), expected.tobytes(), f"{runtime_path.name}: runtime is not exact nearest-neighbor export")

    def test_background_palette_is_dark_tavern_lodging_pixel_art(self) -> None:
        native = load_rgba(SOURCE / "background_native.png")
        data = pixels(native)
        dark = sum(1 for red, green, blue, alpha in data if alpha == 255 and max(red, green, blue) <= 78)
        cold = sum(1 for red, green, blue, alpha in data if alpha == 255 and blue >= red * 0.54 and green >= 20)
        amber = sum(1 for red, green, blue, alpha in data if alpha == 255 and red >= 52 and green >= 30 and blue <= 50 and red >= blue * 1.20)
        bright = sum(1 for red, green, blue, alpha in data if alpha == 255 and max(red, green, blue) >= 220)
        self.assertGreaterEqual(dark, 18_000, "background needs enough dark lodging mass")
        self.assertGreaterEqual(cold, 4_000, "background needs cold stone/wood integration colors")
        self.assertGreaterEqual(amber, 500, "background needs small muted warm accents")
        self.assertLessEqual(amber, 4_200, "warm light should not flood the whole scene")
        self.assertLessEqual(bright, 100, "background should avoid bright noisy pixels")
        self.assertGreaterEqual(color_count(native), 36, "background should keep authored color nuance")

    def test_background_floor_has_no_square_warm_light_patch(self) -> None:
        native = load_rgba(SOURCE / "background_native.png")
        center_floor_luma = self._average_luma(native.crop((102, 102, 218, 154)))
        side_floor_luma = max(
            self._average_luma(native.crop((36, 102, 92, 154))),
            self._average_luma(native.crop((228, 102, 284, 154))),
        )
        self.assertLessEqual(
            center_floor_luma - side_floor_luma,
            2.0,
            "center floor should not read as a separate square warm-light patch",
        )

    def test_background_wall_has_no_square_orange_patch(self) -> None:
        native = load_rgba(SOURCE / "background_native.png")
        target_warm = self._warm_pixel_count(native.crop((96, 44, 126, 88)))
        adjacent_warm = max(
            self._warm_pixel_count(native.crop((84, 44, 96, 88))),
            self._warm_pixel_count(native.crop((126, 44, 152, 88))),
        )
        self.assertLessEqual(
            target_warm,
            adjacent_warm + 30,
            "left-center wall should not read as a separate square orange patch",
        )

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
            self.assertLessEqual(bright_pixel_count(native), 12, f"{item_id}: too many bright pixels for lodging scene")

        for state in EXPECTED_BUTTON_STATES:
            native = load_rgba(SOURCE / "ui" / f"leave_button_{state}_native.png")
            self.assertEqual(native.size, BUTTON_NATIVE_SIZE, f"{state}: button native size mismatch")
            alpha = native.getchannel("A")
            self.assertEqual(alpha.getextrema()[0], 0, f"{state}: button native needs transparent edge pixels")
            self.assertGreater(alpha.getextrema()[1], 0, f"{state}: button native has no visible pixels")
            self.assertEqual(chroma_fringe_pixels(native), 0, f"{state}: button has visible magenta fringe")

    def test_runtime_files_do_not_reference_raw_or_reference_art(self) -> None:
        forbidden = [
            "art_sources/generated_raw/toby_lodging",
            "assets/source/investigation/toby_lodging/reference",
            "toby_lodging_background_source_v1.png",
            "toby_lodging_items_source_v1.png",
            "toby_lodging_contract_assembled_source_v1.png",
            "toby_lodging_leave_button_source_v1.png",
        ]
        for root in (ROOT / "scripts" / "ui", ROOT / "scenes" / "ui"):
            for path in root.rglob("*"):
                if path.suffix not in {".gd", ".tscn", ".tres"}:
                    continue
                text = path.read_text(encoding="utf-8", errors="ignore").replace("\\", "/")
                for marker in forbidden:
                    self.assertNotIn(marker, text, f"{path.relative_to(ROOT)} references raw/reference art")

    def _average_luma(self, image: Image.Image) -> float:
        visible = [px for px in pixels(image) if px[3] > 0]
        self.assertTrue(visible, "luma sample must contain visible pixels")
        return sum(0.2126 * red + 0.7152 * green + 0.0722 * blue for red, green, blue, _alpha in visible) / len(visible)

    def _warm_pixel_count(self, image: Image.Image) -> int:
        return sum(
            1
            for red, green, blue, alpha in pixels(image)
            if alpha == 255 and red >= 52 and green >= 30 and blue <= 50 and red >= blue * 1.20 and red >= green * 0.90
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
