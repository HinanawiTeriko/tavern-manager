from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "mira_stall_encounter" / "mira_stall_encounter_source_v1.png"
SOURCE = ROOT / "assets" / "source" / "encounters" / "mira_stall"
NATIVE = SOURCE / "mira_stall_bg_native.png"
RUNTIME = ROOT / "assets" / "textures" / "encounters" / "mira_stall" / "mira_stall_bg.png"
MANIFEST = SOURCE / "mira_stall_encounter_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "mira_stall_encounter_contact_sheet.png"
NATIVE_SIZE = (320, 180)
RUNTIME_SIZE = (1280, 720)
SCALE = 4


def quantize(image: Image.Image, colors: int) -> Image.Image:
    return image.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")


def normalize_reference(reference: Image.Image) -> Image.Image:
    fitted = ImageOps.fit(reference.convert("RGB"), NATIVE_SIZE, Image.Resampling.LANCZOS, centering=(0.5, 0.5))
    sharpened = fitted.filter(ImageFilter.UnsharpMask(radius=1, percent=165, threshold=2))
    contrast = ImageEnhance.Contrast(sharpened).enhance(1.12)
    color = ImageEnhance.Color(contrast).enhance(0.84)
    balanced = ImageEnhance.Brightness(color).enhance(0.76)
    native = quantize(balanced, 72)

    pixels = native.load()
    for y in range(native.height):
        for x in range(native.width):
            r, g, b, a = pixels[x, y]
            if y > 138:
                r = int(r * 0.62)
                g = int(g * 0.66)
                b = int(b * 0.70)
            elif y < 18:
                r = int(r * 0.80)
                g = int(g * 0.84)
                b = int(b * 0.90)

            if r > 132 and g > 58 and b < 78:
                r = min(196, r)
                g = min(124, g)
                b = min(72, b)
            else:
                r = min(r, 142)
                g = min(g, 138)
                b = min(b, 134)
            pixels[x, y] = (max(4, r), max(5, g), max(6, b), a)
    return quantize(native, 88)


def save_nearest(native: Image.Image) -> Image.Image:
    NATIVE.parent.mkdir(parents=True, exist_ok=True)
    RUNTIME.parent.mkdir(parents=True, exist_ok=True)
    native.save(NATIVE)
    runtime = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
    runtime.save(RUNTIME)
    return runtime


def write_manifest() -> None:
    manifest = {
        "id": "mira_stall_encounter_background",
        "source": "art_sources/generated_raw/mira_stall_encounter/mira_stall_encounter_source_v1.png",
        "native": "assets/source/encounters/mira_stall/mira_stall_bg_native.png",
        "runtime": "assets/textures/encounters/mira_stall/mira_stall_bg.png",
        "native_size": list(NATIVE_SIZE),
        "runtime_size": list(RUNTIME_SIZE),
        "scale": SCALE,
        "safe_area": [0, 0, NATIVE_SIZE[0], NATIVE_SIZE[1]],
        "source_fit": {"method": "ImageOps.fit", "centering": [0.5, 0.5]},
        "pipeline_note": "Generated Mira stall source normalized only; no procedural geometry is authored by the exporter.",
        "intended_godot_use": "Mira stall automatic encounter background behind the existing DialogueManager balloon",
    }
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def make_contact_sheet(reference: Image.Image, native: Image.Image, runtime: Image.Image) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (720, 620), (10, 12, 13, 255))
    ref_preview = ImageOps.contain(reference.convert("RGBA"), (640, 220), Image.Resampling.LANCZOS)
    native_preview = native.resize((640, 360), Image.Resampling.NEAREST)
    runtime_preview = runtime.resize((240, 135), Image.Resampling.NEAREST)

    sheet.alpha_composite(ref_preview, (40, 24))
    sheet.alpha_composite(native_preview, (40, 240))
    sheet.alpha_composite(runtime_preview, (440, 72))
    sheet.convert("RGB").save(CONTACT_SHEET)


def main() -> None:
    if not RAW_SOURCE.exists():
        raise FileNotFoundError(f"{RAW_SOURCE}: missing Mira stall generated source")
    reference = Image.open(RAW_SOURCE).convert("RGB")
    native = normalize_reference(reference)
    runtime = save_nearest(native)
    write_manifest()
    make_contact_sheet(reference, native, runtime)
    print("exported Mira stall encounter background: assets/textures/encounters/mira_stall/mira_stall_bg.png")
    print("contact sheet: docs/art/mira_stall_encounter_contact_sheet.png")


if __name__ == "__main__":
    main()
