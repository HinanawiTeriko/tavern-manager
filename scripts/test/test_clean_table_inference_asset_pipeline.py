from pathlib import Path
import json
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "ui" / "clean_table_inference"
RUNTIME = ROOT / "assets" / "textures" / "ui" / "clean_table_inference"
RAW_REFERENCE = ROOT / "art_sources" / "generated_raw" / "clean_table_inference" / "clean_table_inference_reference_v1.png"
RAW_PROMPT = ROOT / "art_sources" / "generated_raw" / "clean_table_inference" / "clean_table_inference_prompt_v1.txt"
MANIFEST = SOURCE / "clean_table_inference_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "clean_table_inference_contact_sheet.png"
SCALE = 4

ASSETS = {
    "clean_table_backdrop": {"native": (320, 180), "runtime": (1280, 720), "alpha": False},
    "clue_tray_panel": {"native": (76, 142), "runtime": (304, 568), "alpha": False},
    "inference_book_panel": {"native": (130, 142), "runtime": (520, 568), "alpha": False},
    "solved_strip_panel": {"native": (76, 116), "runtime": (304, 464), "alpha": False},
    "clue_paper": {"native": (66, 19), "runtime": (264, 76), "alpha": False},
    "blank_slot_normal": {"native": (44, 10), "runtime": (176, 40), "alpha": False},
    "blank_slot_hover": {"native": (44, 10), "runtime": (176, 40), "alpha": False},
    "blank_slot_pressed": {"native": (44, 10), "runtime": (176, 40), "alpha": False},
    "continue_button_normal": {"native": (44, 15), "runtime": (176, 60), "alpha": False},
    "continue_button_hover": {"native": (44, 15), "runtime": (176, 60), "alpha": False},
    "continue_button_pressed": {"native": (44, 15), "runtime": (176, 60), "alpha": False},
}


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixel_count(image: Image.Image) -> int:
    return sum(image.getchannel("A").histogram()[1:])


def pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    rgba = image.convert("RGBA")
    if hasattr(rgba, "get_flattened_data"):
        return list(rgba.get_flattened_data())
    return list(rgba.getdata())


def alpha_bbox_size(image: Image.Image) -> tuple[int, int]:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        return (0, 0)
    left, top, right, bottom = bbox
    return (right - left, bottom - top)


class CleanTableInferenceAssetPipelineTest(unittest.TestCase):
    def test_manifest_contact_sheet_and_contract_are_retained(self) -> None:
        for path in (RAW_REFERENCE, RAW_PROMPT):
            self.assertTrue(path.exists(), f"{path}: generated source/prompt must be retained")
            self.assertGreater(path.stat().st_size, 0, f"{path}: empty source record")
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing clean-table inference manifest")
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing visual contact sheet")
        self.assertGreater(CONTACT_SHEET.stat().st_size, 0, "contact sheet is empty")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["id"], "clean_table_inference_ui")
        self.assertEqual(manifest["scale"], SCALE)
        self.assertEqual(manifest["source"], "art_sources/generated_raw/clean_table_inference/clean_table_inference_reference_v1.png")
        self.assertEqual(manifest["prompt"], "art_sources/generated_raw/clean_table_inference/clean_table_inference_prompt_v1.txt")
        self.assertEqual(set(manifest["assets"].keys()), set(ASSETS.keys()))
        for asset_id, contract in ASSETS.items():
            asset = manifest["assets"][asset_id]
            self.assertEqual(asset["native_size"], list(contract["native"]), f"{asset_id}: native contract changed")
            self.assertEqual(asset["size"], list(contract["runtime"]), f"{asset_id}: runtime contract changed")
            self.assertEqual(
                asset["output_file"],
                f"assets/textures/ui/clean_table_inference/{asset_id}.png",
                f"{asset_id}: runtime path changed",
            )
            self.assertIn("safe_area", asset, f"{asset_id}: missing safe area")
            self.assertIn("nine_slice_margins", asset, f"{asset_id}: missing nine-slice margins")
            self.assertIn("intended_godot_use", asset, f"{asset_id}: missing Godot usage")

    def test_runtime_outputs_are_exact_nearest_exports(self) -> None:
        for asset_id, contract in ASSETS.items():
            with self.subTest(asset=asset_id):
                native_path = SOURCE / f"{asset_id}_native.png"
                runtime_path = RUNTIME / f"{asset_id}.png"
                self.assertTrue(native_path.exists(), f"{native_path}: missing native source")
                self.assertTrue(runtime_path.exists(), f"{runtime_path}: missing runtime texture")
                native = load_rgba(native_path)
                runtime = load_rgba(runtime_path)
                self.assertEqual(native.size, contract["native"], f"{asset_id}: wrong native size")
                self.assertEqual(runtime.size, contract["runtime"], f"{asset_id}: wrong runtime size")
                if contract["alpha"]:
                    alpha_min, alpha_max = native.getchannel("A").getextrema()
                    self.assertEqual(alpha_min, 0, f"{asset_id}: needs transparent boundary pixels")
                    self.assertGreater(alpha_max, 0, f"{asset_id}: visible pixels missing")
                else:
                    self.assertGreater(visible_pixel_count(native), native.width * native.height * 0.98)
                expected = native.resize(contract["runtime"], Image.Resampling.NEAREST)
                self.assertEqual(runtime.tobytes(), expected.tobytes(), f"{asset_id}: not exact 4x nearest export")

    def test_backdrop_and_panels_match_dark_tavern_pixel_palette(self) -> None:
        backdrop_path = SOURCE / "clean_table_backdrop_native.png"
        book_path = SOURCE / "inference_book_panel_native.png"
        missing = [path for path in (backdrop_path, book_path) if not path.exists()]
        self.assertEqual(missing, [], "palette test requires native backdrop and book panel assets")
        if missing:
            return

        backdrop = load_rgba(backdrop_path)
        px = pixels(backdrop)
        dark_teal = sum(1 for red, green, blue, alpha in px if alpha >= 220 and red <= 70 and 20 <= green <= 100 and 20 <= blue <= 105)
        amber = sum(1 for red, green, blue, alpha in px if alpha >= 220 and red >= 150 and 75 <= green <= 170 and blue <= 95)
        parchment = sum(1 for red, green, blue, alpha in px if alpha >= 220 and 115 <= red <= 225 and 85 <= green <= 190 and 45 <= blue <= 140)
        self.assertGreaterEqual(dark_teal, 9000, "backdrop needs dark teal tavern/stone framing from generated art")
        self.assertGreaterEqual(amber, 4000, "backdrop needs candle/ink amber accents")
        self.assertGreaterEqual(parchment, 12000, "backdrop needs parchment/table light pockets")

        book = load_rgba(book_path)
        book_px = pixels(book)
        book_parchment = sum(1 for red, green, blue, alpha in book_px if alpha >= 220 and 120 <= red <= 225 and 85 <= green <= 190 and 45 <= blue <= 140)
        book_dark = sum(1 for red, green, blue, alpha in book_px if alpha >= 220 and red <= 80 and green <= 74 and blue <= 70)
        self.assertGreaterEqual(book_parchment, 8500, "book panel needs a readable parchment field")
        self.assertLessEqual(book_dark, 2800, "book panel text area cannot be too noisy")

    def test_button_and_blank_states_keep_stable_alpha_bounds(self) -> None:
        for prefix in ("blank_slot", "continue_button"):
            missing = [SOURCE / f"{prefix}_{state}_native.png" for state in ("normal", "hover", "pressed") if not (SOURCE / f"{prefix}_{state}_native.png").exists()]
            self.assertEqual(missing, [], f"{prefix}: missing state native assets")
            if missing:
                continue
            bbox_sizes = set()
            state_bytes = set()
            for state in ("normal", "hover", "pressed"):
                native = load_rgba(SOURCE / f"{prefix}_{state}_native.png")
                bbox_sizes.add(alpha_bbox_size(native))
                state_bytes.add(native.tobytes())
            self.assertEqual(len(bbox_sizes), 1, f"{prefix}: states must not resize the clickable silhouette")
            self.assertEqual(len(state_bytes), 3, f"{prefix}: normal/hover/pressed states must be visually distinct")

    def test_runtime_ui_does_not_reference_unapproved_art_sources(self) -> None:
        scanned = [
            ROOT / "scripts" / "ui" / "clean_table_inference_screen.gd",
            ROOT / "scenes" / "ui" / "CleanTableInferenceScreen.tscn",
        ]
        combined = "\n".join(path.read_text(encoding="utf-8", errors="ignore").replace("\\", "/") for path in scanned)
        for forbidden in (
            "art_sources/generated_raw/clean_table_inference",
            "assets/source/ui/clean_table_inference",
            "clean_table_backdrop.png",
            "clue_tray_panel.png",
            "inference_book_panel.png",
            "solved_strip_panel.png",
            "clue_paper.png",
            "blank_slot_normal.png",
            "blank_slot_hover.png",
            "blank_slot_pressed.png",
            "continue_button_normal.png",
            "continue_button_hover.png",
            "continue_button_pressed.png",
        ):
            self.assertNotIn(forbidden, combined, f"runtime UI must not reference {forbidden}")


if __name__ == "__main__":
    unittest.main(verbosity=2)
