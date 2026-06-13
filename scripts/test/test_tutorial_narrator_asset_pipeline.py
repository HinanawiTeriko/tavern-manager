from pathlib import Path
import json
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_sources" / "generated_raw" / "tutorial_narrator"
SOURCE = ROOT / "assets" / "source" / "tutorial_narrator"
RUNTIME = ROOT / "assets" / "textures" / "tutorial" / "narrator"
DOCS = ROOT / "docs" / "art"
EXPORTER = ROOT / "scripts" / "tools" / "export_tutorial_narrator_assets.py"
MANIFEST = SOURCE / "tutorial_narrator_manifest.json"
CONTACT_SHEET = DOCS / "tutorial_narrator_contact_sheet.png"
SOURCE_IMAGE = RAW / "female_bartender_scribe_pixel_source_v2.png"
PROMPT_RECORD = RAW / "female_bartender_scribe_pixel_prompt_v2.txt"
EXPRESSION_SHEET = RAW / "female_bartender_scribe_expression_sheet_source_v2.png"
EXPRESSION_PROMPT = RAW / "female_bartender_scribe_expression_sheet_prompt_v2.txt"
LEDGE_SOURCE = RAW / "female_bartender_scribe_ledge_source_v3.png"
LEDGE_PROMPT = RAW / "female_bartender_scribe_ledge_prompt_v3.txt"
STYLE_REFERENCE = ROOT / "art_sources" / "generated_raw" / "regular_customers" / "regular_belta_neutral_pilot_source_v1.png"
ASSET_ID = "female_bartender_scribe"
VARIANTS = ["neutral", "smirk", "concerned", "surprised", "ledge"]
NATIVE_SIZE = (128, 160)
RUNTIME_SIZE = (512, 640)
SOURCE_CROP = [0, 0, 1122, 1402]
VARIANT_CROPS = {
    "neutral": [104, 20, 570, 620],
    "smirk": [674, 20, 1138, 620],
    "concerned": [86, 636, 552, 1236],
    "surprised": [676, 636, 1142, 1236],
    "ledge": [183, 168, 903, 1068],
}


def load_rgba(path: Path) -> Image.Image:
    if not path.exists():
        raise AssertionError(f"{path}: missing image")
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def flattened_pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    if hasattr(image, "get_flattened_data"):
        return list(image.get_flattened_data())
    return list(image.getdata())


def is_green_key_fringe(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, _a = pixel
    return g >= 96 and g > max(r, b) * 1.45 and r <= 110 and b <= 130


def visible_bbox_width_ratio(image: Image.Image) -> float:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return 0.0
    x0, _y0, x1, _y1 = bbox
    return (x1 - x0) / image.width


class TutorialNarratorAssetPipelineTest(unittest.TestCase):
    def test_raw_source_and_prompt_are_retained(self) -> None:
        for source, prompt in [
            (SOURCE_IMAGE, PROMPT_RECORD),
            (EXPRESSION_SHEET, EXPRESSION_PROMPT),
            (LEDGE_SOURCE, LEDGE_PROMPT),
        ]:
            with self.subTest(source=source.name):
                self.assertTrue(source.exists(), f"{source}: missing generated source")
                self.assertTrue(prompt.exists(), f"{prompt}: missing prompt record")
                self.assertGreater(source.stat().st_size, 0, "generated source is empty")
                self.assertGreater(prompt.stat().st_size, 0, "prompt record is empty")
                prompt_text = prompt.read_text(encoding="utf-8").lower()
                self.assertIn("belta", prompt_text)
                self.assertIn("vera", prompt_text)
                self.assertIn("same artist family", prompt_text)
                self.assertIn("flat solid #00ff00", prompt_text)
                self.assertIn("do not copy belta", prompt_text)
                with Image.open(source) as image:
                    self.assertGreaterEqual(image.width, 512)
                    self.assertGreaterEqual(image.height, 512)
        self.assertTrue(STYLE_REFERENCE.exists(), f"{STYLE_REFERENCE}: missing Belta style reference")

    def test_exporter_uses_explicit_source_contract(self) -> None:
        self.assertTrue(EXPORTER.exists(), f"{EXPORTER}: missing exporter")
        source = EXPORTER.read_text(encoding="utf-8")
        self.assertIn("SOURCE_IMAGE", source, "exporter must consume the retained raw narrator source")
        self.assertIn("EXPRESSION_SHEET", source, "exporter must consume the retained expression sheet")
        self.assertIn("PROMPT_RECORD", source, "exporter must keep the prompt record in the manifest")
        self.assertIn("STYLE_REFERENCE", source, "exporter must record the Belta style reference")
        self.assertIn("SOURCE_CROP", source, "exporter must use an explicit fixed crop")
        self.assertIn("VARIANT_CROPS", source, "exporter must use explicit fixed variant crops")
        self.assertIn("NATIVE_SIZE", source, "exporter must define the native pixel size")

    def test_native_and_runtime_are_exact_pixel_exports(self) -> None:
        for name in [ASSET_ID, *(f"{ASSET_ID}_{variant}" for variant in VARIANTS)]:
            with self.subTest(name=name):
                native = load_rgba(SOURCE / f"{name}_native.png")
                runtime = load_rgba(RUNTIME / f"{name}.png")
                self.assertEqual(native.size, NATIVE_SIZE)
                self.assertEqual(runtime.size, RUNTIME_SIZE)
                expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
                self.assertEqual(runtime.tobytes(), expected.tobytes(), f"{name}: runtime must be exact nearest-neighbor export")

    def test_native_has_clean_transparency_and_limited_palette(self) -> None:
        for name in [ASSET_ID, *(f"{ASSET_ID}_{variant}" for variant in VARIANTS)]:
            with self.subTest(name=name):
                native = load_rgba(SOURCE / f"{name}_native.png")
                pixels = flattened_pixels(native)
                alphas = [a for _r, _g, _b, a in pixels]
                self.assertEqual(min(alphas), 0, "native needs transparent background pixels")
                self.assertEqual(max(alphas), 255, "native needs visible opaque pixels")
                self.assertTrue(all(a in [0, 255] for a in alphas), "native alpha must be hard pixel art alpha")
                visible = [(r, g, b) for r, g, b, a in pixels if a > 0]
                self.assertGreater(len(visible), native.width * native.height * 0.38, "portrait silhouette is too sparse")
                self.assertLessEqual(len(set(visible)), 36, "native portrait palette is too broad for this pixel pipeline")

    def test_chroma_key_is_removed_from_native_and_runtime(self) -> None:
        for name in [ASSET_ID, *(f"{ASSET_ID}_{variant}" for variant in VARIANTS)]:
            for path in [
                SOURCE / f"{name}_native.png",
                RUNTIME / f"{name}.png",
            ]:
                with self.subTest(path=path):
                    image = load_rgba(path)
                    pixels = flattened_pixels(image)
                    visible_key_pixels = sum(1 for pixel in pixels if pixel[3] > 0 and is_green_key_fringe(pixel))
                    transparent_key_rgb = sum(1 for pixel in pixels if pixel[3] == 0 and is_green_key_fringe(pixel))
                    self.assertEqual(visible_key_pixels, 0, f"{path}: visible green key fringe remains")
                    self.assertEqual(transparent_key_rgb, 0, f"{path}: transparent pixels retain green key RGB")

    def test_expression_variants_are_distinct_but_consistent_portraits(self) -> None:
        neutral = load_rgba(SOURCE / f"{ASSET_ID}_neutral_native.png")
        for variant in ["smirk", "concerned", "surprised"]:
            with self.subTest(variant=variant):
                image = load_rgba(SOURCE / f"{ASSET_ID}_{variant}_native.png")
                changed = sum(
                    1
                    for neutral_px, variant_px in zip(flattened_pixels(neutral), flattened_pixels(image))
                    if neutral_px != variant_px
                )
                self.assertGreaterEqual(changed, 420, f"{variant}: variant is too close to neutral")
                self.assertLessEqual(changed, 16500, f"{variant}: variant drifted too far from the narrator design")
                self.assertGreaterEqual(visible_bbox_width_ratio(image), 0.62, f"{variant}: portrait silhouette is too loose")

    def test_manifest_records_narrator_asset(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing manifest")
        data = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(
            data.get("style_reference"),
            "art_sources/generated_raw/regular_customers/regular_belta_neutral_pilot_source_v1.png",
        )
        assets = data.get("assets", {})
        self.assertIn(ASSET_ID, assets)
        self.assertEqual(
            assets[ASSET_ID],
            {
                "id": ASSET_ID,
                "source_file": "art_sources/generated_raw/tutorial_narrator/female_bartender_scribe_pixel_source_v2.png",
                "prompt": "art_sources/generated_raw/tutorial_narrator/female_bartender_scribe_pixel_prompt_v2.txt",
                "native_file": "assets/source/tutorial_narrator/female_bartender_scribe_native.png",
                "output_file": "assets/textures/tutorial/narrator/female_bartender_scribe.png",
                "native_size": [128, 160],
                "runtime_size": [512, 640],
                "source_crop": SOURCE_CROP,
                "safe_area": [18, 8, 92, 142],
                "intended_godot_use": "TutorialOverlay narrator portrait source, not wired into runtime yet",
            },
        )
        for variant in VARIANTS:
            variant_id = f"{ASSET_ID}_{variant}"
            self.assertIn(variant_id, assets)
            source_file = "art_sources/generated_raw/tutorial_narrator/female_bartender_scribe_expression_sheet_source_v2.png"
            prompt_file = "art_sources/generated_raw/tutorial_narrator/female_bartender_scribe_expression_sheet_prompt_v2.txt"
            intended_use = "TutorialOverlay narrator portrait expression variant, not wired into runtime yet"
            if variant == "ledge":
                source_file = "art_sources/generated_raw/tutorial_narrator/female_bartender_scribe_ledge_source_v3.png"
                prompt_file = "art_sources/generated_raw/tutorial_narrator/female_bartender_scribe_ledge_prompt_v3.txt"
                intended_use = "TutorialOverlay narrator portrait raised dialogue edge pose"
            self.assertEqual(
                assets[variant_id],
                {
                    "id": variant_id,
                    "source_file": source_file,
                    "prompt": prompt_file,
                    "native_file": f"assets/source/tutorial_narrator/{variant_id}_native.png",
                    "output_file": f"assets/textures/tutorial/narrator/{variant_id}.png",
                    "native_size": [128, 160],
                    "runtime_size": [512, 640],
                    "source_crop": VARIANT_CROPS[variant],
                    "safe_area": [18, 8, 92, 142],
                    "expression": variant,
                    "intended_godot_use": intended_use,
                },
            )

    def test_contact_sheet_exists(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing contact sheet")
        image = load_rgba(CONTACT_SHEET)
        self.assertGreaterEqual(image.width, 640)
        self.assertGreaterEqual(image.height, 720)


if __name__ == "__main__":
    unittest.main(verbosity=2)
