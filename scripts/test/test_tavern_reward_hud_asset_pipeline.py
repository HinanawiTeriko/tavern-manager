from __future__ import annotations

import json
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "tavern_reward_hud" / "tavern_reward_hud_sheet_v1.png"
PROMPT = ROOT / "art_sources" / "generated_raw" / "tavern_reward_hud" / "tavern_reward_hud_sheet_v1_prompt.txt"
SOURCE = ROOT / "assets" / "source" / "tavern" / "reward_hud"
RUNTIME = ROOT / "assets" / "textures" / "ui" / "reward_hud"
MANIFEST = SOURCE / "tavern_reward_hud_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_reward_hud_contact_sheet.png"
ASSETS = {
    "reward_gold_progress_bg": ((48, 12), (192, 48)),
    "reward_gold_progress_fill": ((48, 12), (192, 48)),
    "reward_gold_progress_ornate": ((48, 12), (192, 48)),
    "reward_rep_progress_bg": ((48, 12), (192, 48)),
    "reward_rep_progress_fill": ((48, 12), (192, 48)),
    "reward_rep_progress_ornate": ((48, 12), (192, 48)),
    "reward_coin_particle": ((8, 8), (32, 32)),
    "reward_rep_particle": ((8, 8), (32, 32)),
    "reward_spark": ((6, 6), (24, 24)),
}
DEFAULT_PROGRESS_ASSETS = {
    "reward_gold_progress_bg",
    "reward_gold_progress_fill",
    "reward_rep_progress_bg",
    "reward_rep_progress_fill",
}


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    raw = image.tobytes()
    return [tuple(raw[index:index + 4]) for index in range(0, len(raw), 4)]


def visible_pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    return [pixel for pixel in pixels(image) if pixel[3] > 0]


def warm_pixel_count(image: Image.Image) -> int:
    return sum(1 for r, g, b, a in visible_pixels(image) if a > 0 and r >= 120 and 50 <= g <= 190 and b <= 90)


def cool_pixel_count(image: Image.Image) -> int:
    return sum(1 for r, g, b, a in visible_pixels(image) if a > 0 and b >= 110 and g >= 90 and r <= 120)


def dark_teal_pixel_count(image: Image.Image) -> int:
    return sum(1 for r, g, b, a in visible_pixels(image) if a > 0 and b >= r and g >= r * 0.65 and r + g + b <= 190)


class TavernRewardHudAssetPipelineTest(unittest.TestCase):
    def test_generated_source_prompt_and_manifest_are_retained(self) -> None:
        self.assertTrue(RAW_SOURCE.exists(), f"{RAW_SOURCE}: missing generated reward HUD source")
        self.assertGreater(RAW_SOURCE.stat().st_size, 100_000, "generated reward HUD source is unexpectedly small")
        self.assertTrue(PROMPT.exists(), f"{PROMPT}: missing reward HUD generation prompt")
        prompt_text = PROMPT.read_text(encoding="utf-8")
        self.assertIn("Default progress grooves must be simple and quiet", prompt_text)
        self.assertIn("no large medallions", prompt_text)
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing reward HUD manifest")

        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["id"], "tavern_reward_hud")
        self.assertEqual(manifest["source"], "art_sources/generated_raw/tavern_reward_hud/tavern_reward_hud_sheet_v1.png")
        self.assertEqual(manifest["prompt"], "art_sources/generated_raw/tavern_reward_hud/tavern_reward_hud_sheet_v1_prompt.txt")
        self.assertEqual(manifest["scale"], 4)
        self.assertEqual(set(manifest["assets"].keys()), set(ASSETS.keys()))
        for asset_id, (native_size, runtime_size) in ASSETS.items():
            with self.subTest(asset=asset_id):
                asset = manifest["assets"][asset_id]
                self.assertEqual(asset["native"], f"assets/source/tavern/reward_hud/{asset_id}_native.png")
                self.assertEqual(asset["runtime"], f"assets/textures/ui/reward_hud/{asset_id}.png")
                self.assertEqual(asset["native_size"], list(native_size))
                self.assertEqual(asset["runtime_size"], list(runtime_size))
                self.assertIn("crop_rect", asset)
                self.assertIn("safe_area", asset)
                self.assertIn("intended_godot_use", asset)

    def test_runtime_is_exact_four_x_nearest_export(self) -> None:
        for asset_id, (native_size, runtime_size) in ASSETS.items():
            native_path = SOURCE / f"{asset_id}_native.png"
            runtime_path = RUNTIME / f"{asset_id}.png"
            with self.subTest(asset=asset_id):
                self.assertTrue(native_path.exists(), f"{native_path}: missing native source")
                self.assertTrue(runtime_path.exists(), f"{runtime_path}: missing runtime texture")
                native = load_rgba(native_path)
                runtime = load_rgba(runtime_path)
                self.assertEqual(native.size, native_size)
                self.assertEqual(runtime.size, runtime_size)
                expected = native.resize(runtime_size, Image.Resampling.NEAREST)
                self.assertEqual(runtime.tobytes(), expected.tobytes(), f"{asset_id}: runtime must be exact 4x nearest export")

    def test_progress_assets_are_restrained_and_readable(self) -> None:
        for asset_id in DEFAULT_PROGRESS_ASSETS:
            with self.subTest(asset=asset_id):
                native = load_rgba(SOURCE / f"{asset_id}_native.png")
                visible = visible_pixels(native)
                self.assertGreater(len(visible), 120, f"{asset_id}: progress asset has too little visible structure")
                self.assertGreaterEqual(dark_teal_pixel_count(native), 24, f"{asset_id}: progress asset needs dark teal tavern body")
                self.assertLessEqual(warm_pixel_count(native), 360, f"{asset_id}: default progress asset is too ornate or gold-heavy")

        self.assertGreaterEqual(warm_pixel_count(load_rgba(SOURCE / "reward_gold_progress_fill_native.png")), 120)
        self.assertGreaterEqual(cool_pixel_count(load_rgba(SOURCE / "reward_rep_progress_fill_native.png")), 120)

    def test_particles_keep_clear_color_identity(self) -> None:
        coin = load_rgba(SOURCE / "reward_coin_particle_native.png")
        rep = load_rgba(SOURCE / "reward_rep_particle_native.png")
        spark = load_rgba(SOURCE / "reward_spark_native.png")
        self.assertGreaterEqual(warm_pixel_count(coin), 10, "coin particle needs visible warm gold pixels")
        self.assertGreaterEqual(cool_pixel_count(rep), 8, "reputation particle needs visible cool blue pixels")
        self.assertGreaterEqual(warm_pixel_count(spark), 4, "spark needs visible amber pixels")
        for asset_id in ["reward_coin_particle", "reward_rep_particle", "reward_spark"]:
            with self.subTest(asset=asset_id):
                native = load_rgba(SOURCE / f"{asset_id}_native.png")
                self.assertGreater(len(visible_pixels(native)), 4, f"{asset_id}: particle cannot be blank")
                self.assertLessEqual(len(set(visible_pixels(native))), 28, f"{asset_id}: particle palette should stay pixel-restrained")

    def test_contact_sheet_exists(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing reward HUD contact sheet")
        self.assertGreater(CONTACT_SHEET.stat().st_size, 0, "reward HUD contact sheet is empty")


if __name__ == "__main__":
    unittest.main(verbosity=2)
