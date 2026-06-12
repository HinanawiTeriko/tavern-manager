from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "toby_contract_document" / "toby_contract_document_source_v1.png"
SOURCE_DIR = ROOT / "assets" / "source" / "tavern" / "documents"
RUNTIME_DIR = ROOT / "assets" / "textures" / "tavern" / "documents"
MANIFEST_PATH = SOURCE_DIR / "toby_contract_document_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "toby_contract_document_contact_sheet.png"
LEDGER_BACKDROP = ROOT / "assets" / "textures" / "ledger" / "ui" / "ledger_overlay_backdrop.png"

SOURCE_RECT = [0, 0, 1499, 1049]
NATIVE_SIZE = (200, 140)
RUNTIME_SIZE = (800, 560)
SCALE = 4
COLOR_LIMIT = 64
SAFE_AREA = [48, 26, 152, 98]


def normalize_source(source: Image.Image) -> Image.Image:
    crop = source.crop(tuple(SOURCE_RECT)).convert("RGB")
    fitted = ImageOps.fit(crop, NATIVE_SIZE, method=Image.Resampling.BOX, centering=(0.5, 0.5))
    quantized = fitted.quantize(colors=COLOR_LIMIT, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    return quantized


def save_exports(native: Image.Image) -> Image.Image:
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    native_path = SOURCE_DIR / "toby_contract_document_native.png"
    runtime_path = RUNTIME_DIR / "toby_contract_document.png"
    native.save(native_path)
    runtime = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
    runtime.save(runtime_path)
    return runtime


def write_manifest() -> None:
    manifest = {
        "id": "toby_contract_document_art",
        "style_profile": "dark_teal_amber_pixel_document_v1",
        "source": RAW_SOURCE.relative_to(ROOT).as_posix(),
        "source_rect": SOURCE_RECT,
        "native": (SOURCE_DIR / "toby_contract_document_native.png").relative_to(ROOT).as_posix(),
        "runtime": (RUNTIME_DIR / "toby_contract_document.png").relative_to(ROOT).as_posix(),
        "native_size": list(NATIVE_SIZE),
        "runtime_size": list(RUNTIME_SIZE),
        "safe_area": SAFE_AREA,
        "scale": SCALE,
        "color_limit": COLOR_LIMIT,
        "intended_godot_use": "DocumentOverlay special art layer for the completed Toby contract handoff",
        "document_notes": [
            "completed toby commission",
            "assembled torn fragments",
            "dynamic text rendered by Godot Label, not baked into image",
            "runtime texture is exact nearest-neighbor 4x export from native pixel source",
        ],
    }
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def make_contact_sheet(source: Image.Image, native: Image.Image, runtime: Image.Image) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    out = Image.new("RGBA", (1160, 560), (18, 14, 11, 255))
    draw = ImageDraw.Draw(out)
    draw.text((20, 18), "Toby completed contract document art pipeline", fill=(222, 204, 176, 255))
    draw.text((20, 44), "AI source -> native 200x140 -> runtime 800x560 exact nearest", fill=(180, 168, 144, 255))

    source_preview = ImageOps.contain(source.convert("RGBA"), (320, 230), Image.Resampling.LANCZOS)
    out.alpha_composite(source_preview, (24, 86))
    draw.text((24, 330), "AI source preview", fill=(180, 168, 144, 255))

    native_preview = native.resize((NATIVE_SIZE[0] * 2, NATIVE_SIZE[1] * 2), Image.Resampling.NEAREST)
    out.alpha_composite(native_preview, (390, 84))
    sx0, sy0, sx1, sy1 = SAFE_AREA
    draw.rectangle(
        (
            390 + sx0 * 2,
            84 + sy0 * 2,
            390 + sx1 * 2,
            84 + sy1 * 2,
        ),
        outline=(214, 160, 76, 255),
        width=2,
    )
    draw.text((390, 382), "native 2x preview + text safe area", fill=(180, 168, 144, 255))

    if LEDGER_BACKDROP.exists():
        ledger = Image.open(LEDGER_BACKDROP).convert("RGBA")
    else:
        ledger = Image.new("RGBA", (1280, 720), (10, 28, 30, 255))
    scene = ImageOps.contain(ledger, (420, 236), Image.Resampling.NEAREST)
    scene_base = Image.new("RGBA", (420, 236), (10, 28, 30, 255))
    scene_base.alpha_composite(scene, ((420 - scene.width) // 2, (236 - scene.height) // 2))
    doc_preview = ImageOps.contain(runtime, (262, 184), Image.Resampling.NEAREST)
    scene_base.alpha_composite(doc_preview, ((420 - doc_preview.width) // 2, 24))
    out.alpha_composite(scene_base, (720, 84))
    draw.text((720, 334), "runtime overlay context preview", fill=(180, 168, 144, 255))
    out.convert("RGB").save(CONTACT_SHEET)


def main() -> None:
    if not RAW_SOURCE.exists():
        raise FileNotFoundError(f"missing Toby contract document source: {RAW_SOURCE}")
    source = Image.open(RAW_SOURCE).convert("RGBA")
    native = normalize_source(source)
    runtime = save_exports(native)
    write_manifest()
    make_contact_sheet(source, native, runtime)
    print("exported Toby completed contract document art")
    print("runtime: assets/textures/tavern/documents/toby_contract_document.png")
    print("contact sheet: docs/art/toby_contract_document_contact_sheet.png")


if __name__ == "__main__":
    main()
