from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageOps

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from character_contact_sheet import save_character_contact_sheet


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "characters" / "vera"
REFERENCE_SOURCE = RAW_SOURCE / "reference"
APPROVED_REFERENCE = REFERENCE_SOURCE / "vera_approved_reference_v2.png"
APPROVED_PROMPT_RECORD = REFERENCE_SOURCE / "vera_approved_prompt_v2.txt"
EXPRESSION_SHEET = RAW_SOURCE / "vera_expression_sheet_source_v2.png"
EXPRESSION_PROMPT = RAW_SOURCE / "vera_expression_sheet_prompt_v2.txt"
LEDGE_SOURCE = RAW_SOURCE / "vera_ledge_source_v3.png"
LEDGE_PROMPT = RAW_SOURCE / "vera_ledge_prompt_v3.txt"
STYLE_REFERENCE = ROOT / "art_sources" / "generated_raw" / "characters" / "regular_customers" / "regular_belta_style_reference_v1.png"
SOURCE = ROOT / "assets" / "source" / "tavern" / "characters" / "vera"
RUNTIME = ROOT / "assets" / "textures" / "characters" / "vera"
MANIFEST = SOURCE / "vera_character_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "characters" / "vera_contact_sheet.png"

ASSET_ID = "vera"
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
        "intended_godot_use": "TutorialOverlay Vera character portrait raised dialogue edge pose",
    },
}
NATIVE_SIZE = (128, 160)
RUNTIME_SCALE = 4
RUNTIME_SIZE = (NATIVE_SIZE[0] * RUNTIME_SCALE, NATIVE_SIZE[1] * RUNTIME_SCALE)
SAFE_AREA = [0, 0, NATIVE_SIZE[0], NATIVE_SIZE[1]]
VISIBLE_TARGET = (124, 154)
BOTTOM_PADDING = 3
COLOR_LIMIT = 72
STYLE_PROFILE = "approved_vera_belta_runtime_matched_character_portrait_v1"
EDGE_OFFSETS = [
    (-1, 0),
    (1, 0),
    (0, -1),
    (0, 1),
    (-1, -1),
    (1, -1),
    (-1, 1),
    (1, 1),
]


def repo_path(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def is_green_key(r: int, g: int, b: int) -> bool:
    if g >= 170 and r <= 130 and b <= 150 and g > max(r, b) * 1.35:
        return True
    return g >= 96 and r <= 110 and b <= 130 and g > max(r, b) * 1.45


def is_green_spill_pixel(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, a = pixel
    return a > 0 and g >= 24 and g > r + 6 and g > b + 4


def has_transparent_neighbor(mask: list[list[bool]], x: int, y: int) -> bool:
    height = len(mask)
    width = len(mask[0]) if height else 0
    for dx, dy in EDGE_OFFSETS:
        xx = x + dx
        yy = y + dy
        if 0 <= xx < width and 0 <= yy < height and mask[yy][xx]:
            return True
    return False


def refine_green_matte(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    source = rgba.load()
    transparent = [
        [
            source[x, y][3] == 0 or is_green_key(source[x, y][0], source[x, y][1], source[x, y][2])
            for x in range(rgba.width)
        ]
        for y in range(rgba.height)
    ]
    cut_spill = [
        [
            not transparent[y][x] and is_green_spill_pixel(source[x, y]) and has_transparent_neighbor(transparent, x, y)
            for x in range(rgba.width)
        ]
        for y in range(rgba.height)
    ]
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            if transparent[y][x] or cut_spill[y][x]:
                pixels[x, y] = (0, 0, 0, 0)
    return rgba


def despill_green_edges(image: Image.Image) -> Image.Image:
    source = image.convert("RGBA")
    transparent = [
        [source.getpixel((x, y))[3] == 0 for x in range(source.width)]
        for y in range(source.height)
    ]
    cleaned = source.copy()
    pixels = cleaned.load()
    for y in range(source.height):
        for x in range(source.width):
            r, g, b, a = source.getpixel((x, y))
            if a == 0 or not has_transparent_neighbor(transparent, x, y):
                continue
            if g > max(r, b) + 8:
                pixels[x, y] = (r, max(r, b) + 4, b, a)
    return cleaned


def remove_green_key(image: Image.Image) -> Image.Image:
    return despill_green_edges(refine_green_matte(image))


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
    alpha = image.getchannel("A").point(lambda value: 255 if value >= 80 else 0)
    rgb = Image.new("RGB", image.size, (0, 0, 0))
    rgb.paste(image.convert("RGB"), mask=alpha)
    quantized = rgb.quantize(colors=COLOR_LIMIT, method=Image.Quantize.MEDIANCUT).convert("RGBA")
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
    bounds = keyed.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError(f"{label}: source crop has no visible pixels")
    subject = keyed.crop(bounds)
    fitted = ImageOps.contain(subject, VISIBLE_TARGET, Image.Resampling.NEAREST)
    native = Image.new("RGBA", NATIVE_SIZE, (0, 0, 0, 0))
    x = (NATIVE_SIZE[0] - fitted.width) // 2
    y = NATIVE_SIZE[1] - BOTTOM_PADDING - fitted.height
    y = min(max(0, y), max(0, NATIVE_SIZE[1] - fitted.height))
    native.alpha_composite(fitted, (x, y))
    return quantize_visible(despill_green_edges(native))


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
    if len(set(visible)) > COLOR_LIMIT:
        raise ValueError(f"{label}: native palette exceeds {COLOR_LIMIT} colors")
    visible_green = sum(1 for r, g, b in visible if is_green_key(r, g, b))
    if visible_green > 0:
        raise ValueError(f"{label}: native still has visible green key pixels")


def nearest_runtime(native: Image.Image) -> Image.Image:
    return native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)


def write_contact_sheet(outputs: dict[str, tuple[Image.Image, Image.Image]]) -> None:
    ordered_ids = [
        f"{ASSET_ID}_neutral",
        f"{ASSET_ID}_smirk",
        f"{ASSET_ID}_concerned",
        f"{ASSET_ID}_surprised",
        f"{ASSET_ID}_ledge",
    ]
    save_character_contact_sheet(
        CONTACT_SHEET,
        "Vera character contract sheet",
        "expression-sheet neutral plus variants, native 128x160 -> runtime 512x640",
        [(portrait_id, outputs[portrait_id][0]) for portrait_id in ordered_ids],
    )


def write_manifest() -> None:
    manifest = {
        "character_id": "vera",
        "display_name": "Vera",
        "source_file": repo_path(EXPRESSION_SHEET),
        "prompt": repo_path(EXPRESSION_PROMPT),
        "approved_reference": repo_path(APPROVED_REFERENCE),
        "approved_reference_prompt": repo_path(APPROVED_PROMPT_RECORD),
        "expression_sheet": repo_path(EXPRESSION_SHEET),
        "expression_prompt": repo_path(EXPRESSION_PROMPT),
        "ledge_source": repo_path(LEDGE_SOURCE),
        "ledge_prompt": repo_path(LEDGE_PROMPT),
        "style_references": [
            repo_path(APPROVED_REFERENCE),
            repo_path(STYLE_REFERENCE),
        ],
        "style_profile": STYLE_PROFILE,
        "native_dir": "assets/source/tavern/characters/vera",
        "runtime_dir": "assets/textures/characters/vera",
        "contact_sheet": "docs/art/characters/vera_contact_sheet.png",
        "color_limit": COLOR_LIMIT,
        "visible_target": list(VISIBLE_TARGET),
        "bottom_padding": BOTTOM_PADDING,
        "runtime_scale": RUNTIME_SCALE,
        "assets": {
            ASSET_ID: {
                "id": ASSET_ID,
                "source_file": repo_path(EXPRESSION_SHEET),
                "prompt": repo_path(EXPRESSION_PROMPT),
                "native_file": "assets/source/tavern/characters/vera/vera_native.png",
                "output_file": "assets/textures/characters/vera/vera.png",
                "native_size": list(NATIVE_SIZE),
                "runtime_size": list(RUNTIME_SIZE),
                "source_crop": list(VARIANT_CROPS["neutral"]),
                "safe_area": SAFE_AREA,
                "intended_godot_use": "TutorialOverlay Vera character portrait source",
            }
        },
    }
    neutral_id = f"{ASSET_ID}_neutral"
    manifest["assets"][neutral_id] = {
        "id": neutral_id,
        "source_file": repo_path(EXPRESSION_SHEET),
        "prompt": repo_path(EXPRESSION_PROMPT),
        "native_file": f"assets/source/tavern/characters/vera/{neutral_id}_native.png",
        "output_file": f"assets/textures/characters/vera/{neutral_id}.png",
        "native_size": list(NATIVE_SIZE),
        "runtime_size": list(RUNTIME_SIZE),
        "source_crop": list(VARIANT_CROPS["neutral"]),
        "safe_area": SAFE_AREA,
        "expression": "neutral",
        "intended_godot_use": "TutorialOverlay Vera neutral portrait using the expression sheet character pipeline",
    }
    for expression, crop in VARIANT_CROPS.items():
        if expression == "neutral":
            continue
        variant_id = f"{ASSET_ID}_{expression}"
        manifest["assets"][variant_id] = {
            "id": variant_id,
            "source_file": repo_path(EXPRESSION_SHEET),
            "prompt": repo_path(EXPRESSION_PROMPT),
            "native_file": f"assets/source/tavern/characters/vera/{variant_id}_native.png",
            "output_file": f"assets/textures/characters/vera/{variant_id}.png",
            "native_size": list(NATIVE_SIZE),
            "runtime_size": list(RUNTIME_SIZE),
            "source_crop": list(crop),
            "safe_area": SAFE_AREA,
            "expression": expression,
            "intended_godot_use": "TutorialOverlay Vera character portrait expression variant",
        }
    for expression, spec in EXTRA_VARIANTS.items():
        variant_id = f"{ASSET_ID}_{expression}"
        manifest["assets"][variant_id] = {
            "id": variant_id,
            "source_file": repo_path(spec["source"]),
            "prompt": repo_path(spec["prompt"]),
            "native_file": f"assets/source/tavern/characters/vera/{variant_id}_native.png",
            "output_file": f"assets/textures/characters/vera/{variant_id}.png",
            "native_size": list(NATIVE_SIZE),
            "runtime_size": list(RUNTIME_SIZE),
            "source_crop": list(spec["crop"]),
            "safe_area": SAFE_AREA,
            "expression": expression,
            "intended_godot_use": spec["intended_godot_use"],
        }
    MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> None:
    if not APPROVED_REFERENCE.exists():
        raise FileNotFoundError(f"Missing approved Vera reference: {APPROVED_REFERENCE}")
    if not APPROVED_PROMPT_RECORD.exists():
        raise FileNotFoundError(f"Missing approved Vera reference prompt record: {APPROVED_PROMPT_RECORD}")
    if not EXPRESSION_SHEET.exists():
        raise FileNotFoundError(f"Missing Vera character expression sheet: {EXPRESSION_SHEET}")
    if not EXPRESSION_PROMPT.exists():
        raise FileNotFoundError(f"Missing Vera character expression prompt record: {EXPRESSION_PROMPT}")
    for expression, spec in EXTRA_VARIANTS.items():
        if not spec["source"].exists():
            raise FileNotFoundError(f"Missing Vera character {expression} source: {spec['source']}")
        if not spec["prompt"].exists():
            raise FileNotFoundError(f"Missing Vera character {expression} prompt record: {spec['prompt']}")
    if not STYLE_REFERENCE.exists():
        raise FileNotFoundError(f"Missing Vera character style reference: {STYLE_REFERENCE}")
    SOURCE.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)

    outputs: dict[str, tuple[Image.Image, Image.Image]] = {}
    with Image.open(EXPRESSION_SHEET) as expression_sheet:
        native = make_native(expression_sheet, VARIANT_CROPS["neutral"], ASSET_ID)
        validate_native(native, ASSET_ID)
        runtime = nearest_runtime(native)
        outputs[ASSET_ID] = (native, runtime)
        native.save(SOURCE / f"{ASSET_ID}_native.png")
        runtime.save(RUNTIME / f"{ASSET_ID}.png")
        print(f"{ASSET_ID}: {native.size} -> {runtime.size}")

        neutral_id = f"{ASSET_ID}_neutral"
        outputs[neutral_id] = (native.copy(), runtime.copy())
        native.save(SOURCE / f"{neutral_id}_native.png")
        runtime.save(RUNTIME / f"{neutral_id}.png")
        print(f"{neutral_id}: {native.size} -> {runtime.size}")

        for expression, crop in VARIANT_CROPS.items():
            if expression == "neutral":
                continue
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

    write_contact_sheet(outputs)
    write_manifest()
    print(f"contact_sheet: {CONTACT_SHEET}")
    print(f"manifest: {MANIFEST}")


if __name__ == "__main__":
    main()
