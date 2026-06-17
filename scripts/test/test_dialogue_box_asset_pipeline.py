from pathlib import Path
import json
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_sources" / "generated_raw" / "dialogue_box" / "dialogue_box_sheet_v4.png"
PROMPT = ROOT / "art_sources" / "generated_raw" / "dialogue_box" / "dialogue_box_prompt_v4.txt"
PANEL_RAW = ROOT / "art_sources" / "generated_raw" / "dialogue_box" / "dialogue_panel_source_v9_minimal.png"
PANEL_PROMPT = ROOT / "art_sources" / "generated_raw" / "dialogue_box" / "dialogue_panel_prompt_v9_minimal.txt"
SOURCE = ROOT / "assets" / "source" / "ui" / "dialogue_box"
RUNTIME = ROOT / "assets" / "textures" / "ui" / "dialogue_box"
REFERENCE = SOURCE / "reference" / "dialogue_box_sheet_v4_reference.png"
MANIFEST = SOURCE / "dialogue_box_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "dialogue_box_contact_sheet.png"
SCENE_PREVIEW = ROOT / "docs" / "art" / "dialogue_box_scene_preview.png"
CHARACTER_COMPARE = ROOT / "docs" / "art" / "dialogue_box_character_compare.png"
SCALE = 4

EXPECTED_NATIVE_SIZES = {
    "dialogue_panel": (300, 54),
}
EXPECTED_SOURCES = {
    "dialogue_panel": PANEL_RAW,
}
FORBIDDEN_COMPONENT_IDS = {
    "dialogue_nameplate",
    "dialogue_progress_arrow",
    "dialogue_response_normal",
    "dialogue_response_hover",
    "dialogue_response_pressed",
}


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixel_count(image: Image.Image) -> int:
    alpha = image.convert("RGBA").getchannel("A")
    return sum(alpha.histogram()[1:])


def chroma_fringe_pixels(image: Image.Image) -> int:
    count = 0
    rgba = image.convert("RGBA")
    data = rgba.get_flattened_data() if hasattr(rgba, "get_flattened_data") else rgba.getdata()
    for red, green, blue, alpha in data:
        if alpha == 0:
            continue
        if red >= 12 and blue >= 12 and blue >= red * 0.7 and red >= blue * 0.5 and green <= min(red, blue) * 0.45:
            count += 1
    return count


class DialogueBoxAssetPipelineTest(unittest.TestCase):
    def test_raw_prompt_and_manifest_contract(self) -> None:
        self.assertTrue(PANEL_RAW.exists(), "dedicated high-detail dialogue panel source is missing")
        self.assertTrue(PANEL_PROMPT.exists(), "dedicated dialogue panel prompt record is missing")
        panel_prompt = PANEL_PROMPT.read_text(encoding="utf-8").lower()
        for phrase in ("dialogue panel", "perfectly flat solid #ff00ff", "readable text", "minimal", "no bulky corner caps"):
            self.assertIn(phrase, panel_prompt)

        self.assertTrue(MANIFEST.exists(), "dialogue box manifest is missing")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest.get("scale"), SCALE)
        self.assertEqual(manifest.get("style_profile"), "dark_teal_tavern_dialogue_v1")
        entries = manifest.get("items", [])
        by_id = {entry.get("id"): entry for entry in entries}
        self.assertEqual(set(EXPECTED_NATIVE_SIZES), set(by_id))
        serialized = json.dumps(manifest, ensure_ascii=False)
        for component_id in FORBIDDEN_COMPONENT_IDS:
            self.assertNotIn(component_id, serialized, f"{component_id}: obsolete dialogue component art must not be part of the dialogue box pipeline")

        for item_id, native_size in EXPECTED_NATIVE_SIZES.items():
            entry = by_id[item_id]
            self.assertEqual(entry.get("source"), EXPECTED_SOURCES[item_id].relative_to(ROOT).as_posix(), f"{item_id}: wrong source")
            self.assertEqual(entry.get("native_size"), list(native_size), f"{item_id}: wrong native size")
            self.assertEqual(entry.get("runtime_size"), [native_size[0] * SCALE, native_size[1] * SCALE], f"{item_id}: wrong runtime size")
            self.assertEqual(len(entry.get("source_rect", [])), 4, f"{item_id}: source_rect must be explicit")
            self.assertEqual(len(entry.get("safe_area", [])), 4, f"{item_id}: safe_area must be explicit")
            self.assertIn("intended_godot_use", entry, f"{item_id}: missing intended Godot use")
            self.assertIn("palette_colors", entry, f"{item_id}: palette budget must be explicit")
            if item_id == "dialogue_panel":
                self.assertNotIn("source_slice_margins", entry, f"{item_id}: fixed-size panel should not use nine-slice source slicing")
                self.assertEqual(len(entry.get("nine_slice_margins", [])), 4, f"{item_id}: nine_slice_margins must be explicit")
        self.assertGreaterEqual(by_id["dialogue_panel"]["palette_colors"], 40, "dialogue panel needs a richer palette budget than the first rough UI pass")

    def test_no_obsolete_component_art_is_shipped_for_dialogue_box(self) -> None:
        for component_id in FORBIDDEN_COMPONENT_IDS:
            self.assertFalse((SOURCE / f"{component_id}_native.png").exists(), f"{component_id}: obsolete native art should be removed")
            self.assertFalse((RUNTIME / f"{component_id}.png").exists(), f"{component_id}: obsolete runtime art should be removed")

        self.assertFalse((SOURCE / "candidates").exists(), "dialogue box production source candidates should not remain after promotion")
        self.assertFalse((RUNTIME / "candidates").exists(), "dialogue box runtime candidates should not remain after promotion")
        self.assertFalse(any((ROOT / "docs" / "art").glob("dialogue_panel_*candidate*.png")), "obsolete dialogue candidate previews should not remain after promotion")

        for path in [
            ROOT / "scripts" / "tools" / "export_dialogue_box_assets.py",
            ROOT / "scripts" / "ui" / "dialogue_balloon.gd",
            ROOT / "scripts" / "tutorial" / "tutorial_overlay.gd",
            ROOT / "scripts" / "test" / "test_dialogue_balloon_contract.gd",
            ROOT / "scripts" / "test" / "test_tutorial_overlay_ui.gd",
        ]:
            text = path.read_text(encoding="utf-8", errors="ignore")
            for component_id in FORBIDDEN_COMPONENT_IDS:
                self.assertNotIn(component_id, text, f"{path.relative_to(ROOT)} still references obsolete dialogue component art")

    def test_exporter_uses_ui_safe_resampling_rules(self) -> None:
        exporter = (ROOT / "scripts" / "tools" / "export_dialogue_box_assets.py").read_text(encoding="utf-8")
        self.assertNotIn("Image.Resampling.LANCZOS", exporter, "dialogue UI exporter must not blur source art with LANCZOS")
        self.assertNotIn("trimmed.resize(native_size", exporter, "dialogue UI exporter must not stretch whole components into native size")
        self.assertIn("nine_slice_resize", exporter, "dialogue UI exporter should use nine-slice reconstruction for framed components")
        self.assertIn("SOURCE_TO_NATIVE_RESAMPLE = Image.Resampling.BOX", exporter, "framed generated UI should be reconstructed onto native grid before quantization")
        self.assertNotIn("patch.resize((dst_w, dst_h), Image.Resampling.NEAREST)", exporter, "framed generated UI must not nearest-neighbor compress source pixels into native")
        self.assertNotIn("visible.resize(fitted_size, Image.Resampling.NEAREST)", exporter, "generated icons must not nearest-neighbor compress source pixels into native")
        self.assertIn("Image.open(source_path)", exporter, "dialogue UI exporter must crop each component from its own manifest source")
        self.assertNotIn("reference.crop", exporter, "dialogue UI exporter must not crop every component from a shared reference image")

    def test_reference_contact_sheet_and_preview_exist(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), "dialogue box contact sheet is missing")
        contact = load_rgba(CONTACT_SHEET)
        self.assertGreaterEqual(contact.width, 800)
        self.assertGreaterEqual(contact.height, 420)
        self.assertTrue(SCENE_PREVIEW.exists(), "dialogue box scene preview is missing")
        self.assertEqual(load_rgba(SCENE_PREVIEW).size, (1280, 720))
        self.assertTrue(CHARACTER_COMPARE.exists(), "dialogue box versus character comparison sheet is missing")
        character_compare = load_rgba(CHARACTER_COMPARE)
        self.assertGreaterEqual(character_compare.width, 900)
        self.assertGreaterEqual(character_compare.height, 360)

    def test_native_and_runtime_exports(self) -> None:
        for item_id, native_size in EXPECTED_NATIVE_SIZES.items():
            native_path = SOURCE / f"{item_id}_native.png"
            runtime_path = RUNTIME / f"{item_id}.png"
            self.assertTrue(native_path.exists(), f"{item_id}: native file is missing")
            self.assertTrue(runtime_path.exists(), f"{item_id}: runtime file is missing")
            native = load_rgba(native_path)
            runtime = load_rgba(runtime_path)
            self.assertEqual(native.size, native_size, f"{item_id}: native size mismatch")
            self.assertEqual(runtime.size, (native_size[0] * SCALE, native_size[1] * SCALE), f"{item_id}: runtime size mismatch")
            expected = native.resize(runtime.size, Image.Resampling.NEAREST)
            self.assertEqual(runtime.tobytes(), expected.tobytes(), f"{item_id}: runtime is not an exact nearest-neighbor export")
            self.assertGreater(visible_pixel_count(native), native.width * native.height // 8, f"{item_id}: too few visible pixels")
            self.assertEqual(chroma_fringe_pixels(native), 0, f"{item_id}: visible magenta chroma-key fringe remains")

    def test_runtime_ui_does_not_reference_raw_dialogue_art(self) -> None:
        forbidden = [
            "art_sources/generated_raw/dialogue_box",
            "assets/source/ui/dialogue_box/reference",
            "dialogue_box_sheet_v1.png",
        ]
        for root in (ROOT / "scripts" / "ui", ROOT / "scenes" / "ui"):
            for path in root.rglob("*"):
                if path.suffix not in {".gd", ".tscn", ".tres"}:
                    continue
                text = path.read_text(encoding="utf-8", errors="ignore").replace("\\", "/")
                for marker in forbidden:
                    self.assertNotIn(marker, text, f"{path.relative_to(ROOT)} references raw/reference dialogue art")


if __name__ == "__main__":
    unittest.main(verbosity=2)
