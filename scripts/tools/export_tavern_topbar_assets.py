from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "tavern_topbar" / "tavern_topbar_reference_v1.png"
SOURCE_DIR = ROOT / "assets" / "source" / "tavern" / "topbar"
RUNTIME_PATH = ROOT / "assets" / "textures" / "ui" / "bar_top_panel.png"
MANIFEST_PATH = SOURCE_DIR / "tavern_topbar_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_topbar_contact_sheet.png"

NATIVE_SIZE = (320, 12)
RUNTIME_SIZE = (1280, 48)
SCALE = 4
CROP_RECT = [24, 300, 2024, 450]
SAFE_AREA = [8, 1, 312, 11]


def quantize(image: Image.Image, colors: int = 28) -> Image.Image:
    return image.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")


def normalize_topbar(reference: Image.Image) -> Image.Image:
    crop = reference.crop(tuple(CROP_RECT)).convert("RGB")
    resized = crop.resize(NATIVE_SIZE, Image.Resampling.LANCZOS)
    contrast = ImageEnhance.Contrast(resized).enhance(1.2)
    color = ImageEnhance.Color(contrast).enhance(1.05)
    sharp = ImageEnhance.Sharpness(color).enhance(1.7)
    native = quantize(sharp)
    native.putalpha(255)
    return native


def write_manifest() -> None:
    manifest = {
        "id": "tavern_topbar",
        "source": "art_sources/generated_raw/tavern_topbar/tavern_topbar_reference_v1.png",
        "prompt": "art_sources/generated_raw/tavern_topbar/tavern_topbar_reference_v1_prompt.txt",
        "crop_rect": CROP_RECT,
        "native": "assets/source/tavern/topbar/bar_top_panel_native.png",
        "runtime": "assets/textures/ui/bar_top_panel.png",
        "native_size": list(NATIVE_SIZE),
        "runtime_size": list(RUNTIME_SIZE),
        "scale": SCALE,
        "safe_area": SAFE_AREA,
        "intended_godot_use": "Tavern TopPanelBg long pixel UI strip",
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def make_contact_sheet(reference: Image.Image, native: Image.Image, runtime: Image.Image) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (900, 280), (18, 14, 11, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((16, 14), "Tavern topbar pipeline", fill=(220, 204, 176, 255))
    draw.text((16, 42), "generated source with explicit crop", fill=(220, 204, 176, 255))
    source_preview = reference.resize((640, 240), Image.Resampling.LANCZOS).convert("RGBA")
    draw.rectangle(
        (
            int(CROP_RECT[0] * 640 / reference.width) + 16,
            int(CROP_RECT[1] * 240 / reference.height) + 56,
            int(CROP_RECT[2] * 640 / reference.width) + 16,
            int(CROP_RECT[3] * 240 / reference.height) + 56,
        ),
        outline=(255, 188, 92, 255),
        width=1,
    )
    sheet.alpha_composite(source_preview, (16, 56))

    draw.text((684, 42), "native 2x", fill=(220, 204, 176, 255))
    native_preview = native.resize((NATIVE_SIZE[0] * 2, NATIVE_SIZE[1] * 2), Image.Resampling.NEAREST)
    sheet.alpha_composite(native_preview, (684, 64))
    draw.text((684, 104), "runtime context", fill=(220, 204, 176, 255))
    runtime_context = Image.new("RGBA", (192, 48), (9, 12, 13, 255))
    runtime_context.alpha_composite(runtime.crop((0, 0, 192, 48)), (0, 0))
    sheet.alpha_composite(runtime_context, (684, 126))

    sheet.convert("RGB").save(CONTACT_SHEET)


def main() -> None:
    if not RAW_SOURCE.exists():
        raise FileNotFoundError(f"missing Tavern topbar source: {RAW_SOURCE}")
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    RUNTIME_PATH.parent.mkdir(parents=True, exist_ok=True)
    reference = Image.open(RAW_SOURCE).convert("RGB")
    native = normalize_topbar(reference)
    native_path = SOURCE_DIR / "bar_top_panel_native.png"
    native.save(native_path)
    runtime = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
    runtime.save(RUNTIME_PATH)
    write_manifest()
    make_contact_sheet(reference, native, runtime)
    print("exported Tavern topbar: assets/textures/ui/bar_top_panel.png")
    print("contact sheet: docs/art/tavern_topbar_contact_sheet.png")


if __name__ == "__main__":
    main()
