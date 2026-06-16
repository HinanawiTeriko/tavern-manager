from pathlib import Path
import importlib.util
import json
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_sources" / "generated_raw" / "characters" / "vera"
SOURCE = ROOT / "assets" / "source" / "tavern" / "characters" / "vera"
RUNTIME = ROOT / "assets" / "textures" / "characters" / "vera"
DOCS = ROOT / "docs" / "art" / "characters"
EXPORTER = ROOT / "scripts" / "tools" / "export_vera_character_assets.py"
MANIFEST = SOURCE / "vera_character_manifest.json"
CONTACT_SHEET = DOCS / "vera_contact_sheet.png"
APPROVED_REFERENCE = RAW / "reference" / "vera_approved_reference_v2.png"
APPROVED_PROMPT_RECORD = RAW / "reference" / "vera_approved_prompt_v2.txt"
EXPRESSION_SHEET = RAW / "vera_expression_sheet_source_v3.png"
EXPRESSION_PROMPT = RAW / "vera_expression_sheet_prompt_v3.txt"
LEDGE_SOURCE = RAW / "vera_ledge_source_v4.png"
LEDGE_PROMPT = RAW / "vera_ledge_prompt_v4.txt"
STYLE_REFERENCE = ROOT / "art_sources" / "generated_raw" / "characters" / "regular_customers" / "regular_belta_style_reference_v1.png"
ASSET_ID = "vera"
EXPRESSION_VARIANTS = ["neutral", "smirk", "concerned", "surprised", "warm", "stern", "confused", "tired"]
VARIANTS = [*EXPRESSION_VARIANTS, "ledge"]
NATIVE_SIZE = (128, 160)
RUNTIME_SIZE = (512, 640)
LEDGE_NATIVE_SIZE = (128, 320)
LEDGE_RUNTIME_SIZE = (512, 1280)
CONTACT_SHEET_SIZE = (1180, 1540)
CONTACT_SHEET_NATIVE_SCALE = 2
CONTACT_SHEET_NATIVE_PREVIEW_SIZE = (
    NATIVE_SIZE[0] * CONTACT_SHEET_NATIVE_SCALE,
    NATIVE_SIZE[1] * CONTACT_SHEET_NATIVE_SCALE,
)
CONTACT_SHEET_NATIVE_BG = (24, 20, 16, 255)
CONTACT_SHEET_NATIVE_POSITIONS = [
    (44, 92),
    (462, 92),
    (880, 92),
    (44, 452),
    (462, 452),
    (880, 452),
    (44, 812),
    (462, 812),
    (880, 812),
]
CONTACT_SHEET_VARIANTS = VARIANTS
COLOR_LIMIT = 72
VARIANT_CROPS = {
    "neutral": [0, 0, 432, 512],
    "smirk": [336, 0, 816, 512],
    "concerned": [720, 0, 1200, 512],
    "surprised": [1152, 0, 1536, 512],
    "warm": [0, 512, 432, 1024],
    "stern": [336, 512, 816, 1024],
    "confused": [720, 512, 1200, 1024],
    "tired": [1152, 512, 1536, 1024],
    "ledge": [0, 0, 1024, 1535],
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


def expected_backed_native_preview(native: Image.Image) -> Image.Image:
    preview_size = (
        native.width * CONTACT_SHEET_NATIVE_SCALE,
        native.height * CONTACT_SHEET_NATIVE_SCALE,
    )
    preview = native.resize(preview_size, Image.Resampling.NEAREST)
    out = Image.new("RGBA", preview_size, CONTACT_SHEET_NATIVE_BG)
    out.alpha_composite(preview, (0, 0))
    return out.convert("RGB")


def load_exporter_module():
    spec = importlib.util.spec_from_file_location("export_vera_character_assets", EXPORTER)
    if spec is None or spec.loader is None:
        raise AssertionError(f"{EXPORTER}: cannot load exporter module")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def is_green_key_fringe(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, _a = pixel
    return g >= 96 and g > max(r, b) * 1.45 and r <= 110 and b <= 130


def is_alpha_boundary_pixel(image: Image.Image, x: int, y: int) -> bool:
    if image.getpixel((x, y))[3] == 0:
        return False
    for dx, dy in [
        (-1, 0),
        (1, 0),
        (0, -1),
        (0, 1),
        (-1, -1),
        (1, -1),
        (-1, 1),
        (1, 1),
    ]:
        xx = x + dx
        yy = y + dy
        if 0 <= xx < image.width and 0 <= yy < image.height and image.getpixel((xx, yy))[3] == 0:
            return True
    return False


def is_green_screen_boundary_fringe(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, a = pixel
    return a > 0 and g >= 24 and g > r + 6 and g > b + 4


def visible_bbox_width_ratio(image: Image.Image) -> float:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return 0.0
    x0, _y0, x1, _y1 = bbox
    return (x1 - x0) / image.width


class VeraCharacterAssetPipelineTest(unittest.TestCase):
    def test_raw_source_and_prompt_are_retained(self) -> None:
        self.assertTrue(APPROVED_REFERENCE.exists(), f"{APPROVED_REFERENCE}: missing approved Vera reference")
        self.assertTrue(APPROVED_PROMPT_RECORD.exists(), f"{APPROVED_PROMPT_RECORD}: missing approved reference prompt")
        approved_prompt_text = APPROVED_PROMPT_RECORD.read_text(encoding="utf-8").lower()
        self.assertIn("belta", approved_prompt_text)
        self.assertIn("vera", approved_prompt_text)
        self.assertIn("same artist family", approved_prompt_text)
        self.assertIn("flat solid #00ff00", approved_prompt_text)
        self.assertIn("do not copy belta", approved_prompt_text)

        for source, prompt in [
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
                if source == EXPRESSION_SHEET:
                    self.assertIn("4x2", prompt_text)
                    self.assertIn("close-camera", prompt_text)
                    for expression in EXPRESSION_VARIANTS:
                        self.assertIn(expression, prompt_text)
                if source == LEDGE_SOURCE:
                    self.assertIn("full-body", prompt_text)
                    self.assertIn("hanging", prompt_text)
                    self.assertIn("boots", prompt_text)
                with Image.open(source) as image:
                    self.assertGreaterEqual(image.width, 512)
                    self.assertGreaterEqual(image.height, 512)
        self.assertTrue(STYLE_REFERENCE.exists(), f"{STYLE_REFERENCE}: missing Belta style reference")

    def test_exporter_uses_explicit_source_contract(self) -> None:
        self.assertTrue(EXPORTER.exists(), f"{EXPORTER}: missing exporter")
        source = EXPORTER.read_text(encoding="utf-8")
        self.assertIn("EXPRESSION_SHEET", source, "exporter must consume the retained Vera expression source sheet")
        self.assertIn("APPROVED_REFERENCE", source, "exporter must retain approved Vera only as a reference")
        self.assertIn("vera_expression_sheet_source_v3.png", source, "Vera formal source must be the close-camera eight-expression sheet")
        self.assertIn("vera_ledge_source_v4.png", source, "Vera ledge source must be the full-body hanging pose")
        self.assertIn("vera_approved_reference_v2.png", source, "approved Vera v2 must remain only as a reference")
        self.assertIn("STYLE_REFERENCE", source, "exporter must record the Belta style reference")
        self.assertIn("VARIANT_CROPS", source, "exporter must use explicit fixed variant crops")
        self.assertIn("EXPRESSION_COLUMNS = 4", source, "Vera v3 expression source must use a 4-column sheet")
        self.assertIn("EXPRESSION_ROWS = 2", source, "Vera v3 expression source must use a 2-row sheet")
        self.assertIn("SOURCE_CROP_BLEED = 48", source, "Vera expressions should keep hand gestures that cross cell edges")
        self.assertIn("LEDGE_NATIVE_SIZE = (128, 320)", source, "full-body ledge pose must use a two-height native canvas")
        self.assertIn("LEDGE_RUNTIME_SIZE", source, "full-body ledge runtime must have a dedicated size")
        self.assertIn("LEDGE_NATIVE_SIZE[0] * RUNTIME_SCALE", source, "ledge runtime width must preserve the 4x scale")
        self.assertIn("LEDGE_NATIVE_SIZE[1] * RUNTIME_SCALE", source, "ledge runtime height must preserve the 4x scale")
        self.assertIn('"neutral": (0, 0, 432, 512)', source, "neutral Vera must use the first close-camera expression cell with bleed")
        for expression in ["warm", "stern", "confused", "tired"]:
            self.assertIn(expression, source, f"Vera exporter must include {expression} expression")
        self.assertIn("NATIVE_SIZE", source, "exporter must define the native pixel size")
        self.assertIn("VISIBLE_TARGET", source, "Vera must use the shared character portrait fit contract")
        self.assertIn("BOTTOM_PADDING", source, "Vera must use the shared character portrait baseline contract")
        self.assertIn("ImageOps.contain", source, "Vera must normalize visible characters through the character pipeline")
        self.assertIn("refine_green_matte", source, "Vera must remove green spill during the matte stage")
        self.assertIn("despill_green_edges", source, "Vera must decontaminate green spill before palette quantization")
        self.assertIn('"characters" / "vera"', source, "Vera runtime output must live under the formal character directory")
        self.assertNotIn("tutorial_narrator", source, "Vera exporter must not use the old narrator source directory")
        self.assertNotIn('"tutorial" / "narrator"', source, "Vera exporter must not write runtime textures to the old tutorial narrator path")
        self.assertNotIn("female_bartender_scribe", source, "Vera exporter must not keep the old descriptive file id")
        self.assertNotIn("nearest_clean_edge_color", source, "Vera must not hide green spill by copying nearby edge colors")
        self.assertNotIn("remove_green_boundary_fringe", source, "Vera must not rely on post-quantization boundary replacement")
        self.assertNotIn("Image.Resampling.BOX", source, "Vera must not use the old soft downsample branch")
        self.assertNotIn("MAX_COLORS = 36", source, "Vera must not use the old low-color branch")
        self.assertNotIn("vera_expression_sheet_source_v2.png", source, "old far-camera Vera sheet must not remain in the exporter")
        self.assertNotIn("vera_base_source_v2.png", source, "approved v2 must not be the formal source filename")
        self.assertNotIn("vera_base_original_source_v1.png", source, "misidentified v1 reference must not be the formal source filename")

    def test_green_spill_is_matted_before_character_scaling(self) -> None:
        exporter = load_exporter_module()
        source = Image.new("RGBA", (7, 7), (0, 255, 0, 255))
        pixels = source.load()
        for y in range(2, 5):
            for x in range(2, 5):
                pixels[x, y] = (92, 55, 35, 255)
        for x in range(1, 6):
            pixels[x, 1] = (28, 41, 36, 255)
            pixels[x, 5] = (28, 41, 36, 255)
        for y in range(1, 6):
            pixels[1, y] = (28, 41, 36, 255)
            pixels[5, y] = (28, 41, 36, 255)

        refined = exporter.refine_green_matte(source)
        refined_pixels = refined.load()
        remaining_spill = []
        for x in range(1, 6):
            remaining_spill.append(refined_pixels[x, 1][3])
            remaining_spill.append(refined_pixels[x, 5][3])
        for y in range(1, 6):
            remaining_spill.append(refined_pixels[1, y][3])
            remaining_spill.append(refined_pixels[5, y][3])

        self.assertTrue(all(alpha == 0 for alpha in remaining_spill), "green spill edge should be cut in the matte")
        self.assertEqual(refined_pixels[3, 3], (92, 55, 35, 255), "interior character pixels must be preserved")

    def test_native_and_runtime_are_exact_pixel_exports(self) -> None:
        for name in [ASSET_ID, *(f"{ASSET_ID}_{variant}" for variant in VARIANTS)]:
            with self.subTest(name=name):
                native = load_rgba(SOURCE / f"{name}_native.png")
                runtime = load_rgba(RUNTIME / f"{name}.png")
                expected_native_size = LEDGE_NATIVE_SIZE if name == f"{ASSET_ID}_ledge" else NATIVE_SIZE
                expected_runtime_size = LEDGE_RUNTIME_SIZE if name == f"{ASSET_ID}_ledge" else RUNTIME_SIZE
                self.assertEqual(native.size, expected_native_size)
                self.assertEqual(runtime.size, expected_runtime_size)
                expected = native.resize(expected_runtime_size, Image.Resampling.NEAREST)
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
                min_visible_ratio = 0.18 if name == f"{ASSET_ID}_ledge" else 0.38
                self.assertGreater(
                    len(visible),
                    native.width * native.height * min_visible_ratio,
                    "portrait silhouette is too sparse",
                )
                self.assertLessEqual(len(set(visible)), COLOR_LIMIT, "native portrait palette is too broad for the character pipeline")

    def test_neutral_runtime_uses_the_expression_sheet_neutral_portrait(self) -> None:
        base_native = load_rgba(SOURCE / f"{ASSET_ID}_native.png")
        neutral_native = load_rgba(SOURCE / f"{ASSET_ID}_neutral_native.png")
        self.assertEqual(
            neutral_native.tobytes(),
            base_native.tobytes(),
            "base Vera and neutral Vera must both be exported from the expression sheet neutral crop",
        )

        base_runtime = load_rgba(RUNTIME / f"{ASSET_ID}.png")
        neutral_runtime = load_rgba(RUNTIME / f"{ASSET_ID}_neutral.png")
        self.assertEqual(
            neutral_runtime.tobytes(),
            base_runtime.tobytes(),
            "runtime neutral Vera must match the expression sheet neutral runtime portrait exactly",
        )

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

    def test_native_edges_have_no_dark_green_screen_fringe(self) -> None:
        for name in [ASSET_ID, *(f"{ASSET_ID}_{variant}" for variant in VARIANTS)]:
            with self.subTest(name=name):
                native = load_rgba(SOURCE / f"{name}_native.png")
                fringe_pixels = []
                for y in range(native.height):
                    for x in range(native.width):
                        pixel = native.getpixel((x, y))
                        if is_alpha_boundary_pixel(native, x, y) and is_green_screen_boundary_fringe(pixel):
                            fringe_pixels.append((x, y, pixel))
                self.assertEqual(
                    fringe_pixels,
                    [],
                    f"{name}: alpha boundary contains dark green-screen fringe pixels",
                )

    def test_expression_variants_are_distinct_but_consistent_portraits(self) -> None:
        neutral = load_rgba(SOURCE / f"{ASSET_ID}_neutral_native.png")
        for variant in EXPRESSION_VARIANTS:
            if variant == "neutral":
                continue
            with self.subTest(variant=variant):
                image = load_rgba(SOURCE / f"{ASSET_ID}_{variant}_native.png")
                changed = sum(
                    1
                    for neutral_px, variant_px in zip(flattened_pixels(neutral), flattened_pixels(image))
                    if neutral_px != variant_px
                )
                self.assertGreaterEqual(changed, 420, f"{variant}: variant is too close to neutral")
                self.assertLessEqual(changed, 18500, f"{variant}: variant drifted too far from the Vera character design")
                self.assertGreaterEqual(visible_bbox_width_ratio(image), 0.62, f"{variant}: portrait silhouette is too loose")

    def test_ledge_pose_is_full_body_hanging_variant(self) -> None:
        ledge = load_rgba(SOURCE / f"{ASSET_ID}_ledge_native.png")
        self.assertEqual(ledge.size, LEDGE_NATIVE_SIZE, "ledge pose must use the dedicated double-height native canvas")
        bbox = ledge.getchannel("A").getbbox()
        self.assertIsNotNone(bbox, "ledge portrait must contain visible pixels")
        if bbox == None:
            return
        left, top, right, bottom = bbox
        visible_width = right - left
        visible_height = bottom - top
        self.assertGreaterEqual(visible_height, 300, "full-body ledge pose should use most of the double-height native canvas")
        self.assertGreaterEqual(visible_width, 78, "ledge upper body should stay near normal portrait scale")
        self.assertLessEqual(visible_width, 124, "full-body ledge pose should remain a vertical hanging silhouette")
        self.assertLessEqual(top, 4, "ledge pose should reach near the top because both hands grip the ledge")
        self.assertGreaterEqual(ledge.height - bottom, 2, "ledge pose must keep boots inside the frame with bottom padding")

    def test_manifest_records_vera_character_asset(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing manifest")
        data = json.loads(MANIFEST.read_text(encoding="utf-8"))
        serialized = json.dumps(data, ensure_ascii=False)
        self.assertNotIn("tutorial_narrator", serialized)
        self.assertNotIn("tutorial/narrator", serialized)
        self.assertNotIn("female_bartender_scribe", serialized)
        self.assertEqual(
            data.get("source_file"),
            "art_sources/generated_raw/characters/vera/vera_expression_sheet_source_v3.png",
        )
        self.assertEqual(
            data.get("prompt"),
            "art_sources/generated_raw/characters/vera/vera_expression_sheet_prompt_v3.txt",
        )
        self.assertEqual(
            data.get("approved_reference"),
            "art_sources/generated_raw/characters/vera/reference/vera_approved_reference_v2.png",
        )
        self.assertEqual(
            data.get("approved_reference_prompt"),
            "art_sources/generated_raw/characters/vera/reference/vera_approved_prompt_v2.txt",
        )
        self.assertEqual(
            data.get("style_references"),
            [
                "art_sources/generated_raw/characters/vera/reference/vera_approved_reference_v2.png",
                "art_sources/generated_raw/characters/regular_customers/regular_belta_style_reference_v1.png",
            ],
        )
        self.assertNotEqual(data.get("source_file"), data.get("approved_reference"))
        assets = data.get("assets", {})
        self.assertIn(ASSET_ID, assets)
        self.assertEqual(
            assets[ASSET_ID],
            {
                "id": ASSET_ID,
                "source_file": "art_sources/generated_raw/characters/vera/vera_expression_sheet_source_v3.png",
                "prompt": "art_sources/generated_raw/characters/vera/vera_expression_sheet_prompt_v3.txt",
                "native_file": "assets/source/tavern/characters/vera/vera_native.png",
                "output_file": "assets/textures/characters/vera/vera.png",
                "native_size": [128, 160],
                "runtime_size": [512, 640],
                "source_crop": VARIANT_CROPS["neutral"],
                "safe_area": [0, 0, 128, 160],
                "intended_godot_use": "TutorialOverlay Vera character portrait source",
            },
        )
        for variant in VARIANTS:
            variant_id = f"{ASSET_ID}_{variant}"
            self.assertIn(variant_id, assets)
            source_file = "art_sources/generated_raw/characters/vera/vera_expression_sheet_source_v3.png"
            prompt_file = "art_sources/generated_raw/characters/vera/vera_expression_sheet_prompt_v3.txt"
            intended_use = "TutorialOverlay Vera character portrait expression variant"
            if variant == "neutral":
                intended_use = "TutorialOverlay Vera neutral portrait using the expression sheet character pipeline"
            if variant == "ledge":
                source_file = "art_sources/generated_raw/characters/vera/vera_ledge_source_v4.png"
                prompt_file = "art_sources/generated_raw/characters/vera/vera_ledge_prompt_v4.txt"
                intended_use = "TutorialOverlay Vera full-body hanging ledge pose"
            self.assertEqual(
                assets[variant_id],
                {
                    "id": variant_id,
                    "source_file": source_file,
                    "prompt": prompt_file,
                    "native_file": f"assets/source/tavern/characters/vera/{variant_id}_native.png",
                    "output_file": f"assets/textures/characters/vera/{variant_id}.png",
                    "native_size": list(LEDGE_NATIVE_SIZE if variant == "ledge" else NATIVE_SIZE),
                    "runtime_size": list(LEDGE_RUNTIME_SIZE if variant == "ledge" else RUNTIME_SIZE),
                    "source_crop": VARIANT_CROPS[variant],
                    "safe_area": [0, 0, 128, 320] if variant == "ledge" else [0, 0, 128, 160],
                    "expression": variant,
                    "intended_godot_use": intended_use,
                },
            )

    def test_contact_sheet_exists(self) -> None:
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing contact sheet")
        image = load_rgba(CONTACT_SHEET)
        self.assertEqual(image.size, CONTACT_SHEET_SIZE)

    def test_contact_sheet_uses_standard_character_grid_without_duplicate_base(self) -> None:
        contact = load_rgba(CONTACT_SHEET).convert("RGB")
        for index, variant in enumerate(CONTACT_SHEET_VARIANTS):
            portrait_id = f"{ASSET_ID}_{variant}"
            with self.subTest(portrait_id=portrait_id):
                native = load_rgba(SOURCE / f"{portrait_id}_native.png")
                x, y = CONTACT_SHEET_NATIVE_POSITIONS[index]
                preview_size = (
                    native.width * CONTACT_SHEET_NATIVE_SCALE,
                    native.height * CONTACT_SHEET_NATIVE_SCALE,
                )
                actual_native = contact.crop((
                    x,
                    y,
                    x + preview_size[0],
                    y + preview_size[1],
                ))
                self.assertEqual(
                    actual_native.tobytes(),
                    expected_backed_native_preview(native).tobytes(),
                    f"{portrait_id}: contact sheet preview must be exact 2x native pixels",
                )

        self.assertEqual(
            len(CONTACT_SHEET_VARIANTS),
            len(CONTACT_SHEET_NATIVE_POSITIONS),
            "Vera contact sheet should have one occupied slot for each expression and ledge pose",
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
