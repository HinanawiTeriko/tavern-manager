from pathlib import Path
import json
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
REFERENCE = ROOT / "assets" / "source" / "investigation" / "mine_items" / "reference" / "mine_item_sheet_v1_reference.png"
SOURCE = ROOT / "assets" / "source" / "investigation" / "mine_items"
RUNTIME = ROOT / "assets" / "ui" / "generated" / "investigation" / "mine_items"
MANIFEST = SOURCE / "mine_item_art_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "mine_investigation_item_art_contact_sheet.png"
SCALE = 4

EXPECTED_ITEMS = {
    "broken_arrow": (24, 12),
    "dented_shield": (32, 32),
    "lost_boot": (28, 18),
    "rubble": (60, 45),
    "torn_backpack": (36, 28),
    "coins": (10, 10),
    "warhammer_token": (14, 14),
    "bloodied_paper": (20, 26),
}


def load_image(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.copy()


def visible_pixel_count(image: Image.Image) -> int:
    alpha = image.convert("RGBA").getchannel("A")
    return sum(alpha.histogram()[1:])


def alpha_bbox_size(image: Image.Image) -> tuple[int, int]:
    box = image.convert("RGBA").getchannel("A").getbbox()
    if box is None:
        return (0, 0)
    return (box[2] - box[0], box[3] - box[1])


def chroma_fringe_pixels(image: Image.Image) -> int:
    count = 0
    rgba = image.convert("RGBA")
    data = rgba.get_flattened_data() if hasattr(rgba, "get_flattened_data") else rgba.getdata()
    for red, green, blue, alpha in data:
        if alpha == 0:
            continue
        if red >= 10 and blue >= 10 and blue >= red * 0.70 and red >= blue * 0.50 and green <= min(red, blue) * 0.45:
            count += 1
    return count


class MineInvestigationItemArtPipelineTest(unittest.TestCase):
    def test_manifest_has_all_contract_items(self) -> None:
        self.assertTrue(MANIFEST.exists(), "mine item art manifest is missing")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        entries = manifest.get("items", [])
        by_id = {entry.get("id"): entry for entry in entries}
        self.assertEqual(set(EXPECTED_ITEMS), set(by_id), "manifest item ids must match MineInvestigation item tags")
        self.assertEqual(manifest.get("scale"), SCALE, "manifest scale must be 4")
        self.assertEqual(manifest.get("reference"), str(REFERENCE.relative_to(ROOT)).replace("\\", "/"))

        for item_id, native_size in EXPECTED_ITEMS.items():
            entry = by_id[item_id]
            self.assertEqual(entry.get("native_size"), list(native_size), f"{item_id}: wrong native size")
            self.assertEqual(entry.get("runtime_size"), [native_size[0] * SCALE, native_size[1] * SCALE], f"{item_id}: wrong runtime size")
            self.assertEqual(len(entry.get("source_rect", [])), 4, f"{item_id}: source_rect must be explicit")
            self.assertEqual(len(entry.get("safe_area", [])), 4, f"{item_id}: safe_area must be explicit")
            self.assertIn("intended_godot_use", entry, f"{item_id}: missing intended Godot use")

    def test_reference_and_contact_sheet_exist(self) -> None:
        self.assertTrue(REFERENCE.exists(), "stable reference sheet is missing")
        reference = load_image(REFERENCE)
        self.assertEqual(reference.size, (2048, 1024), "stable reference sheet must be 2048x1024 for fixed 4x2 crops")
        self.assertTrue(CONTACT_SHEET.exists(), "contact sheet is missing")
        contact = load_image(CONTACT_SHEET)
        self.assertGreaterEqual(contact.width, 900, "contact sheet is too narrow to review")
        self.assertGreaterEqual(contact.height, 600, "contact sheet is too short to review")

    def test_native_and_runtime_assets_are_valid(self) -> None:
        for item_id, native_size in EXPECTED_ITEMS.items():
            native_path = SOURCE / f"{item_id}_native.png"
            runtime_path = RUNTIME / f"{item_id}.png"
            self.assertTrue(native_path.exists(), f"{item_id}: native file missing")
            self.assertTrue(runtime_path.exists(), f"{item_id}: runtime file missing")

            native = load_image(native_path).convert("RGBA")
            runtime = load_image(runtime_path).convert("RGBA")
            self.assertEqual(native.size, native_size, f"{item_id}: native size mismatch")
            self.assertEqual(runtime.size, (native.width * SCALE, native.height * SCALE), f"{item_id}: runtime size mismatch")
            self.assertEqual(runtime.tobytes(), native.resize(runtime.size, Image.Resampling.NEAREST).tobytes(), f"{item_id}: runtime is not exact nearest-neighbor export")

            alpha_extrema = native.getchannel("A").getextrema()
            self.assertEqual(alpha_extrema[0], 0, f"{item_id}: native needs transparent pixels")
            self.assertGreater(alpha_extrema[1], 0, f"{item_id}: native has no visible pixels")
            self.assertGreaterEqual(visible_pixel_count(native), max(12, native.width * native.height // 8), f"{item_id}: too few visible pixels")
            bbox_width, bbox_height = alpha_bbox_size(native)
            self.assertGreaterEqual(bbox_width, max(4, native.width // 3), f"{item_id}: alpha bbox too narrow")
            self.assertGreaterEqual(bbox_height, max(4, native.height // 3), f"{item_id}: alpha bbox too short")
            self.assertEqual(chroma_fringe_pixels(native), 0, f"{item_id}: native contains visible magenta chroma-key fringe pixels")

    def test_runtime_files_do_not_reference_raw_sources(self) -> None:
        forbidden = [
            "art_sources/generated_raw/mine_investigation",
            "assets/source/investigation/mine_items/reference",
            "mine_item_sheet_v1.png",
        ]
        checked_roots = [ROOT / "scripts" / "ui", ROOT / "scenes" / "ui"]
        for root in checked_roots:
            for path in root.rglob("*"):
                if path.suffix not in {".gd", ".tscn", ".tres"}:
                    continue
                text = path.read_text(encoding="utf-8", errors="ignore")
                for marker in forbidden:
                    self.assertNotIn(marker, text.replace("\\", "/"), f"{path.relative_to(ROOT)} references raw/reference art")


if __name__ == "__main__":
    unittest.main(verbosity=2)
