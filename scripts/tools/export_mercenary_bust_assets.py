from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from character_contact_sheet import save_character_contact_sheet
from character_green_matte import despill_green_edges


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "characters" / "mercenary" / "mercenary_a_source_v2.png"
PROMPT = ROOT / "art_sources" / "generated_raw" / "characters" / "mercenary" / "mercenary_a_prompt_v2.txt"
RYAN_REFERENCE = ROOT / "assets" / "textures" / "characters" / "ryan_neutral.png"
SOURCE_DIR = ROOT / "assets" / "source" / "tavern" / "characters"
RUNTIME_DIR = ROOT / "assets" / "textures" / "characters"
MANIFEST_PATH = SOURCE_DIR / "mercenary_bust_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "characters" / "mercenary_contact_sheet.png"

PORTRAIT_ID = "mercenary_a"
NATIVE_SIZE = (128, 160)
RUNTIME_SIZE = (512, 640)
SCALE = 4
COLOR_LIMIT = 72
VISIBLE_TARGET = (124, 154)
BOTTOM_PADDING = 3
SOURCE_RECT = [0, 0, 1122, 1402]
STYLE_PROFILE = "approved_vera_belta_runtime_matched_important_npc_v1"
CONTACT_SHEET_NATIVE_SCALE = 2
CONTACT_SHEET_NATIVE_PREVIEW_SIZE = (
    NATIVE_SIZE[0] * CONTACT_SHEET_NATIVE_SCALE,
    NATIVE_SIZE[1] * CONTACT_SHEET_NATIVE_SCALE,
)
CONTACT_SHEET_NATIVE_X = 340
CONTACT_SHEET_NATIVE_Y = 88
CONTACT_SHEET_NATIVE_BG = (24, 19, 15, 255)
CONTACT_SHEET_BAR_CROP_TOP = 83
CONTACT_SHEET_BAR_CROP_HEIGHT = 52
CONTACT_SHEET_BAR_Y_NATIVE = 121
CONTACT_SHEET_BAR_SIZE = (
    NATIVE_SIZE[0] * CONTACT_SHEET_NATIVE_SCALE,
    CONTACT_SHEET_BAR_CROP_HEIGHT * CONTACT_SHEET_NATIVE_SCALE,
)
CONTACT_SHEET_BAR_X = 690
CONTACT_SHEET_BAR_Y = 88
CONTACT_SHEET_BAR_FILL = (58, 35, 22, 255)
CONTACT_SHEET_BAR_LINE = (205, 132, 58, 255)


def remove_chroma_key(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = pixels[x, y]
            is_key = green >= 145 and green > red * 1.35 and green > blue * 1.35 and green > max(red, blue) + 42
            is_edge_key = green >= 90 and green > red * 1.18 and green > blue * 1.18 and red < 120 and blue < 120
            if is_key or is_edge_key:
                pixels[x, y] = (0, 0, 0, 0)
            elif green > max(red, blue) + 22:
                pixels[x, y] = (red, max(red, blue) + 4, blue, alpha)
    return rgba


def visible_bounds(image: Image.Image) -> tuple[int, int, int, int]:
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        return (0, 0, image.width, image.height)
    return bounds


def trim_visible(image: Image.Image) -> Image.Image:
    left, top, right, bottom = visible_bounds(image)
    width = right - left
    height = bottom - top
    margin_x = max(6, width // 18)
    margin_y = max(6, height // 22)
    return image.crop((
        max(0, left - margin_x),
        max(0, top - margin_y),
        min(image.width, right + margin_x),
        min(image.height, bottom + margin_y),
    ))


def quantize_visible(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A").point(lambda value: 255 if value >= 88 else 0)
    rgb = Image.new("RGB", rgba.size, (0, 0, 0))
    rgb.paste(rgba.convert("RGB"), mask=alpha)
    quantized = rgb.quantize(colors=COLOR_LIMIT, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    quantized.putalpha(alpha)
    pixels = quantized.load()
    for y in range(quantized.height):
        for x in range(quantized.width):
            if pixels[x, y][3] == 0:
                pixels[x, y] = (0, 0, 0, 0)
    return despill_green_edges(quantized)


def normalize_portrait(source: Image.Image) -> Image.Image:
    crop = source.crop(tuple(SOURCE_RECT))
    keyed = remove_chroma_key(crop)
    trimmed = trim_visible(keyed)
    fitted = ImageOps.contain(trimmed, VISIBLE_TARGET, Image.Resampling.NEAREST)
    native = Image.new("RGBA", NATIVE_SIZE, (0, 0, 0, 0))
    x = (NATIVE_SIZE[0] - fitted.width) // 2
    y = NATIVE_SIZE[1] - BOTTOM_PADDING - fitted.height
    y = min(max(0, y), max(0, NATIVE_SIZE[1] - fitted.height))
    native.alpha_composite(fitted, (x, y))
    return quantize_visible(native)


def save_exports(native: Image.Image) -> Image.Image:
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    native_path = SOURCE_DIR / f"{PORTRAIT_ID}_native.png"
    runtime_path = RUNTIME_DIR / f"{PORTRAIT_ID}.png"
    native.save(native_path)
    runtime = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
    runtime.save(runtime_path)
    return runtime


def write_manifest() -> None:
    manifest = {
        "id": "mercenary_bust_portrait",
        "style_profile": STYLE_PROFILE,
        "source": RAW_SOURCE.relative_to(ROOT).as_posix(),
        "prompt": PROMPT.relative_to(ROOT).as_posix(),
        "comparison_reference": RYAN_REFERENCE.relative_to(ROOT).as_posix(),
        "source_rect": SOURCE_RECT,
        "native": (SOURCE_DIR / f"{PORTRAIT_ID}_native.png").relative_to(ROOT).as_posix(),
        "runtime": (RUNTIME_DIR / f"{PORTRAIT_ID}.png").relative_to(ROOT).as_posix(),
        "native_size": list(NATIVE_SIZE),
        "runtime_size": list(RUNTIME_SIZE),
        "safe_area": [0, 0, NATIVE_SIZE[0], NATIVE_SIZE[1]],
        "scale": SCALE,
        "color_limit": COLOR_LIMIT,
        "visible_target": list(VISIBLE_TARGET),
        "bottom_padding": BOTTOM_PADDING,
        "intended_godot_use": "Tavern CustomerSprite Day 3 mercenary messenger portrait behind TabletopArt",
        "character_notes": [
            "adult mercenary messenger",
            "grave fate-reveal expression",
            "battered dark iron helmet",
            "brown cloak and leather armor",
            "no Ryan blue scarf or trainee silhouette",
        ],
    }
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def backed_exact(image: Image.Image, size: tuple[int, int], bg: tuple[int, int, int, int] = CONTACT_SHEET_NATIVE_BG) -> Image.Image:
    preview = image.convert("RGBA")
    if preview.width > size[0] or preview.height > size[1]:
        raise ValueError(f"contact sheet preview {preview.size} does not fit exact backing {size}")
    out = Image.new("RGBA", size, bg)
    out.alpha_composite(preview, ((size[0] - preview.width) // 2, (size[1] - preview.height) // 2))
    return out


def bar_occlusion_preview(native: Image.Image) -> Image.Image:
    crop = native.crop((
        0,
        CONTACT_SHEET_BAR_CROP_TOP,
        NATIVE_SIZE[0],
        CONTACT_SHEET_BAR_CROP_TOP + CONTACT_SHEET_BAR_CROP_HEIGHT,
    ))
    preview = crop.resize(CONTACT_SHEET_BAR_SIZE, Image.Resampling.NEAREST)
    out = backed_exact(preview, CONTACT_SHEET_BAR_SIZE)
    bar_y = (CONTACT_SHEET_BAR_Y_NATIVE - CONTACT_SHEET_BAR_CROP_TOP) * CONTACT_SHEET_NATIVE_SCALE
    draw = ImageDraw.Draw(out)
    draw.rectangle((0, bar_y, CONTACT_SHEET_BAR_SIZE[0], CONTACT_SHEET_BAR_SIZE[1]), fill=CONTACT_SHEET_BAR_FILL)
    draw.line((0, bar_y, CONTACT_SHEET_BAR_SIZE[0], bar_y), fill=CONTACT_SHEET_BAR_LINE, width=1)
    return out


def make_contact_sheet(source: Image.Image, native: Image.Image) -> None:
    del source
    save_character_contact_sheet(
        CONTACT_SHEET,
        "Mercenary character contract sheet",
        "single-expression character sheet, native 128x160 -> runtime 512x640",
        [(PORTRAIT_ID, native)],
    )


def main() -> None:
    if not RAW_SOURCE.exists():
        raise FileNotFoundError(f"missing mercenary source: {RAW_SOURCE}")
    if not PROMPT.exists():
        raise FileNotFoundError(f"missing mercenary prompt record: {PROMPT}")
    source = Image.open(RAW_SOURCE).convert("RGBA")
    native = normalize_portrait(source)
    runtime = save_exports(native)
    write_manifest()
    make_contact_sheet(source, native)
    print("exported mercenary bust: mercenary_a")
    print("contact sheet: docs/art/characters/mercenary_contact_sheet.png")


if __name__ == "__main__":
    main()
