from pathlib import Path
import json
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "ui" / "menu_brush_hover_marker_base.png"
MANIFEST = ROOT / "assets" / "source" / "ui" / "menu_accent_manifest.json"
RAW = ROOT / "art_sources" / "generated_raw" / "menu_hover_marker"
RUNTIME = ROOT / "assets" / "textures" / "ui"
MARKER_PATHS = [
    RUNTIME / "menu_brush_hover_marker_1.png",
    RUNTIME / "menu_brush_hover_marker_2.png",
    RUNTIME / "menu_brush_hover_marker_3.png",
    RUNTIME / "menu_brush_hover_marker_4.png",
]


def load_rgba(path: Path) -> Image.Image:
    if not path.exists():
        raise AssertionError(f"{path}: missing image")
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixels(image: Image.Image) -> int:
    return sum(image.getchannel("A").histogram()[1:])


class MenuAccentAssetPipelineTest(unittest.TestCase):
    def test_manifest_records_hover_marker_variants(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        assets = manifest.get("assets", {})
        for index, path in enumerate(MARKER_PATHS, start=1):
            asset_id = f"menu_brush_hover_marker_{index}"
            raw_path = f"art_sources/generated_raw/menu_hover_marker/menu_brush_hover_marker_generated_{index}.png"
            with self.subTest(asset_id=asset_id):
                self.assertIn(asset_id, assets)
                self.assertEqual(assets[asset_id]["source_file"], raw_path)
                self.assertEqual(assets[asset_id]["output_file"], f"assets/textures/ui/{path.name}")
                self.assertEqual(assets[asset_id]["size"], [243, 28])
                self.assertEqual(assets[asset_id]["safe_area"], [16, 6, 211, 16])
                self.assertEqual(len(assets[asset_id]["source_crop"]), 4)

    def test_hover_marker_variants_keep_current_marker_style(self) -> None:
        source = load_rgba(SOURCE)
        self.assertEqual(source.size, (243, 28))
        self.assertGreater(visible_pixels(source), 4200)

        variant_bytes: set[bytes] = set()
        for index, path in enumerate(MARKER_PATHS, start=1):
            with self.subTest(path=path.name):
                raw_source = RAW / f"menu_brush_hover_marker_generated_{index}.png"
                self.assertTrue(raw_source.exists(), f"{raw_source}: missing generated source")
                image = load_rgba(path)
                self.assertEqual(image.size, source.size)
                self.assertGreater(visible_pixels(image), 3300)
                self.assertLess(visible_pixels(image), 5600)
                self.assertIsNotNone(image.getchannel("A").getbbox())
                variant_bytes.add(image.tobytes())

        self.assertEqual(len(variant_bytes), len(MARKER_PATHS), "hover marker variants must be visually distinct")


if __name__ == "__main__":
    unittest.main(verbosity=2)
