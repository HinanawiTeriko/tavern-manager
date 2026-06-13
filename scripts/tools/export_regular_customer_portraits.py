from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE_V5_A = ROOT / "art_sources" / "generated_raw" / "regular_customers" / "regular_customer_expression_sheet_v5_a.png"
RAW_SOURCE_V5_B = ROOT / "art_sources" / "generated_raw" / "regular_customers" / "regular_customer_expression_sheet_v5_b.png"
RAW_SOURCE_V5_C = ROOT / "art_sources" / "generated_raw" / "regular_customers" / "regular_customer_expression_sheet_v5_c.png"
VERA_REFERENCE = ROOT / "art_sources" / "generated_raw" / "tutorial_narrator" / "female_bartender_scribe_pixel_source_v2.png"
PILOT_SOURCE = ROOT / "art_sources" / "generated_raw" / "regular_customers" / "regular_belta_neutral_pilot_source_v1.png"
PILOT_PROMPT = ROOT / "art_sources" / "generated_raw" / "regular_customers" / "regular_belta_neutral_pilot_prompt_v1.txt"
SOURCE_DIR = ROOT / "assets" / "source" / "tavern" / "regular_customers"
RUNTIME_DIR = ROOT / "assets" / "textures" / "characters"
MANIFEST_PATH = SOURCE_DIR / "regular_customer_portraits_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "regular_customer_portraits_contact_sheet.png"

NATIVE_SIZE = (128, 160)
RUNTIME_SIZE = (512, 640)
PILOT_PORTRAIT_ID = "regular_belta_neutral"
PILOT_NATIVE_SIZE = (128, 160)
PILOT_RUNTIME_SIZE = (512, 640)
SCALE = 4
STYLE_PROFILE = "approved_vera_belta_runtime_matched_regular_portraits_v5"
UNIFORM_VISIBLE_HEIGHT = 154
UNIFORM_MAX_VISIBLE_WIDTH = 128
UNIFORM_BOTTOM_PADDING = 3
CONTACT_SHEET_PREVIEW_SCALE = 2
CONTACT_SHEET_PANEL_SIZE = (300, 374)
CONTACT_SHEET_PREVIEW_AREA_H = 326
CUSTOMER_GROUPS = [
    {
        "source": RAW_SOURCE_V5_A,
        "prompt": RAW_SOURCE_V5_A.with_name("regular_customer_expression_sheet_v5_a_prompt.txt"),
        "customers": ["regular_belta", "regular_noel", "regular_masha", "regular_coen"],
    },
    {
        "source": RAW_SOURCE_V5_B,
        "prompt": RAW_SOURCE_V5_B.with_name("regular_customer_expression_sheet_v5_b_prompt.txt"),
        "customers": ["regular_dorin", "regular_elira", "regular_marco", "regular_nix"],
    },
    {
        "source": RAW_SOURCE_V5_C,
        "prompt": RAW_SOURCE_V5_C.with_name("regular_customer_expression_sheet_v5_c_prompt.txt"),
        "customers": ["regular_selene", "regular_gareth", "regular_lyra", "regular_oma"],
    },
]
CUSTOMERS = [customer_id for group in CUSTOMER_GROUPS for customer_id in group["customers"]]
STATES = ["neutral", "satisfied", "dissatisfied"]


def fixed_grid_crops(sheet: Image.Image, source_path: Path, customers: list[str]) -> dict[str, dict]:
    width, height = sheet.size
    cell_w = width // len(customers)
    cell_h = height // len(STATES)
    crops: dict[str, dict] = {}
    pad_x = max(8, cell_w // 40)
    pad_y = max(8, cell_h // 48)
    for row, state in enumerate(STATES):
        for col, customer_id in enumerate(customers):
            left = col * cell_w + pad_x
            top = row * cell_h + pad_y
            right = (col + 1) * cell_w - pad_x
            bottom = (row + 1) * cell_h - pad_y
            portrait_id = f"{customer_id}_{state}"
            crops[portrait_id] = {
                "customer_id": customer_id,
                "state": state,
                "source": source_path.relative_to(ROOT).as_posix(),
                "crop_rect": [left, top, right, bottom],
            }
    return crops


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


def trim_visible(image: Image.Image) -> Image.Image:
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        return image
    left, top, right, bottom = bounds
    margin_x = max(4, (right - left) // 12)
    margin_y = max(4, (bottom - top) // 16)
    return image.crop((
        max(0, left - margin_x),
        max(0, top - margin_y),
        min(image.width, right + margin_x),
        min(image.height, bottom + margin_y),
    ))


def visible_crop(image: Image.Image) -> Image.Image:
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        return image
    return image.crop(bounds)


def quantize_visible(image: Image.Image, colors: int = 34) -> Image.Image:
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


def normalize_portrait(
    sheet: Image.Image,
    crop_rect: list[int],
    native_size: tuple[int, int] = NATIVE_SIZE,
    colors: int = 64,
) -> Image.Image:
    crop = sheet.crop(tuple(crop_rect))
    keyed = remove_chroma_key(crop)
    subject = visible_crop(keyed)
    target_box = (
        min(native_size[0], UNIFORM_MAX_VISIBLE_WIDTH),
        min(native_size[1] - UNIFORM_BOTTOM_PADDING, UNIFORM_VISIBLE_HEIGHT),
    )
    fitted = ImageOps.contain(subject, target_box, Image.Resampling.NEAREST)
    native = Image.new("RGBA", native_size, (0, 0, 0, 0))
    x = (native_size[0] - fitted.width) // 2
    bounds = fitted.getchannel("A").getbbox()
    visible_bottom = bounds[3] if bounds is not None else fitted.height
    y = native_size[1] - UNIFORM_BOTTOM_PADDING - visible_bottom
    y = min(max(0, y), max(0, native_size[1] - fitted.height))
    native.alpha_composite(fitted, (x, y))
    return quantize_visible(native, colors=colors)


def save_runtime(
    native: Image.Image,
    portrait_id: str,
    runtime_size: tuple[int, int] = RUNTIME_SIZE,
) -> Image.Image:
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    native_path = SOURCE_DIR / f"{portrait_id}_native.png"
    runtime_path = RUNTIME_DIR / f"{portrait_id}.png"
    native.save(native_path)
    runtime = native.resize(runtime_size, Image.Resampling.NEAREST)
    runtime.save(runtime_path)
    return runtime


def write_manifest(crops: dict[str, dict]) -> None:
    portraits = {}
    for portrait_id, spec in crops.items():
        native_size = spec.get("native_size", NATIVE_SIZE)
        runtime_size = spec.get("runtime_size", RUNTIME_SIZE)
        portraits[portrait_id] = {
            "customer_id": spec["customer_id"],
            "state": spec["state"],
            "source": spec["source"],
            "crop_rect": spec["crop_rect"],
            "native": f"assets/source/tavern/regular_customers/{portrait_id}_native.png",
            "runtime": f"assets/textures/characters/{portrait_id}.png",
            "safe_area": [0, 0, native_size[0], native_size[1]],
            "intended_godot_use": "Tavern CustomerSprite named regular customer bust portrait behind TabletopArt",
        }
        if "prompt" in spec:
            portraits[portrait_id]["prompt"] = spec["prompt"]
        if native_size != NATIVE_SIZE:
            portraits[portrait_id]["native_size"] = list(native_size)
        if runtime_size != RUNTIME_SIZE:
            portraits[portrait_id]["runtime_size"] = list(runtime_size)
    sources = [group["source"].relative_to(ROOT).as_posix() for group in CUSTOMER_GROUPS]
    prompt_sources = [group["prompt"].relative_to(ROOT).as_posix() for group in CUSTOMER_GROUPS]
    if PILOT_SOURCE.exists():
        sources.append(PILOT_SOURCE.relative_to(ROOT).as_posix())
    if PILOT_PROMPT.exists():
        prompt_sources.append(PILOT_PROMPT.relative_to(ROOT).as_posix())
    manifest = {
        "id": "regular_customer_portraits",
        "style_profile": STYLE_PROFILE,
        "style_references": [
            VERA_REFERENCE.relative_to(ROOT).as_posix(),
            PILOT_SOURCE.relative_to(ROOT).as_posix(),
        ],
        "source": CUSTOMER_GROUPS[0]["source"].relative_to(ROOT).as_posix(),
        "sources": sources,
        "prompt_sources": prompt_sources,
        "native_size": list(NATIVE_SIZE),
        "runtime_size": list(RUNTIME_SIZE),
        "scale": SCALE,
        "uniform_visible_height": UNIFORM_VISIBLE_HEIGHT,
        "uniform_max_visible_width": UNIFORM_MAX_VISIBLE_WIDTH,
        "uniform_bottom_padding": UNIFORM_BOTTOM_PADDING,
        "pilot_portraits": [PILOT_PORTRAIT_ID] if PILOT_PORTRAIT_ID in crops else [],
        "portraits": portraits,
    }
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def checkerboard(size: tuple[int, int], tile: int = 16) -> Image.Image:
    out = Image.new("RGBA", size, (44, 44, 44, 255))
    draw = ImageDraw.Draw(out)
    for y in range(0, size[1], tile):
        for x in range(0, size[0], tile):
            if (x // tile + y // tile) % 2 == 0:
                draw.rectangle((x, y, x + tile - 1, y + tile - 1), fill=(58, 58, 58, 255))
    return out


def backed(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    preview = image.convert("RGBA")
    if preview.width > size[0] or preview.height > size[1]:
        raise ValueError(f"contact sheet preview {preview.size} does not fit backing {size}")
    out = checkerboard(size)
    out.alpha_composite(preview, ((size[0] - preview.width) // 2, (size[1] - preview.height) // 2))
    return out


def make_contact_sheet(sheets: dict[str, Image.Image], natives: dict[str, Image.Image]) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    del sheets
    columns = 6
    panel_size = CONTACT_SHEET_PANEL_SIZE
    gap = 22
    margin = 24
    title_h = 40
    rows = (len(CUSTOMERS) * len(STATES) + columns - 1) // columns
    out_size = (
        margin * 2 + columns * panel_size[0] + (columns - 1) * gap,
        margin * 2 + title_h + rows * panel_size[1] + (rows - 1) * gap,
    )
    out = Image.new("RGBA", out_size, (18, 14, 11, 255))
    draw = ImageDraw.Draw(out)
    draw.text((margin, 14), "Regular customer runtime sheet - Belta-scale baseline", fill=(220, 204, 176, 255))
    index = 0
    for customer_id in CUSTOMERS:
        for state in STATES:
            portrait_id = f"{customer_id}_{state}"
            col = index % columns
            row = index // columns
            x = margin + col * (panel_size[0] + gap)
            y = margin + title_h + row * (panel_size[1] + gap)
            native = natives[portrait_id]
            preview = native.resize(
                (NATIVE_SIZE[0] * CONTACT_SHEET_PREVIEW_SCALE, NATIVE_SIZE[1] * CONTACT_SHEET_PREVIEW_SCALE),
                Image.Resampling.NEAREST,
            )
            out.alpha_composite(backed(preview, (panel_size[0], CONTACT_SHEET_PREVIEW_AREA_H)), (x, y))
            left, top, right, bottom = native.getchannel("A").getbbox()
            visible_w = (right - left) * SCALE
            visible_h = (bottom - top) * SCALE
            bottom_padding = (NATIVE_SIZE[1] - bottom) * SCALE
            draw.text((x, y + panel_size[1] - 30), f"{customer_id.replace('regular_', '')} {state}", fill=(220, 204, 176, 255))
            draw.text(
                (x, y + panel_size[1] - 14),
                f"visible {visible_w}x{visible_h}, bottom {bottom_padding}",
                fill=(170, 155, 132, 255),
            )
            index += 1
    out.convert("RGB").save(CONTACT_SHEET)


def export_pilot(natives: dict[str, Image.Image], crops: dict[str, dict]) -> None:
    if not PILOT_SOURCE.exists():
        return
    source = Image.open(PILOT_SOURCE).convert("RGBA")
    crop_rect = [0, 0, source.width, source.height]
    native = normalize_portrait(
        source,
        crop_rect,
        native_size=PILOT_NATIVE_SIZE,
        colors=64,
    )
    save_runtime(native, PILOT_PORTRAIT_ID, runtime_size=PILOT_RUNTIME_SIZE)
    natives[PILOT_PORTRAIT_ID] = native
    crops[PILOT_PORTRAIT_ID] = {
        "customer_id": "regular_belta",
        "state": "neutral",
        "source": PILOT_SOURCE.relative_to(ROOT).as_posix(),
        "prompt": PILOT_PROMPT.relative_to(ROOT).as_posix(),
        "crop_rect": crop_rect,
        "native_size": PILOT_NATIVE_SIZE,
        "runtime_size": PILOT_RUNTIME_SIZE,
    }


def main() -> None:
    sheets: dict[str, Image.Image] = {}
    crops = {}
    for group in CUSTOMER_GROUPS:
        source_path: Path = group["source"]
        if not source_path.exists():
            raise FileNotFoundError(f"missing regular customer source: {source_path}")
        sheet = Image.open(source_path).convert("RGBA")
        source_key = source_path.relative_to(ROOT).as_posix()
        sheets[source_key] = sheet
        crops.update(fixed_grid_crops(sheet, source_path, group["customers"]))
    natives = {}
    for portrait_id, spec in crops.items():
        sheet = sheets[spec["source"]]
        native = normalize_portrait(sheet, spec["crop_rect"])
        save_runtime(native, portrait_id)
        natives[portrait_id] = native
    export_pilot(natives, crops)
    write_manifest(crops)
    make_contact_sheet(sheets, natives)
    print("exported regular customer portraits: " + ", ".join(crops.keys()))
    print("contact sheet: docs/art/regular_customer_portraits_contact_sheet.png")


if __name__ == "__main__":
    main()
