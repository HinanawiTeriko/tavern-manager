from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "ryan_bust" / "ryan_bust_expression_sheet_v2.png"
SOURCE_DIR = ROOT / "assets" / "source" / "tavern" / "characters"
RUNTIME_DIR = ROOT / "assets" / "textures" / "characters"
MANIFEST_PATH = SOURCE_DIR / "ryan_bust_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "ryan_bust_contact_sheet.png"

NATIVE_SIZE = (70, 90)
RUNTIME_SIZE = (280, 360)
SCALE = 4

PORTRAITS = {
    "ryan_neutral": {
        "expression": "forced smile",
        "crop_rect": [18, 100, 430, 760],
    },
    "ryan_excited": {
        "expression": "trying to act confident",
        "crop_rect": [448, 88, 870, 760],
    },
    "ryan_hesitant": {
        "expression": "worried hesitation",
        "crop_rect": [880, 102, 1290, 760],
    },
    "ryan_dejected": {
        "expression": "tired dejection",
        "crop_rect": [1290, 132, 1722, 760],
    },
}


def remove_chroma_key(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if g >= 115 and g > r * 1.2 and g > b * 1.2 and g > max(r, b) + 24:
                pixels[x, y] = (0, 0, 0, 0)
            elif g > max(r, b) + 18:
                pixels[x, y] = (r, max(r, b) + 4, b, a)
    return rgba


def quantize_visible(image: Image.Image, colors: int = 32) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A").point(lambda value: 255 if value >= 96 else 0)
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


def normalize_portrait(sheet: Image.Image, crop_rect: list[int]) -> Image.Image:
    crop = sheet.crop(tuple(crop_rect))
    keyed = remove_chroma_key(crop)
    fitted = ImageOps.contain(keyed, NATIVE_SIZE, Image.Resampling.NEAREST)
    native = Image.new("RGBA", NATIVE_SIZE, (0, 0, 0, 0))
    x = (NATIVE_SIZE[0] - fitted.width) // 2
    y = max(0, NATIVE_SIZE[1] - fitted.height)
    native.alpha_composite(fitted, (x, y))
    return quantize_visible(native)


def save_runtime(native: Image.Image, portrait_id: str) -> Image.Image:
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    native_path = SOURCE_DIR / f"{portrait_id}_native.png"
    runtime_path = RUNTIME_DIR / f"{portrait_id}.png"
    native.save(native_path)
    runtime = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
    runtime.save(runtime_path)
    return runtime


def write_manifest() -> None:
    portraits = {}
    for portrait_id, spec in PORTRAITS.items():
        portraits[portrait_id] = {
            "expression": spec["expression"],
            "crop_rect": spec["crop_rect"],
            "native": f"assets/source/tavern/characters/{portrait_id}_native.png",
            "runtime": f"assets/textures/characters/{portrait_id}.png",
            "safe_area": [0, 0, NATIVE_SIZE[0], NATIVE_SIZE[1]],
            "intended_godot_use": "Tavern CustomerSprite Ryan bust portrait behind TabletopArt",
        }
    manifest = {
        "id": "ryan_bust_portraits",
        "source": "art_sources/generated_raw/ryan_bust/ryan_bust_expression_sheet_v2.png",
        "native_size": list(NATIVE_SIZE),
        "runtime_size": list(RUNTIME_SIZE),
        "scale": SCALE,
        "portraits": portraits,
        "bar_occlusion_contract": {
            "customer_sprite_path": "res://scenes/ui/Tavern.tscn:CustomerArea/CustomerSprite",
            "runtime_sprite_size": list(RUNTIME_SIZE),
            "tabletop_top_y_runtime": 455,
            "tabletop_art_z_index": -90,
            "customer_sprite_z_index": -95,
        },
    }
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def backed(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    preview = ImageOps.contain(image.convert("RGBA"), size, Image.Resampling.NEAREST)
    out = Image.new("RGBA", size, (26, 21, 17, 255))
    out.alpha_composite(preview, ((size[0] - preview.width) // 2, (size[1] - preview.height) // 2))
    return out


def make_contact_sheet(sheet: Image.Image, natives: dict[str, Image.Image], runtimes: dict[str, Image.Image]) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    out = Image.new("RGBA", (900, 620), (18, 14, 11, 255))
    draw = ImageDraw.Draw(out)
    draw.text((20, 16), "Ryan bust portrait pipeline", fill=(220, 204, 176, 255))
    draw.text((20, 48), "generated source sheet", fill=(220, 204, 176, 255))
    source_preview = ImageOps.contain(sheet.convert("RGBA"), (860, 190), Image.Resampling.LANCZOS)
    out.alpha_composite(source_preview, (20, 72))
    draw.text((20, 282), "native 4x previews", fill=(220, 204, 176, 255))
    draw.text((20, 482), "runtime preview: lower bust sits behind bar", fill=(220, 204, 176, 255))

    for index, portrait_id in enumerate(PORTRAITS):
        x = 26 + index * 216
        native_preview = natives[portrait_id].resize((NATIVE_SIZE[0] * 2, NATIVE_SIZE[1] * 2), Image.Resampling.NEAREST)
        out.alpha_composite(backed(native_preview, (160, 180)), (x, 306))
        runtime_preview = ImageOps.contain(runtimes[portrait_id], (160, 116), Image.Resampling.NEAREST)
        backed_runtime = Image.new("RGBA", (190, 116), (26, 21, 17, 255))
        backed_runtime.alpha_composite(runtime_preview, ((190 - runtime_preview.width) // 2, 0))
        bar_y = 84
        ImageDraw.Draw(backed_runtime).rectangle((0, bar_y, 190, 116), fill=(58, 35, 22, 240))
        ImageDraw.Draw(backed_runtime).line((0, bar_y, 190, bar_y), fill=(205, 132, 58, 255), width=1)
        out.alpha_composite(backed_runtime, (x - 15, 506))
        draw.text((x, 490), portrait_id, fill=(180, 168, 144, 255))

    out.convert("RGB").save(CONTACT_SHEET)


def main() -> None:
    if not RAW_SOURCE.exists():
        raise FileNotFoundError(f"missing Ryan bust source: {RAW_SOURCE}")
    sheet = Image.open(RAW_SOURCE).convert("RGBA")
    natives = {}
    runtimes = {}
    for portrait_id, spec in PORTRAITS.items():
        native = normalize_portrait(sheet, spec["crop_rect"])
        runtime = save_runtime(native, portrait_id)
        natives[portrait_id] = native
        runtimes[portrait_id] = runtime
    write_manifest()
    make_contact_sheet(sheet, natives, runtimes)
    print("exported Ryan bust portraits: " + ", ".join(PORTRAITS.keys()))
    print("contact sheet: docs/art/ryan_bust_contact_sheet.png")


if __name__ == "__main__":
    main()
