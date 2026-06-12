from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "regular_customers" / "regular_customer_expression_sheet_v1.png"
RAW_SOURCE_V2_A = ROOT / "art_sources" / "generated_raw" / "regular_customers" / "regular_customer_expression_sheet_v2_a.png"
RAW_SOURCE_V2_B = ROOT / "art_sources" / "generated_raw" / "regular_customers" / "regular_customer_expression_sheet_v2_b.png"
SOURCE_DIR = ROOT / "assets" / "source" / "tavern" / "regular_customers"
RUNTIME_DIR = ROOT / "assets" / "textures" / "characters"
MANIFEST_PATH = SOURCE_DIR / "regular_customer_portraits_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "regular_customer_portraits_contact_sheet.png"

NATIVE_SIZE = (70, 90)
RUNTIME_SIZE = (280, 360)
SCALE = 4
CUSTOMER_GROUPS = [
    {
        "source": RAW_SOURCE,
        "customers": ["regular_belta", "regular_noel", "regular_masha", "regular_coen"],
    },
    {
        "source": RAW_SOURCE_V2_A,
        "customers": ["regular_dorin", "regular_elira", "regular_marco", "regular_nix"],
    },
    {
        "source": RAW_SOURCE_V2_B,
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
    pad_x = max(10, cell_w // 18)
    pad_y = max(10, cell_h // 24)
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


def normalize_portrait(sheet: Image.Image, crop_rect: list[int]) -> Image.Image:
    crop = sheet.crop(tuple(crop_rect))
    keyed = remove_chroma_key(crop)
    trimmed = trim_visible(keyed)
    fitted = ImageOps.contain(trimmed, NATIVE_SIZE, Image.Resampling.NEAREST)
    native = Image.new("RGBA", NATIVE_SIZE, (0, 0, 0, 0))
    x = (NATIVE_SIZE[0] - fitted.width) // 2
    bounds = fitted.getchannel("A").getbbox()
    visible_bottom = bounds[3] if bounds != None else fitted.height
    y = 76 - visible_bottom
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


def write_manifest(crops: dict[str, dict]) -> None:
    portraits = {}
    for portrait_id, spec in crops.items():
        portraits[portrait_id] = {
            "customer_id": spec["customer_id"],
            "state": spec["state"],
            "source": spec["source"],
            "crop_rect": spec["crop_rect"],
            "native": f"assets/source/tavern/regular_customers/{portrait_id}_native.png",
            "runtime": f"assets/textures/characters/{portrait_id}.png",
            "safe_area": [0, 0, NATIVE_SIZE[0], NATIVE_SIZE[1]],
            "intended_godot_use": "Tavern CustomerSprite named regular customer bust portrait behind TabletopArt",
        }
    manifest = {
        "id": "regular_customer_portraits",
        "source": "art_sources/generated_raw/regular_customers/regular_customer_expression_sheet_v1.png",
        "sources": [group["source"].relative_to(ROOT).as_posix() for group in CUSTOMER_GROUPS],
        "native_size": list(NATIVE_SIZE),
        "runtime_size": list(RUNTIME_SIZE),
        "scale": SCALE,
        "portraits": portraits,
    }
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def backed(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    preview = ImageOps.contain(image.convert("RGBA"), size, Image.Resampling.NEAREST)
    out = Image.new("RGBA", size, (24, 19, 15, 255))
    out.alpha_composite(preview, ((size[0] - preview.width) // 2, (size[1] - preview.height) // 2))
    return out


def make_contact_sheet(sheets: dict[str, Image.Image], natives: dict[str, Image.Image]) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    out = Image.new("RGBA", (1320, 1300), (18, 14, 11, 255))
    draw = ImageDraw.Draw(out)
    draw.text((20, 16), "Regular customer portrait pipeline", fill=(220, 204, 176, 255))
    for index, group in enumerate(CUSTOMER_GROUPS):
        source_key = group["source"].relative_to(ROOT).as_posix()
        source_preview = ImageOps.contain(sheets[source_key].convert("RGBA"), (410, 290), Image.Resampling.LANCZOS)
        out.alpha_composite(source_preview, (20 + index * 430, 44))

    draw.text((20, 360), "native previews, 3 states per regular customer", fill=(220, 204, 176, 255))
    for index, customer_id in enumerate(CUSTOMERS):
        col = index % 4
        group_row = index // 4
        for row, state in enumerate(STATES):
            portrait_id = f"{customer_id}_{state}"
            x = 24 + col * 318
            y = 400 + group_row * 290 + row * 88
            preview = natives[portrait_id].resize((NATIVE_SIZE[0] * 1, NATIVE_SIZE[1] * 1), Image.Resampling.NEAREST)
            out.alpha_composite(backed(preview, (82, 82)), (x, y))
            draw.text((x + 92, y + 8), customer_id.replace("regular_", ""), fill=(180, 168, 144, 255))
            draw.text((x + 92, y + 28), state, fill=(180, 168, 144, 255))
    out.convert("RGB").save(CONTACT_SHEET)


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
    write_manifest(crops)
    make_contact_sheet(sheets, natives)
    print("exported regular customer portraits: " + ", ".join(crops.keys()))
    print("contact sheet: docs/art/regular_customer_portraits_contact_sheet.png")


if __name__ == "__main__":
    main()
