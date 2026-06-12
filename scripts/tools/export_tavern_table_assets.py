from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art_sources" / "generated_raw" / "tavern_table" / "tabletop_reference_v2.png"
MANIFEST = ROOT / "assets" / "source" / "tavern" / "table" / "tabletop_manifest.json"
NATIVE = ROOT / "assets" / "source" / "tavern" / "table" / "tabletop_native.png"
RUNTIME = ROOT / "assets" / "textures" / "tavern" / "table" / "tabletop.png"
CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_table_contact_sheet.png"
NATIVE_SIZE = (320, 80)
RUNTIME_SIZE = (1280, 320)
SCALE = 4
SPRITE_POSITION_RUNTIME = (640, 600)
SURFACE_TOP_Y_RUNTIME = 455
FRONT_LIP_Y_RUNTIME = 655
GROUND_Y_RUNTIME = 655
CUTOUT_POLYGON_NATIVE = [(10, 14), (310, 14), (320, 64), (320, 73), (0, 73), (0, 64)]


def quantize_image(image: Image.Image, colors: int = 18) -> Image.Image:
    rgb = image.convert("RGB")
    return rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")


def apply_cutout_mask(image: Image.Image) -> Image.Image:
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


def normalize_work_surface(source: Image.Image) -> Image.Image:
    resized = source.convert("RGB").resize(NATIVE_SIZE, Image.Resampling.LANCZOS)
    sharpened = resized.filter(ImageFilter.UnsharpMask(radius=1, percent=280, threshold=2))
    contrast = ImageEnhance.Contrast(sharpened).enhance(1.45)
    color = ImageEnhance.Color(contrast).enhance(0.50)
    balanced = ImageEnhance.Brightness(color).enhance(0.70)
    native = quantize_image(balanced, 22)
    pixels = native.load()
    source_pixels = resized.load()
    for y in range(native.height):
        for x in range(native.width):
            r, g, b, a = pixels[x, y]
            sr, sg, sb = source_pixels[x, y]
            r = min(155, max(16, r))
            g = min(105, max(12, g))
            b = min(82, max(10, b))
            warm_source = sr >= 125 and sr >= sb * 1.2 and sg >= 62
            if r < 66:
                b = min(82, max(b, int(r * 0.58)))
            if y < 8:
                r = max(14, int(r * 0.72))
                g = max(12, int(g * 0.74))
                b = max(16, int(b * 0.92))
            elif y > native.height - 4:
                r = max(14, int(r * 0.76))
                g = max(12, int(g * 0.76))
                b = max(12, int(b * 0.84))
            if warm_source:
                r = max(r, 92)
                g = max(g, 42)
                b = min(b, 44)
            pixels[x, y] = (r, g, b, 255)
    return apply_cutout_mask(native)


def save_manifest() -> None:
    manifest = {
        "id": "tavern_bar_work_surface",
        "source": "art_sources/generated_raw/tavern_table/tabletop_reference_v2.png",
        "native": "assets/source/tavern/table/tabletop_native.png",
        "runtime": "assets/textures/tavern/table/tabletop.png",
        "native_size": list(NATIVE_SIZE),
        "runtime_size": list(RUNTIME_SIZE),
        "scale": SCALE,
        "safe_area": [0, 0, 320, 80],
        "cutout_polygon_native": [list(point) for point in CUTOUT_POLYGON_NATIVE],
        "physics_alignment": {
            "sprite_position_runtime": list(SPRITE_POSITION_RUNTIME),
            "surface_top_y_runtime": SURFACE_TOP_Y_RUNTIME,
            "front_lip_y_runtime": FRONT_LIP_Y_RUNTIME,
            "ground_y_runtime": GROUND_Y_RUNTIME,
            "playable_x_range_runtime": [150, 1130],
        },
        "intended_godot_use": "visual-only Tavern physics-aligned bar work surface Sprite2D layer",
    }
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def make_contact_sheet(reference: Image.Image, native: Image.Image, runtime: Image.Image) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (720, 432), (18, 14, 11, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((20, 16), "Tavern physics-aligned work surface pipeline", fill=(220, 204, 176, 255))
    draw.text((20, 52), "reference", fill=(220, 204, 176, 255))
    draw.text((20, 178), "native 4x preview", fill=(220, 204, 176, 255))
    draw.text((20, 354), "runtime preview with y=455/y=655 guide rows", fill=(220, 204, 176, 255))
    ref_preview = ImageOps.contain(reference.convert("RGBA"), (640, 96), Image.Resampling.LANCZOS)
    native_preview = native.resize((native.width * 4, native.height * 4), Image.Resampling.NEAREST)
    native_preview = ImageOps.contain(native_preview, (640, 144), Image.Resampling.NEAREST)
    runtime_preview = ImageOps.contain(runtime.convert("RGBA"), (640, 48), Image.Resampling.NEAREST)
    sheet.alpha_composite(ref_preview, (60, 76))
    sheet.alpha_composite(native_preview, (60, 202))
    sheet.alpha_composite(runtime_preview, (60, 378))
    runtime_top_y = SPRITE_POSITION_RUNTIME[1] - RUNTIME_SIZE[1] // 2
    guide_scale = runtime_preview.height / RUNTIME_SIZE[1]
    surface_guide_y = int(378 + (SURFACE_TOP_Y_RUNTIME - runtime_top_y) * guide_scale)
    lip_guide_y = int(378 + (FRONT_LIP_Y_RUNTIME - runtime_top_y) * guide_scale)
    draw.line((60, surface_guide_y, 700, surface_guide_y), fill=(229, 163, 70, 255), width=1)
    draw.line((60, lip_guide_y, 700, lip_guide_y), fill=(96, 169, 157, 255), width=1)
    sheet.convert("RGB").save(CONTACT_SHEET)


def main() -> None:
    if not SOURCE.exists():
        raise FileNotFoundError(f"missing work surface reference: {SOURCE}")
    reference = Image.open(SOURCE).convert("RGBA")
    native = normalize_work_surface(reference)
    runtime = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
    NATIVE.parent.mkdir(parents=True, exist_ok=True)
    RUNTIME.parent.mkdir(parents=True, exist_ok=True)
    native.save(NATIVE)
    runtime.save(RUNTIME)
    save_manifest()
    make_contact_sheet(reference, native, runtime)
    print("exported tavern work surface: assets/textures/tavern/table/tabletop.png")


if __name__ == "__main__":
    main()
