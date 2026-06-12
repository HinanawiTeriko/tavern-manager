import json
from pathlib import Path
import subprocess
import sys
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "daymap" / "shop_clean"
RUNTIME = ROOT / "assets" / "textures" / "daymap" / "shop_clean"
MANIFEST = SOURCE / "shop_clean_manifest.json"
EXPORT_SCRIPT = ROOT / "scripts" / "tools" / "export_shop_clean_assets.py"
BACKDROP_V7_RAW = ROOT / "art_sources" / "generated_raw" / "shop_clean" / "shop_clean_backdrop_v7_pouch_clear_retry2_generated_raw.png"
PURCHASE_SEAL_V3_RAW = ROOT / "art_sources" / "generated_raw" / "shop_clean" / "shop_clean_purchase_seal_v3_generated_raw.png"
CLOSE_TAG_V2_RAW = ROOT / "art_sources" / "generated_raw" / "shop_clean" / "shop_clean_close_tag_v2_generated_raw.png"
QUANTITY_CONTROLS_V5_RAW = ROOT / "art_sources" / "generated_raw" / "shop_clean" / "shop_clean_quantity_controls_v5_generated_raw.png"
TABS_V2_RAW = ROOT / "art_sources" / "generated_raw" / "shop_clean" / "shop_clean_tabs_v2_generated_raw.png"

EXPECTED = {
    "shop_clean_backdrop": ((320, 180), (1280, 720), False),
    "shop_clean_list_panel": ((170, 100), (680, 400), True),
    "shop_clean_detail_page_base": ((108, 130), (432, 520), True),
    "shop_clean_detail_title_slip": ((92, 16), (368, 64), True),
    "shop_clean_detail_body_panel": ((92, 52), (368, 208), True),
    "shop_clean_detail_uses_panel": ((92, 20), (368, 80), True),
    "shop_clean_gold_tag": ((36, 14), (144, 56), True),
    "shop_clean_tab_normal": ((42, 16), (168, 64), True),
    "shop_clean_tab_hover": ((42, 16), (168, 64), True),
    "shop_clean_tab_selected": ((42, 16), (168, 64), True),
    "shop_clean_item_row_normal": ((145, 16), (580, 64), True),
    "shop_clean_item_row_hover": ((145, 16), (580, 64), True),
    "shop_clean_item_row_selected": ((145, 16), (580, 64), True),
    "shop_clean_item_row_disabled": ((145, 16), (580, 64), True),
    "shop_clean_quantity_button_minus_normal": ((9, 9), (36, 36), True),
    "shop_clean_quantity_button_minus_hover": ((9, 9), (36, 36), True),
    "shop_clean_quantity_button_minus_disabled": ((9, 9), (36, 36), True),
    "shop_clean_quantity_button_plus_normal": ((9, 9), (36, 36), True),
    "shop_clean_quantity_button_plus_hover": ((9, 9), (36, 36), True),
    "shop_clean_quantity_button_plus_disabled": ((9, 9), (36, 36), True),
    "shop_clean_quantity_body": ((9, 9), (36, 36), True),
    "shop_clean_purchase_receipt": ((64, 18), (256, 72), True),
    "shop_clean_purchase_seal_normal": ((24, 24), (96, 96), True),
    "shop_clean_purchase_seal_hover": ((24, 24), (96, 96), True),
    "shop_clean_purchase_seal_pressed": ((24, 24), (96, 96), True),
    "shop_clean_purchase_seal_disabled": ((24, 24), (96, 96), True),
    "shop_clean_close_tag_normal": ((20, 32), (80, 128), True),
    "shop_clean_close_tag_hover": ((20, 32), (80, 128), True),
}

PURCHASE_SEAL_V3_BOXES = {
    "shop_clean_purchase_seal_normal": [13, 17, 269, 273],
    "shop_clean_purchase_seal_hover": [242, 17, 498, 273],
    "shop_clean_purchase_seal_pressed": [13, 253, 269, 509],
    "shop_clean_purchase_seal_disabled": [242, 253, 498, 509],
}

CLOSE_TAG_V2_BOXES = {
    "shop_clean_close_tag_normal": [31, 60, 266, 436],
    "shop_clean_close_tag_hover": [247, 60, 482, 436],
}

QUANTITY_CONTROLS_V3_BOXES = {
    "shop_clean_quantity_button_minus_normal": [90, 110, 405, 425],
    "shop_clean_quantity_button_minus_hover": [475, 110, 790, 425],
    "shop_clean_quantity_button_minus_disabled": [860, 110, 1175, 425],
    "shop_clean_quantity_button_plus_normal": [90, 500, 405, 815],
    "shop_clean_quantity_button_plus_hover": [475, 500, 790, 815],
    "shop_clean_quantity_button_plus_disabled": [860, 500, 1175, 815],
    "shop_clean_quantity_body": [475, 870, 790, 1185],
}

TABS_V2_BOXES = {
    "shop_clean_tab_normal": [230, 44, 1545, 270],
    "shop_clean_tab_hover": [230, 338, 1545, 564],
    "shop_clean_tab_selected": [230, 632, 1545, 858],
}


def load(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.copy()


def visible_pixels(image: Image.Image) -> int:
    return sum(image.convert("RGBA").getchannel("A").histogram()[1:])


def visible_pixels_in_row(image: Image.Image, row: int) -> int:
    rgba = image.convert("RGBA")
    return sum(1 for x in range(rgba.width) if rgba.getpixel((x, row))[3] > 0)


def visible_chroma_remnants(image: Image.Image) -> list[tuple[int, int, tuple[int, int, int, int]]]:
    rgba = image.convert("RGBA")
    remnants = []
    pixels = rgba.get_flattened_data() if hasattr(rgba, "get_flattened_data") else rgba.getdata()
    for index, (red, green, blue, alpha) in enumerate(pixels):
        if alpha == 0:
            continue
        if red <= 8 and blue <= 8 and green >= 24:
            remnants.append((index % rgba.width, index // rgba.width, (red, green, blue, alpha)))
    return remnants


def visible_average_rgb(image: Image.Image) -> tuple[int, int, int]:
    rgba = image.convert("RGBA")
    data = rgba.get_flattened_data() if hasattr(rgba, "get_flattened_data") else rgba.getdata()
    pixels = [(red, green, blue) for red, green, blue, alpha in data if alpha > 0]
    if not pixels:
        return (0, 0, 0)
    return tuple(sum(pixel[channel] for pixel in pixels) // len(pixels) for channel in range(3))


def alpha_bbox_center(image: Image.Image) -> tuple[float, float]:
    rgba = image.convert("RGBA")
    coords = [
        (x, y)
        for y in range(rgba.height)
        for x in range(rgba.width)
        if rgba.getpixel((x, y))[3] > 0
    ]
    if not coords:
        return (-1.0, -1.0)
    xs = [x for x, _y in coords]
    ys = [y for _x, y in coords]
    return ((min(xs) + max(xs)) / 2.0, (min(ys) + max(ys)) / 2.0)


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    rgba = image.convert("RGBA")
    coords = [
        (x, y)
        for y in range(rgba.height)
        for x in range(rgba.width)
        if rgba.getpixel((x, y))[3] > 0
    ]
    if not coords:
        return (-1, -1, -1, -1)
    xs = [x for x, _y in coords]
    ys = [y for _x, y in coords]
    return (min(xs), min(ys), max(xs) + 1, max(ys) + 1)


def region_luminance_and_warmth(image: Image.Image, box: tuple[int, int, int, int]) -> tuple[float, float]:
    normalized = image.convert("RGB").resize((320, 180), Image.Resampling.BICUBIC)
    crop = normalized.crop(box)
    pixels = list(crop.get_flattened_data() if hasattr(crop, "get_flattened_data") else crop.getdata())
    red = sum(pixel[0] for pixel in pixels) / len(pixels)
    green = sum(pixel[1] for pixel in pixels) / len(pixels)
    blue = sum(pixel[2] for pixel in pixels) / len(pixels)
    luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
    warmth = red - blue
    return (luminance, warmth)


def visible_shopkeeper_pixels(image: Image.Image) -> tuple[int, int]:
    # Native crop matches the runtime gap between the left list panel and right detail page.
    gap = image.convert("RGB").crop((186, 55, 200, 94))
    pixels = list(gap.get_flattened_data() if hasattr(gap, "get_flattened_data") else gap.getdata())
    warm_pixels = sum(1 for red, green, blue in pixels if red >= 30 and green >= 20 and blue <= 24 and red - blue >= 10)
    readable_pixels = sum(1 for red, green, blue in pixels if red + green + blue >= 55)
    return (warm_pixels, readable_pixels)


def pouch_like_pixels(image: Image.Image, box: tuple[int, int, int, int]) -> tuple[int, int]:
    crop = image.convert("RGB").crop(box)
    pixels = list(crop.get_flattened_data() if hasattr(crop, "get_flattened_data") else crop.getdata())
    pouch_pixels = sum(
        1
        for red, green, blue in pixels
        if red >= 22 and green >= 12 and blue <= 18 and red - blue >= 7 and red + green + blue >= 42
    )
    gold_pixels = sum(1 for red, green, blue in pixels if red >= 32 and green >= 22 and blue <= 18 and red - blue >= 10)
    return (pouch_pixels, gold_pixels)


class ShopCleanAssetPipelineTest(unittest.TestCase):
    def test_manifest_and_export_script_exist(self) -> None:
        self.assertTrue(MANIFEST.exists(), "shop clean manifest exists")
        self.assertTrue(EXPORT_SCRIPT.exists(), "shop clean exporter exists")

    def test_manifest_covers_expected_assets(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        assets = manifest.get("assets", {})
        for asset_id, (native_size, runtime_size, transparent) in EXPECTED.items():
            with self.subTest(asset=asset_id):
                self.assertIn(asset_id, assets)
                spec = assets[asset_id]
                self.assertEqual(tuple(spec["native_size"]), native_size)
                self.assertEqual(tuple(spec["runtime_size"]), runtime_size)
                self.assertEqual(bool(spec["transparent"]), transparent)
                self.assertNotIn("shop_scene_v2_master_reference", str(spec))
                self.assertIn("safe_area", spec)

    def test_native_and_runtime_outputs_exist_and_scale_exactly(self) -> None:
        for asset_id, (native_size, runtime_size, transparent) in EXPECTED.items():
            native = SOURCE / f"{asset_id}_native.png"
            runtime = RUNTIME / f"{asset_id}.png"
            with self.subTest(asset=asset_id):
                self.assertTrue(native.exists(), f"{asset_id}: native exists")
                self.assertTrue(runtime.exists(), f"{asset_id}: runtime exists")
                native_image = load(native)
                runtime_image = load(runtime)
                self.assertEqual(native_image.size, native_size)
                self.assertEqual(runtime_image.size, runtime_size)
                expected = native_image.resize(runtime_size, Image.Resampling.NEAREST)
                self.assertEqual(runtime_image.mode, expected.mode)
                self.assertEqual(runtime_image.tobytes(), expected.tobytes(), f"{asset_id}: exact nearest export")
                if transparent:
                    self.assertIn("A", native_image.getbands())
                    self.assertGreater(visible_pixels(native_image), 0)

    def test_state_families_have_matching_sizes_and_distinct_art(self) -> None:
        families = [
            ["shop_clean_tab_normal", "shop_clean_tab_hover", "shop_clean_tab_selected"],
            [
                "shop_clean_item_row_normal",
                "shop_clean_item_row_hover",
                "shop_clean_item_row_selected",
                "shop_clean_item_row_disabled",
            ],
            [
                "shop_clean_quantity_button_minus_normal",
                "shop_clean_quantity_button_minus_hover",
                "shop_clean_quantity_button_minus_disabled",
            ],
            [
                "shop_clean_quantity_button_plus_normal",
                "shop_clean_quantity_button_plus_hover",
                "shop_clean_quantity_button_plus_disabled",
            ],
            [
                "shop_clean_purchase_seal_normal",
                "shop_clean_purchase_seal_hover",
                "shop_clean_purchase_seal_pressed",
                "shop_clean_purchase_seal_disabled",
            ],
            ["shop_clean_close_tag_normal", "shop_clean_close_tag_hover"],
        ]
        for family in families:
            with self.subTest(family=family[0]):
                images = [load(SOURCE / f"{asset_id}_native.png").convert("RGBA") for asset_id in family]
                self.assertEqual(len({image.size for image in images}), 1, "state family sizes match")
                self.assertEqual(
                    len({image.tobytes() for image in images}),
                    len(images),
                    "state family images are distinct",
                )

    def test_quantity_normal_assets_have_no_visible_chroma_remnants(self) -> None:
        targets = [
            SOURCE / "shop_clean_quantity_button_minus_normal_native.png",
            SOURCE / "shop_clean_quantity_button_plus_normal_native.png",
            RUNTIME / "shop_clean_quantity_button_minus_normal.png",
            RUNTIME / "shop_clean_quantity_button_plus_normal.png",
        ]
        for path in targets:
            with self.subTest(path=path.name):
                remnants = visible_chroma_remnants(load(path))
                self.assertEqual(remnants, [], f"{path.name}: visible green chroma remnants: {remnants[:8]}")

    def test_detail_page_base_has_no_isolated_bottom_pixel_line(self) -> None:
        native = load(SOURCE / "shop_clean_detail_page_base_native.png")
        self.assertEqual(visible_pixels_in_row(native, native.height - 2), 0)
        self.assertEqual(visible_pixels_in_row(native, native.height - 1), 0)

    def test_backdrop_uses_generated_v7_visible_pouch_stage(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(
            Path(manifest["source_files"].get("backdrop_v7", "")),
            Path("art_sources/generated_raw/shop_clean/shop_clean_backdrop_v7_pouch_clear_retry2_generated_raw.png"),
        )
        self.assertTrue(BACKDROP_V7_RAW.exists(), "backdrop v7 generated raw source exists")
        assets = manifest.get("assets", {})
        backdrop = assets["shop_clean_backdrop"]
        self.assertEqual(backdrop.get("source"), "backdrop_v7")
        self.assertIsNone(backdrop.get("source_box"))
        self.assertEqual(tuple(backdrop["native_size"]), (320, 180))
        self.assertEqual(tuple(backdrop["runtime_size"]), (1280, 720))
        self.assertFalse(bool(backdrop["transparent"]))

    def test_backdrop_has_readable_shopkeeper_in_existing_panel_gap(self) -> None:
        warm_pixels, readable_pixels = visible_shopkeeper_pixels(load(SOURCE / "shop_clean_backdrop_native.png"))
        self.assertGreaterEqual(warm_pixels, 36, "hooded shopkeeper face should read in the panel gap")
        self.assertGreaterEqual(readable_pixels, 72, "panel gap needs enough mid-value pixels to reveal the shopkeeper")

    def test_backdrop_keeps_money_pouch_below_left_panel(self) -> None:
        image = load(SOURCE / "shop_clean_backdrop_native.png")
        visible_pouch_pixels, visible_gold_pixels = pouch_like_pixels(image, (6, 132, 36, 158))
        overlap_pouch_pixels, overlap_gold_pixels = pouch_like_pixels(image, (14, 108, 58, 128))
        self.assertGreaterEqual(visible_pouch_pixels, 140, "small money pouch should read in the lower-left visible background")
        self.assertGreaterEqual(visible_gold_pixels, 40, "coin highlights should stay visible below the left panel")
        self.assertLessEqual(overlap_pouch_pixels, 40, "money pouch should not sit under the left panel bottom edge")
        self.assertLessEqual(overlap_gold_pixels, 8, "coin highlights should not be hidden by the left panel")

    def test_backdrop_keeps_counter_band_subordinate_to_ui(self) -> None:
        counter_band = (0, 122, 320, 165)
        luminance, warmth = region_luminance_and_warmth(load(SOURCE / "shop_clean_backdrop_native.png"), counter_band)
        self.assertLessEqual(luminance, 27.0, "counter band should stay darker than foreground UI")
        self.assertLessEqual(warmth, 18.0, "counter band should not become a warm foreground block")

    def test_tabs_use_generated_v2_low_contrast_treatment(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(
            Path(manifest["source_files"].get("tabs_v2", "")),
            Path("art_sources/generated_raw/shop_clean/shop_clean_tabs_v2_generated_raw.png"),
        )
        self.assertTrue(TABS_V2_RAW.exists(), "tabs v2 generated raw source exists")
        self.assertGreaterEqual(load(TABS_V2_RAW).size[0], 512, "tabs v2 raw is large enough for fixed crop use")
        assets = manifest.get("assets", {})
        for asset_id, source_box in TABS_V2_BOXES.items():
            with self.subTest(asset=asset_id):
                self.assertEqual(assets[asset_id].get("source"), "tabs_v2")
                self.assertEqual(assets[asset_id].get("source_box"), source_box)
                self.assertEqual(tuple(assets[asset_id]["native_size"]), (42, 16))
                self.assertEqual(tuple(assets[asset_id]["runtime_size"]), (168, 64))

    def test_purchase_seal_uses_textless_v3_stamp_treatment(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(
            Path(manifest["source_files"].get("purchase_seal_v3", "")),
            Path("art_sources/generated_raw/shop_clean/shop_clean_purchase_seal_v3_generated_raw.png"),
        )
        self.assertTrue(PURCHASE_SEAL_V3_RAW.exists(), "purchase seal v3 generated raw source exists")
        self.assertEqual(load(PURCHASE_SEAL_V3_RAW).size, (512, 512), "purchase seal v3 raw is normalized before pipeline use")
        assets = manifest.get("assets", {})
        for asset_id, source_box in PURCHASE_SEAL_V3_BOXES.items():
            with self.subTest(asset=asset_id):
                self.assertEqual(assets[asset_id].get("source"), "purchase_seal_v3")
                self.assertEqual(assets[asset_id].get("source_box"), source_box)
                self.assertNotIn("postprocess", assets[asset_id])

        normal_rgb = visible_average_rgb(load(SOURCE / "shop_clean_purchase_seal_normal_native.png"))
        hover_rgb = visible_average_rgb(load(SOURCE / "shop_clean_purchase_seal_hover_native.png"))
        pressed_rgb = visible_average_rgb(load(SOURCE / "shop_clean_purchase_seal_pressed_native.png"))
        for asset_id, average_rgb in [
            ("shop_clean_purchase_seal_normal", normal_rgb),
            ("shop_clean_purchase_seal_hover", hover_rgb),
            ("shop_clean_purchase_seal_pressed", pressed_rgb),
        ]:
            with self.subTest(palette=asset_id):
                red, green, _blue = average_rgb
                self.assertGreater(red, green, f"{asset_id}: stamp remains red-led")
        self.assertGreaterEqual(normal_rgb[2], 18, "normal stamp is no longer old amber/orange-only wax")
        self.assertGreaterEqual(hover_rgb[2], 18, "hover stamp is no longer old amber/orange-only wax")
        self.assertLess(pressed_rgb[0] + pressed_rgb[1] + pressed_rgb[2], normal_rgb[0] + normal_rgb[1] + normal_rgb[2])

    def test_purchase_seal_state_anchors_match(self) -> None:
        centers = {}
        for asset_id in PURCHASE_SEAL_V3_BOXES:
            centers[asset_id] = alpha_bbox_center(load(SOURCE / f"{asset_id}_native.png"))
        self.assertEqual(
            len(set(centers.values())),
            1,
            f"purchase seal state centers must not shift: {centers}",
        )

    def test_close_tag_uses_generated_v2_tag_treatment(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(
            Path(manifest["source_files"].get("close_tag_v2", "")),
            Path("art_sources/generated_raw/shop_clean/shop_clean_close_tag_v2_generated_raw.png"),
        )
        self.assertTrue(CLOSE_TAG_V2_RAW.exists(), "close tag v2 generated raw source exists")
        self.assertEqual(load(CLOSE_TAG_V2_RAW).size, (512, 512), "close tag v2 raw is normalized before pipeline use")
        assets = manifest.get("assets", {})
        for asset_id, source_box in CLOSE_TAG_V2_BOXES.items():
            with self.subTest(asset=asset_id):
                self.assertEqual(assets[asset_id].get("source"), "close_tag_v2")
                self.assertEqual(assets[asset_id].get("source_box"), source_box)

        centers = {}
        for asset_id in CLOSE_TAG_V2_BOXES:
            centers[asset_id] = alpha_bbox_center(load(SOURCE / f"{asset_id}_native.png"))
        self.assertEqual(
            len(set(centers.values())),
            1,
            f"close tag state centers must not shift: {centers}",
        )

    def test_quantity_controls_use_generated_v5_native_grid_treatment(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(
            Path(manifest["source_files"].get("quantity_controls_v5", "")),
            Path("art_sources/generated_raw/shop_clean/shop_clean_quantity_controls_v5_generated_raw.png"),
        )
        self.assertTrue(QUANTITY_CONTROLS_V5_RAW.exists(), "quantity controls v5 generated raw source exists")
        self.assertGreaterEqual(load(QUANTITY_CONTROLS_V5_RAW).size[0], 512, "quantity controls v5 raw is large enough for fixed crop use")
        assets = manifest.get("assets", {})
        for asset_id, source_box in QUANTITY_CONTROLS_V3_BOXES.items():
            with self.subTest(asset=asset_id):
                self.assertEqual(assets[asset_id].get("source"), "quantity_controls_v5")
                self.assertEqual(assets[asset_id].get("source_box"), source_box)
                self.assertNotEqual(assets[asset_id].get("resample"), "nearest")

        for family in [
            [
                "shop_clean_quantity_button_minus_normal",
                "shop_clean_quantity_button_minus_hover",
                "shop_clean_quantity_button_minus_disabled",
            ],
            [
                "shop_clean_quantity_button_plus_normal",
                "shop_clean_quantity_button_plus_hover",
                "shop_clean_quantity_button_plus_disabled",
            ],
        ]:
            with self.subTest(family=family[0]):
                centers = {asset_id: alpha_bbox_center(load(SOURCE / f"{asset_id}_native.png")) for asset_id in family}
                self.assertEqual(len(set(centers.values())), 1, f"quantity button state centers must not shift: {centers}")

        displayed_frames = {
            asset_id: alpha_bbox(load(SOURCE / f"{asset_id}_native.png"))
            for asset_id in [
                "shop_clean_quantity_button_minus_normal",
                "shop_clean_quantity_body",
                "shop_clean_quantity_button_plus_normal",
            ]
        }
        self.assertEqual(
            len(set(displayed_frames.values())),
            1,
            f"quantity minus/body/plus outer frames must align: {displayed_frames}",
        )

    def test_export_script_reproduces_assets(self) -> None:
        result = subprocess.run([sys.executable, str(EXPORT_SCRIPT)], cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
