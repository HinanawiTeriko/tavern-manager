from pathlib import Path
import json
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
BACKDROP_REFERENCE = ROOT / "art_sources" / "generated_raw" / "ledger_ui" / "ledger_overlay_background_reference_v2.png"
BACKDROP_PROMPT = ROOT / "art_sources" / "generated_raw" / "ledger_ui" / "ledger_overlay_background_prompt_v2.txt"
CONTROL_REFERENCE = ROOT / "art_sources" / "generated_raw" / "ledger_ui" / "ledger_controls_reference_v2.png"
CONTROL_PROMPT = ROOT / "art_sources" / "generated_raw" / "ledger_ui" / "ledger_controls_prompt_v2.txt"
UI_MANIFEST = ROOT / "assets" / "source" / "ledger" / "ui" / "ledger_ui_v2_manifest.json"
SOURCE = ROOT / "assets" / "source" / "ledger" / "ui"
RUNTIME = ROOT / "assets" / "textures" / "ledger" / "ui"

BACKDROP_NATIVE_SIZE = (320, 180)
BACKDROP_RUNTIME_SIZE = (1280, 720)
NAV_BUTTON_NATIVE_SIZE = (28, 30)
NAV_BUTTON_RUNTIME_SIZE = (112, 120)
CLOSE_BUTTON_NATIVE_SIZE = (24, 24)
CLOSE_BUTTON_RUNTIME_SIZE = (96, 96)
STATES = ["normal", "hover", "pressed"]


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixel_count(image: Image.Image) -> int:
    return sum(image.getchannel("A").histogram()[1:])


def image_pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    if hasattr(image, "get_flattened_data"):
        return list(image.get_flattened_data())
    return list(image.getdata())


def assert_exact_native_export(
    test_case: unittest.TestCase,
    native_path: Path,
    runtime_path: Path,
    native_size: tuple[int, int],
    runtime_size: tuple[int, int],
) -> Image.Image:
    test_case.assertTrue(native_path.exists(), f"{native_path}: missing native source")
    test_case.assertTrue(runtime_path.exists(), f"{runtime_path}: missing runtime texture")
    native = load_rgba(native_path)
    runtime = load_rgba(runtime_path)
    test_case.assertEqual(native.size, native_size, f"{native_path.name}: wrong native size")
    test_case.assertEqual(runtime.size, runtime_size, f"{runtime_path.name}: wrong runtime size")
    test_case.assertGreater(visible_pixel_count(native), 0, f"{native_path.name}: has no visible pixels")
    expected = native.resize(runtime_size, Image.Resampling.NEAREST)
    test_case.assertEqual(runtime.tobytes(), expected.tobytes(), f"{runtime_path.name}: not exact nearest export")
    return native


def alpha_bbox_size(image: Image.Image) -> tuple[int, int]:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        return (0, 0)
    left, top, right, bottom = bbox
    return (right - left, bottom - top)


class LedgerUiAssetPipelineTest(unittest.TestCase):
    def test_reference_art_is_retained_in_project(self) -> None:
        for path in [BACKDROP_REFERENCE, BACKDROP_PROMPT, CONTROL_REFERENCE, CONTROL_PROMPT, UI_MANIFEST]:
            self.assertTrue(path.exists(), f"{path}: ledger UI v2 source contract must be retained")
            self.assertGreater(path.stat().st_size, 0, f"{path}: empty")
        backdrop_reference = load_rgba(BACKDROP_REFERENCE)
        control_reference = load_rgba(CONTROL_REFERENCE)
        self.assertGreaterEqual(backdrop_reference.width, 1280, "backdrop reference should be high enough for native reduction")
        self.assertGreaterEqual(backdrop_reference.height, 720, "backdrop reference should be high enough for native reduction")
        self.assertGreaterEqual(control_reference.width, 900, "control sheet should be high enough for fixed crops")
        self.assertGreaterEqual(control_reference.height, 700, "control sheet should be high enough for fixed crops")

    def test_button_manifest_uses_explicit_fixed_crops(self) -> None:
        self.assertTrue(UI_MANIFEST.exists(), "ledger UI v2 manifest must exist")
        manifest = json.loads(UI_MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["id"], "ledger_ui_v2")
        self.assertEqual(manifest["backdrop"]["source"], "art_sources/generated_raw/ledger_ui/ledger_overlay_background_reference_v2.png")
        self.assertEqual(manifest["backdrop"]["prompt"], "art_sources/generated_raw/ledger_ui/ledger_overlay_background_prompt_v2.txt")
        self.assertEqual(manifest["controls"]["source"], "art_sources/generated_raw/ledger_ui/ledger_controls_reference_v2.png")
        self.assertEqual(manifest["controls"]["prompt"], "art_sources/generated_raw/ledger_ui/ledger_controls_prompt_v2.txt")
        self.assertEqual(manifest["backdrop"]["runtime"], "assets/textures/ledger/ui/ledger_overlay_backdrop.png")
        self.assertEqual(
            manifest["backdrop"]["text_safe_zones_native"],
            {"left": [70, 30, 134, 122], "right": [186, 30, 250, 122]},
            "ledger UI manifest must describe the inset text layout safe zones",
        )
        assets = manifest["controls"]["assets"]
        self.assertEqual(set(assets.keys()), {"button_nav_left", "button_nav_right", "button_close"})
        for base, contract in assets.items():
            self.assertEqual(set(contract["states"].keys()), set(STATES), f"{base}: missing a button state")
            crop_sizes: set[tuple[int, int]] = set()
            for state, state_contract in contract["states"].items():
                crop = state_contract["source_rect"]
                self.assertEqual(len(crop), 4, f"{base} {state}: crop must be an explicit fixed rect")
                self.assertGreater(crop[2] - crop[0], 0, f"{base} {state}: crop width must be positive")
                self.assertGreater(crop[3] - crop[1], 0, f"{base} {state}: crop height must be positive")
                crop_sizes.add((crop[2] - crop[0], crop[3] - crop[1]))
                self.assertEqual(
                    state_contract["runtime"],
                    f"assets/textures/ledger/ui/{base}_{state}.png",
                    f"{base} {state}: runtime path changed",
                )
            self.assertEqual(len(crop_sizes), 1, f"{base}: states must use the same source crop size to avoid visual scaling")

    def test_exporter_uses_generated_reference_not_procedural_shapes(self) -> None:
        exporter = ROOT / "scripts" / "tools" / "export_ledger_ui_assets.py"
        self.assertTrue(exporter.exists(), "ledger UI exporter must exist")
        source = exporter.read_text(encoding="utf-8")
        self.assertIn("ledger_overlay_background_reference_v2.png", source)
        self.assertIn("ledger_controls_reference_v2.png", source)
        self.assertIn("ledger_ui_v2_manifest.json", source)
        self.assertNotIn("ledger_overlay_reference_generated.png", source, "v2 ledger UI must not crop controls from the old backdrop")
        self.assertNotIn("ImageDraw", source, "ledger UI assets must derive from generated reference art")
        self.assertNotIn("ImageEnhance", source, "button states need authored/generated state art, not brightness variants")
        self.assertNotIn("fill_rect", source, "ledger UI exporter must not draw primitive rectangles")
        self.assertNotIn("set_pixel", source, "ledger UI exporter must not paint pixel primitives")

    def test_backdrop_is_exact_native_export(self) -> None:
        native = assert_exact_native_export(
            self,
            SOURCE / "ledger_overlay_backdrop_native.png",
            RUNTIME / "ledger_overlay_backdrop.png",
            BACKDROP_NATIVE_SIZE,
            BACKDROP_RUNTIME_SIZE,
        )
        pixels = image_pixels(native)
        parchment_pixels = sum(
            1 for red, green, blue, alpha in pixels
            if alpha >= 220 and 120 <= red <= 230 and 85 <= green <= 190 and 45 <= blue <= 130
        )
        dark_teal_pixels = sum(
            1 for red, green, blue, alpha in pixels
            if alpha >= 220 and red <= 45 and 15 <= green <= 90 and 18 <= blue <= 95
        )
        amber_pixels = sum(
            1 for red, green, blue, alpha in pixels
            if alpha >= 220 and red >= 160 and 70 <= green <= 175 and blue <= 85
        )
        self.assertGreaterEqual(parchment_pixels, 16000, "ledger backdrop needs readable parchment pages")
        self.assertGreaterEqual(dark_teal_pixels, 8000, "ledger backdrop needs dark tavern/table framing")
        self.assertGreaterEqual(amber_pixels, 80, "ledger backdrop needs sparse amber tabs or binding accents")

    def test_page_text_safe_zones_are_clean(self) -> None:
        native = load_rgba(SOURCE / "ledger_overlay_backdrop_native.png")
        safe_zones = {
            "left": (70, 30, 134, 122),
            "right": (186, 30, 250, 122),
        }
        for name, box in safe_zones.items():
            with self.subTest(page=name):
                crop = native.crop(box)
                pixels = image_pixels(crop)
                area = crop.width * crop.height
                parchment_pixels = sum(
                    1 for red, green, blue, alpha in pixels
                    if alpha >= 220 and 130 <= red <= 230 and 90 <= green <= 190 and 50 <= blue <= 140
                )
                dark_noise_pixels = sum(
                    1 for red, green, blue, alpha in pixels
                    if alpha >= 220 and red <= 95 and green <= 85 and blue <= 70
                )
                self.assertGreaterEqual(
                    parchment_pixels,
                    int(area * 0.82),
                    f"{name} page needs a mostly clean parchment reading area",
                )
                self.assertLessEqual(
                    dark_noise_pixels,
                    int(area * 0.035),
                    f"{name} page has too much ink/noise under body text",
                )

    def test_navigation_buttons_are_exact_native_exports(self) -> None:
        for base in ["button_nav_left", "button_nav_right"]:
            previous_bytes: bytes | None = None
            bbox_sizes: set[tuple[int, int]] = set()
            for state in STATES:
                with self.subTest(base=base, state=state):
                    native = assert_exact_native_export(
                        self,
                        SOURCE / f"{base}_{state}_native.png",
                        RUNTIME / f"{base}_{state}.png",
                        NAV_BUTTON_NATIVE_SIZE,
                        NAV_BUTTON_RUNTIME_SIZE,
                    )
                    current_bytes = native.tobytes()
                    if previous_bytes is not None:
                        self.assertNotEqual(current_bytes, previous_bytes, f"{base} {state} matches previous state")
                    previous_bytes = current_bytes
                    bbox_sizes.add(alpha_bbox_size(native))
            self.assertEqual(len(bbox_sizes), 1, f"{base}: button frame alpha bounds must not resize between states")

    def test_close_button_states_are_exact_native_exports(self) -> None:
        previous_bytes: bytes | None = None
        bbox_sizes: set[tuple[int, int]] = set()
        for state in STATES:
            with self.subTest(state=state):
                native = assert_exact_native_export(
                    self,
                    SOURCE / f"button_close_{state}_native.png",
                    RUNTIME / f"button_close_{state}.png",
                    CLOSE_BUTTON_NATIVE_SIZE,
                    CLOSE_BUTTON_RUNTIME_SIZE,
                )
                current_bytes = native.tobytes()
                if previous_bytes is not None:
                    self.assertNotEqual(current_bytes, previous_bytes, f"close {state} matches previous state")
                previous_bytes = current_bytes
                bbox_sizes.add(alpha_bbox_size(native))
        self.assertEqual(len(bbox_sizes), 1, "close button frame alpha bounds must not resize between states")


if __name__ == "__main__":
    unittest.main(verbosity=2)
