from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "ryan_bust" / "ryan_bust_expression_sheet_v4.png"
PROMPT = ROOT / "art_sources" / "generated_raw" / "ryan_bust" / "ryan_bust_expression_sheet_v4_prompt.txt"
SOURCE_DIR = ROOT / "assets" / "source" / "tavern" / "characters"
RUNTIME_DIR = ROOT / "assets" / "textures" / "characters"
MANIFEST_PATH = SOURCE_DIR / "ryan_bust_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "ryan_bust_contact_sheet.png"

NATIVE_SIZE = (128, 160)
RUNTIME_SIZE = (512, 640)
SCALE = 4
STYLE_PROFILE = "approved_vera_belta_runtime_matched_important_npc_v4"
COLOR_LIMIT = 72
UNIFORM_VISIBLE_HEIGHT = 154
UNIFORM_MAX_VISIBLE_WIDTH = 128
UNIFORM_BOTTOM_PADDING = 3

PORTRAITS = {
    "ryan_neutral": {
        "expression": "forced oath-smile",
        "crop_rect": [0, 0, 543, 724],
    },
    "ryan_excited": {
        "expression": "overbright confidence",
        "crop_rect": [543, 0, 1086, 724],
    },
    "ryan_hesitant": {
        "expression": "hesitation",
        "crop_rect": [1086, 0, 1629, 724],
    },
    "ryan_dejected": {
        "expression": "dejected",
        "crop_rect": [1629, 0, 2172, 724],
    },
}


def remove_chroma_key(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if g >= 150 and g > r * 1.4 and g > b * 1.4 and g > max(r, b) + 50:
                pixels[x, y] = (0, 0, 0, 0)
            elif g > max(r, b) + 30:
                pixels[x, y] = (r, max(r, b) + 4, b, a)
    return rgba


def visible_crop(image: Image.Image) -> Image.Image:
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        return image
    return image.crop(bounds)


def visible_bounds(image: Image.Image) -> tuple[int, int, int, int]:
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        return (0, 0, 0, 0)
    return bounds


def unique_visible_color_count(image: Image.Image) -> int:
    rgba = image.convert("RGBA")
    raw = rgba.tobytes()
    return len({
        tuple(raw[index:index + 4])
        for index in range(0, len(raw), 4)
        if raw[index + 3] > 0
    })


def quantize_visible(image: Image.Image, colors: int = COLOR_LIMIT) -> Image.Image:
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
    subject = visible_crop(keyed)
    target_box = (
        min(NATIVE_SIZE[0], UNIFORM_MAX_VISIBLE_WIDTH),
        min(NATIVE_SIZE[1] - UNIFORM_BOTTOM_PADDING, UNIFORM_VISIBLE_HEIGHT),
    )
    fitted = ImageOps.contain(subject, target_box, Image.Resampling.NEAREST)
    native = Image.new("RGBA", NATIVE_SIZE, (0, 0, 0, 0))
    x = (NATIVE_SIZE[0] - fitted.width) // 2
    fitted_bounds = visible_bounds(fitted)
    visible_bottom = fitted_bounds[3] if fitted_bounds != (0, 0, 0, 0) else fitted.height
    y = NATIVE_SIZE[1] - UNIFORM_BOTTOM_PADDING - visible_bottom
    y = min(max(0, y), max(0, NATIVE_SIZE[1] - fitted.height))
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


def write_manifest(natives: dict[str, Image.Image]) -> None:
    portraits = {}
    for portrait_id, spec in PORTRAITS.items():
        native = natives[portrait_id]
        portraits[portrait_id] = {
            "expression": spec["expression"],
            "source_file": RAW_SOURCE.relative_to(ROOT).as_posix(),
            "prompt": PROMPT.relative_to(ROOT).as_posix(),
            "crop_rect": spec["crop_rect"],
            "native": f"assets/source/tavern/characters/{portrait_id}_native.png",
            "runtime": f"assets/textures/characters/{portrait_id}.png",
            "safe_area": [0, 0, NATIVE_SIZE[0], NATIVE_SIZE[1]],
            "visible_bounds_native": list(visible_bounds(native)),
            "visible_color_count": unique_visible_color_count(native),
            "intended_godot_use": "Tavern CustomerSprite Ryan bust portrait behind TabletopArt",
        }
    manifest = {
        "id": "ryan_bust_portraits",
        "style_profile": STYLE_PROFILE,
        "source": RAW_SOURCE.relative_to(ROOT).as_posix(),
        "prompt": PROMPT.relative_to(ROOT).as_posix(),
        "native_size": list(NATIVE_SIZE),
        "runtime_size": list(RUNTIME_SIZE),
        "scale": SCALE,
        "uniform_visible_height": UNIFORM_VISIBLE_HEIGHT,
        "uniform_max_visible_width": UNIFORM_MAX_VISIBLE_WIDTH,
        "uniform_bottom_padding": UNIFORM_BOTTOM_PADDING,
        "color_limit": COLOR_LIMIT,
        "portraits": portraits,
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
    out = Image.new("RGBA", size, (26, 21, 17, 255))
    out.alpha_composite(preview, ((size[0] - preview.width) // 2, (size[1] - preview.height) // 2))
    return out


def make_contact_sheet(sheet: Image.Image, natives: dict[str, Image.Image], runtimes: dict[str, Image.Image]) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    out = Image.new("RGBA", (1180, 820), (18, 14, 11, 255))
    draw = ImageDraw.Draw(out)
    draw.text((20, 16), "Ryan bust portrait pipeline - v4 promoted to runtime", fill=(220, 204, 176, 255))
    draw.text((20, 46), "source sheet -> native 128x160 -> runtime 512x640", fill=(180, 168, 144, 255))
    source_preview = ImageOps.contain(sheet.convert("RGBA"), (1140, 250), Image.Resampling.LANCZOS)
    out.alpha_composite(source_preview, (20, 72))
    draw.text((20, 346), "native previews x2", fill=(220, 204, 176, 255))
    draw.text((20, 630), "runtime preview: lower bust sits behind bar", fill=(220, 204, 176, 255))

    for index, portrait_id in enumerate(PORTRAITS):
        x = 34 + index * 284
        native_preview = natives[portrait_id].resize((NATIVE_SIZE[0] * 2, NATIVE_SIZE[1] * 2), Image.Resampling.NEAREST)
        out.alpha_composite(backed(native_preview, (256, 260)), (x, 370))
        runtime_preview = ImageOps.contain(runtimes[portrait_id], (210, 150), Image.Resampling.NEAREST)
        backed_runtime = Image.new("RGBA", (250, 150), (26, 21, 17, 255))
        backed_runtime.alpha_composite(runtime_preview, ((250 - runtime_preview.width) // 2, 0))
        bar_y = 112
        ImageDraw.Draw(backed_runtime).rectangle((0, bar_y, 250, 150), fill=(58, 35, 22, 240))
        ImageDraw.Draw(backed_runtime).line((0, bar_y, 250, bar_y), fill=(205, 132, 58, 255), width=1)
        out.alpha_composite(backed_runtime, (x + 3, 660))
        draw.text((x, 634), portrait_id, fill=(180, 168, 144, 255))

    out.convert("RGB").save(CONTACT_SHEET)


def main() -> None:
    if not RAW_SOURCE.exists():
        raise FileNotFoundError(f"missing Ryan bust source: {RAW_SOURCE}")
    if not PROMPT.exists():
        raise FileNotFoundError(f"missing Ryan bust prompt: {PROMPT}")
    sheet = Image.open(RAW_SOURCE).convert("RGBA")
    natives = {}
    runtimes = {}
    for portrait_id, spec in PORTRAITS.items():
        native = normalize_portrait(sheet, spec["crop_rect"])
        runtime = save_runtime(native, portrait_id)
        natives[portrait_id] = native
        runtimes[portrait_id] = runtime
    write_manifest(natives)
    make_contact_sheet(sheet, natives, runtimes)
    print("exported Ryan bust portraits: " + ", ".join(PORTRAITS.keys()))
    print("contact sheet: docs/art/ryan_bust_contact_sheet.png")


if __name__ == "__main__":
    main()
