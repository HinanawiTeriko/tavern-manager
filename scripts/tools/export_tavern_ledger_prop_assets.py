from __future__ import annotations

from collections import Counter
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "tavern_ledger" / "ledger_prop_reference_v2.png"
PROMPT = ROOT / "art_sources" / "generated_raw" / "tavern_ledger" / "ledger_prop_prompt_v2.txt"
MANIFEST = ROOT / "assets" / "source" / "tavern" / "props" / "tavern_ledger_prop_manifest.json"
NATIVE = ROOT / "assets" / "source" / "tavern" / "props" / "ledger_native.png"
RUNTIME = ROOT / "assets" / "textures" / "tavern" / "props" / "ledger.png"
CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_ledger_prop_contact_sheet.png"
NATIVE_SIZE = (40, 28)
SOURCE_RECT = (96, 140, 1458, 862)
SCALE = 4
CHROMA_KEY = "#ff00ff"
OUTLINE = (18, 13, 10, 255)


def chroma_key_from_border(image: Image.Image) -> tuple[int, int, int]:
    rgba = image.convert("RGBA")
    samples: list[tuple[int, int, int]] = []
    for x in range(rgba.width):
        for y in (0, rgba.height - 1):
            r, g, b, a = rgba.getpixel((x, y))
            if a > 0:
                samples.append((r, g, b))
    for y in range(rgba.height):
        for x in (0, rgba.width - 1):
            r, g, b, a = rgba.getpixel((x, y))
            if a > 0:
                samples.append((r, g, b))
    if not samples:
        return (255, 0, 255)
    return Counter(samples).most_common(1)[0][0]


def remove_chroma(image: Image.Image, threshold: int = 88) -> Image.Image:
    rgba = image.convert("RGBA")
    key = chroma_key_from_border(rgba)
    max_distance_sq = threshold * threshold
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                pixels[x, y] = (0, 0, 0, 0)
                continue
            dr = r - key[0]
            dg = g - key[1]
            db = b - key[2]
            if dr * dr + dg * dg + db * db <= max_distance_sq:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (r, g, b, 255)
    return rgba


def quantize_visible(image: Image.Image, colors: int = 18) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    rgb = Image.new("RGB", rgba.size, (0, 0, 0))
    rgb.paste(rgba.convert("RGB"), mask=alpha)
    quantized = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    quantized.putalpha(alpha)
    return quantized


def harden_alpha(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if a < 58:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (r, g, b, 255)
    return rgba


def add_pixel_outline(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    outlined = rgba.copy()
    source = rgba.load()
    target = outlined.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            if source[x, y][3] > 0:
                continue
            touches = False
            for ny in range(max(0, y - 1), min(rgba.height, y + 2)):
                for nx in range(max(0, x - 1), min(rgba.width, x + 2)):
                    if source[nx, ny][3] > 0:
                        touches = True
                        break
                if touches:
                    break
            if touches:
                target[x, y] = OUTLINE
    return outlined


def normalize_native(reference: Image.Image) -> Image.Image:
    source_crop = reference.crop(SOURCE_RECT)
    cropped = remove_chroma(source_crop)
    fitted = ImageOps.contain(cropped, (NATIVE_SIZE[0] - 2, NATIVE_SIZE[1] - 2), Image.Resampling.LANCZOS)
    fitted = harden_alpha(quantize_visible(fitted))
    fitted = add_pixel_outline(fitted)
    native = Image.new("RGBA", NATIVE_SIZE, (0, 0, 0, 0))
    native.alpha_composite(fitted, ((NATIVE_SIZE[0] - fitted.width) // 2, (NATIVE_SIZE[1] - fitted.height) // 2))
    return native


def write_manifest() -> None:
    manifest = {
        "id": "tavern_ledger_prop",
        "source": "art_sources/generated_raw/tavern_ledger/ledger_prop_reference_v2.png",
        "prompt": "art_sources/generated_raw/tavern_ledger/ledger_prop_prompt_v2.txt",
        "source_rect": list(SOURCE_RECT),
        "native": "assets/source/tavern/props/ledger_native.png",
        "runtime": "assets/textures/tavern/props/ledger.png",
        "native_size": list(NATIVE_SIZE),
        "runtime_size": [NATIVE_SIZE[0] * SCALE, NATIVE_SIZE[1] * SCALE],
        "scale": SCALE,
        "chroma_key": CHROMA_KEY,
        "safe_area": [0, 0, NATIVE_SIZE[0], NATIVE_SIZE[1]],
        "intended_godot_use": "ReadableDeskItem ledger Sprite2D art on Tavern work surface",
    }
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def backed_preview(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    preview = ImageOps.contain(image.convert("RGBA"), size, Image.Resampling.NEAREST)
    backing = Image.new("RGBA", size, (32, 26, 20, 255))
    backing.alpha_composite(preview, ((size[0] - preview.width) // 2, (size[1] - preview.height) // 2))
    return backing


def make_contact_sheet(reference: Image.Image, native: Image.Image, runtime: Image.Image) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (720, 240), (18, 14, 11, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((20, 16), "Tavern ledger prop pipeline", fill=(220, 204, 176, 255))
    labels = [("generated source", 44), ("native 4x preview", 284), ("runtime", 500)]
    for label, x in labels:
        draw.text((x, 46), label, fill=(220, 204, 176, 255))
    sheet.alpha_composite(backed_preview(reference, (192, 144)), (44, 72))
    native_preview = native.resize((native.width * 4, native.height * 4), Image.Resampling.NEAREST)
    sheet.alpha_composite(backed_preview(native_preview, (160, 112)), (284, 88))
    sheet.alpha_composite(backed_preview(runtime, (160, 112)), (500, 88))
    sheet.convert("RGB").save(CONTACT_SHEET)


def main() -> None:
    if not RAW_SOURCE.exists():
        raise FileNotFoundError(f"missing generated ledger reference: {RAW_SOURCE}")
    if not PROMPT.exists():
        raise FileNotFoundError(f"missing ledger prompt record: {PROMPT}")
    reference = Image.open(RAW_SOURCE).convert("RGBA")
    native = normalize_native(reference)
    runtime = native.resize((NATIVE_SIZE[0] * SCALE, NATIVE_SIZE[1] * SCALE), Image.Resampling.NEAREST)
    NATIVE.parent.mkdir(parents=True, exist_ok=True)
    RUNTIME.parent.mkdir(parents=True, exist_ok=True)
    native.save(NATIVE)
    runtime.save(RUNTIME)
    write_manifest()
    make_contact_sheet(reference, native, runtime)
    print("exported Tavern ledger prop: assets/textures/tavern/props/ledger.png")
    print("contact sheet: docs/art/tavern_ledger_prop_contact_sheet.png")


if __name__ == "__main__":
    main()
