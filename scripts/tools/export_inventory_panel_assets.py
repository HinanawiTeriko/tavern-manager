from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "source" / "ui" / "inventory_panel" / "inventory_panel_manifest.json"


def load_manifest() -> dict:
    with MANIFEST.open(encoding="utf-8") as handle:
        return json.load(handle)


def pixelize_native(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    native = image.convert("RGBA").resize(size, Image.Resampling.BOX)
    alpha = native.getchannel("A").point(lambda value: 0 if value < 12 else 255)
    indexed = native.convert("RGB").quantize(colors=72, method=Image.Quantize.MEDIANCUT)
    quantized = indexed.convert("RGBA")
    quantized.putalpha(alpha)
    return quantized


def nearest_runtime(native: Image.Image, scale: int) -> Image.Image:
    return native.resize((native.width * scale, native.height * scale), Image.Resampling.NEAREST)


def build_contact_sheet(native: Image.Image, runtime: Image.Image, manifest: dict) -> Image.Image:
    padding = 24
    label_h = 34
    sheet = Image.new("RGBA", (runtime.width + padding * 2, runtime.height + padding * 2 + label_h), (18, 20, 20, 255))
    sheet.alpha_composite(runtime.convert("RGBA"), (padding, padding))

    draw = ImageDraw.Draw(sheet)
    asset = manifest["asset"]
    safe = asset["safe_area"]
    margins = asset["nine_slice_margins"]
    sx, sy, sw, sh = safe
    draw.rectangle((padding + sx, padding + sy, padding + sx + sw, padding + sy + sh), outline=(255, 206, 96, 255), width=2)
    left, top, right, bottom = margins
    draw.line((padding + left, padding, padding + left, padding + runtime.height), fill=(92, 184, 188, 255), width=1)
    draw.line((padding + runtime.width - right, padding, padding + runtime.width - right, padding + runtime.height), fill=(92, 184, 188, 255), width=1)
    draw.line((padding, padding + top, padding + runtime.width, padding + top), fill=(92, 184, 188, 255), width=1)
    draw.line((padding, padding + runtime.height - bottom, padding + runtime.width, padding + runtime.height - bottom), fill=(92, 184, 188, 255), width=1)
    draw.text((padding, padding + runtime.height + 10), f"inventory_panel native {native.size} runtime {runtime.size}", fill=(235, 198, 132, 255))
    return sheet


def main() -> None:
    manifest = load_manifest()
    asset = manifest["asset"]
    scale = int(manifest["runtime_scale"])
    source_path = ROOT / asset["source_file"]
    with Image.open(source_path) as source:
        source_size = tuple(int(value) for value in asset["source_size"])
        if source.size != source_size:
            raise ValueError(f"{asset['id']}: source size {source.size}, expected {source_size}")
        native_size = tuple(int(value) for value in asset["native_size"])
        native = pixelize_native(source, native_size)

    runtime = nearest_runtime(native, scale)
    expected_runtime_size = tuple(int(value) for value in asset["runtime_size"])
    if runtime.size != expected_runtime_size:
        raise ValueError(f"{asset['id']}: runtime size {runtime.size}, expected {expected_runtime_size}")

    native_path = ROOT / asset["native_file"]
    output_path = ROOT / asset["output_file"]
    native_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    native.save(native_path)
    runtime.save(output_path)
    print(f"{asset['id']}: {native.size} -> {runtime.size}")

    contact_path = ROOT / manifest["contact_sheet"]
    contact_path.parent.mkdir(parents=True, exist_ok=True)
    build_contact_sheet(native, runtime, manifest).convert("RGB").save(contact_path)
    print(f"contact_sheet: {contact_path}")


if __name__ == "__main__":
    main()
