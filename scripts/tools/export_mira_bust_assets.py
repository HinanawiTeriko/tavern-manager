from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "mira_bust" / "mira_neutral_source_v2.png"
EXPRESSION_SOURCE = ROOT / "art_sources" / "generated_raw" / "mira_bust" / "mira_expression_sheet_source_v1.png"
RYAN_REFERENCE = ROOT / "assets" / "textures" / "characters" / "ryan_neutral.png"
SOURCE_DIR = ROOT / "assets" / "source" / "tavern" / "characters"
RUNTIME_DIR = ROOT / "assets" / "textures" / "characters"
MANIFEST_PATH = SOURCE_DIR / "mira_bust_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "mira_bust_contact_sheet.png"

NATIVE_SIZE = (70, 90)
RUNTIME_SIZE = (280, 360)
SCALE = 4
SOURCE_RECT = [0, 0, 1107, 1421]
EXPRESSION_CELL = 724
COLOR_LIMIT = 20
TARGET_VISIBLE_WIDTH = 58
PORTRAITS = {
    "mira_neutral": {
        "source": RAW_SOURCE,
        "source_rect": SOURCE_RECT,
        "expression_notes": ["guarded professional smile"],
    },
    "mira_smile": {
        "source": EXPRESSION_SOURCE,
        "source_rect": [0, 0, EXPRESSION_CELL, EXPRESSION_CELL],
        "expression_notes": ["genuine warm smile"],
    },
    "mira_surprised": {
        "source": EXPRESSION_SOURCE,
        "source_rect": [EXPRESSION_CELL, 0, EXPRESSION_CELL * 2, EXPRESSION_CELL],
        "expression_notes": ["surprised raised brows"],
    },
    "mira_serious": {
        "source": EXPRESSION_SOURCE,
        "source_rect": [EXPRESSION_CELL * 2, 0, EXPRESSION_CELL * 3, EXPRESSION_CELL],
        "expression_notes": ["serious direct gaze"],
    },
}


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


def normalize_portrait(source: Image.Image, source_rect: list[int]) -> Image.Image:
    crop = source.crop(tuple(source_rect))
    keyed = remove_chroma_key(crop)
    bounds = visible_bounds(keyed)
    subject = keyed.crop(bounds)
    fitted = ImageOps.contain(subject, (66, 88), Image.Resampling.NEAREST)
    if fitted.width > TARGET_VISIBLE_WIDTH:
        fitted = fitted.resize((TARGET_VISIBLE_WIDTH, fitted.height), Image.Resampling.NEAREST)
    native = Image.new("RGBA", NATIVE_SIZE, (0, 0, 0, 0))
    x = (NATIVE_SIZE[0] - fitted.width) // 2
    y = max(0, NATIVE_SIZE[1] - fitted.height)
    native.alpha_composite(fitted, (x, y))
    return quantize_visible(native)


def save_exports(portrait_id: str, native: Image.Image) -> Image.Image:
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
            "source": spec["source"].relative_to(ROOT).as_posix(),
            "source_rect": spec["source_rect"],
            "native": (SOURCE_DIR / f"{portrait_id}_native.png").relative_to(ROOT).as_posix(),
            "runtime": (RUNTIME_DIR / f"{portrait_id}.png").relative_to(ROOT).as_posix(),
            "native_size": list(NATIVE_SIZE),
            "runtime_size": list(RUNTIME_SIZE),
            "safe_area": [0, 0, NATIVE_SIZE[0], NATIVE_SIZE[1]],
            "scale": SCALE,
            "color_limit": COLOR_LIMIT,
            "target_visible_width": TARGET_VISIBLE_WIDTH,
            "expression_notes": spec["expression_notes"],
            "intended_godot_use": "Tavern CustomerSprite Mira expression portrait",
        }
    manifest = {
        "id": "mira_bust_portrait",
        "style_profile": "ryan_matched_low_detail_pixel_v2",
        "source": RAW_SOURCE.relative_to(ROOT).as_posix(),
        "expression_source": EXPRESSION_SOURCE.relative_to(ROOT).as_posix(),
        "comparison_reference": RYAN_REFERENCE.relative_to(ROOT).as_posix(),
        "source_rect": SOURCE_RECT,
        "native": (SOURCE_DIR / "mira_neutral_native.png").relative_to(ROOT).as_posix(),
        "runtime": (RUNTIME_DIR / "mira_neutral.png").relative_to(ROOT).as_posix(),
        "native_size": list(NATIVE_SIZE),
        "runtime_size": list(RUNTIME_SIZE),
        "safe_area": [0, 0, NATIVE_SIZE[0], NATIVE_SIZE[1]],
        "scale": SCALE,
        "color_limit": COLOR_LIMIT,
        "target_visible_width": TARGET_VISIBLE_WIDTH,
        "intended_godot_use": "Tavern CustomerSprite Mira bust portrait behind TabletopArt",
        "portraits": portraits,
        "character_notes": [
            "adult traveling merchant",
            "guarded professional smile",
            "expression set includes genuine warm smile, surprised raised brows, and serious direct gaze",
            "high ponytail",
            "large readable merchant shapes: cloak, shoulder bag, scroll tube, brass scale",
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


def make_contact_sheet(sources: dict[str, Image.Image], natives: dict[str, Image.Image], runtimes: dict[str, Image.Image]) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    out = Image.new("RGBA", (1220, 650), (18, 14, 11, 255))
    draw = ImageDraw.Draw(out)
    draw.text((20, 18), "Mira bust portrait pipeline", fill=(222, 204, 176, 255))
    draw.text((20, 46), "v2 expression set: Ryan comparison, native 70x90, runtime 280x360", fill=(180, 168, 144, 255))

    ryan = Image.open(RYAN_REFERENCE).convert("RGBA") if RYAN_REFERENCE.exists() else Image.new("RGBA", RUNTIME_SIZE, (0, 0, 0, 0))
    ryan_preview = ImageOps.contain(ryan, (190, 270), Image.Resampling.NEAREST)
    ryan_backed = Image.new("RGBA", (210, 290), (24, 20, 16, 255))
    ryan_backed.alpha_composite(ryan_preview, ((210 - ryan_preview.width) // 2, 8))
    out.alpha_composite(ryan_backed, (24, 92))
    draw.text((24, 392), "Ryan neutral reference", fill=(180, 168, 144, 255))

    labels = ["mira_neutral", "mira_smile", "mira_surprised", "mira_serious"]
    for index, portrait_id in enumerate(labels):
        x = 260 + index * 230
        source_preview = ImageOps.contain(sources[portrait_id].convert("RGBA"), (180, 170), Image.Resampling.LANCZOS)
        source_backed = Image.new("RGBA", (190, 180), (24, 20, 16, 255))
        source_backed.alpha_composite(source_preview, ((190 - source_preview.width) // 2, (180 - source_preview.height) // 2))
        out.alpha_composite(source_backed, (x, 88))
        native_preview = natives[portrait_id].resize((NATIVE_SIZE[0] * 3, NATIVE_SIZE[1] * 3), Image.Resampling.NEAREST)
        out.alpha_composite(backed(native_preview, (210, 280)), (x - 10, 286))
        draw.text((x, 576), portrait_id, fill=(180, 168, 144, 255))

    runtime_preview = ImageOps.contain(runtimes["mira_serious"], (150, 220), Image.Resampling.NEAREST)
    backed_runtime = Image.new("RGBA", (160, 220), (24, 20, 16, 255))
    backed_runtime.alpha_composite(runtime_preview, ((160 - runtime_preview.width) // 2, 0))
    ImageDraw.Draw(backed_runtime).rectangle((0, 164, 160, 220), fill=(58, 35, 22, 240))
    ImageDraw.Draw(backed_runtime).line((0, 164, 160, 164), fill=(205, 132, 58, 255), width=1)
    out.alpha_composite(backed_runtime, (1040, 88))
    draw.text((1040, 320), "bar occlusion", fill=(180, 168, 144, 255))
    out.convert("RGB").save(CONTACT_SHEET)


def main() -> None:
    if not RAW_SOURCE.exists():
        raise FileNotFoundError(f"missing Mira bust source: {RAW_SOURCE}")
    if not EXPRESSION_SOURCE.exists():
        raise FileNotFoundError(f"missing Mira expression source: {EXPRESSION_SOURCE}")

    loaded_sources = {
        RAW_SOURCE: Image.open(RAW_SOURCE).convert("RGBA"),
        EXPRESSION_SOURCE: Image.open(EXPRESSION_SOURCE).convert("RGBA"),
    }
    source_previews: dict[str, Image.Image] = {}
    natives: dict[str, Image.Image] = {}
    runtimes: dict[str, Image.Image] = {}
    for portrait_id, spec in PORTRAITS.items():
        source = loaded_sources[spec["source"]]
        source_previews[portrait_id] = source.crop(tuple(spec["source_rect"])).convert("RGBA")
        native = normalize_portrait(source, spec["source_rect"])
        runtime = save_exports(portrait_id, native)
        natives[portrait_id] = native
        runtimes[portrait_id] = runtime
        print("exported Mira bust portrait: " + portrait_id)

    write_manifest()
    make_contact_sheet(source_previews, natives, runtimes)
    print("contact sheet: docs/art/mira_bust_contact_sheet.png")


if __name__ == "__main__":
    main()
