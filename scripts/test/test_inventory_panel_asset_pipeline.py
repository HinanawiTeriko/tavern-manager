from pathlib import Path
import json
import unittest

from PIL import Image, ImageFilter, ImageStat


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "source" / "ui" / "inventory_panel" / "inventory_panel_manifest.json"


def load_image(path: Path) -> Image.Image:
    if not path.exists():
        raise AssertionError(f"{path}: missing image")
    with Image.open(path) as image:
        return image.copy()


class InventoryPanelAssetPipelineTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        with MANIFEST.open(encoding="utf-8") as handle:
            cls.manifest = json.load(handle)

    def test_manifest_and_generated_source_exist(self) -> None:
        asset = self.manifest["asset"]
        self.assertEqual(asset["id"], "inventory_panel")
        source = ROOT / asset["source_file"]
        self.assertTrue(source.exists(), "missing generated inventory panel source")
        self.assertNotIn("inventory_panel_v1", asset["source_file"], "do not ship the rejected thick-frame panel")
        source_image = load_image(source)
        self.assertEqual(source_image.size, tuple(asset["source_size"]))
        self.assertIn("safe_area", asset)
        self.assertIn("nine_slice_margins", asset)
        self.assertIn("intended_godot_use", asset)

    def test_panel_uses_thin_carrier_margins(self) -> None:
        asset = self.manifest["asset"]
        margins = asset["nine_slice_margins"]
        content = asset["content_margins"]
        self.assertLessEqual(max(margins), 32, "inventory carrier must not read as a thick oversized slot")
        self.assertLessEqual(max(content), 56, "inventory carrier art should not force the old UI into a tiny center")

    def test_runtime_panel_is_exact_nearest_export(self) -> None:
        asset = self.manifest["asset"]
        scale = int(self.manifest["runtime_scale"])
        native = load_image(ROOT / asset["native_file"])
        runtime = load_image(ROOT / asset["output_file"])
        self.assertEqual(native.size, tuple(asset["native_size"]))
        self.assertEqual(runtime.size, tuple(asset["runtime_size"]))
        expected = native.resize((native.width * scale, native.height * scale), Image.Resampling.NEAREST)
        self.assertEqual(runtime.tobytes(), expected.tobytes(), "runtime is not an exact nearest export")

    def test_panel_is_a_subtle_dark_carrier(self) -> None:
        asset = self.manifest["asset"]
        runtime = load_image(ROOT / asset["output_file"]).convert("RGBA")
        center = runtime.crop((120, 132, 500, 410)).convert("RGB")
        full = runtime.convert("RGB")
        center_luma = sum(ImageStat.Stat(center).mean) / 3
        full_edge = sum(ImageStat.Stat(full.filter(ImageFilter.FIND_EDGES)).mean) / 3
        self.assertLess(center_luma, 38, "inventory panel center is too bright for readable grid slots")
        self.assertLess(full_edge, 8, "inventory panel art is too busy behind grid slots")

    def test_panel_does_not_bake_inventory_slots(self) -> None:
        asset = self.manifest["asset"]
        runtime = load_image(ROOT / asset["output_file"]).convert("RGBA")
        center = runtime.crop((108, 120, 512, 424)).convert("RGB")
        edges = ImageStat.Stat(center.filter(ImageFilter.FIND_EDGES)).mean
        self.assertLess(sum(edges) / 3, 9, "inventory panel center has too much baked slot-like structure")

    def test_contact_sheet_exists(self) -> None:
        sheet = ROOT / self.manifest["contact_sheet"]
        self.assertTrue(sheet.exists(), f"{sheet}: missing contact sheet")
        image = load_image(sheet)
        self.assertGreaterEqual(image.width, 620)
        self.assertGreaterEqual(image.height, 540)


if __name__ == "__main__":
    unittest.main(verbosity=2)
