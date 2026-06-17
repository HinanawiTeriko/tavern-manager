from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = ROOT / "art_sources" / "generated_raw" / "clean_table_inference"
RAW_REFERENCE = RAW_DIR / "clean_table_tabletop_reference_v1.png"
RAW_PROMPT = RAW_DIR / "clean_table_tabletop_prompt_v1.txt"
SOURCE = ROOT / "assets" / "source" / "ui" / "clean_table_inference"
RUNTIME = ROOT / "assets" / "textures" / "ui" / "clean_table_inference"
CONTACT_SHEET = ROOT / "docs" / "art" / "clean_table_tabletop_contact_sheet.png"
MANIFEST = SOURCE / "clean_table_tabletop_manifest.json"
ASSET_ID = "clean_table_tabletop"
NATIVE_SIZE = (320, 180)
RUNTIME_SIZE = (1280, 720)
SCALE = 4


def load_reference() -> Image.Image:
    if not RAW_REFERENCE.exists():
        raise FileNotFoundError(f"missing raw tabletop reference: {RAW_REFERENCE}")
    if not RAW_PROMPT.exists():
        raise FileNotFoundError(f"missing tabletop prompt record: {RAW_PROMPT}")
    with Image.open(RAW_REFERENCE) as image:
        return image.convert("RGBA")


def quantize_rgba(image: Image.Image, colors: int = 36) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    rgb = Image.new("RGB", rgba.size, (0, 0, 0))
    rgb.paste(rgba.convert("RGB"), mask=alpha)
    quantized = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGBA")
    quantized.putalpha(alpha)
    return quantized


def make_native(reference: Image.Image) -> Image.Image:
    fitted = ImageOps.fit(reference, NATIVE_SIZE, method=Image.Resampling.BOX, centering=(0.5, 0.5))
    return quantize_rgba(fitted, 36)


def make_runtime(native: Image.Image) -> Image.Image:
    return native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)


def write_manifest() -> None:
    manifest = {
        "id": "clean_table_tabletop_background",
        "scale": SCALE,
        "source": "art_sources/generated_raw/clean_table_inference/clean_table_tabletop_reference_v1.png",
        "prompt": "art_sources/generated_raw/clean_table_inference/clean_table_tabletop_prompt_v1.txt",
        "assets": {
            ASSET_ID: {
                "id": ASSET_ID,
                "source_file": "art_sources/generated_raw/clean_table_inference/clean_table_tabletop_reference_v1.png",
                "prompt": "art_sources/generated_raw/clean_table_inference/clean_table_tabletop_prompt_v1.txt",
                "native_file": "assets/source/ui/clean_table_inference/clean_table_tabletop_native.png",
                "output_file": "assets/textures/ui/clean_table_inference/clean_table_tabletop.png",
                "native_size": list(NATIVE_SIZE),
                "size": list(RUNTIME_SIZE),
                "safe_area": [0, 0, RUNTIME_SIZE[0], RUNTIME_SIZE[1]],
                "nine_slice_margins": [0, 0, 0, 0],
                "intended_godot_use": "CleanTableInferenceScreen full-screen background candidate; not runtime-wired until accepted.",
            }
        },
    }
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def make_contact_sheet(reference: Image.Image, native: Image.Image, runtime: Image.Image) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (1280, 760), (14, 16, 16, 255))
    raw_preview = ImageOps.contain(reference, (600, 338), Image.Resampling.LANCZOS)
    native_preview = native.resize((640, 360), Image.Resampling.NEAREST)
    runtime_preview = runtime.resize((600, 338), Image.Resampling.NEAREST)
    sheet.alpha_composite(raw_preview, (24, 24))
    sheet.alpha_composite(native_preview, (624, 24))
    sheet.alpha_composite(runtime_preview, (340, 398))
    sheet.save(CONTACT_SHEET)


def validate(reference: Image.Image, native: Image.Image, runtime: Image.Image) -> None:
    if reference.width < reference.height:
        raise ValueError("tabletop source must be landscape")
    if native.size != NATIVE_SIZE:
        raise ValueError(f"{ASSET_ID}: wrong native size {native.size}")
    if runtime.size != RUNTIME_SIZE:
        raise ValueError(f"{ASSET_ID}: wrong runtime size {runtime.size}")
    expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
    if runtime.mode != expected.mode or runtime.tobytes() != expected.tobytes():
        raise ValueError(f"{ASSET_ID}: runtime is not an exact nearest-neighbor export")
    colors = native.convert("RGB").getcolors(maxcolors=1024)
    if colors is None or len(colors) > 96:
        raise ValueError(f"{ASSET_ID}: native palette is too broad for this background")


def main() -> None:
    reference = load_reference()
    native = make_native(reference)
    runtime = make_runtime(native)
    validate(reference, native, runtime)
    SOURCE.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    native.save(SOURCE / "clean_table_tabletop_native.png")
    runtime.save(RUNTIME / "clean_table_tabletop.png")
    write_manifest()
    make_contact_sheet(reference, native, runtime)
    print(f"{ASSET_ID}: {reference.size} -> {NATIVE_SIZE} -> {RUNTIME_SIZE}")


if __name__ == "__main__":
    main()
