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
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "characters" / "mira" / "mira_expression_sheet_source_v2.png"
EXPRESSION_SOURCE = RAW_SOURCE
RYAN_REFERENCE = ROOT / "assets" / "textures" / "characters" / "ryan_neutral.png"
RYAN_NATIVE_REFERENCE = ROOT / "assets" / "source" / "tavern" / "characters" / "ryan_neutral_native.png"
SOURCE_DIR = ROOT / "assets" / "source" / "tavern" / "characters"
RUNTIME_DIR = ROOT / "assets" / "textures" / "characters"
MANIFEST_PATH = SOURCE_DIR / "mira_bust_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "characters" / "mira_contact_sheet.png"

NATIVE_SIZE = (128, 160)
RUNTIME_SIZE = (512, 640)
SCALE = 4
SOURCE_RECT = [0, 0, 543, 724]
EXPRESSION_CELL_WIDTH = 543
EXPRESSION_CELL_HEIGHT = 724
COLOR_LIMIT = 72
VISIBLE_TARGET = (124, 154)
BOTTOM_PADDING = 3
STYLE_PROFILE = "approved_vera_belta_runtime_matched_important_npc_v1"
CONTACT_SHEET_NATIVE_SCALE = 2
CONTACT_SHEET_NATIVE_PREVIEW_SIZE = (
    NATIVE_SIZE[0] * CONTACT_SHEET_NATIVE_SCALE,
    NATIVE_SIZE[1] * CONTACT_SHEET_NATIVE_SCALE,
)
CONTACT_SHEET_NATIVE_Y = 360
CONTACT_SHEET_NATIVE_BG = (24, 20, 16, 255)
CONTACT_SHEET_BAR_CROP_TOP = 83
CONTACT_SHEET_BAR_CROP_HEIGHT = 52
CONTACT_SHEET_BAR_Y_NATIVE = 121
CONTACT_SHEET_BAR_SIZE = (
    NATIVE_SIZE[0] * CONTACT_SHEET_NATIVE_SCALE,
    CONTACT_SHEET_BAR_CROP_HEIGHT * CONTACT_SHEET_NATIVE_SCALE,
)
CONTACT_SHEET_BAR_Y = 714
CONTACT_SHEET_BAR_FILL = (58, 35, 22, 255)
CONTACT_SHEET_BAR_LINE = (205, 132, 58, 255)
PORTRAITS = {
    "mira_neutral": {
        "source": RAW_SOURCE,
        "source_rect": SOURCE_RECT,
        "expression_notes": ["guarded professional smile"],
    },
    "mira_smile": {
        "source": EXPRESSION_SOURCE,
        "source_rect": [EXPRESSION_CELL_WIDTH, 0, EXPRESSION_CELL_WIDTH * 2, EXPRESSION_CELL_HEIGHT],
        "expression_notes": ["genuine warm smile"],
    },
    "mira_surprised": {
        "source": EXPRESSION_SOURCE,
        "source_rect": [EXPRESSION_CELL_WIDTH * 2, 0, EXPRESSION_CELL_WIDTH * 3, EXPRESSION_CELL_HEIGHT],
        "expression_notes": ["surprised raised brows"],
    },
    "mira_serious": {
        "source": EXPRESSION_SOURCE,
        "source_rect": [EXPRESSION_CELL_WIDTH * 3, 0, EXPRESSION_CELL_WIDTH * 4, EXPRESSION_CELL_HEIGHT],
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
    return despill_green_edges(quantized)


def normalize_portrait(source: Image.Image, source_rect: list[int]) -> Image.Image:
    crop = source.crop(tuple(source_rect))
    keyed = remove_chroma_key(crop)
    bounds = visible_bounds(keyed)
    subject = keyed.crop(bounds)
    fitted = ImageOps.contain(subject, VISIBLE_TARGET, Image.Resampling.NEAREST)
    native = Image.new("RGBA", NATIVE_SIZE, (0, 0, 0, 0))
    x = (NATIVE_SIZE[0] - fitted.width) // 2
    y = NATIVE_SIZE[1] - BOTTOM_PADDING - fitted.height
    y = min(max(0, y), max(0, NATIVE_SIZE[1] - fitted.height))
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
            "visible_target": list(VISIBLE_TARGET),
            "bottom_padding": BOTTOM_PADDING,
            "expression_notes": spec["expression_notes"],
            "intended_godot_use": "Tavern CustomerSprite Mira expression portrait",
        }
    manifest = {
        "id": "mira_bust_portrait",
        "style_profile": STYLE_PROFILE,
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
        "visible_target": list(VISIBLE_TARGET),
        "bottom_padding": BOTTOM_PADDING,
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


def backed_exact(image: Image.Image, size: tuple[int, int], bg: tuple[int, int, int, int] = CONTACT_SHEET_NATIVE_BG) -> Image.Image:
    preview = image.convert("RGBA")
    if preview.width > size[0] or preview.height > size[1]:
        raise ValueError(f"contact sheet preview {preview.size} does not fit exact backing {size}")
    out = Image.new("RGBA", size, bg)
    out.alpha_composite(preview, ((size[0] - preview.width) // 2, (size[1] - preview.height) // 2))
    return out


def load_native_reference(native_path: Path, runtime_path: Path) -> Image.Image:
    if native_path.exists():
        return Image.open(native_path).convert("RGBA")
    if runtime_path.exists():
        return Image.open(runtime_path).convert("RGBA").resize(NATIVE_SIZE, Image.Resampling.NEAREST)
    return Image.new("RGBA", NATIVE_SIZE, (0, 0, 0, 0))


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


def make_contact_sheet(sources: dict[str, Image.Image], natives: dict[str, Image.Image]) -> None:
    del sources
    save_character_contact_sheet(
        CONTACT_SHEET,
        "Mira character contract sheet",
        "native 128x160 -> runtime 512x640, grid matches all character sheets",
        [(portrait_id, natives[portrait_id]) for portrait_id in PORTRAITS],
    )


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
    make_contact_sheet(source_previews, natives)
    print("contact sheet: docs/art/characters/mira_contact_sheet.png")


if __name__ == "__main__":
    main()
