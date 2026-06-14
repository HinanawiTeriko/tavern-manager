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
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "characters" / "ryan" / "ryan_bust_expression_sheet_v6.png"
PROMPT = ROOT / "art_sources" / "generated_raw" / "characters" / "ryan" / "ryan_bust_expression_sheet_v6_prompt.txt"
SOURCE_DIR = ROOT / "assets" / "source" / "tavern" / "characters"
RUNTIME_DIR = ROOT / "assets" / "textures" / "characters"
MANIFEST_PATH = SOURCE_DIR / "ryan_bust_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "characters" / "ryan_contact_sheet.png"

NATIVE_SIZE = (128, 160)
RUNTIME_SIZE = (512, 640)
SCALE = 4
STYLE_PROFILE = "approved_mira_vera_belta_runtime_matched_tiefling_contract_runner_v6"
NORMALIZATION_MODE = "explicit_crop_visible_subject_v6"
EXPRESSION_COLUMNS = 4
EXPRESSION_ROWS = 2
COLOR_LIMIT = 72
UNIFORM_VISIBLE_HEIGHT = 154
UNIFORM_MAX_VISIBLE_WIDTH = 124
UNIFORM_BOTTOM_PADDING = 3
CONTACT_SHEET_NATIVE_SCALE = 2
CONTACT_SHEET_NATIVE_PREVIEW_SIZE = (
    NATIVE_SIZE[0] * CONTACT_SHEET_NATIVE_SCALE,
    NATIVE_SIZE[1] * CONTACT_SHEET_NATIVE_SCALE,
)
CONTACT_SHEET_NATIVE_Y = 360
CONTACT_SHEET_NATIVE_BG = (26, 21, 17, 255)
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
    "ryan_neutral": {
        "expression": "neutral",
        "crop_rect": [2, 2, 382, 510],
    },
    "ryan_confident": {
        "expression": "confident",
        "crop_rect": [386, 2, 766, 510],
    },
    "ryan_hesitant": {
        "expression": "hesitation",
        "crop_rect": [770, 2, 1150, 510],
    },
    "ryan_alarmed": {
        "expression": "alarmed",
        "crop_rect": [1154, 2, 1534, 510],
    },
    "ryan_resolved": {
        "expression": "resolved",
        "crop_rect": [2, 514, 382, 1022],
    },
    "ryan_relieved": {
        "expression": "relieved",
        "crop_rect": [386, 514, 766, 1022],
    },
    "ryan_wary": {
        "expression": "wary",
        "crop_rect": [770, 514, 1150, 1022],
    },
    "ryan_broken": {
        "expression": "broken",
        "crop_rect": [1154, 514, 1534, 1022],
    },
}


def remove_chroma_key(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            is_key = g >= 110 and g > r * 1.45 and g > b * 1.45 and g > max(r, b) + 30
            is_dark_key = (
                g >= 12
                and r <= 96
                and b <= 96
                and g > r + 3
                and g > b + 3
                and max(r, g, b) <= 140
            )
            if is_key or is_dark_key:
                pixels[x, y] = (0, 0, 0, 0)
            elif g > max(r, b) + 18:
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
    return despill_green_edges(quantized)


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
            "normalization": {
                "mode": NORMALIZATION_MODE,
            },
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
        "grid": {
            "columns": EXPRESSION_COLUMNS,
            "rows": EXPRESSION_ROWS,
        },
        "normalization": {
            "mode": NORMALIZATION_MODE,
        },
        "uniform_visible_height": UNIFORM_VISIBLE_HEIGHT,
        "uniform_max_visible_width": UNIFORM_MAX_VISIBLE_WIDTH,
        "uniform_bottom_padding": UNIFORM_BOTTOM_PADDING,
        "color_limit": COLOR_LIMIT,
        "portraits": portraits,
        "character_notes": [
            "subtle tiefling contract runner approved from the top-left direction",
            "ash-lilac short braid, small horn nubs, mostly human face",
            "simple oath tag and wax-seal pouch only, with low accessory density",
            "source sheet uses a dark-green grid fringe, so each explicit crop is inset by two pixels",
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


def make_contact_sheet(sheet: Image.Image, natives: dict[str, Image.Image]) -> None:
    del sheet
    save_character_contact_sheet(
        CONTACT_SHEET,
        "Ryan character contract sheet",
        "8 expressions, native 128x160 -> runtime 512x640, integer preview",
        [(portrait_id, natives[portrait_id]) for portrait_id in PORTRAITS],
        column_count=4,
    )


def validate_crop_rect(portrait_id: str, source: Image.Image, crop_rect: list[int]) -> None:
    if len(crop_rect) != 4:
        raise ValueError(f"{portrait_id}: crop_rect must have four values")
    left, top, right, bottom = crop_rect
    if left < 0 or top < 0 or right > source.width or bottom > source.height:
        raise ValueError(f"{portrait_id}: crop_rect {crop_rect} is outside source {source.size}")
    cell_width = source.width // EXPRESSION_COLUMNS
    cell_height = source.height // EXPRESSION_ROWS
    expected_size = (cell_width - 4, cell_height - 4)
    if (right - left, bottom - top) != expected_size:
        raise ValueError(
            f"{portrait_id}: crop_rect {crop_rect} must keep the approved "
            f"{expected_size[0]}x{expected_size[1]} inset expression-cell size"
        )


def main() -> None:
    if not RAW_SOURCE.exists():
        raise FileNotFoundError(f"missing Ryan bust source: {RAW_SOURCE}")
    if not PROMPT.exists():
        raise FileNotFoundError(f"missing Ryan bust prompt: {PROMPT}")
    sheet = Image.open(RAW_SOURCE).convert("RGBA")
    if sheet.width % EXPRESSION_COLUMNS != 0 or sheet.height % EXPRESSION_ROWS != 0:
        raise ValueError(
            f"Ryan expression source {sheet.size} must divide into "
            f"{EXPRESSION_COLUMNS}x{EXPRESSION_ROWS} fixed cells"
        )
    natives = {}
    runtimes = {}
    for portrait_id, spec in PORTRAITS.items():
        validate_crop_rect(portrait_id, sheet, spec["crop_rect"])
        native = normalize_portrait(sheet, spec["crop_rect"])
        runtime = save_runtime(native, portrait_id)
        natives[portrait_id] = native
        runtimes[portrait_id] = runtime
    write_manifest(natives)
    make_contact_sheet(sheet, natives)
    print("exported Ryan bust portraits: " + ", ".join(PORTRAITS.keys()))
    print("contact sheet: docs/art/characters/ryan_contact_sheet.png")


if __name__ == "__main__":
    main()
