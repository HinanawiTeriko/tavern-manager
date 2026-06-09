from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
REFERENCE = ROOT / "assets" / "source" / "ledger" / "reference" / "ledger_overlay_reference_generated.png"
SOURCE = ROOT / "assets" / "source" / "ledger" / "ui"
RUNTIME = ROOT / "assets" / "textures" / "ledger" / "ui"

BACKDROP_NATIVE_SIZE = (320, 180)
BACKDROP_RUNTIME_SIZE = (1280, 720)
NAV_BUTTON_NATIVE_SIZE = (26, 22)
NAV_BUTTON_RUNTIME_SIZE = (104, 88)
CLOSE_BUTTON_NATIVE_SIZE = (128, 22)
CLOSE_BUTTON_RUNTIME_SIZE = (512, 88)
STATES = ["normal", "hover", "pressed"]


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixel_count(image: Image.Image) -> int:
    return sum(image.getchannel("A").histogram()[1:])


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


class LedgerUiAssetPipelineTest(unittest.TestCase):
    def test_reference_art_is_retained_in_project(self) -> None:
        self.assertTrue(REFERENCE.exists(), "generated ledger close-up reference must be retained")
        reference = load_rgba(REFERENCE)
        self.assertGreaterEqual(reference.width, 1280, "reference should be high enough for native reduction")
        self.assertGreaterEqual(reference.height, 720, "reference should be high enough for native reduction")

    def test_exporter_uses_generated_reference_not_procedural_shapes(self) -> None:
        exporter = ROOT / "scripts" / "tools" / "export_ledger_ui_assets.py"
        self.assertTrue(exporter.exists(), "ledger UI exporter must exist")
        source = exporter.read_text(encoding="utf-8")
        self.assertIn("ledger_overlay_reference_generated.png", source)
        self.assertNotIn("ImageDraw", source, "ledger UI assets must derive from generated reference art")
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
        pixels = list(native.get_flattened_data())
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
        self.assertGreaterEqual(parchment_pixels, 18000, "ledger backdrop needs readable parchment pages")
        self.assertGreaterEqual(dark_teal_pixels, 8000, "ledger backdrop needs dark tavern/table framing")
        self.assertGreaterEqual(amber_pixels, 80, "ledger backdrop needs sparse amber tabs or binding accents")

    def test_page_text_safe_zones_are_clean(self) -> None:
        native = load_rgba(SOURCE / "ledger_overlay_backdrop_native.png")
        safe_zones = {
            "left": (54, 30, 151, 137),
            "right": (171, 30, 268, 137),
        }
        for name, box in safe_zones.items():
            with self.subTest(page=name):
                crop = native.crop(box)
                pixels = list(crop.get_flattened_data())
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

    def test_close_button_states_are_exact_native_exports(self) -> None:
        previous_bytes: bytes | None = None
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


if __name__ == "__main__":
    unittest.main(verbosity=2)
