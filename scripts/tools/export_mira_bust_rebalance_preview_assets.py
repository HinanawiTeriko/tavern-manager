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
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "characters" / "mira" / "mira_expression_sheet_source_v4.png"
PROMPT = ROOT / "art_sources" / "generated_raw" / "characters" / "mira" / "mira_expression_sheet_prompt_v4.txt"
RYAN_REFERENCE = ROOT / "assets" / "textures" / "characters" / "ryan_neutral.png"
TOBY_REFERENCE = ROOT / "assets" / "textures" / "characters" / "toby_neutral.png"
MIRA_CURRENT_REFERENCE = ROOT / "assets" / "textures" / "characters" / "mira_neutral.png"
SOURCE_DIR = ROOT / "assets" / "source" / "tavern" / "characters"
RUNTIME_DIR = ROOT / "assets" / "textures" / "characters"
MANIFEST_PATH = SOURCE_DIR / "mira_rebalance_bust_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "characters" / "mira_rebalance_contact_sheet.png"

NATIVE_SIZE = (128, 160)
RUNTIME_SIZE = (512, 640)
SCALE = 4
EXPRESSION_COLUMNS = 4
EXPRESSION_ROWS = 2
COLOR_LIMIT = 72
VISIBLE_TARGET = (124, 154)
BOTTOM_PADDING = 3
STYLE_PROFILE = "mira_rebalanced_tavern_bust_v4_preview"
SOURCE_CROP_BLEED = 48
PORTRAIT_IDS = [
    ("mira_rebalance_neutral", "guarded professional half-smile"),
    ("mira_rebalance_smile", "genuine warm smile"),
    ("mira_rebalance_surprised", "surprised raised brows"),
    ("mira_rebalance_serious", "serious direct gaze"),
    ("mira_rebalance_guilty", "guilty averted glance"),
    ("mira_rebalance_conflicted", "conflicted hesitation"),
    ("mira_rebalance_resolved", "resolved accountability"),
    ("mira_rebalance_detached", "detached withdrawal"),
]


def visible_bounds(image: Image.Image) -> tuple[int, int, int, int]:
    bounds = image.getchannel("A").getbbox()
    if bounds == None:
        return (0, 0, image.width, image.height)
    return bounds


def cell_rects(source: Image.Image) -> list[list[int]]:
    cell_width = source.width // EXPRESSION_COLUMNS
    cell_height = source.height // EXPRESSION_ROWS
    rects: list[list[int]] = []
    for row in range(EXPRESSION_ROWS):
        for column in range(EXPRESSION_COLUMNS):
            rects.append([
                max(0, column * cell_width - SOURCE_CROP_BLEED),
                row * cell_height,
                min(source.width, (column + 1) * cell_width + SOURCE_CROP_BLEED),
                (row + 1) * cell_height,
            ])
    return rects


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


def write_manifest(rects: list[list[int]]) -> None:
    portraits = {}
    for index, (portrait_id, expression_note) in enumerate(PORTRAIT_IDS):
        portraits[portrait_id] = {
            "source": RAW_SOURCE.relative_to(ROOT).as_posix(),
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
            "expression_notes": [expression_note],
            "intended_godot_use": "Tavern CustomerSprite Mira rebalance preview expression portrait",
        }
    manifest = {
        "id": "mira_rebalance_bust_portraits",
        "style_profile": STYLE_PROFILE,
        "source": RAW_SOURCE.relative_to(ROOT).as_posix(),
        "prompt": PROMPT.relative_to(ROOT).as_posix(),
        "comparison_references": [
            RYAN_REFERENCE.relative_to(ROOT).as_posix(),
            TOBY_REFERENCE.relative_to(ROOT).as_posix(),
            MIRA_CURRENT_REFERENCE.relative_to(ROOT).as_posix(),
        ],
        "grid": {
            "columns": EXPRESSION_COLUMNS,
            "rows": EXPRESSION_ROWS,
        },
        "native_size": list(NATIVE_SIZE),
        "runtime_size": list(RUNTIME_SIZE),
        "safe_area": [0, 0, NATIVE_SIZE[0], NATIVE_SIZE[1]],
        "scale": SCALE,
        "color_limit": COLOR_LIMIT,
        "visible_target": list(VISIBLE_TARGET),
        "bottom_padding": BOTTOM_PADDING,
        "source_crop_bleed": SOURCE_CROP_BLEED,
        "intended_godot_use": "Mira tavern customer bust rebalance preview; not wired into runtime data",
        "portraits": portraits,
        "character_notes": [
            "preview-only rebalanced Mira source",
            "keeps silver-gray short hair, glasses, mature account-merchant identity",
            "targets Ryan/Toby/regular customer tavern bust proportions",
            "broader shoulder block, fewer fine vertical coat lines, lower accessory density",
        ],
    }
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def make_contact_sheet(natives: list[tuple[str, Image.Image]]) -> None:
    save_character_contact_sheet(
        CONTACT_SHEET,
        "Mira rebalance preview character sheet",
        "preview v4, native 128x160 -> runtime 512x640",
        natives,
        row_count=2,
        column_count=4,
    )


def main() -> None:
    if not RAW_SOURCE.exists():
        raise FileNotFoundError(f"missing Mira rebalance source: {RAW_SOURCE}")
    if not PROMPT.exists():
        raise FileNotFoundError(f"missing Mira rebalance prompt: {PROMPT}")
    source = Image.open(RAW_SOURCE).convert("RGBA")
    if source.width % EXPRESSION_COLUMNS != 0 or source.height % EXPRESSION_ROWS != 0:
        raise ValueError(f"source sheet {source.size} is not divisible by {EXPRESSION_COLUMNS}x{EXPRESSION_ROWS}")
    rects = cell_rects(source)
    natives: list[tuple[str, Image.Image]] = []
    for index, (portrait_id, _note) in enumerate(PORTRAIT_IDS):
        native = normalize_portrait(source, rects[index])
        save_exports(portrait_id, native)
        natives.append((portrait_id, native))
    write_manifest(rects)
    make_contact_sheet(natives)
    print("exported Mira rebalance preview portraits")
    print("contact sheet: docs/art/characters/mira_rebalance_contact_sheet.png")


if __name__ == "__main__":
    main()
