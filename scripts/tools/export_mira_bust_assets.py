from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "mira_bust" / "mira_neutral_source_v1.png"
SOURCE_DIR = ROOT / "assets" / "source" / "tavern" / "characters"
RUNTIME_DIR = ROOT / "assets" / "textures" / "characters"
MANIFEST_PATH = SOURCE_DIR / "mira_bust_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "mira_bust_contact_sheet.png"

PORTRAIT_ID = "mira_neutral"
NATIVE_SIZE = (70, 90)
RUNTIME_SIZE = (280, 360)
SCALE = 4
SOURCE_RECT = [0, 0, 1111, 1416]


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


def quantize_visible(image: Image.Image, colors: int = 32) -> Image.Image:
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
    fitted = ImageOps.contain(subject, (66, 88), Image.Resampling.LANCZOS)
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
        "id": "mira_bust_portrait",
        "source": RAW_SOURCE.relative_to(ROOT).as_posix(),
        "source_rect": SOURCE_RECT,
        "native": (SOURCE_DIR / f"{PORTRAIT_ID}_native.png").relative_to(ROOT).as_posix(),
        "runtime": (RUNTIME_DIR / f"{PORTRAIT_ID}.png").relative_to(ROOT).as_posix(),
        "native_size": list(NATIVE_SIZE),
        "runtime_size": list(RUNTIME_SIZE),
        "safe_area": [0, 0, NATIVE_SIZE[0], NATIVE_SIZE[1]],
        "scale": SCALE,
        "intended_godot_use": "Tavern CustomerSprite Mira bust portrait behind TabletopArt",
        "character_notes": [
            "adult traveling merchant",
            "guarded professional smile",
            "high ponytail",
            "merchant pouches, brass scale, scroll tube, shoulder bag",
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


def make_contact_sheet(source: Image.Image, native: Image.Image, runtime: Image.Image) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    out = Image.new("RGBA", (720, 460), (18, 14, 11, 255))
    draw = ImageDraw.Draw(out)
    draw.text((20, 18), "Mira bust portrait pipeline", fill=(222, 204, 176, 255))
    draw.text((20, 46), "AI source, native 70x90, runtime 280x360", fill=(180, 168, 144, 255))
    source_preview = ImageOps.contain(source.convert("RGBA"), (240, 310), Image.Resampling.LANCZOS)
    out.alpha_composite(source_preview, (28, 78))
    draw.text((28, 392), "raw source", fill=(180, 168, 144, 255))

    native_preview = native.resize((NATIVE_SIZE[0] * 3, NATIVE_SIZE[1] * 3), Image.Resampling.NEAREST)
    out.alpha_composite(backed(native_preview, (230, 300)), (294, 82))
    draw.text((294, 392), "native 3x preview", fill=(180, 168, 144, 255))

    runtime_preview = ImageOps.contain(runtime, (150, 220), Image.Resampling.NEAREST)
    backed_runtime = Image.new("RGBA", (160, 220), (24, 20, 16, 255))
    backed_runtime.alpha_composite(runtime_preview, ((160 - runtime_preview.width) // 2, 0))
    ImageDraw.Draw(backed_runtime).rectangle((0, 164, 160, 220), fill=(58, 35, 22, 240))
    ImageDraw.Draw(backed_runtime).line((0, 164, 160, 164), fill=(205, 132, 58, 255), width=1)
    out.alpha_composite(backed_runtime, (542, 120))
    draw.text((542, 392), "bar occlusion preview", fill=(180, 168, 144, 255))
    out.convert("RGB").save(CONTACT_SHEET)


def main() -> None:
    if not RAW_SOURCE.exists():
        raise FileNotFoundError(f"missing Mira bust source: {RAW_SOURCE}")
    source = Image.open(RAW_SOURCE).convert("RGBA")
    native = normalize_portrait(source)
    runtime = save_exports(native)
    write_manifest()
    make_contact_sheet(source, native, runtime)
    print("exported Mira bust portrait: " + PORTRAIT_ID)
    print("contact sheet: docs/art/mira_bust_contact_sheet.png")


if __name__ == "__main__":
    main()
