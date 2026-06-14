from pathlib import Path
import json
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_sources" / "generated_raw" / "dialogue_box" / "dialogue_box_sheet_v1.png"
PROMPT = ROOT / "art_sources" / "generated_raw" / "dialogue_box" / "dialogue_box_prompt_v1.txt"
SOURCE = ROOT / "assets" / "source" / "ui" / "dialogue_box"
RUNTIME = ROOT / "assets" / "textures" / "ui" / "dialogue_box"
REFERENCE = SOURCE / "reference" / "dialogue_box_sheet_v1_reference.png"
MANIFEST = SOURCE / "dialogue_box_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "dialogue_box_contact_sheet.png"
SCENE_PREVIEW = ROOT / "docs" / "art" / "dialogue_box_scene_preview.png"
SCALE = 4

EXPECTED_NATIVE_SIZES = {
    "dialogue_panel": (300, 54),
    "dialogue_nameplate": (136, 18),
    "dialogue_response_normal": (172, 18),
    "dialogue_response_hover": (172, 18),
    "dialogue_response_pressed": (172, 18),
    "dialogue_progress_arrow": (16, 14),
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
        self.assertTrue(RAW.exists(), "raw AI dialogue box sheet is missing")
        self.assertTrue(PROMPT.exists(), "dialogue box prompt record is missing")
        prompt = PROMPT.read_text(encoding="utf-8").lower()
        for phrase in ("perfectly flat solid #ff00ff", "no readable text", "dark dungeon tavern", "continue arrow"):
            self.assertIn(phrase, prompt)

        self.assertTrue(MANIFEST.exists(), "dialogue box manifest is missing")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest.get("scale"), SCALE)
        self.assertEqual(manifest.get("style_profile"), "dark_teal_tavern_dialogue_v1")
        self.assertEqual(manifest.get("reference"), REFERENCE.relative_to(ROOT).as_posix())
        entries = manifest.get("items", [])
        by_id = {entry.get("id"): entry for entry in entries}
        self.assertEqual(set(EXPECTED_NATIVE_SIZES), set(by_id))

        for item_id, native_size in EXPECTED_NATIVE_SIZES.items():
            entry = by_id[item_id]
            self.assertEqual(entry.get("source"), RAW.relative_to(ROOT).as_posix(), f"{item_id}: wrong source")
            self.assertEqual(entry.get("native_size"), list(native_size), f"{item_id}: wrong native size")
            self.assertEqual(entry.get("runtime_size"), [native_size[0] * SCALE, native_size[1] * SCALE], f"{item_id}: wrong runtime size")
            self.assertEqual(len(entry.get("source_rect", [])), 4, f"{item_id}: source_rect must be explicit")
            self.assertEqual(len(entry.get("safe_area", [])), 4, f"{item_id}: safe_area must be explicit")
            self.assertIn("intended_godot_use", entry, f"{item_id}: missing intended Godot use")

    def test_reference_contact_sheet_and_preview_exist(self) -> None:
        self.assertTrue(REFERENCE.exists(), "stable dialogue box reference is missing")
        self.assertEqual(load_rgba(REFERENCE).size, (1664, 928), "reference must keep the normalized generated sheet size")
        self.assertTrue(CONTACT_SHEET.exists(), "dialogue box contact sheet is missing")
        contact = load_rgba(CONTACT_SHEET)
        self.assertGreaterEqual(contact.width, 800)
        self.assertGreaterEqual(contact.height, 420)
        self.assertTrue(SCENE_PREVIEW.exists(), "dialogue box scene preview is missing")
        self.assertEqual(load_rgba(SCENE_PREVIEW).size, (1280, 720))

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
