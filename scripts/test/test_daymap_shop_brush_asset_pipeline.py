from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "daymap" / "shop_brush"
REFERENCE = SOURCE / "reference"
RUNTIME = ROOT / "assets" / "textures" / "daymap" / "shop_brush"
EXPORTER = ROOT / "scripts" / "tools" / "export_daymap_shop_brush_assets.py"
MENU_SOURCE = ROOT / "assets" / "source" / "ui" / "menu_brush_components_approved.png"
SHOP_UI_CHROMA_REFERENCE = REFERENCE / "shop_ui_chroma_reference_v3.png"
SHOP_BACKDROP_REFERENCE = REFERENCE / "shop_clean_background_reference_v2.png"
MENU_RUNTIME_ASSETS = [
    ROOT / "assets" / "textures" / "ui" / "menu_brush_panel.png",
    ROOT / "assets" / "textures" / "ui" / "menu_brush_band.png",
    ROOT / "assets" / "textures" / "ui" / "menu_brush_tab.png",
]

EXPECTED_ASSETS = {
    "shop_brush_backdrop": ((320, 180), (1280, 720)),
    "shop_brush_panel_list": ((190, 99), (760, 396)),
    "shop_brush_panel_detail": ((90, 99), (360, 396)),
    "shop_brush_row_normal": ((145, 16), (580, 64)),
    "shop_brush_row_hover": ((145, 16), (580, 64)),
    "shop_brush_row_selected": ((145, 16), (580, 64)),
    "shop_brush_row_disabled": ((145, 16), (580, 64)),
    "shop_brush_checkout_strip": ((260, 32), (1040, 128)),
    "shop_brush_category_normal": ((48, 16), (192, 64)),
    "shop_brush_category_selected": ((48, 16), (192, 64)),
    "shop_brush_button_normal": ((64, 18), (256, 72)),
    "shop_brush_button_hover": ((64, 18), (256, 72)),
    "shop_brush_button_pressed": ((64, 18), (256, 72)),
    "shop_brush_button_disabled": ((64, 18), (256, 72)),
    "shop_brush_close_normal": ((18, 18), (72, 72)),
    "shop_brush_close_hover": ((18, 18), (72, 72)),
    "shop_brush_close_pressed": ((18, 18), (72, 72)),
    "shop_brush_gold_area": ((36, 14), (144, 56)),
    "shop_brush_quantity_minus": ((18, 18), (72, 72)),
    "shop_brush_quantity_body": ((44, 18), (176, 72)),
    "shop_brush_quantity_plus": ((18, 18), (72, 72)),
    "shop_brush_status_owned": ((14, 12), (56, 48)),
    "shop_brush_status_discount": ((14, 13), (56, 52)),
    "shop_brush_divider": ((180, 4), (720, 16)),
}


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixel_count(image: Image.Image) -> int:
    return sum(image.getchannel("A").histogram()[1:])


def dark_teal_readable_ratio(image: Image.Image) -> float:
    crop = image.crop((
        image.width // 8,
        image.height // 8,
        image.width - image.width // 8,
        image.height - image.height // 8,
    ))
    pixels = list(crop.get_flattened_data())
    visible = [
        (red, green, blue, alpha)
        for red, green, blue, alpha in pixels
        if alpha >= 120
    ]
    if not visible:
        return 0.0
    readable = [
        p for p in visible
        if p[0] <= 70 and 18 <= p[1] <= 105 and 18 <= p[2] <= 110
    ]
    return len(readable) / len(visible)


def amber_ratio(image: Image.Image) -> float:
    visible = 0
    amber = 0
    for red, green, blue, alpha in image.get_flattened_data():
        if alpha <= 0:
            continue
        visible += 1
        if red >= 170 and 55 <= green <= 180 and blue <= 105:
            amber += 1
    return amber / max(1, visible)


def magenta_fringe_ratio(image: Image.Image) -> float:
    visible = 0
    fringe = 0
    for red, green, blue, alpha in image.get_flattened_data():
        if alpha <= 0:
            continue
        visible += 1
        if red >= 70 and blue >= 70 and green <= 80 and red > green * 1.45 and blue > green * 1.45:
            fringe += 1
    return fringe / max(1, visible)


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
    test_case.assertGreater(visible_pixel_count(native), 0, f"{name}: has no visible pixels")
    expected = native.resize(runtime_size, Image.Resampling.NEAREST)
    test_case.assertEqual(runtime.tobytes(), expected.tobytes(), f"{name}: not exact nearest export")
    return native


class DayMapShopBrushAssetPipelineTest(unittest.TestCase):
    def test_exporter_uses_approved_brush_source_as_style_input(self) -> None:
        self.assertTrue(EXPORTER.exists(), f"{EXPORTER}: missing shop brush exporter")
        source = EXPORTER.read_text(encoding="utf-8")
        self.assertIn("shop_ui_chroma_reference_v3.png", source)
        self.assertIn("shop_clean_background_reference_v2.png", source)
        self.assertIn("menu_brush_components_approved.png", source)
        self.assertIn("SHOP_UI_CHROMA_REFERENCE", source)
        self.assertIn("SHOP_BACKDROP_REFERENCE", source)
        self.assertIn("save_pair", source)
        self.assertIn("remove_chroma_background", source)
        self.assertNotIn("soften_selected", source)
        self.assertNotIn("add_amber_edge", source)
        self.assertNotIn("assets/textures/ui/menu_brush_panel.png", source)
        self.assertNotIn("assets/textures/ui/menu_brush_band.png", source)
        self.assertNotIn("assets/textures/ui/menu_brush_tab.png", source)

    def test_reference_source_is_retained(self) -> None:
        retained = REFERENCE / "menu_brush_components_approved.png"
        self.assertTrue(MENU_SOURCE.exists(), f"{MENU_SOURCE}: missing approved menu brush source")
        self.assertTrue(retained.exists(), f"{retained}: missing retained shop brush reference source")
        self.assertEqual(load_rgba(retained).size, load_rgba(MENU_SOURCE).size)
        self.assertTrue(SHOP_UI_CHROMA_REFERENCE.exists(), f"{SHOP_UI_CHROMA_REFERENCE}: missing shop brush chroma UI reference")
        self.assertTrue(SHOP_BACKDROP_REFERENCE.exists(), f"{SHOP_BACKDROP_REFERENCE}: missing shop brush backdrop reference")
        self.assertGreater(SHOP_UI_CHROMA_REFERENCE.stat().st_size, 0)
        self.assertGreater(SHOP_BACKDROP_REFERENCE.stat().st_size, 0)

    def test_shop_brush_assets_are_exact_native_exports(self) -> None:
        for name, (native_size, runtime_size) in EXPECTED_ASSETS.items():
            with self.subTest(name=name):
                assert_exact_native_export(self, name, native_size, runtime_size)

    def test_shop_brush_assets_are_derived_not_runtime_reuse(self) -> None:
        menu_runtime_bytes = []
        for path in MENU_RUNTIME_ASSETS:
            self.assertTrue(path.exists(), f"{path}: missing menu runtime comparison asset")
            menu_runtime_bytes.append((load_rgba(path).size, load_rgba(path).tobytes()))

        for name in EXPECTED_ASSETS:
            runtime = load_rgba(RUNTIME / f"{name}.png")
            with self.subTest(name=name):
                for menu_size, menu_bytes in menu_runtime_bytes:
                    self.assertFalse(
                        runtime.size == menu_size and runtime.tobytes() == menu_bytes,
                        f"{name}: directly reuses a menu runtime texture",
                    )

    def test_main_surfaces_keep_dark_readable_centers(self) -> None:
        for name in ["shop_brush_panel_list", "shop_brush_panel_detail", "shop_brush_row_normal", "shop_brush_checkout_strip"]:
            with self.subTest(name=name):
                native = load_rgba(SOURCE / f"{name}_native.png")
                self.assertGreaterEqual(
                    dark_teal_readable_ratio(native),
                    0.45,
                    f"{name}: center is not dark teal readable brush material",
                )

    def test_quantity_stepper_icons_are_preserved(self) -> None:
        for name in ["shop_brush_quantity_minus", "shop_brush_quantity_plus"]:
            with self.subTest(name=name):
                native = load_rgba(SOURCE / f"{name}_native.png")
                self.assertGreater(
                    amber_ratio(native),
                    0.015,
                    f"{name}: missing the amber stepper icon after cropping",
                )

    def test_selected_row_is_a_subtle_state_not_full_orange_bar(self) -> None:
        selected = load_rgba(SOURCE / "shop_brush_row_selected_native.png")
        self.assertLessEqual(amber_ratio(selected), 0.12, "selected row amber bar is too heavy")

    def test_selected_category_is_a_subtle_state_not_full_orange_tab(self) -> None:
        selected = load_rgba(SOURCE / "shop_brush_category_selected_native.png")
        self.assertLessEqual(amber_ratio(selected), 0.12, "selected category amber block is too heavy")

    def test_state_assets_are_distinct(self) -> None:
        groups = [
            ["shop_brush_row_normal", "shop_brush_row_hover", "shop_brush_row_selected", "shop_brush_row_disabled"],
            ["shop_brush_category_normal", "shop_brush_category_selected"],
            ["shop_brush_button_normal", "shop_brush_button_hover", "shop_brush_button_pressed", "shop_brush_button_disabled"],
            ["shop_brush_close_normal", "shop_brush_close_hover", "shop_brush_close_pressed"],
        ]
        for group in groups:
            seen: set[bytes] = set()
            for name in group:
                with self.subTest(name=name):
                    data = load_rgba(SOURCE / f"{name}_native.png").tobytes()
                    self.assertNotIn(data, seen, f"{name}: state art duplicates another state")
                    seen.add(data)

    def test_amber_is_sparse_except_selected_and_purchase_states(self) -> None:
        exempt = {
            "shop_brush_row_selected",
            "shop_brush_category_selected",
            "shop_brush_button_hover",
            "shop_brush_button_pressed",
            "shop_brush_close_hover",
            "shop_brush_close_pressed",
            "shop_brush_quantity_minus",
            "shop_brush_quantity_plus",
            "shop_brush_status_owned",
            "shop_brush_status_discount",
        }
        for name in EXPECTED_ASSETS:
            if name in exempt:
                continue
            with self.subTest(name=name):
                native = load_rgba(SOURCE / f"{name}_native.png")
                self.assertLessEqual(amber_ratio(native), 0.18, f"{name}: amber overused")

    def test_chroma_key_edges_are_clean(self) -> None:
        for name in EXPECTED_ASSETS:
            if name == "shop_brush_backdrop":
                continue
            with self.subTest(name=name):
                native = load_rgba(SOURCE / f"{name}_native.png")
                self.assertLessEqual(
                    magenta_fringe_ratio(native),
                    0.002,
                    f"{name}: visible magenta fringe remains after chroma extraction",
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
