from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "tavern"
RUNTIME = ROOT / "assets" / "textures" / "tavern"
REFERENCE = SOURCE / "reference"
SCALE = 4

OPAQUE_ASSETS = {
    "background/tavern_bg": (320, 180),
    "ui/topbar": (320, 12),
    "ui/shortcut_bar": (300, 14),
    "ui/patience_bg": (80, 5),
    "ui/patience_fill": (80, 5),
    "ui/panel_menu": (175, 125),
    "ui/panel_inventory": (155, 135),
    "ui/panel_document": (320, 180),
}

TRANSPARENT_ASSETS = {
    "ui/shortcut_slot": (24, 10),
    "ui/order_bubble": (100, 28),
    "ui/list_row": (70, 10),
    "ui/scroll_track": (4, 80),
    "ui/scroll_grabber": (4, 16),
    "props/barrel": (54, 46),
    "props/grill": (80, 28),
    "props/pot": (56, 46),
    "props/spoon": (16, 64),
    "props/shaker": (28, 42),
    "props/ledger": (40, 28),
}

for state in ["normal", "hover", "pressed", "disabled"]:
    TRANSPARENT_ASSETS[f"ui/button_wide_{state}"] = (70, 18)
    TRANSPARENT_ASSETS[f"ui/button_small_{state}"] = (32, 12)
for state in ["normal", "selected"]:
    TRANSPARENT_ASSETS[f"ui/button_tab_{state}"] = (36, 12)
for name in ["close", "prev", "next"]:
    TRANSPARENT_ASSETS[f"ui/button_icon_{name}"] = (16, 16)

ITEM_KEYS = [
    "ale",
    "flour",
    "meat_raw",
    "grape",
    "herb",
    "bread",
    "meat_cooked",
    "ale_beer",
    "wine",
    "herb_tea",
    "meat_sand",
    "herbal_ale",
    "spiced_wine",
    "meat_stew",
    "herb_broth",
    "malt_porridge",
    "sleep_powder",
    "bloodied_contract",
    "alternative_contract",
    "toby_contract",
]
for key in ITEM_KEYS:
    TRANSPARENT_ASSETS[f"icons/{key}"] = (24, 24)


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixel_count(image: Image.Image) -> int:
    return sum(image.getchannel("A").histogram()[1:])


def exact_runtime_export(
    test_case: unittest.TestCase,
    name: str,
    native_size: tuple[int, int],
) -> Image.Image:
    native_path = SOURCE / f"{name}_native.png"
    runtime_path = RUNTIME / f"{name}.png"
    test_case.assertTrue(native_path.exists(), f"{native_path}: missing native source")
    test_case.assertTrue(runtime_path.exists(), f"{runtime_path}: missing runtime texture")
    native = load_rgba(native_path)
    runtime = load_rgba(runtime_path)
    expected_size = (native_size[0] * SCALE, native_size[1] * SCALE)
    test_case.assertEqual(native.size, native_size, f"{name}: wrong native size")
    test_case.assertEqual(runtime.size, expected_size, f"{name}: wrong runtime size")
    expected = native.resize(expected_size, Image.Resampling.NEAREST)
    test_case.assertEqual(runtime.tobytes(), expected.tobytes(), f"{name}: not exact nearest export")
    return native


class TavernAssetPipelineTest(unittest.TestCase):
    def test_reference_art_is_retained(self) -> None:
        required = [
            "tavern_background_reference.png",
            "tavern_ui_reference.png",
            "tavern_props_reference.png",
            "tavern_icons_reference.png",
            "tavern_characters_reference.png",
        ]
        for filename in required:
            path = REFERENCE / filename
            self.assertTrue(path.exists(), f"{path}: missing retained generated reference")
            self.assertGreater(path.stat().st_size, 0, f"{path}: retained reference is empty")

    def test_opaque_assets_are_exact_native_exports(self) -> None:
        for name, native_size in OPAQUE_ASSETS.items():
            with self.subTest(name=name):
                native = exact_runtime_export(self, name, native_size)
                alpha_min, alpha_max = native.getchannel("A").getextrema()
                self.assertEqual((alpha_min, alpha_max), (255, 255), f"{name}: must be fully opaque")

    def test_transparent_assets_have_alpha_and_exact_runtime_exports(self) -> None:
        for name, native_size in TRANSPARENT_ASSETS.items():
            with self.subTest(name=name):
                native = exact_runtime_export(self, name, native_size)
                alpha_min, alpha_max = native.getchannel("A").getextrema()
                self.assertEqual(alpha_min, 0, f"{name}: needs transparent pixels")
                self.assertGreater(alpha_max, 0, f"{name}: has no visible pixels")
                self.assertGreater(visible_pixel_count(native), 8, f"{name}: too sparse")

    def test_background_matches_tavern_palette_guardrails(self) -> None:
        native = exact_runtime_export(self, "background/tavern_bg", (320, 180))
        pixels = list(native.getdata())
        dark = sum(1 for r, g, b, a in pixels if a >= 250 and max(r, g, b) <= 58)
        teal = sum(
            1
            for r, g, b, a in pixels
            if a >= 250 and b >= 34 and g >= 30 and b >= r * 1.05
        )
        warm = sum(
            1
            for r, g, b, a in pixels
            if a >= 250 and r >= 105 and g >= 45 and r >= b * 1.45
        )
        self.assertGreaterEqual(dark, 20000, "background needs enough dark dungeon mass")
        self.assertGreaterEqual(teal, 3000, "background needs visible teal depth")
        self.assertGreaterEqual(warm, 160, "background needs sparse amber light accents")
        self.assertLessEqual(warm, 10000, "background amber accents are flooding the frame")

    def test_text_carrier_assets_have_clear_safe_areas(self) -> None:
        cases = {
            "ui/topbar": (48, 2, 300, 10),
            "ui/order_bubble": (8, 5, 92, 23),
            "ui/panel_menu": (10, 12, 165, 113),
            "ui/panel_inventory": (8, 10, 147, 125),
            "ui/panel_document": (54, 28, 266, 148),
            "ui/list_row": (8, 2, 66, 8),
        }
        for name, box in cases.items():
            with self.subTest(name=name):
                native = load_rgba(SOURCE / f"{name}_native.png")
                left, top, right, bottom = box
                area = native.crop((left, top, right, bottom)).convert("RGBA")
                pixels = list(area.getdata())
                readable_dark = sum(1 for r, g, b, a in pixels if a >= 240 and max(r, g, b) <= 92)
                readable_paper = sum(
                    1
                    for r, g, b, a in pixels
                    if a >= 240 and 80 <= r <= 185 and 50 <= g <= 145 and 28 <= b <= 120
                )
                self.assertGreater(
                    readable_dark + readable_paper,
                    len(pixels) * 0.68,
                    f"{name}: text safe area is too noisy",
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
