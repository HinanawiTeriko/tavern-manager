from pathlib import Path
import json
import unittest

from PIL import Image, ImageStat


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "source" / "ui" / "inventory_grid_slot" / "inventory_grid_slot_manifest.json"


def load_image(path: Path) -> Image.Image:
    if not path.exists():
        raise AssertionError(f"{path}: missing image")
    with Image.open(path) as image:
        return image.copy()


class InventoryGridSlotAssetPipelineTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        with MANIFEST.open(encoding="utf-8") as handle:
            cls.manifest = json.load(handle)

    def test_generated_sources_and_manifest_entries_exist(self) -> None:
        self.assertNotIn("source_file", self.manifest, "manifest should use per-state source files")
        for asset in self.manifest["assets"]:
            self.assertIn("id", asset)
            self.assertNotIn("source_rect", asset, f"{asset['id']}: independent sources must not be cropped")
            source = ROOT / asset["source_file"]
            self.assertTrue(source.exists(), f"{asset['id']}: missing source")
            source_image = load_image(source)
            self.assertEqual(source_image.size, (1254, 1254), f"{asset['id']}: wrong source size")
            self.assertIn("output_file", asset)
            self.assertIn("runtime_size", asset)
            self.assertIn("safe_area", asset)
            self.assertIn("intended_godot_use", asset)

    def test_native_and_runtime_assets_are_exact_nearest_exports(self) -> None:
        scale = int(self.manifest["runtime_scale"])
        for asset in self.manifest["assets"]:
            native = load_image(ROOT / asset["native_file"])
            runtime = load_image(ROOT / asset["output_file"])
            native_size = tuple(asset["native_size"])
            runtime_size = tuple(asset["runtime_size"])
            self.assertEqual(native.size, native_size, f"{asset['id']}: wrong native size")
            self.assertEqual(runtime.size, runtime_size, f"{asset['id']}: wrong runtime size")
            expected = native.resize((native.width * scale, native.height * scale), Image.Resampling.NEAREST)
            self.assertEqual(runtime.tobytes(), expected.tobytes(), f"{asset['id']}: runtime is not nearest export")

    def test_slot_art_has_visible_frame_and_dark_center(self) -> None:
        for asset in self.manifest["assets"]:
            runtime = load_image(ROOT / asset["output_file"]).convert("RGBA")
            center = runtime.crop((24, 24, 56, 56)).convert("RGB")
            frame_edges = [
                runtime.crop((12, 8, 68, 18)).convert("RGBA"),
                runtime.crop((8, 12, 18, 68)).convert("RGBA"),
                runtime.crop((12, 62, 68, 72)).convert("RGBA"),
                runtime.crop((62, 12, 72, 68)).convert("RGBA"),
            ]
            center_luma = sum(ImageStat.Stat(center).mean) / 3
            self.assertLess(center_luma, 38, f"{asset['id']}: center is not dark enough")
            for edge in frame_edges:
                alpha = edge.getchannel("A")
                visible = sum(alpha.histogram()[1:])
                self.assertGreater(
                    visible,
                    edge.width * edge.height * 0.35,
                    f"{asset['id']}: frame edge is too sparse",
                )

    def test_runtime_slots_do_not_include_top_black_background_strip(self) -> None:
        for asset in self.manifest["assets"]:
            runtime = load_image(ROOT / asset["output_file"]).convert("RGBA")
            top_rows = [
                runtime.getpixel((x, y))
                for y in range(0, 6)
                for x in range(runtime.width)
            ]
            opaque_black = sum(
                1 for r, g, b, a in top_rows
                if a > 0 and r < 8 and g < 8 and b < 8
            )
            self.assertLess(
                opaque_black,
                runtime.width,
                f"{asset['id']}: top edge still contains an opaque black source strip",
            )

    def test_contact_sheet_exists(self) -> None:
        sheet = ROOT / self.manifest["contact_sheet"]
        self.assertTrue(sheet.exists(), f"{sheet}: missing contact sheet")
        image = load_image(sheet)
        self.assertGreaterEqual(image.width, 700)
        self.assertGreaterEqual(image.height, 140)


if __name__ == "__main__":
    unittest.main(verbosity=2)
