from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "mercenary_bust" / "mercenary_a_source_v1.png"
PROMPT = ROOT / "art_sources" / "generated_raw" / "mercenary_bust" / "mercenary_a_prompt_v1.txt"
RYAN_REFERENCE = ROOT / "assets" / "textures" / "characters" / "ryan_neutral.png"
SOURCE_DIR = ROOT / "assets" / "source" / "tavern" / "characters"
RUNTIME_DIR = ROOT / "assets" / "textures" / "characters"
MANIFEST_PATH = SOURCE_DIR / "mercenary_bust_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "mercenary_bust_contact_sheet.png"

PORTRAIT_ID = "mercenary_a"
NATIVE_SIZE = (70, 90)
RUNTIME_SIZE = (280, 360)
SCALE = 4
COLOR_LIMIT = 28
TARGET_VISIBLE_WIDTH = 62


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
    return quantized


def normalize_portrait(source: Image.Image) -> Image.Image:
    keyed = remove_chroma_key(source)
    trimmed = trim_visible(keyed)
    fitted = ImageOps.contain(trimmed, (66, 88), Image.Resampling.NEAREST)
    if fitted.width > TARGET_VISIBLE_WIDTH:
        fitted = fitted.resize((TARGET_VISIBLE_WIDTH, fitted.height), Image.Resampling.NEAREST)
    native = Image.new("RGBA", NATIVE_SIZE, (0, 0, 0, 0))
    x = (NATIVE_SIZE[0] - fitted.width) // 2
    y = max(0, NATIVE_SIZE[1] - fitted.height)
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
        "style_profile": "ryan_distinct_low_detail_pixel_v1",
        "source": RAW_SOURCE.relative_to(ROOT).as_posix(),
        "prompt": PROMPT.relative_to(ROOT).as_posix(),
        "comparison_reference": RYAN_REFERENCE.relative_to(ROOT).as_posix(),
        "source_rect": [0, 0, 1108, 1421],
        "native": (SOURCE_DIR / f"{PORTRAIT_ID}_native.png").relative_to(ROOT).as_posix(),
        "runtime": (RUNTIME_DIR / f"{PORTRAIT_ID}.png").relative_to(ROOT).as_posix(),
        "native_size": list(NATIVE_SIZE),
        "runtime_size": list(RUNTIME_SIZE),
        "safe_area": [0, 0, NATIVE_SIZE[0], NATIVE_SIZE[1]],
        "scale": SCALE,
        "color_limit": COLOR_LIMIT,
        "target_visible_width": TARGET_VISIBLE_WIDTH,
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


def backed(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    preview = ImageOps.contain(image.convert("RGBA"), size, Image.Resampling.NEAREST)
    out = Image.new("RGBA", size, (24, 19, 15, 255))
    out.alpha_composite(preview, ((size[0] - preview.width) // 2, (size[1] - preview.height) // 2))
    return out


def make_contact_sheet(source: Image.Image, native: Image.Image, runtime: Image.Image) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    out = Image.new("RGBA", (980, 470), (18, 14, 11, 255))
    draw = ImageDraw.Draw(out)
    draw.text((20, 18), "Mercenary A bust portrait pipeline", fill=(222, 204, 176, 255))
    draw.text((20, 44), "source -> native 70x90 -> runtime 280x360, Ryan-distinct Day3 messenger", fill=(180, 168, 144, 255))

    source_preview = ImageOps.contain(source.convert("RGBA"), (260, 330), Image.Resampling.LANCZOS)
    source_backed = Image.new("RGBA", (280, 350), (24, 19, 15, 255))
    source_backed.alpha_composite(source_preview, ((280 - source_preview.width) // 2, (350 - source_preview.height) // 2))
    out.alpha_composite(source_backed, (24, 88))
    draw.text((24, 442), "generated source", fill=(180, 168, 144, 255))

    native_preview = native.resize((NATIVE_SIZE[0] * 4, NATIVE_SIZE[1] * 4), Image.Resampling.NEAREST)
    out.alpha_composite(backed(native_preview, (300, 360)), (340, 78))
    draw.text((340, 442), "native 70x90 preview x4", fill=(180, 168, 144, 255))

    runtime_preview = ImageOps.contain(runtime, (240, 330), Image.Resampling.NEAREST)
    runtime_backed = Image.new("RGBA", (260, 350), (24, 19, 15, 255))
    runtime_backed.alpha_composite(runtime_preview, ((260 - runtime_preview.width) // 2, 0))
    ImageDraw.Draw(runtime_backed).rectangle((0, 272, 260, 350), fill=(58, 35, 22, 240))
    ImageDraw.Draw(runtime_backed).line((0, 272, 260, 272), fill=(205, 132, 58, 255), width=1)
    out.alpha_composite(runtime_backed, (690, 88))
    draw.text((690, 442), "runtime with bar occlusion", fill=(180, 168, 144, 255))
    out.convert("RGB").save(CONTACT_SHEET)


def main() -> None:
    if not RAW_SOURCE.exists():
        raise FileNotFoundError(f"missing mercenary source: {RAW_SOURCE}")
    if not PROMPT.exists():
        raise FileNotFoundError(f"missing mercenary prompt record: {PROMPT}")
    source = Image.open(RAW_SOURCE).convert("RGBA")
    native = normalize_portrait(source)
    runtime = save_exports(native)
    write_manifest()
    make_contact_sheet(source, native, runtime)
    print("exported mercenary bust: mercenary_a")
    print("contact sheet: docs/art/mercenary_bust_contact_sheet.png")


if __name__ == "__main__":
    main()
