from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "tavern_background" / "tavern_background_no_people_reference_v1.png"
ORDER_GROOVE_SOURCE = ROOT / "art_sources" / "generated_raw" / "tavern_order_groove" / "tavern_table_order_groove_source_v1.png"
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
PLAYABLE_X_RANGE_RUNTIME = [0, 1280]
SURFACE_TOP_Y_RUNTIME = 484
FRONT_LIP_Y_RUNTIME = 588
GROUND_Y_RUNTIME = 536
BACKGROUND_TABLE_SAMPLE_Y_RANGE = (110, 180)
TABLE_OCCLUSION_RECT_NATIVE = (0, 11, 320, 70)
ORDER_GROOVE_RECT_NATIVE = (78, 39, 242, 53)
ORDER_GROOVE_SAFE_AREA_RUNTIME = [392, 604, 888, 636]


def quantize_image(image: Image.Image, colors: int) -> Image.Image:
    return image.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")


def normalize_background(reference: Image.Image) -> Image.Image:
    fitted = ImageOps.fit(reference.convert("RGB"), BACKGROUND_NATIVE_SIZE, Image.Resampling.LANCZOS, centering=(0.5, 0.47))
    sharpened = fitted.filter(ImageFilter.UnsharpMask(radius=1, percent=150, threshold=2))
    contrast = ImageEnhance.Contrast(sharpened).enhance(1.16)
    color = ImageEnhance.Color(contrast).enhance(0.92)
    balanced = ImageEnhance.Brightness(color).enhance(0.88)
    native = quantize_image(balanced, 96)
    pixels = native.load()
    for y in range(native.height):
        for x in range(native.width):
            r, g, b, a = pixels[x, y]
            if y < 24 or y > 166:
                r = int(r * 0.82)
                g = int(g * 0.84)
                b = int(b * 0.88)
            if r > 135 and g > 48 and b < 76:
                r = min(185, r)
                g = min(106, g)
                b = min(62, b)
            else:
                r = min(r, 135)
                g = min(g, 124)
                b = min(b, 112)
            pixels[x, y] = (r, g, b, 255)
    return native


def normalize_table(background_native: Image.Image) -> Image.Image:
    native = Image.new("RGBA", TABLE_NATIVE_SIZE, (0, 0, 0, 0))
    pixels = native.load()
    background = background_native.convert("RGBA")
    source_start_y, _source_end_y = BACKGROUND_TABLE_SAMPLE_Y_RANGE
    left, top, right, bottom = TABLE_OCCLUSION_RECT_NATIVE
    for y in range(top, bottom):
        source_y = source_start_y + y
        for x in range(left, right):
            r, g, b, _a = background.getpixel((x, source_y))
            pixels[x, y] = (r, g, b, 255)
    return native


def runtime_rect_from_native(rect: tuple[int, int, int, int]) -> list[int]:
    runtime_top_y = SPRITE_POSITION_RUNTIME[1] - TABLE_RUNTIME_SIZE[1] // 2
    left, top, right, bottom = rect
    return [left * SCALE, runtime_top_y + top * SCALE, right * SCALE, runtime_top_y + bottom * SCALE]


def normalize_order_groove_source(reference: Image.Image, size: tuple[int, int]) -> Image.Image:
    fitted = ImageOps.fit(reference.convert("RGB"), size, Image.Resampling.LANCZOS, centering=(0.5, 0.47))
    sharpened = fitted.filter(ImageFilter.UnsharpMask(radius=1, percent=190, threshold=1))
    contrast = ImageEnhance.Contrast(sharpened).enhance(1.24)
    color = ImageEnhance.Color(contrast).enhance(0.82)
    balanced = ImageEnhance.Brightness(color).enhance(0.72)
    native = quantize_image(balanced, 40)
    pixels = native.load()
    width, height = native.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            luma = int(0.2126 * r + 0.7152 * g + 0.0722 * b)
            if y <= 3:
                r = int(r * 0.54)
                g = int(g * 0.52)
                b = int(b * 0.50)
            elif y >= height - 4:
                r = min(146, int(r * 1.72) + 24)
                g = min(90, int(g * 1.38) + 12)
                b = min(48, int(b * 1.04) + 3)
            else:
                r = min(105, int(r * 0.86))
                g = min(66, int(g * 0.84))
                b = min(42, int(b * 0.82))
            if 4 <= y <= height - 5 and luma < 44:
                r = int(r * 0.66)
                g = int(g * 0.62)
                b = int(b * 0.58)
            pixels[x, y] = (max(6, r), max(4, g), max(3, b), a)
    return quantize_image(native, 36)


def make_fixed_rect_blend_mask(size: tuple[int, int]) -> Image.Image:
    width, height = size
    mask = Image.new("L", size, 0)
    pixels = mask.load()
    for y in range(height):
        for x in range(width):
            edge = min(x, width - 1 - x, y, height - 1 - y)
            if edge <= 0:
                alpha = 86
            elif edge == 1:
                alpha = 142
            elif edge == 2:
                alpha = 202
            else:
                alpha = 255
            pixels[x, y] = alpha
    return mask


def bake_order_groove(table_native: Image.Image, groove_source: Image.Image) -> Image.Image:
    native = table_native.copy()
    left, top, right, bottom = ORDER_GROOVE_RECT_NATIVE
    size = (right - left, bottom - top)
    groove = normalize_order_groove_source(groove_source, size)
    base = native.crop(ORDER_GROOVE_RECT_NATIVE).convert("RGBA")
    mask = make_fixed_rect_blend_mask(size)
    merged = Image.composite(groove, base, mask)
    native.alpha_composite(merged, (left, top))
    return native


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
        "id": "tavern_bar_background_foreground_occluder",
        "source": "art_sources/generated_raw/tavern_background/tavern_background_no_people_reference_v1.png",
        "native": "assets/source/tavern/table/tabletop_native.png",
        "runtime": "assets/textures/tavern/table/tabletop.png",
        "native_size": list(TABLE_NATIVE_SIZE),
        "runtime_size": list(TABLE_RUNTIME_SIZE),
        "scale": SCALE,
        "safe_area": [0, 0, 320, 80],
        "derived_from": "assets/source/tavern/background/tavern_bg_native.png",
        "background_sample_native_y_range": list(BACKGROUND_TABLE_SAMPLE_Y_RANGE),
        "occlusion_rect_native": list(TABLE_OCCLUSION_RECT_NATIVE),
        "order_groove_source": "art_sources/generated_raw/tavern_order_groove/tavern_table_order_groove_source_v1.png",
        "order_groove_rect_native": list(ORDER_GROOVE_RECT_NATIVE),
        "order_groove_runtime_rect": runtime_rect_from_native(ORDER_GROOVE_RECT_NATIVE),
        "order_groove_safe_area_runtime": ORDER_GROOVE_SAFE_AREA_RUNTIME,
        "order_groove_pipeline": {
            "method": "fixed-rect imagegen source composite",
            "runtime_ui": "Godot Labels and ProgressBar only; no text baked into the texture",
        },
        "physics_alignment": {
            "sprite_position_runtime": list(SPRITE_POSITION_RUNTIME),
            "surface_top_y_runtime": SURFACE_TOP_Y_RUNTIME,
            "front_lip_y_runtime": FRONT_LIP_Y_RUNTIME,
            "ground_y_runtime": GROUND_Y_RUNTIME,
            "playable_x_range_runtime": PLAYABLE_X_RANGE_RUNTIME,
        },
        "intended_godot_use": "background-matched Tavern foreground bar occluder that preserves customer bust depth",
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
    ground_y = overlay_y + int((GROUND_Y_RUNTIME - runtime_top_y) * 0.5)
    lip_y = overlay_y + int((FRONT_LIP_Y_RUNTIME - runtime_top_y) * 0.5)
    draw.line((40, surface_y, 680, surface_y), fill=(229, 163, 70, 255), width=1)
    draw.line((40, ground_y, 680, ground_y), fill=(96, 169, 157, 255), width=1)
    draw.line((40, lip_y, 680, lip_y), fill=(112, 124, 106, 255), width=1)
    sheet.convert("RGB").save(BACKGROUND_CONTACT_SHEET)


def make_table_contact_sheet(background: Image.Image, native: Image.Image, runtime: Image.Image, groove_source: Image.Image) -> None:
    TABLE_CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (720, 690), (18, 14, 11, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((20, 16), "Tavern counter pipeline from no-people background", fill=(220, 204, 176, 255))
    draw.text((20, 52), "background lower sample", fill=(220, 204, 176, 255))
    draw.text((20, 178), "native 4x preview", fill=(220, 204, 176, 255))
    draw.text(
        (20, 354),
        "runtime preview with y=%d/y=%d/y=%d guide rows" % (
            SURFACE_TOP_Y_RUNTIME,
            GROUND_Y_RUNTIME,
            FRONT_LIP_Y_RUNTIME,
        ),
        fill=(220, 204, 176, 255),
    )
    draw.text((20, 550), "generated order groove source crop reference", fill=(220, 204, 176, 255))
    sample_start, sample_end = BACKGROUND_TABLE_SAMPLE_Y_RANGE
    sample = background.crop((0, sample_start, TABLE_NATIVE_SIZE[0], sample_end)).convert("RGBA")
    ref_preview = ImageOps.contain(sample, (640, 96), Image.Resampling.NEAREST)
    native_preview = native.resize((native.width * 4, native.height * 4), Image.Resampling.NEAREST)
    native_preview = ImageOps.contain(native_preview, (640, 144), Image.Resampling.NEAREST)
    runtime_preview = runtime.convert("RGBA").resize((640, 160), Image.Resampling.NEAREST)
    groove_preview = ImageOps.contain(groove_source.convert("RGBA"), (640, 100), Image.Resampling.LANCZOS)
    sheet.alpha_composite(ref_preview, (60, 76))
    sheet.alpha_composite(native_preview, (60, 202))
    sheet.alpha_composite(runtime_preview, (60, 378))
    sheet.alpha_composite(groove_preview, (60, 574))
    runtime_top_y = SPRITE_POSITION_RUNTIME[1] - TABLE_RUNTIME_SIZE[1] // 2
    guide_scale = runtime_preview.height / TABLE_RUNTIME_SIZE[1]
    surface_guide_y = int(378 + (SURFACE_TOP_Y_RUNTIME - runtime_top_y) * guide_scale)
    ground_guide_y = int(378 + (GROUND_Y_RUNTIME - runtime_top_y) * guide_scale)
    lip_guide_y = int(378 + (FRONT_LIP_Y_RUNTIME - runtime_top_y) * guide_scale)
    draw.line((60, surface_guide_y, 700, surface_guide_y), fill=(229, 163, 70, 255), width=1)
    draw.line((60, ground_guide_y, 700, ground_guide_y), fill=(96, 169, 157, 255), width=1)
    draw.line((60, lip_guide_y, 700, lip_guide_y), fill=(112, 124, 106, 255), width=1)
    left, top, right, bottom = ORDER_GROOVE_RECT_NATIVE
    native_left = 60 + left * 2
    native_top = 202 + top * 2
    native_right = 60 + right * 2
    native_bottom = 202 + bottom * 2
    draw.rectangle((native_left, native_top, native_right, native_bottom), outline=(229, 163, 70, 255), width=1)
    runtime_rect = runtime_rect_from_native(ORDER_GROOVE_RECT_NATIVE)
    runtime_left = 60 + int(runtime_rect[0] * 0.5)
    runtime_top = 378 + int((runtime_rect[1] - runtime_top_y) * guide_scale)
    runtime_right = 60 + int(runtime_rect[2] * 0.5)
    runtime_bottom = 378 + int((runtime_rect[3] - runtime_top_y) * guide_scale)
    draw.rectangle((runtime_left, runtime_top, runtime_right, runtime_bottom), outline=(229, 163, 70, 255), width=1)
    sheet.convert("RGB").save(TABLE_CONTACT_SHEET)


def main() -> None:
    if not RAW_SOURCE.exists():
        raise FileNotFoundError(f"missing generated Tavern background reference: {RAW_SOURCE}")
    if not ORDER_GROOVE_SOURCE.exists():
        raise FileNotFoundError(f"missing generated Tavern order groove reference: {ORDER_GROOVE_SOURCE}")
    reference = Image.open(RAW_SOURCE).convert("RGB")
    groove_source = Image.open(ORDER_GROOVE_SOURCE).convert("RGB")
    background_native = normalize_background(reference)
    table_native = bake_order_groove(normalize_table(background_native), groove_source)
    background_runtime = save_nearest(background_native, BACKGROUND_NATIVE, BACKGROUND_RUNTIME, BACKGROUND_RUNTIME_SIZE)
    table_runtime = save_nearest(table_native, TABLE_NATIVE, TABLE_RUNTIME, TABLE_RUNTIME_SIZE)
    write_background_manifest()
    write_table_manifest()
    make_background_contact_sheet(reference, background_native, table_native)
    make_table_contact_sheet(background_native, table_native, table_runtime, groove_source)
    print("exported Tavern background: assets/textures/tavern/background/tavern_bg.png")
    print("exported Tavern foreground occluder: assets/textures/tavern/table/tabletop.png")
    print("contact sheet: docs/art/tavern_background_contact_sheet.png")


if __name__ == "__main__":
    main()
