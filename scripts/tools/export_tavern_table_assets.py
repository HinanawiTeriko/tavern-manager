from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageOps


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art_sources" / "generated_raw" / "tavern_table" / "tabletop_reference_v1.png"
MANIFEST = ROOT / "assets" / "source" / "tavern" / "table" / "tabletop_manifest.json"
NATIVE = ROOT / "assets" / "source" / "tavern" / "table" / "tabletop_native.png"
RUNTIME = ROOT / "assets" / "textures" / "tavern" / "table" / "tabletop.png"
CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_table_contact_sheet.png"
NATIVE_SIZE = (320, 80)
RUNTIME_SIZE = (1280, 320)
SCALE = 4


def quantize_image(image: Image.Image, colors: int = 18) -> Image.Image:
    rgb = image.convert("RGB")
    return rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")


def normalize_tabletop(source: Image.Image) -> Image.Image:
    cropped = ImageOps.fit(source.convert("RGB"), NATIVE_SIZE, method=Image.Resampling.LANCZOS, centering=(0.5, 0.56))
    contrast = ImageEnhance.Contrast(cropped).enhance(1.18)
    color = ImageEnhance.Color(contrast).enhance(0.82)
    darkened = ImageEnhance.Brightness(color).enhance(0.68)
    native = quantize_image(darkened, 18)
    pixels = native.load()
    source_pixels = cropped.load()
    for y in range(native.height):
        for x in range(native.width):
            r, g, b, a = pixels[x, y]
            sr, sg, sb = source_pixels[x, y]
            r = min(150, max(18, r))
            g = min(104, max(14, g))
            b = min(80, max(10, b))
            if r < 70:
                b = min(80, max(b, int(r * 0.62)))
            if sr >= 60 and sr >= sb * 1.5 and sg >= 34:
                r = max(r, 96)
                g = max(g, 48)
                b = min(b, 36)
            if y < 4 or y > native.height - 6:
                r = max(16, int(r * 0.78))
                g = max(12, int(g * 0.78))
                b = max(10, int(b * 0.86))
            pixels[x, y] = (r, g, b, 255)
    return native


def save_manifest() -> None:
    manifest = {
        "id": "tavern_tabletop",
        "source": "art_sources/generated_raw/tavern_table/tabletop_reference_v1.png",
        "native": "assets/source/tavern/table/tabletop_native.png",
        "runtime": "assets/textures/tavern/table/tabletop.png",
        "native_size": list(NATIVE_SIZE),
        "runtime_size": list(RUNTIME_SIZE),
        "scale": SCALE,
        "safe_area": [0, 0, 320, 80],
        "intended_godot_use": "visual-only Tavern tabletop Sprite2D layer",
    }
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def make_contact_sheet(reference: Image.Image, native: Image.Image, runtime: Image.Image) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (720, 380), (18, 14, 11, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((20, 16), "Tavern tabletop art pipeline", fill=(220, 204, 176, 255))
    draw.text((20, 52), "reference", fill=(220, 204, 176, 255))
    draw.text((20, 178), "native 4x preview", fill=(220, 204, 176, 255))
    draw.text((20, 304), "runtime preview", fill=(220, 204, 176, 255))
    ref_preview = ImageOps.contain(reference.convert("RGBA"), (640, 96), Image.Resampling.LANCZOS)
    native_preview = native.resize((native.width * 4, native.height * 4), Image.Resampling.NEAREST)
    native_preview = ImageOps.contain(native_preview, (640, 96), Image.Resampling.NEAREST)
    runtime_preview = ImageOps.contain(runtime.convert("RGBA"), (640, 48), Image.Resampling.NEAREST)
    sheet.alpha_composite(ref_preview, (60, 76))
    sheet.alpha_composite(native_preview, (60, 202))
    sheet.alpha_composite(runtime_preview, (60, 328))
    sheet.convert("RGB").save(CONTACT_SHEET)


def main() -> None:
    if not SOURCE.exists():
        raise FileNotFoundError(f"missing tabletop reference: {SOURCE}")
    reference = Image.open(SOURCE).convert("RGBA")
    native = normalize_tabletop(reference)
    runtime = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
    NATIVE.parent.mkdir(parents=True, exist_ok=True)
    RUNTIME.parent.mkdir(parents=True, exist_ok=True)
    native.save(NATIVE)
    runtime.save(RUNTIME)
    save_manifest()
    make_contact_sheet(reference, native, runtime)
    print("exported tavern tabletop: assets/textures/tavern/table/tabletop.png")


if __name__ == "__main__":
    main()
