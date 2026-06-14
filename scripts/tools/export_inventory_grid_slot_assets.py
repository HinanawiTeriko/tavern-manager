from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "source" / "ui" / "inventory_grid_slot" / "inventory_grid_slot_manifest.json"


def load_manifest() -> dict:
    with MANIFEST.open(encoding="utf-8") as handle:
        return json.load(handle)


def key_to_alpha(image: Image.Image, key_color: tuple[int, int, int]) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    kr, kg, kb = key_color
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if _is_key_pixel(r, g, b, kr, kg, kb):
                pixels[x, y] = (0, 0, 0, 0)
    return rgba


def _is_key_pixel(r: int, g: int, b: int, kr: int, kg: int, kb: int) -> bool:
    if abs(r - kr) <= 24 and abs(g - kg) <= 24 and abs(b - kb) <= 24:
        return True
    return r > 170 and b > 170 and g < 70


def pixelize_native(image: Image.Image, size: tuple[int, int], key_color: tuple[int, int, int]) -> Image.Image:
    native = key_to_alpha(image, key_color).resize(size, Image.Resampling.BOX)
    alpha = native.getchannel("A")
    alpha = alpha.point(lambda value: 0 if value < 96 else 255)
    indexed = native.convert("RGB").quantize(colors=48, method=Image.Quantize.MEDIANCUT)
    quantized = indexed.convert("RGBA")
    quantized.putalpha(alpha)
    return clear_source_black_background(quantized)


def clear_source_black_background(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if a > 0 and r < 8 and g < 8 and b < 8:
                pixels[x, y] = (0, 0, 0, 0)
    return rgba


def nearest_runtime(native: Image.Image, scale: int) -> Image.Image:
    return native.resize((native.width * scale, native.height * scale), Image.Resampling.NEAREST)


def paste_preview(sheet: Image.Image, image: Image.Image, xy: tuple[int, int]) -> None:
    x0, y0 = xy
    tile = 8
    for y in range(y0, y0 + image.height):
        for x in range(x0, x0 + image.width):
            shade = 28 if ((x // tile) + (y // tile)) % 2 == 0 else 38
            sheet.putpixel((x, y), (shade, shade, shade, 255))
    sheet.alpha_composite(image.convert("RGBA"), xy)


def build_contact_sheet(outputs: dict[str, tuple[Image.Image, Image.Image]]) -> Image.Image:
    names = list(outputs.keys())
    cell_w = 192
    cell_h = 148
    sheet = Image.new("RGBA", (cell_w * len(names), cell_h), (18, 20, 20, 255))
    draw = ImageDraw.Draw(sheet)
    for index, name in enumerate(names):
        native, runtime = outputs[name]
        x = index * cell_w + 16
        paste_preview(sheet, runtime, (x, 18))
        paste_preview(
            sheet,
            native.resize((native.width * 2, native.height * 2), Image.Resampling.NEAREST),
            (x + 92, 18),
        )
        draw.text((x, 114), name, fill=(235, 198, 132, 255))
    return sheet


def main() -> None:
    manifest = load_manifest()
    key_color = tuple(int(channel) for channel in manifest["key_color"])
    scale = int(manifest["runtime_scale"])
    outputs: dict[str, tuple[Image.Image, Image.Image]] = {}
    for asset in manifest["assets"]:
        asset_id = asset["id"]
        source_path = ROOT / asset["source_file"]
        with Image.open(source_path) as source:
            native_size = tuple(int(value) for value in asset["native_size"])
            native = pixelize_native(source, native_size, key_color)
        runtime = nearest_runtime(native, scale)
        expected_runtime_size = tuple(int(value) for value in asset["runtime_size"])
        if runtime.size != expected_runtime_size:
            raise ValueError(f"{asset_id}: runtime size {runtime.size}, expected {expected_runtime_size}")

        native_path = ROOT / asset["native_file"]
        output_path = ROOT / asset["output_file"]
        native_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        native.save(native_path)
        runtime.save(output_path)
        outputs[asset_id] = (native, runtime)
        print(f"{asset_id}: {native.size} -> {runtime.size}")

    contact_path = ROOT / manifest["contact_sheet"]
    contact_path.parent.mkdir(parents=True, exist_ok=True)
    build_contact_sheet(outputs).convert("RGB").save(contact_path)
    print(f"contact_sheet: {contact_path}")


if __name__ == "__main__":
    main()
