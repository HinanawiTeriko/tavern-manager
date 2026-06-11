from pathlib import Path
import json
import subprocess
import sys
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "daymap" / "shop_scene_v2"
REFERENCE = SOURCE / "reference"
RUNTIME = ROOT / "assets" / "textures" / "daymap" / "shop_scene_v2"
PREPARE_SCRIPT = ROOT / "scripts" / "tools" / "prepare_daymap_shop_scene_v2_sources.py"
EXPORT_SCRIPT = ROOT / "scripts" / "tools" / "export_daymap_shop_scene_v2_assets.py"
SCALE = 4

EXPECTED_ASSETS = {
    "shop_scene_bg": ((320, 180), (1280, 720), False),
    "shop_scene_list_panel": ((190, 99), (760, 396), False),
    "shop_scene_detail_panel": ((90, 99), (360, 396), False),
    "shop_scene_checkout": ((260, 32), (1040, 128), False),
    "shop_scene_gold_area": ((36, 14), (144, 56), True),
    "shop_scene_tab_materials_normal": ((48, 16), (192, 64), True),
    "shop_scene_tab_materials_selected": ((48, 16), (192, 64), True),
    "shop_scene_tab_recipes_normal": ((48, 16), (192, 64), True),
    "shop_scene_tab_recipes_selected": ((48, 16), (192, 64), True),
    "shop_scene_tab_abilities_normal": ((48, 16), (192, 64), True),
    "shop_scene_tab_abilities_selected": ((48, 16), (192, 64), True),
    "shop_scene_row_normal": ((145, 16), (580, 64), True),
    "shop_scene_row_hover": ((145, 16), (580, 64), True),
    "shop_scene_row_selected": ((145, 16), (580, 64), True),
    "shop_scene_row_disabled": ((145, 16), (580, 64), True),
    "shop_scene_button_normal": ((64, 18), (256, 72), True),
    "shop_scene_button_hover": ((64, 18), (256, 72), True),
    "shop_scene_button_pressed": ((64, 18), (256, 72), True),
    "shop_scene_button_disabled": ((64, 18), (256, 72), True),
    "shop_scene_quantity_minus": ((18, 18), (72, 72), True),
    "shop_scene_quantity_body": ((44, 18), (176, 72), True),
    "shop_scene_quantity_plus": ((18, 18), (72, 72), True),
    "shop_scene_close_normal": ((18, 18), (72, 72), True),
    "shop_scene_close_hover": ((18, 18), (72, 72), True),
    "shop_scene_close_pressed": ((18, 18), (72, 72), True),
    "shop_scene_status_owned": ((14, 12), (56, 48), True),
    "shop_scene_status_discount": ((14, 13), (56, 52), True),
}

SAFE_AREAS = {
    "shop_scene_list_panel": (10, 8, 173, 92),
    "shop_scene_detail_panel": (10, 10, 80, 90),
    "shop_scene_checkout": (13, 7, 248, 25),
    "shop_scene_row_normal": (8, 4, 108, 13),
}


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def visible_pixel_count(image: Image.Image) -> int:
    return sum(image.getchannel("A").histogram()[1:])


def exact_runtime_export(
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
    expected = native.resize(runtime_size, Image.Resampling.NEAREST)
    test_case.assertEqual(runtime.tobytes(), expected.tobytes(), f"{name}: not exact nearest export")
    return native


def dark_teal_readable_ratio(image: Image.Image) -> float:
    visible = 0
    readable = 0
    for red, green, blue, alpha in image.getdata():
        if alpha < 180:
            continue
        visible += 1
        if red <= 95 and 18 <= green <= 120 and 18 <= blue <= 125:
            readable += 1
    return readable / max(1, visible)


def amber_ratio(image: Image.Image) -> float:
    visible = 0
    amber = 0
    for red, green, blue, alpha in image.getdata():
        if alpha <= 0:
            continue
        visible += 1
        if red >= 150 and 45 <= green <= 180 and blue <= 115 and red >= blue * 1.25:
            amber += 1
    return amber / max(1, visible)


def magenta_fringe_ratio(image: Image.Image) -> float:
    visible = 0
    fringe = 0
    for red, green, blue, alpha in image.getdata():
        if alpha <= 0:
            continue
        visible += 1
        if red >= 65 and blue >= 65 and green <= 90 and red > green * 1.4 and blue > green * 1.4:
            fringe += 1
    return fringe / max(1, visible)


class DayMapShopSceneV2AssetPipelineTest(unittest.TestCase):
    def test_manifest_covers_every_generated_asset(self) -> None:
        manifest = json.loads((REFERENCE / "shop_scene_v2_manifest.json").read_text(encoding="utf-8"))
        assets: dict = manifest.get("assets", {})
        self.assertEqual(set(EXPECTED_ASSETS.keys()), set(assets.keys()), "manifest asset ids must match generated assets")
        for name, (native_size, runtime_size, transparent) in EXPECTED_ASSETS.items():
            with self.subTest(name=name):
                spec: dict = assets[name]
                self.assertEqual(spec.get("id"), name, f"{name}: manifest id mismatch")
                self.assertEqual(tuple(spec.get("native_size", [])), native_size, f"{name}: native size missing from manifest")
                self.assertEqual(tuple(spec.get("runtime_size", [])), runtime_size, f"{name}: runtime size missing from manifest")
                self.assertEqual(bool(spec.get("transparent")), transparent, f"{name}: transparency mismatch")
                self.assertEqual(spec.get("native_output"), f"assets/source/daymap/shop_scene_v2/{name}_native.png")
                self.assertEqual(spec.get("runtime_output"), f"assets/textures/daymap/shop_scene_v2/{name}.png")
                self.assertTrue(spec.get("godot_use", ""), f"{name}: intended Godot use is required")
                self.assertTrue(
                    spec.get("source_box") or spec.get("derived_from"),
                    f"{name}: manifest must document a fixed source crop or derivation",
                )

    def test_reference_art_and_manifest_are_retained(self) -> None:
        required = [
            "shop_scene_v2_master_reference.png",
            "shop_scene_v2_reference_prompt.md",
            "shop_scene_v2_manifest.json",
            "shop_scene_v2_native_preview.png",
            "shop_scene_v2_runtime_preview.png",
        ]
        for filename in required:
            path = REFERENCE / filename
            self.assertTrue(path.exists(), f"{path}: missing retained reference artifact")
            self.assertGreater(path.stat().st_size, 0, f"{path}: retained reference artifact is empty")

    def test_scripts_exist_and_do_not_use_abacus_language(self) -> None:
        for script in [PREPARE_SCRIPT, EXPORT_SCRIPT]:
            self.assertTrue(script.exists(), f"{script}: missing pipeline script")
            text = script.read_text(encoding="utf-8")
            self.assertNotIn("abacus", text.lower(), f"{script.name}: abacus language must not return")
            self.assertNotIn("quantity_abacus", text, f"{script.name}: old quantity_abacus naming must not return")

    def test_prepare_script_does_not_draw_final_status_or_state_ornaments(self) -> None:
        text = PREPARE_SCRIPT.read_text(encoding="utf-8")
        self.assertNotIn("make_status", text, "status marks must come from explicit source crops")
        self.assertNotIn("add_amber_pixels", text, "state ornaments must not be procedurally drawn")
        self.assertNotIn("draw.line", text, "final UI ornaments must not be line-drawn in code")
        self.assertNotIn("draw.polygon", text, "final UI ornaments must not be polygon-drawn in code")

    def test_assets_are_exact_native_exports(self) -> None:
        for name, (native_size, runtime_size, _transparent) in EXPECTED_ASSETS.items():
            with self.subTest(name=name):
                exact_runtime_export(self, name, native_size, runtime_size)

    def test_pipeline_scripts_reproduce_checked_in_assets(self) -> None:
        tracked_outputs = {}
        for name in EXPECTED_ASSETS:
            native_path = SOURCE / f"{name}_native.png"
            runtime_path = RUNTIME / f"{name}.png"
            self.assertTrue(native_path.exists(), f"{native_path}: missing native source before reproduction")
            self.assertTrue(runtime_path.exists(), f"{runtime_path}: missing runtime texture before reproduction")
            tracked_outputs[native_path] = native_path.read_bytes()
            tracked_outputs[runtime_path] = runtime_path.read_bytes()

        for script in [PREPARE_SCRIPT, EXPORT_SCRIPT]:
            result = subprocess.run(
                [sys.executable, str(script)],
                cwd=ROOT,
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, f"{script.name} failed:\n{result.stdout}\n{result.stderr}")

        for path, before_bytes in tracked_outputs.items():
            with self.subTest(path=path.name):
                self.assertEqual(path.read_bytes(), before_bytes, f"{path}: pipeline script is not deterministic")

    def test_transparent_assets_have_alpha_and_visible_pixels(self) -> None:
        for name, (native_size, runtime_size, transparent) in EXPECTED_ASSETS.items():
            if not transparent:
                continue
            with self.subTest(name=name):
                native = exact_runtime_export(self, name, native_size, runtime_size)
                alpha_min, alpha_max = native.getchannel("A").getextrema()
                self.assertEqual(alpha_min, 0, f"{name}: needs transparent pixels")
                self.assertGreater(alpha_max, 0, f"{name}: transparent layer is empty")
                self.assertGreater(visible_pixel_count(native), 12, f"{name}: too sparse")
                self.assertLessEqual(magenta_fringe_ratio(native), 0.002, f"{name}: magenta extraction fringe remains")

    def test_opaque_scene_surfaces_have_readable_text_safe_areas(self) -> None:
        for name, safe_box in SAFE_AREAS.items():
            with self.subTest(name=name):
                native = load_rgba(SOURCE / f"{name}_native.png")
                safe_area = native.crop(safe_box).convert("RGBA")
                self.assertGreaterEqual(
                    dark_teal_readable_ratio(safe_area),
                    0.46,
                    f"{name}: text safe area is too noisy or too bright",
                )

    def test_background_keeps_title_style_palette(self) -> None:
        native = load_rgba(SOURCE / "shop_scene_bg_native.png")
        pixels = list(native.getdata())
        dark = sum(1 for red, green, blue, alpha in pixels if alpha >= 250 and max(red, green, blue) <= 64)
        teal = sum(
            1
            for red, green, blue, alpha in pixels
            if alpha >= 250 and blue >= 30 and green >= 26 and blue >= red * 0.95
        )
        warm = sum(
            1
            for red, green, blue, alpha in pixels
            if alpha >= 250 and red >= 110 and green >= 40 and red >= blue * 1.35
        )
        self.assertGreaterEqual(dark, 18000, "shop background needs enough dark dungeon mass")
        self.assertGreaterEqual(teal, 2500, "shop background needs visible dark teal depth")
        self.assertGreaterEqual(warm, 120, "shop background needs sparse amber accents")
        self.assertLessEqual(warm, 9500, "shop background amber accents are too dominant")

    def test_state_assets_are_distinct(self) -> None:
        groups = [
            ["shop_scene_row_normal", "shop_scene_row_hover", "shop_scene_row_selected", "shop_scene_row_disabled"],
            ["shop_scene_button_normal", "shop_scene_button_hover", "shop_scene_button_pressed", "shop_scene_button_disabled"],
            ["shop_scene_close_normal", "shop_scene_close_hover", "shop_scene_close_pressed"],
            ["shop_scene_tab_materials_normal", "shop_scene_tab_materials_selected"],
        ]
        for group in groups:
            seen: set[bytes] = set()
            for name in group:
                with self.subTest(name=name):
                    data = load_rgba(SOURCE / f"{name}_native.png").tobytes()
                    self.assertNotIn(data, seen, f"{name}: duplicates another state")
                    seen.add(data)

    def test_amber_is_sparse_except_emphasis_states(self) -> None:
        exempt = {
            "shop_scene_row_selected",
            "shop_scene_button_hover",
            "shop_scene_button_pressed",
            "shop_scene_close_hover",
            "shop_scene_close_pressed",
            "shop_scene_quantity_minus",
            "shop_scene_quantity_plus",
            "shop_scene_status_owned",
            "shop_scene_status_discount",
            "shop_scene_gold_area",
        }
        for name in EXPECTED_ASSETS:
            if name in exempt:
                continue
            with self.subTest(name=name):
                native = load_rgba(SOURCE / f"{name}_native.png")
                self.assertLessEqual(amber_ratio(native), 0.18, f"{name}: amber overused")


if __name__ == "__main__":
    unittest.main(verbosity=2)
