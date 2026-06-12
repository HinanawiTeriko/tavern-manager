from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "toby_bust" / "toby_neutral_source_v2.png"
RYAN_REFERENCE = ROOT / "assets" / "textures" / "characters" / "ryan_neutral.png"
MIRA_REFERENCE = ROOT / "assets" / "textures" / "characters" / "mira_neutral.png"
SOURCE_DIR = ROOT / "assets" / "source" / "tavern" / "characters"
RUNTIME_DIR = ROOT / "assets" / "textures" / "characters"
MANIFEST_PATH = SOURCE_DIR / "toby_bust_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "toby_bust_contact_sheet.png"

PORTRAIT_ID = "toby_neutral"
NATIVE_SIZE = (70, 90)
RUNTIME_SIZE = (280, 360)
SCALE = 4
SOURCE_RECT = [0, 0, 1106, 1422]
COLOR_LIMIT = 20
TARGET_VISIBLE_WIDTH = 54


def remove_chroma_key(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = pixels[x, y]
            is_key = green >= 110 and green > red * 1.55 and green > blue * 1.55
            is_edge_key = green >= 85 and green > red * 1.25 and green > blue * 1.25 and red < 90 and blue < 90
            if is_key or is_edge_key:
                pixels[x, y] = (0, 0, 0, 0)
            elif green > max(red, blue) + 18:
                pixels[x, y] = (red, max(red, blue) + 4, blue, alpha)
    return rgba


def visible_bounds(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A")
    bounds = alpha.getbbox()
    if bounds == None:
        return (0, 0, image.width, image.height)
    return bounds


def quantize_visible(image: Image.Image, colors: int = COLOR_LIMIT) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A").point(lambda value: 255 if value >= 80 else 0)
    rgb = Image.new("RGB", rgba.size, (0, 0, 0))
    rgb.paste(rgba.convert("RGB"), mask=alpha)
    quantized = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    quantized.putalpha(alpha)
    pixels = quantized.load()
    for y in range(quantized.height):
        for x in range(quantized.width):
            if pixels[x, y][3] == 0:
                pixels[x, y] = (0, 0, 0, 0)
    return quantized


def normalize_portrait(source: Image.Image) -> Image.Image:
    crop = source.crop(tuple(SOURCE_RECT))
    keyed = remove_chroma_key(crop)
    bounds = visible_bounds(keyed)
    subject = keyed.crop(bounds)
    fitted = ImageOps.contain(subject, (62, 88), Image.Resampling.NEAREST)
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
        "id": "toby_bust_portrait",
        "style_profile": "ryan_mira_distinct_low_detail_pixel_v2",
        "source": RAW_SOURCE.relative_to(ROOT).as_posix(),
        "comparison_references": [
            RYAN_REFERENCE.relative_to(ROOT).as_posix(),
            MIRA_REFERENCE.relative_to(ROOT).as_posix(),
        ],
        "source_rect": SOURCE_RECT,
        "native": (SOURCE_DIR / f"{PORTRAIT_ID}_native.png").relative_to(ROOT).as_posix(),
        "runtime": (RUNTIME_DIR / f"{PORTRAIT_ID}.png").relative_to(ROOT).as_posix(),
        "native_size": list(NATIVE_SIZE),
        "runtime_size": list(RUNTIME_SIZE),
        "safe_area": [0, 0, NATIVE_SIZE[0], NATIVE_SIZE[1]],
        "scale": SCALE,
        "color_limit": COLOR_LIMIT,
        "target_visible_width": TARGET_VISIBLE_WIDTH,
        "intended_godot_use": "Tavern CustomerSprite Toby bust portrait behind TabletopArt",
        "character_notes": [
            "teenage wandering apprentice",
            "stubborn tired expression",
            "dirty blond bowl-cut hair and ragged gray-green shoulder cape",
            "large readable shapes: patched shirt, belt pouch, awkward short sword, contract roll",
            "nearest-neighbor native pass with a tight palette to avoid high-resolution illustration texture",
        ],
        "bar_occlusion_contract": {
            "customer_sprite_path": "res://scenes/ui/Tavern.tscn:CustomerArea/CustomerSprite",
            "runtime_sprite_size": list(RUNTIME_SIZE),
            "tabletop_top_y_runtime": 484,
            "tabletop_art_z_index": -90,
            "customer_sprite_z_index": -95,
        },
    }
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def backed(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    preview = ImageOps.contain(image.convert("RGBA"), size, Image.Resampling.NEAREST)
    out = Image.new("RGBA", size, (24, 20, 16, 255))
    out.alpha_composite(preview, ((size[0] - preview.width) // 2, (size[1] - preview.height) // 2))
    return out


def load_reference(path: Path) -> Image.Image:
    if path.exists():
        return Image.open(path).convert("RGBA")
    return Image.new("RGBA", RUNTIME_SIZE, (0, 0, 0, 0))


def make_contact_sheet(source: Image.Image, native: Image.Image, runtime: Image.Image) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    out = Image.new("RGBA", (1180, 500), (18, 14, 11, 255))
    draw = ImageDraw.Draw(out)
    draw.text((20, 18), "Toby bust portrait pipeline", fill=(222, 204, 176, 255))
    draw.text((20, 46), "v2 distinct low-detail native pass: Ryan and Mira comparison, native 70x90, runtime 280x360", fill=(180, 168, 144, 255))
    source_preview = ImageOps.contain(source.convert("RGBA"), (190, 250), Image.Resampling.LANCZOS)
    out.alpha_composite(source_preview, (24, 88))
    draw.text((24, 352), "raw v2 source", fill=(180, 168, 144, 255))

    ryan_preview = ImageOps.contain(load_reference(RYAN_REFERENCE), (170, 250), Image.Resampling.NEAREST)
    ryan_backed = Image.new("RGBA", (190, 270), (24, 20, 16, 255))
    ryan_backed.alpha_composite(ryan_preview, ((190 - ryan_preview.width) // 2, 8))
    out.alpha_composite(ryan_backed, (236, 96))
    draw.text((236, 392), "Ryan neutral reference", fill=(180, 168, 144, 255))

    mira_preview = ImageOps.contain(load_reference(MIRA_REFERENCE), (170, 250), Image.Resampling.NEAREST)
    mira_backed = Image.new("RGBA", (190, 270), (24, 20, 16, 255))
    mira_backed.alpha_composite(mira_preview, ((190 - mira_preview.width) // 2, 8))
    out.alpha_composite(mira_backed, (444, 96))
    draw.text((444, 392), "Mira neutral reference", fill=(180, 168, 144, 255))

    native_preview = native.resize((NATIVE_SIZE[0] * 4, NATIVE_SIZE[1] * 4), Image.Resampling.NEAREST)
    out.alpha_composite(backed(native_preview, (300, 370)), (650, 82))
    draw.text((650, 462), "Toby native 4x preview", fill=(180, 168, 144, 255))

    runtime_preview = ImageOps.contain(runtime, (150, 220), Image.Resampling.NEAREST)
    backed_runtime = Image.new("RGBA", (160, 220), (24, 20, 16, 255))
    backed_runtime.alpha_composite(runtime_preview, ((160 - runtime_preview.width) // 2, 0))
    ImageDraw.Draw(backed_runtime).rectangle((0, 164, 160, 220), fill=(58, 35, 22, 240))
    ImageDraw.Draw(backed_runtime).line((0, 164, 160, 164), fill=(205, 132, 58, 255), width=1)
    out.alpha_composite(backed_runtime, (980, 132))
    draw.text((980, 392), "bar occlusion preview", fill=(180, 168, 144, 255))
    out.convert("RGB").save(CONTACT_SHEET)


def main() -> None:
    if not RAW_SOURCE.exists():
        raise FileNotFoundError(f"missing Toby bust source: {RAW_SOURCE}")
    source = Image.open(RAW_SOURCE).convert("RGBA")
    native = normalize_portrait(source)
    runtime = save_exports(native)
    write_manifest()
    make_contact_sheet(source, native, runtime)
    print("exported Toby bust portrait: " + PORTRAIT_ID)
    print("contact sheet: docs/art/toby_bust_contact_sheet.png")


if __name__ == "__main__":
    main()
