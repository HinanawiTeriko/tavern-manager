from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "tavern_background" / "tavern_background_no_people_reference_v1.png"
BACKGROUND_NATIVE = ROOT / "assets" / "source" / "tavern" / "background" / "tavern_bg_native.png"
BACKGROUND_RUNTIME = ROOT / "assets" / "textures" / "tavern" / "background" / "tavern_bg.png"
BACKGROUND_MANIFEST = ROOT / "assets" / "source" / "tavern" / "background" / "tavern_background_manifest.json"
TABLE_NATIVE = ROOT / "assets" / "source" / "tavern" / "table" / "tabletop_native.png"
TABLE_RUNTIME = ROOT / "assets" / "textures" / "tavern" / "table" / "tabletop.png"
TABLE_MANIFEST = ROOT / "assets" / "source" / "tavern" / "table" / "tabletop_manifest.json"
BACKGROUND_CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_background_contact_sheet.png"
TABLE_CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_table_contact_sheet.png"
SCALE = 4
BACKGROUND_NATIVE_SIZE = (320, 180)
BACKGROUND_RUNTIME_SIZE = (1280, 720)
TABLE_NATIVE_SIZE = (320, 80)
TABLE_RUNTIME_SIZE = (1280, 320)
SPRITE_POSITION_RUNTIME = (640, 600)
SURFACE_TOP_Y_RUNTIME = 455
FRONT_LIP_Y_RUNTIME = 655
GROUND_Y_RUNTIME = 655
PLAYABLE_X_RANGE_RUNTIME = [150, 1130]
TABLE_SOURCE_BOX = (0, 602, 1672, 941)
CUTOUT_POLYGON_NATIVE = [(10, 10), (310, 10), (320, 64), (320, 73), (0, 73), (0, 64)]


def quantize_image(image: Image.Image, colors: int) -> Image.Image:
    return image.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")


def normalize_background(reference: Image.Image) -> Image.Image:
    fitted = ImageOps.fit(reference.convert("RGB"), BACKGROUND_NATIVE_SIZE, Image.Resampling.LANCZOS, centering=(0.5, 0.47))
    sharpened = fitted.filter(ImageFilter.UnsharpMask(radius=1, percent=180, threshold=2))
    contrast = ImageEnhance.Contrast(sharpened).enhance(1.30)
    color = ImageEnhance.Color(contrast).enhance(0.82)
    balanced = ImageEnhance.Brightness(color).enhance(0.82)
    native = quantize_image(balanced, 48)
    pixels = native.load()
    for y in range(native.height):
        for x in range(native.width):
            r, g, b, a = pixels[x, y]
            if y < 24 or y > 166:
                r = int(r * 0.78)
                g = int(g * 0.80)
                b = int(b * 0.88)
            if r > 120 and g > 46 and b < 72:
                r = min(178, r)
                g = min(98, g)
                b = min(56, b)
            elif b >= r and g >= int(r * 0.70):
                b = min(92, max(b, 34))
                g = min(88, max(g, 30))
                r = min(r, 76)
            else:
                r = min(r, 120)
                g = min(g, 110)
                b = min(b, 100)
            pixels[x, y] = (r, g, b, 255)
    return native


def apply_table_cutout(image: Image.Image) -> Image.Image:
    mask = Image.new("L", image.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.polygon(CUTOUT_POLYGON_NATIVE, fill=255)
    cutout = image.convert("RGBA")
    cutout.putalpha(mask)
    pixels = cutout.load()
    for y in range(cutout.height):
        for x in range(cutout.width):
            if pixels[x, y][3] == 0:
                pixels[x, y] = (0, 0, 0, 0)
    return cutout


def normalize_table(reference: Image.Image) -> Image.Image:
    crop = reference.crop(TABLE_SOURCE_BOX).convert("RGB")
    resized = crop.resize(TABLE_NATIVE_SIZE, Image.Resampling.LANCZOS)
    sharpened = resized.filter(ImageFilter.UnsharpMask(radius=1, percent=260, threshold=2))
    contrast = ImageEnhance.Contrast(sharpened).enhance(1.35)
    color = ImageEnhance.Color(contrast).enhance(0.72)
    balanced = ImageEnhance.Brightness(color).enhance(0.92)
    native = quantize_image(balanced, 24)
    pixels = native.load()
    for y in range(native.height):
        for x in range(native.width):
            r, g, b, a = pixels[x, y]
            r = min(150, max(12, r))
            g = min(104, max(10, g))
            b = min(78, max(8, b))
            if r >= 92 and g >= 42 and b <= 46:
                r = max(r, 96)
                g = max(g, 42)
                b = min(b, 44)
            elif r < 20 and g < 14 and b < 14:
                r = max(r, 22)
                g = max(g, 14)
                b = max(b, 10)
            if y < 14:
                r = int(r * 0.80)
                g = int(g * 0.78)
                b = int(b * 0.86)
            elif y > 64:
                r = int(r * 0.65)
                g = int(g * 0.64)
                b = int(b * 0.74)
            if r < 34 and g < 24:
                r = max(r, 22)
                g = max(g, 16)
                b = max(b, 18)
            pixels[x, y] = (r, g, b, a)
    return apply_table_cutout(native)


def save_nearest(native: Image.Image, native_path: Path, runtime_path: Path, runtime_size: tuple[int, int]) -> Image.Image:
    native_path.parent.mkdir(parents=True, exist_ok=True)
    runtime_path.parent.mkdir(parents=True, exist_ok=True)
    native.save(native_path)
    runtime = native.resize(runtime_size, Image.Resampling.NEAREST)
    runtime.save(runtime_path)
    return runtime


def write_background_manifest() -> None:
    manifest = {
        "id": "tavern_no_people_background",
        "source": "art_sources/generated_raw/tavern_background/tavern_background_no_people_reference_v1.png",
        "native": "assets/source/tavern/background/tavern_bg_native.png",
        "runtime": "assets/textures/tavern/background/tavern_bg.png",
        "native_size": list(BACKGROUND_NATIVE_SIZE),
        "runtime_size": list(BACKGROUND_RUNTIME_SIZE),
        "scale": SCALE,
        "safe_area": [0, 0, 320, 180],
        "source_fit": {"method": "ImageOps.fit", "centering": [0.5, 0.47]},
        "intended_godot_use": "Tavern service scene visual-only no-people background Sprite2D layer",
    }
    BACKGROUND_MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    BACKGROUND_MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def write_table_manifest() -> None:
    manifest = {
        "id": "tavern_bar_work_surface",
        "source": "art_sources/generated_raw/tavern_background/tavern_background_no_people_reference_v1.png",
        "native": "assets/source/tavern/table/tabletop_native.png",
        "runtime": "assets/textures/tavern/table/tabletop.png",
        "native_size": list(TABLE_NATIVE_SIZE),
        "runtime_size": list(TABLE_RUNTIME_SIZE),
        "scale": SCALE,
        "safe_area": [0, 0, 320, 80],
        "source_box": list(TABLE_SOURCE_BOX),
        "cutout_polygon_native": [list(point) for point in CUTOUT_POLYGON_NATIVE],
        "physics_alignment": {
            "sprite_position_runtime": list(SPRITE_POSITION_RUNTIME),
            "surface_top_y_runtime": SURFACE_TOP_Y_RUNTIME,
            "front_lip_y_runtime": FRONT_LIP_Y_RUNTIME,
            "ground_y_runtime": GROUND_Y_RUNTIME,
            "playable_x_range_runtime": PLAYABLE_X_RANGE_RUNTIME,
        },
        "intended_godot_use": "visual-only Tavern physics-aligned bar work surface Sprite2D layer",
    }
    TABLE_MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    TABLE_MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def make_background_contact_sheet(reference: Image.Image, background: Image.Image, table: Image.Image) -> None:
    BACKGROUND_CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (720, 680), (16, 14, 12, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((20, 14), "Tavern no-people background and counter pipeline", fill=(220, 204, 176, 255))
    draw.text((20, 44), "approved generated reference", fill=(220, 204, 176, 255))
    ref_preview = ImageOps.contain(reference.convert("RGBA"), (640, 180), Image.Resampling.LANCZOS)
    sheet.alpha_composite(ref_preview, (40, 66))
    draw.text((20, 260), "background native 2x preview", fill=(220, 204, 176, 255))
    bg_preview = background.resize((640, 360), Image.Resampling.NEAREST)
    sheet.alpha_composite(bg_preview, (40, 284))
    table_preview = table.resize((640, 160), Image.Resampling.NEAREST)
    overlay_y = 284 + 360 - 160
    sheet.alpha_composite(table_preview, (40, overlay_y))
    runtime_top_y = SPRITE_POSITION_RUNTIME[1] - TABLE_RUNTIME_SIZE[1] // 2
    surface_y = overlay_y + int((SURFACE_TOP_Y_RUNTIME - runtime_top_y) * 0.5)
    lip_y = overlay_y + int((FRONT_LIP_Y_RUNTIME - runtime_top_y) * 0.5)
    draw.line((40, surface_y, 680, surface_y), fill=(229, 163, 70, 255), width=1)
    draw.line((40, lip_y, 680, lip_y), fill=(96, 169, 157, 255), width=1)
    sheet.convert("RGB").save(BACKGROUND_CONTACT_SHEET)


def make_table_contact_sheet(reference: Image.Image, native: Image.Image, runtime: Image.Image) -> None:
    TABLE_CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (720, 432), (18, 14, 11, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((20, 16), "Tavern counter pipeline from no-people background", fill=(220, 204, 176, 255))
    draw.text((20, 52), "reference crop", fill=(220, 204, 176, 255))
    draw.text((20, 178), "native 4x preview", fill=(220, 204, 176, 255))
    draw.text((20, 354), "runtime preview with y=455/y=655 guide rows", fill=(220, 204, 176, 255))
    ref_crop = reference.crop(TABLE_SOURCE_BOX).convert("RGBA")
    ref_preview = ImageOps.contain(ref_crop, (640, 96), Image.Resampling.LANCZOS)
    native_preview = native.resize((native.width * 4, native.height * 4), Image.Resampling.NEAREST)
    native_preview = ImageOps.contain(native_preview, (640, 144), Image.Resampling.NEAREST)
    runtime_preview = ImageOps.contain(runtime.convert("RGBA"), (640, 48), Image.Resampling.NEAREST)
    sheet.alpha_composite(ref_preview, (60, 76))
    sheet.alpha_composite(native_preview, (60, 202))
    sheet.alpha_composite(runtime_preview, (60, 378))
    runtime_top_y = SPRITE_POSITION_RUNTIME[1] - TABLE_RUNTIME_SIZE[1] // 2
    guide_scale = runtime_preview.height / TABLE_RUNTIME_SIZE[1]
    surface_guide_y = int(378 + (SURFACE_TOP_Y_RUNTIME - runtime_top_y) * guide_scale)
    lip_guide_y = int(378 + (FRONT_LIP_Y_RUNTIME - runtime_top_y) * guide_scale)
    draw.line((60, surface_guide_y, 700, surface_guide_y), fill=(229, 163, 70, 255), width=1)
    draw.line((60, lip_guide_y, 700, lip_guide_y), fill=(96, 169, 157, 255), width=1)
    sheet.convert("RGB").save(TABLE_CONTACT_SHEET)


def main() -> None:
    if not RAW_SOURCE.exists():
        raise FileNotFoundError(f"missing generated Tavern background reference: {RAW_SOURCE}")
    reference = Image.open(RAW_SOURCE).convert("RGB")
    background_native = normalize_background(reference)
    table_native = normalize_table(reference)
    background_runtime = save_nearest(background_native, BACKGROUND_NATIVE, BACKGROUND_RUNTIME, BACKGROUND_RUNTIME_SIZE)
    table_runtime = save_nearest(table_native, TABLE_NATIVE, TABLE_RUNTIME, TABLE_RUNTIME_SIZE)
    write_background_manifest()
    write_table_manifest()
    make_background_contact_sheet(reference, background_native, table_native)
    make_table_contact_sheet(reference, table_native, table_runtime)
    print("exported Tavern background: assets/textures/tavern/background/tavern_bg.png")
    print("exported Tavern counter: assets/textures/tavern/table/tabletop.png")
    print("contact sheet: docs/art/tavern_background_contact_sheet.png")


if __name__ == "__main__":
    main()
