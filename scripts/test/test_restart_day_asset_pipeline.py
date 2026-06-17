from pathlib import Path
import json
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_sources" / "generated_raw" / "restart_day"
SOURCE = ROOT / "assets" / "source" / "ui" / "restart_day"
RUNTIME = ROOT / "assets" / "textures" / "ui" / "restart_day"
MANIFEST = SOURCE / "restart_day_manifest.json"
EXPORTER = ROOT / "scripts" / "tools" / "export_restart_day_assets.py"
CONTACT_SHEET = ROOT / "docs" / "art" / "restart_day" / "restart_day_contact_sheet.png"

ASSET_SIZES = {
    "restart_day_button_normal": ((42, 18), (168, 72)),
    "restart_day_button_hover": ((42, 18), (168, 72)),
    "restart_day_button_pressed": ((42, 18), (168, 72)),
    "restart_day_clock_face": ((104, 104), (416, 416)),
    "restart_day_clock_hand": ((16, 62), (64, 248)),
    "restart_day_event_panel": ((112, 104), (448, 416)),
}
BUTTONS = (
    "restart_day_button_normal",
    "restart_day_button_hover",
    "restart_day_button_pressed",
)


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixel_count(image: Image.Image) -> int:
    return sum(image.getchannel("A").histogram()[1:])


def alpha_bbox_size(image: Image.Image) -> tuple[int, int]:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        return (0, 0)
    left, top, right, bottom = bbox
    return (right - left, bottom - top)


def assert_exact_native_export(
    test_case: unittest.TestCase,
    name: str,
    native_size: tuple[int, int],
    runtime_size: tuple[int, int],
) -> Image.Image:
    native_path = SOURCE / f"{name}_native.png"
    runtime_path = RUNTIME / f"{name}.png"
    test_case.assertTrue(native_path.exists(), f"{native_path}: missing native source")
    test_case.assertTrue(runtime_path.exists(), f"{runtime_path}: missing runtime texture")
    native = load_rgba(native_path)
    runtime = load_rgba(runtime_path)
    test_case.assertEqual(native.size, native_size, f"{name}: wrong native size")
    test_case.assertEqual(runtime.size, runtime_size, f"{name}: wrong runtime size")
    test_case.assertGreater(visible_pixel_count(native), 0, f"{name}: empty or transparent native")
    expected = native.resize(runtime_size, Image.Resampling.NEAREST)
    test_case.assertEqual(runtime.tobytes(), expected.tobytes(), f"{name}: runtime is not exact nearest export")
    return native


class RestartDayAssetPipelineTest(unittest.TestCase):
    def test_raw_ai_source_and_prompt_are_retained(self) -> None:
        required = [
            RAW / "restart_day_controls_source_v1.png",
            RAW / "restart_day_controls_prompt_v1.txt",
            MANIFEST,
        ]
        for path in required:
            self.assertTrue(path.exists(), f"{path}: required source contract missing")
            self.assertGreater(path.stat().st_size, 0, f"{path}: empty source contract")
        raw = load_rgba(RAW / "restart_day_controls_source_v1.png")
        self.assertGreaterEqual(raw.width, 1024)
        self.assertGreaterEqual(raw.height, 1024)

    def test_manifest_declares_fixed_crops_and_runtime_paths(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["id"], "restart_day_clock_rewind_v1")
        self.assertEqual(manifest["source"], "art_sources/generated_raw/restart_day/restart_day_controls_source_v1.png")
        self.assertEqual(manifest["prompt"], "art_sources/generated_raw/restart_day/restart_day_controls_prompt_v1.txt")
        self.assertEqual(set(manifest["assets"].keys()), set(ASSET_SIZES.keys()))
        for name, entry in manifest["assets"].items():
            self.assertEqual(entry["id"], name)
            self.assertEqual(entry["source"], manifest["source"])
            self.assertEqual(len(entry["source_rect"]), 4, f"{name}: missing fixed source rect")
            self.assertEqual(entry["native"], f"assets/source/ui/restart_day/{name}_native.png")
            self.assertEqual(entry["runtime"], f"assets/textures/ui/restart_day/{name}.png")
            self.assertEqual(entry["native_size"], list(ASSET_SIZES[name][0]))
            self.assertEqual(entry["runtime_size"], list(ASSET_SIZES[name][1]))
            self.assertEqual(len(entry["safe_area_native"]), 4, f"{name}: missing safe area")
            self.assertNotIn("generated_raw", entry["runtime"], f"{name}: runtime must not reference raw source")

    def test_exporter_derives_from_ai_source_not_procedural_decoration(self) -> None:
        source = EXPORTER.read_text(encoding="utf-8")
        self.assertIn("restart_day_controls_source_v1.png", source)
        self.assertIn("restart_day_manifest.json", source)
        self.assertNotIn("ImageDraw", source)
        self.assertNotIn("rounded_rectangle", source)
        self.assertNotIn("line(", source)
        self.assertNotIn("polygon(", source)
        self.assertNotIn(".text(", source)

    def test_assets_are_exact_native_exports(self) -> None:
        button_bytes: list[bytes] = []
        button_bbox_sizes: set[tuple[int, int]] = set()
        for name, (native_size, runtime_size) in ASSET_SIZES.items():
            native = assert_exact_native_export(self, name, native_size, runtime_size)
            if name in BUTTONS:
                button_bytes.append(native.tobytes())
                button_bbox_sizes.add(alpha_bbox_size(native))
        self.assertEqual(len(set(button_bytes)), len(BUTTONS), "restart button states must be distinct")
        self.assertEqual(len(button_bbox_sizes), 1, "restart button alpha bounds must not shift between states")

    def test_contact_sheet_exists(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), "restart day contact sheet must be exported")
        self.assertGreater(CONTACT_SHEET.stat().st_size, 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
