import json
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = ROOT / "art_sources" / "generated_raw" / "clean_table_inference" / "components"
SOURCE = ROOT / "assets" / "source" / "ui" / "clean_table_inference" / "components"
RUNTIME = ROOT / "assets" / "textures" / "ui" / "clean_table_inference" / "components"
MANIFEST = SOURCE / "clean_table_components_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "clean_table_components_contact_sheet.png"
SCALE = 4
MAX_NATIVE_ALPHA_LEVELS = 4
MAX_NATIVE_VISIBLE_RGB_COLORS = 40

ASSETS = {
    "clue_scrap": {"native": (66, 19), "runtime": (264, 76), "source": "clue_scrap_source_v1.png"},
    "inference_note": {"native": (128, 142), "runtime": (512, 568), "source": "inference_note_source_v1.png"},
    "ink_ring_slot": {"native": (12, 12), "runtime": (48, 48), "source": "ink_ring_slot_source_v1.png"},
    "conclusion_strip": {"native": (70, 16), "runtime": (280, 64), "source": "conclusion_strip_source_v1.png"},
    "keyword_notes_panel": {"native": (76, 142), "runtime": (304, 568), "source": "keyword_notes_panel_source_v1.png"},
    "paper_tag_button": {"native": (44, 15), "runtime": (176, 60), "source": "paper_tag_button_states_source_v1.png"},
    "paper_tag_button_normal": {"native": (44, 15), "runtime": (176, 60), "source": "paper_tag_button_states_source_v1.png"},
    "paper_tag_button_hover": {"native": (44, 15), "runtime": (176, 60), "source": "paper_tag_button_states_source_v1.png"},
    "paper_tag_button_pressed": {"native": (44, 15), "runtime": (176, 60), "source": "paper_tag_button_states_source_v1.png"},
}


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def flattened_pixels(image: Image.Image):
    return image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()


def alpha_level_count(image: Image.Image) -> int:
    return len(set(image.convert("RGBA").getchannel("A").tobytes()))


def visible_rgb_color_count(image: Image.Image) -> int:
    rgba = image.convert("RGBA")
    return len({(r, g, b) for r, g, b, a in flattened_pixels(rgba) if a >= 120})


class CleanTableComponentAssetPipelineTest(unittest.TestCase):
    def test_raw_sources_manifest_and_contact_sheet_are_retained(self) -> None:
        self.assertTrue((RAW_DIR / "component_prompts_v1.txt").exists(), "component prompt record must be retained")
        for contract in ASSETS.values():
            raw = RAW_DIR / contract["source"]
            self.assertTrue(raw.exists(), f"{raw}: missing raw generated component")
            self.assertGreater(raw.stat().st_size, 0, f"{raw}: empty raw generated component")
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing component manifest")
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing component contact sheet")

        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["id"], "clean_table_component_assets")
        self.assertEqual(manifest["scale"], SCALE)
        self.assertEqual(set(manifest["assets"].keys()), set(ASSETS.keys()))
        for asset_id, contract in ASSETS.items():
            asset = manifest["assets"][asset_id]
            self.assertEqual(asset["native_size"], list(contract["native"]), f"{asset_id}: wrong native size in manifest")
            self.assertEqual(asset["size"], list(contract["runtime"]), f"{asset_id}: wrong runtime size in manifest")
            self.assertEqual(
                asset["source_file"],
                f"art_sources/generated_raw/clean_table_inference/components/{contract['source']}",
                f"{asset_id}: source path changed",
            )
            self.assertEqual(
                asset["output_file"],
                f"assets/textures/ui/clean_table_inference/components/{asset_id}.png",
                f"{asset_id}: output path changed",
            )
            self.assertIn("source_rect", asset, f"{asset_id}: explicit source rectangle required")
            self.assertIn("nine_slice_margins", asset, f"{asset_id}: nine-slice margins required")
            self.assertIn("intended_godot_use", asset, f"{asset_id}: Godot usage required")

    def test_runtime_outputs_are_exact_nearest_exports(self) -> None:
        for asset_id, contract in ASSETS.items():
            with self.subTest(asset=asset_id):
                native = load_rgba(SOURCE / f"{asset_id}_native.png")
                runtime = load_rgba(RUNTIME / f"{asset_id}.png")
                self.assertEqual(native.size, contract["native"], f"{asset_id}: wrong native size")
                self.assertEqual(runtime.size, contract["runtime"], f"{asset_id}: wrong runtime size")
                expected = native.resize(contract["runtime"], Image.Resampling.NEAREST)
                self.assertEqual(runtime.tobytes(), expected.tobytes(), f"{asset_id}: runtime is not exact nearest export")

    def test_paper_tag_button_has_distinct_interaction_states(self) -> None:
        normal = load_rgba(RUNTIME / "paper_tag_button_normal.png")
        hover = load_rgba(RUNTIME / "paper_tag_button_hover.png")
        pressed = load_rgba(RUNTIME / "paper_tag_button_pressed.png")
        self.assertNotEqual(normal.tobytes(), hover.tobytes(), "paper tag hover state must be visually distinct")
        self.assertNotEqual(normal.tobytes(), pressed.tobytes(), "paper tag pressed state must be visually distinct")
        self.assertNotEqual(hover.tobytes(), pressed.tobytes(), "paper tag hover and pressed states must differ")

    def test_components_have_transparent_boundaries_and_visible_centers(self) -> None:
        for asset_id in ASSETS:
            with self.subTest(asset=asset_id):
                native = load_rgba(SOURCE / f"{asset_id}_native.png")
                alpha = native.getchannel("A")
                alpha_min, alpha_max = alpha.getextrema()
                self.assertEqual(alpha_min, 0, f"{asset_id}: needs transparent padding after chroma removal")
                self.assertGreater(alpha_max, 180, f"{asset_id}: visible pixels missing")
                visible = sum(alpha.histogram()[1:])
                self.assertGreater(visible, native.width * native.height * 0.08, f"{asset_id}: too little visible art")

    def test_native_components_are_chunky_pixel_assets_not_soft_resamples(self) -> None:
        for asset_id in ASSETS:
            with self.subTest(asset=asset_id):
                native = load_rgba(SOURCE / f"{asset_id}_native.png")
                self.assertLessEqual(
                    alpha_level_count(native),
                    MAX_NATIVE_ALPHA_LEVELS,
                    f"{asset_id}: too many alpha levels; antialiased edges read blurry in-game",
                )
                self.assertLessEqual(
                    visible_rgb_color_count(native),
                    MAX_NATIVE_VISIBLE_RGB_COLORS,
                    f"{asset_id}: too many visible colors; generated gradients need pixel-palette reduction",
                )

    def test_component_palette_stays_paper_and_ink_focused(self) -> None:
        for asset_id in ("clue_scrap", "inference_note", "conclusion_strip", "keyword_notes_panel", "paper_tag_button"):
            native = load_rgba(SOURCE / f"{asset_id}_native.png")
            pixels = list(native.get_flattened_data()) if hasattr(native, "get_flattened_data") else list(native.getdata())
            visible = [(r, g, b, a) for r, g, b, a in pixels if a >= 120]
            parchment = sum(1 for r, g, b, _a in visible if r >= 130 and 80 <= g <= 205 and 40 <= b <= 150)
            self.assertGreater(parchment, len(visible) * 0.45, f"{asset_id}: should read as parchment")

    def test_runtime_ui_uses_components_only_through_runtime_paths(self) -> None:
        scanned = [
            ROOT / "scripts" / "ui" / "clean_table_inference_screen.gd",
            ROOT / "scenes" / "ui" / "CleanTableInferenceScreen.tscn",
        ]
        combined = "\n".join(path.read_text(encoding="utf-8", errors="ignore").replace("\\", "/") for path in scanned)
        self.assertNotIn("art_sources/generated_raw/clean_table_inference/components", combined)
        self.assertNotIn("assets/source/ui/clean_table_inference/components", combined)


if __name__ == "__main__":
    unittest.main(verbosity=2)
