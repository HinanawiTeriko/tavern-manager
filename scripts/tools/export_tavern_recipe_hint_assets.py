"""Export the Tavern recipe hint strip through the native pixel UI pipeline."""

from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = ROOT / "art_sources" / "generated_raw" / "recipe_hint_strip"
RAW_SOURCE = RAW_DIR / "recipe_hint_strip_source_v1.png"
PROMPT = RAW_DIR / "recipe_hint_strip_prompt_v1.txt"
SOURCE_DIR = ROOT / "assets" / "source" / "ui" / "recipe_hint_strip"
RUNTIME_DIR = ROOT / "assets" / "textures" / "ui" / "recipe_hint_strip"
MANIFEST = SOURCE_DIR / "recipe_hint_strip_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "recipe_hint_strip_contact_sheet.png"

ASSET_ID = "recipe_hint_strip_panel"
SOURCE_RECTS = {
    ASSET_ID: [72, 388, 1182, 584],
}
SCALE = 4
NATIVE_SIZE = (118, 14)
RUNTIME_SIZE = (NATIVE_SIZE[0] * SCALE, NATIVE_SIZE[1] * SCALE)
SAFE_AREA = [96, 10, 400, 34]
NINE_SLICE_MARGINS = [56, 20, 56, 20]

PIXEL_PALETTE = [
    (24, 14, 9),
    (38, 23, 14),
    (55, 34, 20),
    (76, 47, 27),
    (98, 62, 34),
    (125, 79, 42),
    (154, 97, 49),
    (185, 125, 67),
    (207, 153, 86),
    (224, 176, 103),
    (238, 197, 126),
    (248, 218, 151),
    (255, 236, 178),
]


def _is_chroma_green(red: int, green: int, blue: int) -> bool:
    return green >= 130 and green > red * 1.35 and green > blue * 1.35


def _remove_chroma(image: Image.Image) -> Image.Image:
    src = image.convert("RGBA")
    out = Image.new("RGBA", src.size, (0, 0, 0, 0))
    src_px = src.load()
    out_px = out.load()
    for y in range(src.height):
        for x in range(src.width):
            red, green, blue, alpha = src_px[x, y]
            if alpha < 18 or _is_chroma_green(red, green, blue):
                continue
            out_px[x, y] = (red, green, blue, alpha)
    return out


def _resize_premultiplied(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    src = image.convert("RGBA")
    premultiplied = Image.new("RGBA", src.size, (0, 0, 0, 0))
    src_px = src.load()
    pre_px = premultiplied.load()
    for y in range(src.height):
        for x in range(src.width):
            red, green, blue, alpha = src_px[x, y]
            factor = alpha / 255.0
            pre_px[x, y] = (int(red * factor), int(green * factor), int(blue * factor), alpha)

    resized = premultiplied.resize(size, Image.Resampling.BOX)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    resized_px = resized.load()
    out_px = out.load()
    for y in range(size[1]):
        for x in range(size[0]):
            red, green, blue, alpha = resized_px[x, y]
            if alpha <= 0:
                continue
            factor = 255.0 / alpha
            out_px[x, y] = (
                min(255, int(red * factor)),
                min(255, int(green * factor)),
                min(255, int(blue * factor)),
                alpha,
            )
    return out


def _nearest_palette_color(color: tuple[int, int, int]) -> tuple[int, int, int]:
    red, green, blue = color
    return min(
        PIXEL_PALETTE,
        key=lambda option: (
            math.pow(red - option[0], 2)
            + math.pow(green - option[1], 2)
            + math.pow(blue - option[2], 2)
        ),
    )


def _normalize_native(image: Image.Image) -> Image.Image:
    resized = _resize_premultiplied(image, NATIVE_SIZE)
    out = Image.new("RGBA", NATIVE_SIZE, (0, 0, 0, 0))
    resized_px = resized.load()
    out_px = out.load()
    for y in range(NATIVE_SIZE[1]):
        for x in range(NATIVE_SIZE[0]):
            red, green, blue, alpha = resized_px[x, y]
            if alpha < 32:
                continue
            out_px[x, y] = (*_nearest_palette_color((red, green, blue)), 255)
    return out


def _export_asset(raw: Image.Image) -> Image.Image:
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    crop = raw.crop(tuple(SOURCE_RECTS[ASSET_ID]))
    crop = _remove_chroma(crop)
    native = _normalize_native(crop)
    native.save(SOURCE_DIR / f"{ASSET_ID}_native.png")
    native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST).save(RUNTIME_DIR / f"{ASSET_ID}.png")
    print(f"{ASSET_ID}: {NATIVE_SIZE} -> {RUNTIME_SIZE}")
    return native


def _write_manifest() -> None:
    manifest = {
        "id": "recipe_hint_strip",
        "raw_source": RAW_SOURCE.relative_to(ROOT).as_posix(),
        "prompt": PROMPT.relative_to(ROOT).as_posix(),
        "scale": SCALE,
        "contact_sheet": CONTACT_SHEET.relative_to(ROOT).as_posix(),
        "assets": {
            ASSET_ID: {
                "id": ASSET_ID,
                "source_file": RAW_SOURCE.relative_to(ROOT).as_posix(),
                "source_rect": SOURCE_RECTS[ASSET_ID],
                "native_size": list(NATIVE_SIZE),
                "runtime_size": list(RUNTIME_SIZE),
                "native_file": f"assets/source/ui/recipe_hint_strip/{ASSET_ID}_native.png",
                "runtime_file": f"assets/textures/ui/recipe_hint_strip/{ASSET_ID}.png",
                "safe_area": SAFE_AREA,
                "nine_slice_margins": NINE_SLICE_MARGINS,
                "intended_godot_use": "Tavern CustomerArea/RecipeHintPanel paper and wood strip backing",
            }
        },
    }
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(MANIFEST.relative_to(ROOT).as_posix())


def _write_contact_sheet(native: Image.Image) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    runtime = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
    sheet = Image.new("RGBA", (560, 176), (8, 25, 29, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((16, 12), "RecipeHintPanel strip - fixed source rect, 4x nearest runtime", fill=(220, 204, 176, 255))
    sheet.alpha_composite(runtime, (44, 52))
    left, top = 44 + SAFE_AREA[0], 52 + SAFE_AREA[1]
    right, bottom = 44 + SAFE_AREA[2], 52 + SAFE_AREA[3]
    draw.rectangle((left, top, right, bottom), outline=(68, 39, 22, 255), width=1)
    draw.text((44, 118), "safe text area: warm paper, dark ink label rendered by Godot", fill=(156, 141, 120, 255))
    sheet.convert("RGB").save(CONTACT_SHEET)
    print(CONTACT_SHEET.relative_to(ROOT).as_posix())


def main() -> int:
    if not RAW_SOURCE.exists():
        raise FileNotFoundError(f"missing generated source: {RAW_SOURCE}")
    if not PROMPT.exists():
        raise FileNotFoundError(f"missing prompt record: {PROMPT}")
    raw = Image.open(RAW_SOURCE).convert("RGBA")
    native = _export_asset(raw)
    _write_manifest()
    _write_contact_sheet(native)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
