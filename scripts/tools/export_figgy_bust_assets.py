from __future__ import annotations

import json
import sys
from collections import deque
from pathlib import Path

from PIL import Image, ImageOps

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from character_contact_sheet import save_character_contact_sheet
from character_green_matte import despill_green_edges, source_level_green_matte


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE = (
    ROOT
    / "art_sources"
    / "generated_raw"
    / "characters"
    / "figgy_concepts"
    / "figgy_expression_sheet_source_v1.png"
)
PROMPT = (
    ROOT
    / "art_sources"
    / "generated_raw"
    / "characters"
    / "figgy_concepts"
    / "figgy_expression_sheet_prompt_v1.txt"
)
RYAN_REFERENCE = ROOT / "assets" / "textures" / "characters" / "ryan_neutral.png"
MIRA_REFERENCE = ROOT / "assets" / "textures" / "characters" / "mira_neutral.png"
SOURCE_DIR = ROOT / "assets" / "source" / "tavern" / "characters"
RUNTIME_DIR = ROOT / "assets" / "textures" / "characters"
MANIFEST_PATH = SOURCE_DIR / "figgy_bust_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "characters" / "figgy_contact_sheet.png"

NATIVE_SIZE = (128, 160)
RUNTIME_SIZE = (512, 640)
SCALE = 4
EXPRESSION_COLUMNS = 4
EXPRESSION_ROWS = 2
COLOR_LIMIT = 72
VISIBLE_TARGET = (124, 154)
BOTTOM_PADDING = 3
STYLE_PROFILE = "figgy_aqua_fae_normal_clothes_expression_sheet_v1"
NORMALIZATION_MODE = "fixed_cell_visible_subject_v1"

PORTRAIT_IDS = [
    ("figgy_neutral", "polite cute tavern entry, tiny knowing smile"),
    ("figgy_pleased", "cheerful confident grin after spotting a loophole"),
    ("figgy_innocent", "exaggerated harmless face, pretending she did nothing"),
    ("figgy_shocked", "comic surprise when fate says something stupid"),
    ("figgy_smug", "sly sideways smile before exploiting wording"),
    ("figgy_confused", "puzzled by a bad prophecy but not afraid"),
    ("figgy_serious", "calm sharp resolve ready to challenge fate"),
    ("figgy_victorious", "delighted triumphant grin after beating fate by technicality"),
]


def visible_bounds(image: Image.Image) -> tuple[int, int, int, int]:
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        return (0, 0, image.width, image.height)
    return bounds


def cell_rects(source: Image.Image) -> list[list[int]]:
    cell_width = source.width // EXPRESSION_COLUMNS
    cell_height = source.height // EXPRESSION_ROWS
    rects: list[list[int]] = []
    for row in range(EXPRESSION_ROWS):
        for column in range(EXPRESSION_COLUMNS):
            rects.append([
                column * cell_width,
                row * cell_height,
                (column + 1) * cell_width,
                (row + 1) * cell_height,
            ])
    return rects


def keep_largest_alpha_component(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    pixels = alpha.load()
    width, height = alpha.size
    seen: set[tuple[int, int]] = set()
    components: list[list[tuple[int, int]]] = []
    for y in range(height):
        for x in range(width):
            if pixels[x, y] == 0 or (x, y) in seen:
                continue
            queue: deque[tuple[int, int]] = deque([(x, y)])
            seen.add((x, y))
            component: list[tuple[int, int]] = []
            while queue:
                cx, cy = queue.popleft()
                component.append((cx, cy))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx = cx + dx
                    ny = cy + dy
                    if 0 <= nx < width and 0 <= ny < height and pixels[nx, ny] > 0 and (nx, ny) not in seen:
                        seen.add((nx, ny))
                        queue.append((nx, ny))
            components.append(component)
    if not components:
        return rgba
    keep = set(max(components, key=len))
    out = rgba.copy()
    out_pixels = out.load()
    for y in range(height):
        for x in range(width):
            if out_pixels[x, y][3] > 0 and (x, y) not in keep:
                out_pixels[x, y] = (0, 0, 0, 0)
    return out


def unique_visible_color_count(image: Image.Image) -> int:
    rgba = image.convert("RGBA")
    data = rgba.get_flattened_data() if hasattr(rgba, "get_flattened_data") else rgba.getdata()
    return len({(red, green, blue) for red, green, blue, alpha in data if alpha > 0})


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
    return keep_largest_alpha_component(despill_green_edges(quantized))


def normalize_portrait(source: Image.Image, source_rect: list[int]) -> Image.Image:
    crop = source.crop(tuple(source_rect))
    keyed = keep_largest_alpha_component(source_level_green_matte(crop))
    subject = keyed.crop(visible_bounds(keyed))
    fitted = ImageOps.contain(subject, VISIBLE_TARGET, Image.Resampling.NEAREST)
    native = Image.new("RGBA", NATIVE_SIZE, (0, 0, 0, 0))
    x = (NATIVE_SIZE[0] - fitted.width) // 2
    bounds = visible_bounds(fitted)
    y = NATIVE_SIZE[1] - BOTTOM_PADDING - bounds[3]
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


def write_manifest(rects: list[list[int]], natives: dict[str, Image.Image]) -> None:
    portraits = {}
    for index, (portrait_id, expression_note) in enumerate(PORTRAIT_IDS):
        native = natives[portrait_id]
        portraits[portrait_id] = {
            "source": RAW_SOURCE.relative_to(ROOT).as_posix(),
            "prompt": PROMPT.relative_to(ROOT).as_posix(),
            "source_rect": rects[index],
            "native": (SOURCE_DIR / f"{portrait_id}_native.png").relative_to(ROOT).as_posix(),
            "runtime": (RUNTIME_DIR / f"{portrait_id}.png").relative_to(ROOT).as_posix(),
            "native_size": list(NATIVE_SIZE),
            "runtime_size": list(RUNTIME_SIZE),
            "safe_area": [0, 0, NATIVE_SIZE[0], NATIVE_SIZE[1]],
            "scale": SCALE,
            "color_limit": COLOR_LIMIT,
            "visible_target": list(VISIBLE_TARGET),
            "bottom_padding": BOTTOM_PADDING,
            "visible_bounds_native": list(visible_bounds(native)),
            "visible_color_count": unique_visible_color_count(native),
            "normalization": {
                "mode": NORMALIZATION_MODE,
            },
            "expression_notes": [expression_note],
            "intended_godot_use": "Tavern CustomerSprite Figgy expression portrait",
        }
    manifest = {
        "id": "figgy_bust_portrait",
        "style_profile": STYLE_PROFILE,
        "source": RAW_SOURCE.relative_to(ROOT).as_posix(),
        "prompt": PROMPT.relative_to(ROOT).as_posix(),
        "expression_source": RAW_SOURCE.relative_to(ROOT).as_posix(),
        "comparison_references": [
            RYAN_REFERENCE.relative_to(ROOT).as_posix(),
            MIRA_REFERENCE.relative_to(ROOT).as_posix(),
        ],
        "source_rect": rects[0],
        "grid": {
            "columns": EXPRESSION_COLUMNS,
            "rows": EXPRESSION_ROWS,
        },
        "normalization": {
            "mode": NORMALIZATION_MODE,
        },
        "native": (SOURCE_DIR / "figgy_neutral_native.png").relative_to(ROOT).as_posix(),
        "runtime": (RUNTIME_DIR / "figgy_neutral.png").relative_to(ROOT).as_posix(),
        "native_size": list(NATIVE_SIZE),
        "runtime_size": list(RUNTIME_SIZE),
        "safe_area": [0, 0, NATIVE_SIZE[0], NATIVE_SIZE[1]],
        "scale": SCALE,
        "color_limit": COLOR_LIMIT,
        "visible_target": list(VISIBLE_TARGET),
        "bottom_padding": BOTTOM_PADDING,
        "intended_godot_use": "Tavern CustomerSprite Figgy bust portrait behind TabletopArt",
        "portraits": portraits,
        "character_notes": [
            "cute aqua fae/sylph important NPC",
            "normal wearable short jacket, cream blouse, narrow dark tie, no wax-seal or paper motif",
            "comic wording-loophole performer exploring free will against fate",
            "v1 expression sheet accepted as a raw candidate with small comic symbols retained",
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


def make_contact_sheet(natives: list[tuple[str, Image.Image]]) -> None:
    save_character_contact_sheet(
        CONTACT_SHEET,
        "Figgy character contract sheet",
        "v1 expression sheet, native 128x160 -> runtime 512x640",
        natives,
        row_count=EXPRESSION_ROWS,
        column_count=EXPRESSION_COLUMNS,
    )


def validate_source_rect(portrait_id: str, source: Image.Image, source_rect: list[int]) -> None:
    if len(source_rect) != 4:
        raise ValueError(f"{portrait_id}: source_rect must have four values")
    left, top, right, bottom = source_rect
    if left < 0 or top < 0 or right > source.width or bottom > source.height:
        raise ValueError(f"{portrait_id}: source_rect {source_rect} is outside source {source.size}")
    cell_width = source.width // EXPRESSION_COLUMNS
    cell_height = source.height // EXPRESSION_ROWS
    if (right - left, bottom - top) != (cell_width, cell_height):
        raise ValueError(
            f"{portrait_id}: source_rect {source_rect} must keep the full "
            f"{cell_width}x{cell_height} expression-cell size"
        )


def main() -> None:
    if not RAW_SOURCE.exists():
        raise FileNotFoundError(f"missing Figgy expression source: {RAW_SOURCE}")
    if not PROMPT.exists():
        raise FileNotFoundError(f"missing Figgy prompt record: {PROMPT}")

    source = Image.open(RAW_SOURCE).convert("RGBA")
    if source.width % EXPRESSION_COLUMNS != 0 or source.height % EXPRESSION_ROWS != 0:
        raise ValueError(
            f"Figgy expression source {source.size} must divide into "
            f"{EXPRESSION_COLUMNS}x{EXPRESSION_ROWS} fixed cells"
        )

    rects = cell_rects(source)
    natives: dict[str, Image.Image] = {}
    contact_entries: list[tuple[str, Image.Image]] = []
    for index, (portrait_id, _note) in enumerate(PORTRAIT_IDS):
        validate_source_rect(portrait_id, source, rects[index])
        native = normalize_portrait(source, rects[index])
        save_exports(portrait_id, native)
        natives[portrait_id] = native
        contact_entries.append((portrait_id, native))
        print("exported Figgy bust portrait: " + portrait_id)

    write_manifest(rects, natives)
    make_contact_sheet(contact_entries)
    print("contact sheet: docs/art/characters/figgy_contact_sheet.png")


if __name__ == "__main__":
    main()
