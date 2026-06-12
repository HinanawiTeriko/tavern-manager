from pathlib import Path
import json
import subprocess
import sys
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art" / "ui2" / "source" / "shop_ledger_rebuild"
PIXEL = ROOT / "art" / "ui2" / "pixel" / "shop_ledger_rebuild"
REFERENCE = SOURCE / "shop_ledger_integrated_reference_user_v1.png"
NATIVE = SOURCE / "shop_ledger_integrated_native.png"
RUNTIME = PIXEL / "shop_ledger_integrated.png"
MANIFEST = PIXEL / "shop_ledger_rebuild_manifest_v1.json"
EXPORT_TOOL = ROOT / "scripts" / "tools" / "export_shop_ledger_rebuild_assets.py"
NATIVE_SIZE = (320, 180)
RUNTIME_SIZE = (1280, 720)
SCALE = 4


def load_image(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA")


def unique_color_count(image: Image.Image) -> int:
    return len(set(image.convert("RGB").getdata()))


class ShopLedgerRebuildAssetPipelineTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        result = subprocess.run([sys.executable, str(EXPORT_TOOL)], capture_output=True, text=True)
        if result.returncode != 0:
            raise AssertionError(
                "export_shop_ledger_rebuild_assets.py failed\n"
                f"stdout:\n{result.stdout}\n"
                f"stderr:\n{result.stderr}"
            )

    def test_integrated_reference_is_preserved_as_source_only(self) -> None:
        self.assertTrue(REFERENCE.exists(), f"missing source reference: {REFERENCE}")
        reference = load_image(REFERENCE)
        self.assertGreaterEqual(reference.width, 1200)
        self.assertGreaterEqual(reference.height, 650)
        self.assertFalse(str(RUNTIME).startswith(str(SOURCE)))

    def test_native_and_runtime_match_pixel_pipeline(self) -> None:
        native = load_image(NATIVE)
        runtime = load_image(RUNTIME)
        self.assertEqual(native.size, NATIVE_SIZE)
        self.assertEqual(runtime.size, RUNTIME_SIZE)
        expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
        self.assertEqual(runtime.tobytes(), expected.tobytes(), "runtime must be exact 4x nearest from native")

    def test_native_palette_is_limited_but_not_flat(self) -> None:
        native = load_image(NATIVE)
        color_count = unique_color_count(native)
        self.assertGreater(color_count, 16, "native image lost too much visual information")
        self.assertLessEqual(color_count, 96, "native image palette is too noisy for the project pixel UI")

    def test_manifest_records_source_and_runtime_contract(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"missing manifest: {MANIFEST}")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["pipeline"], "shop_ledger_rebuild_v1")
        self.assertEqual(manifest["source_file"], "art/ui2/source/shop_ledger_rebuild/shop_ledger_integrated_reference_user_v1.png")
        self.assertEqual(manifest["native_file"], "art/ui2/source/shop_ledger_rebuild/shop_ledger_integrated_native.png")
        self.assertEqual(manifest["runtime_file"], "art/ui2/pixel/shop_ledger_rebuild/shop_ledger_integrated.png")
        self.assertEqual(manifest["native_size"], list(NATIVE_SIZE))
        self.assertEqual(manifest["runtime_size"], list(RUNTIME_SIZE))
        self.assertEqual(manifest["scale"], SCALE)


if __name__ == "__main__":
    unittest.main(verbosity=2)
