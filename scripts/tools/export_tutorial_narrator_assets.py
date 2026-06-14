from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageEnhance


ROOT = Path(__file__).resolve().parents[2]
SOURCE_IMAGE = ROOT / "art_sources" / "generated_raw" / "tutorial_narrator" / "female_bartender_scribe_pixel_source_v2.png"
PROMPT_RECORD = ROOT / "art_sources" / "generated_raw" / "tutorial_narrator" / "female_bartender_scribe_pixel_prompt_v2.txt"
EXPRESSION_SHEET = ROOT / "art_sources" / "generated_raw" / "tutorial_narrator" / "female_bartender_scribe_expression_sheet_source_v2.png"
EXPRESSION_PROMPT = ROOT / "art_sources" / "generated_raw" / "tutorial_narrator" / "female_bartender_scribe_expression_sheet_prompt_v2.txt"
LEDGE_SOURCE = ROOT / "art_sources" / "generated_raw" / "tutorial_narrator" / "female_bartender_scribe_ledge_source_v3.png"
LEDGE_PROMPT = ROOT / "art_sources" / "generated_raw" / "tutorial_narrator" / "female_bartender_scribe_ledge_prompt_v3.txt"
STYLE_REFERENCE = ROOT / "art_sources" / "generated_raw" / "regular_customers" / "regular_belta_neutral_pilot_source_v1.png"
SOURCE = ROOT / "assets" / "source" / "tutorial_narrator"
RUNTIME = ROOT / "assets" / "textures" / "tutorial" / "narrator"
MANIFEST = SOURCE / "tutorial_narrator_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "tutorial_narrator_contact_sheet.png"

ASSET_ID = "female_bartender_scribe"
SOURCE_CROP = (0, 0, 1122, 1402)
VARIANT_CROPS = {
    "neutral": (104, 20, 570, 620),
    "smirk": (674, 20, 1138, 620),
    "concerned": (86, 636, 552, 1236),
    "surprised": (676, 636, 1142, 1236),
}
EXTRA_VARIANTS = {
    "ledge": {
        "source": LEDGE_SOURCE,
        "prompt": LEDGE_PROMPT,
        "crop": (183, 168, 903, 1068),
        "intended_godot_use": "TutorialOverlay narrator portrait raised dialogue edge pose",
    },
}
NATIVE_SIZE = (128, 160)
RUNTIME_SCALE = 4
RUNTIME_SIZE = (NATIVE_SIZE[0] * RUNTIME_SCALE, NATIVE_SIZE[1] * RUNTIME_SCALE)
SAFE_AREA = [18, 8, 92, 142]
MAX_COLORS = 36


def is_green_key(r: int, g: int, b: int) -> bool:
    if g >= 170 and r <= 130 and b <= 150 and g > max(r, b) * 1.35:
        return True
    return g >= 96 and r <= 110 and b <= 130 and g > max(r, b) * 1.45


def remove_green_key(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if a == 0 or is_green_key(r, g, b):
                pixels[x, y] = (0, 0, 0, 0)
    return rgba


def crop_explicit_source(image: Image.Image, crop: tuple[int, int, int, int], label: str) -> Image.Image:
    x0, y0, x1, y1 = crop
    if x0 < 0 or y0 < 0 or x1 > image.width or y1 > image.height or x1 <= x0 or y1 <= y0:
        raise ValueError(f"{label}: invalid source crop {crop} for source {image.size}")
    return image.crop(crop).convert("RGBA")


def clear_transparent_pixels(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if a == 0 or is_green_key(r, g, b):
                pixels[x, y] = (0, 0, 0, 0)
    return rgba


def quantize_visible(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    rgb = Image.new("RGB", image.size, (0, 0, 0))
    rgb.paste(image.convert("RGB"), mask=alpha)
    quantized = rgb.quantize(colors=MAX_COLORS, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    quantized.putalpha(alpha)
    return clear_transparent_pixels(quantized)


def flattened_pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    if hasattr(image, "get_flattened_data"):
        return list(image.get_flattened_data())
    return list(image.getdata())


def make_native(
    image: Image.Image,
    crop: tuple[int, int, int, int],
    label: str,
) -> Image.Image:
    keyed = remove_green_key(crop_explicit_source(image, crop, label))
    resized = keyed.resize(NATIVE_SIZE, Image.Resampling.BOX).convert("RGBA")
    resized = ImageEnhance.Contrast(resized).enhance(1.08)
    alpha = resized.getchannel("A").point(lambda value: 255 if value >= 96 else 0)
    resized.putalpha(alpha)
    return quantize_visible(clear_transparent_pixels(resized))


def validate_native(native: Image.Image, label: str) -> None:
    if native.size != NATIVE_SIZE:
        raise ValueError(f"{label}: native must be {NATIVE_SIZE}, got {native.size}")
    pixels = flattened_pixels(native.convert("RGBA"))
    alphas = [a for _r, _g, _b, a in pixels]
    if min(alphas) != 0 or max(alphas) != 255:
        raise ValueError(f"{label}: native needs transparent and opaque pixels")
    if any(a not in [0, 255] for a in alphas):
        raise ValueError(f"{label}: native alpha must be hard")
    visible = [(r, g, b) for r, g, b, a in pixels if a > 0]
    if len(visible) <= native.width * native.height * 0.38:
        raise ValueError(f"{label}: native silhouette is too sparse")
    if len(set(visible)) > MAX_COLORS:
        raise ValueError(f"{label}: native palette exceeds {MAX_COLORS} colors")
    visible_green = sum(1 for r, g, b in visible if is_green_key(r, g, b))
    if visible_green > 0:
        raise ValueError(f"{label}: native still has visible green key pixels")


def nearest_runtime(native: Image.Image) -> Image.Image:
    return native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)


def checkerboard(size: tuple[int, int], tile: int = 16) -> Image.Image:
    sheet = Image.new("RGBA", size, (0, 0, 0, 255))
    pixels = sheet.load()
    for y in range(size[1]):
        for x in range(size[0]):
            shade = 38 if ((x // tile) + (y // tile)) % 2 == 0 else 54
            pixels[x, y] = (shade, shade, shade, 255)
    return sheet


def build_contact_sheet(outputs: dict[str, tuple[Image.Image, Image.Image]]) -> Image.Image:
    sheet = checkerboard((1120, 900), tile=16)
    positions = {
        ASSET_ID: (32, 32),
        f"{ASSET_ID}_neutral": (392, 32),
        f"{ASSET_ID}_ledge": (752, 32),
        f"{ASSET_ID}_smirk": (32, 476),
        f"{ASSET_ID}_concerned": (392, 476),
        f"{ASSET_ID}_surprised": (752, 476),
    }
    for name, position in positions.items():
        native, _runtime = outputs[name]
        preview = native.resize((native.width * 2, native.height * 2), Image.Resampling.NEAREST)
        sheet.alpha_composite(preview, position)
    return sheet


def write_manifest() -> None:
    manifest = {
        "source_file": "art_sources/generated_raw/tutorial_narrator/female_bartender_scribe_pixel_source_v2.png",
        "prompt": "art_sources/generated_raw/tutorial_narrator/female_bartender_scribe_pixel_prompt_v2.txt",
        "expression_sheet": "art_sources/generated_raw/tutorial_narrator/female_bartender_scribe_expression_sheet_source_v2.png",
        "expression_prompt": "art_sources/generated_raw/tutorial_narrator/female_bartender_scribe_expression_sheet_prompt_v2.txt",
        "ledge_source": "art_sources/generated_raw/tutorial_narrator/female_bartender_scribe_ledge_source_v3.png",
        "ledge_prompt": "art_sources/generated_raw/tutorial_narrator/female_bartender_scribe_ledge_prompt_v3.txt",
        "style_reference": "art_sources/generated_raw/regular_customers/regular_belta_neutral_pilot_source_v1.png",
        "runtime_scale": RUNTIME_SCALE,
        "assets": {
            ASSET_ID: {
                "id": ASSET_ID,
                "source_file": "art_sources/generated_raw/tutorial_narrator/female_bartender_scribe_pixel_source_v2.png",
                "prompt": "art_sources/generated_raw/tutorial_narrator/female_bartender_scribe_pixel_prompt_v2.txt",
                "native_file": "assets/source/tutorial_narrator/female_bartender_scribe_native.png",
                "output_file": "assets/textures/tutorial/narrator/female_bartender_scribe.png",
                "native_size": list(NATIVE_SIZE),
                "runtime_size": list(RUNTIME_SIZE),
                "source_crop": list(SOURCE_CROP),
                "safe_area": SAFE_AREA,
                "intended_godot_use": "TutorialOverlay narrator portrait source, not wired into runtime yet",
            }
        },
    }
    for expression, crop in VARIANT_CROPS.items():
        variant_id = f"{ASSET_ID}_{expression}"
        manifest["assets"][variant_id] = {
            "id": variant_id,
            "source_file": "art_sources/generated_raw/tutorial_narrator/female_bartender_scribe_expression_sheet_source_v2.png",
            "prompt": "art_sources/generated_raw/tutorial_narrator/female_bartender_scribe_expression_sheet_prompt_v2.txt",
            "native_file": f"assets/source/tutorial_narrator/{variant_id}_native.png",
            "output_file": f"assets/textures/tutorial/narrator/{variant_id}.png",
            "native_size": list(NATIVE_SIZE),
            "runtime_size": list(RUNTIME_SIZE),
            "source_crop": list(crop),
            "safe_area": SAFE_AREA,
            "expression": expression,
            "intended_godot_use": "TutorialOverlay narrator portrait expression variant, not wired into runtime yet",
        }
    for expression, spec in EXTRA_VARIANTS.items():
        variant_id = f"{ASSET_ID}_{expression}"
        manifest["assets"][variant_id] = {
            "id": variant_id,
            "source_file": str(spec["source"].relative_to(ROOT)).replace("\\", "/"),
            "prompt": str(spec["prompt"].relative_to(ROOT)).replace("\\", "/"),
            "native_file": f"assets/source/tutorial_narrator/{variant_id}_native.png",
            "output_file": f"assets/textures/tutorial/narrator/{variant_id}.png",
            "native_size": list(NATIVE_SIZE),
            "runtime_size": list(RUNTIME_SIZE),
            "source_crop": list(spec["crop"]),
            "safe_area": SAFE_AREA,
            "expression": expression,
            "intended_godot_use": spec["intended_godot_use"],
        }
    MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> None:
    if not SOURCE_IMAGE.exists():
        raise FileNotFoundError(f"Missing tutorial narrator source: {SOURCE_IMAGE}")
    if not PROMPT_RECORD.exists():
        raise FileNotFoundError(f"Missing tutorial narrator prompt record: {PROMPT_RECORD}")
    if not EXPRESSION_SHEET.exists():
        raise FileNotFoundError(f"Missing tutorial narrator expression sheet: {EXPRESSION_SHEET}")
    if not EXPRESSION_PROMPT.exists():
        raise FileNotFoundError(f"Missing tutorial narrator expression prompt record: {EXPRESSION_PROMPT}")
    for expression, spec in EXTRA_VARIANTS.items():
        if not spec["source"].exists():
            raise FileNotFoundError(f"Missing tutorial narrator {expression} source: {spec['source']}")
        if not spec["prompt"].exists():
            raise FileNotFoundError(f"Missing tutorial narrator {expression} prompt record: {spec['prompt']}")
    if not STYLE_REFERENCE.exists():
        raise FileNotFoundError(f"Missing tutorial narrator style reference: {STYLE_REFERENCE}")
    SOURCE.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)

    outputs: dict[str, tuple[Image.Image, Image.Image]] = {}
    with Image.open(SOURCE_IMAGE) as source_image:
        native = make_native(source_image, SOURCE_CROP, ASSET_ID)
    validate_native(native, ASSET_ID)
    runtime = nearest_runtime(native)
    outputs[ASSET_ID] = (native, runtime)
    native.save(SOURCE / f"{ASSET_ID}_native.png")
    runtime.save(RUNTIME / f"{ASSET_ID}.png")
    print(f"{ASSET_ID}: {native.size} -> {runtime.size}")

    with Image.open(EXPRESSION_SHEET) as expression_sheet:
        for expression, crop in VARIANT_CROPS.items():
            variant_id = f"{ASSET_ID}_{expression}"
            variant_native = make_native(expression_sheet, crop, variant_id)
            validate_native(variant_native, variant_id)
            variant_runtime = nearest_runtime(variant_native)
            outputs[variant_id] = (variant_native, variant_runtime)
            variant_native.save(SOURCE / f"{variant_id}_native.png")
            variant_runtime.save(RUNTIME / f"{variant_id}.png")
            print(f"{variant_id}: {variant_native.size} -> {variant_runtime.size}")

    for expression, spec in EXTRA_VARIANTS.items():
        variant_id = f"{ASSET_ID}_{expression}"
        with Image.open(spec["source"]) as source_image:
            variant_native = make_native(source_image, spec["crop"], variant_id)
        validate_native(variant_native, variant_id)
        variant_runtime = nearest_runtime(variant_native)
        outputs[variant_id] = (variant_native, variant_runtime)
        variant_native.save(SOURCE / f"{variant_id}_native.png")
        variant_runtime.save(RUNTIME / f"{variant_id}.png")
        print(f"{variant_id}: {variant_native.size} -> {variant_runtime.size}")

    build_contact_sheet(outputs).convert("RGB").save(CONTACT_SHEET)
    write_manifest()
    print(f"contact_sheet: {CONTACT_SHEET}")
    print(f"manifest: {MANIFEST}")


if __name__ == "__main__":
    main()
