import json
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "intro"
REFERENCE = SOURCE / "reference"
RUNTIME = ROOT / "assets" / "textures" / "intro"
INTRO_DATA = ROOT / "data" / "intro.json"
NATIVE_SIZE = (320, 180)
RUNTIME_SIZE = (1280, 720)
SCALE = 4
STILLS = [
    "intro_descent",
    "intro_hearth_memory",
    "intro_tavern_dark",
    "intro_rusted_key",
    "intro_threshold",
]
REFERENCE_FILES = [*STILLS, "tavern_continuity_master"]


def load_image(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.copy()


class IntroAssetPipelineTest(unittest.TestCase):
    def test_approved_references_exist(self) -> None:
        for name in REFERENCE_FILES:
            path = REFERENCE / f"{name}.png"
            self.assertTrue(path.exists(), f"{path}: missing approved reference")
            image = load_image(path)
            self.assertGreaterEqual(image.width, RUNTIME_SIZE[0], f"{name}: reference is too narrow")
            self.assertGreaterEqual(image.height, RUNTIME_SIZE[1], f"{name}: reference is too short")

    def test_native_and_runtime_files_exist_at_expected_sizes(self) -> None:
        self.assertEqual(
            RUNTIME_SIZE,
            (NATIVE_SIZE[0] * SCALE, NATIVE_SIZE[1] * SCALE),
            "runtime size must be an integer-scale export of the native grid",
        )
        for name in STILLS:
            native_path = SOURCE / f"{name}_native.png"
            runtime_path = RUNTIME / f"{name}.png"
            self.assertTrue(native_path.exists(), f"{native_path}: missing native source")
            self.assertTrue(runtime_path.exists(), f"{runtime_path}: missing runtime texture")

            native = load_image(native_path)
            runtime = load_image(runtime_path)
            self.assertEqual(native.size, NATIVE_SIZE, f"{name}: wrong native size")
            self.assertEqual(runtime.size, RUNTIME_SIZE, f"{name}: wrong runtime size")

    def test_runtime_manifest_uses_the_five_pipeline_textures_in_order(self) -> None:
        with INTRO_DATA.open(encoding="utf-8") as handle:
            intro_data = json.load(handle)

        actual = [beat["image"] for beat in intro_data["beats"]]
        expected = [f"res://assets/textures/intro/{name}.png" for name in STILLS]
        self.assertEqual(actual, expected)


if __name__ == "__main__":
    unittest.main(verbosity=2)
