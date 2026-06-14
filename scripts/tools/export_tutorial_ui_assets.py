from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "source" / "tutorial_ui" / "tutorial_ui_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "tutorial_ui_contact_sheet.png"


def load_manifest() -> dict:
    with MANIFEST.open(encoding="utf-8") as handle:
        return json.load(handle)


def key_to_alpha(image: Image.Image, key: tuple[int, int, int]) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    kr, kg, kb = key
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if _is_key_pixel(r, g, b, kr, kg, kb):
                pixels[x, y] = (0, 0, 0, 0)
    return rgba


def _is_key_pixel(r: int, g: int, b: int, kr: int, kg: int, kb: int) -> bool:
    if abs(r - kr) <= 34 and abs(g - kg) <= 34 and abs(b - kb) <= 34:
        return True
    return _is_magenta_key_fringe(r, g, b)


def _is_magenta_key_fringe(r: int, g: int, b: int) -> bool:
    return r > 48 and b > 48 and abs(r - b) < 80 and g < min(r, b) * 0.58


def clean_key_pixels(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if a == 0 or _is_magenta_key_fringe(r, g, b):
                pixels[x, y] = (0, 0, 0, 0)
    return rgba


def crunch_native(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    resized = clean_key_pixels(image).resize(size, Image.Resampling.BOX).convert("RGBA")
    alpha = resized.getchannel("A")
    alpha = alpha.point(lambda value: 0 if value < 128 else 255)
    resized.putalpha(alpha)
    resized = clean_key_pixels(resized)
    alpha = resized.getchannel("A")
    quantized = resized.convert("RGB").quantize(colors=48).convert("RGBA")
    quantized.putalpha(alpha)
    return clean_key_pixels(quantized)


def validate_native(
    asset_id: str,
    image: Image.Image,
    size: tuple[int, int],
    min_visible_ratio: float,
) -> None:
    if image.size != size:
        raise ValueError(f"{asset_id}: native must be {size}, got {image.size}")
    alpha = image.convert("RGBA").getchannel("A")
    low, high = alpha.getextrema()
    if low != 0 or high == 0:
        raise ValueError(f"{asset_id}: native must contain transparent and visible pixels")
    visible = sum(alpha.histogram()[1:])
    if visible < image.width * image.height * min_visible_ratio:
        raise ValueError(f"{asset_id}: native is too sparse ({visible} visible pixels)")


def nearest_runtime(native: Image.Image, scale: int) -> Image.Image:
    return native.resize(
        (native.width * scale, native.height * scale),
        Image.Resampling.NEAREST,
    )


def paste_on_checkerboard(sheet: Image.Image, image: Image.Image, xy: tuple[int, int]) -> None:
    x0, y0 = xy
    tile = 8
    for y in range(y0, y0 + image.height):
        for x in range(x0, x0 + image.width):
            shade = 38 if ((x // tile) + (y // tile)) % 2 == 0 else 54
            sheet.putpixel((x, y), (shade, shade, shade, 255))
    sheet.alpha_composite(image.convert("RGBA"), xy)


def build_contact_sheet(outputs: dict[str, tuple[Image.Image, Image.Image]]) -> Image.Image:
    panel_native, panel_runtime = outputs["tutorial_panel"]
    frame_native, frame_runtime = outputs["tutorial_highlight_frame"]
    native_preview_width = max(panel_native.width * 2, frame_native.width * 2)
    runtime_width = max(panel_runtime.width, frame_runtime.width)
    sheet = Image.new(
        "RGBA",
        (runtime_width + native_preview_width + 144, 448),
        (20, 24, 24, 255),
    )
    paste_on_checkerboard(sheet, panel_runtime, (32, 32))
    paste_on_checkerboard(sheet, frame_runtime, (32, 256))
    paste_on_checkerboard(sheet, panel_native.resize((panel_native.width * 2, panel_native.height * 2), Image.Resampling.NEAREST), (panel_runtime.width + 80, 32))
    paste_on_checkerboard(sheet, frame_native.resize((frame_native.width * 2, frame_native.height * 2), Image.Resampling.NEAREST), (panel_runtime.width + 80, 180))
    return sheet


def main() -> None:
    manifest = load_manifest()
    source = ROOT / manifest["source_file"]
    key = tuple(int(channel) for channel in manifest["key_color"])
    scale = int(manifest["runtime_scale"])
    with Image.open(source) as source_image:
        keyed_source = key_to_alpha(source_image, key)

    outputs: dict[str, tuple[Image.Image, Image.Image]] = {}
    for asset in manifest["assets"]:
        asset_id = asset["id"]
        x, y, w, h = [int(value) for value in asset["source_rect"]]
        native_size = tuple(int(value) for value in asset["native_size"])
        native = crunch_native(keyed_source.crop((x, y, x + w, y + h)), native_size)
        min_visible_ratio = float(asset.get("min_visible_ratio", 0.18))
        validate_native(asset_id, native, native_size, min_visible_ratio)
        runtime = nearest_runtime(native, scale)

        native_path = ROOT / asset["native_file"]
        runtime_path = ROOT / asset["output_file"]
        native_path.parent.mkdir(parents=True, exist_ok=True)
        runtime_path.parent.mkdir(parents=True, exist_ok=True)
        native.save(native_path)
        runtime.save(runtime_path)
        outputs[asset_id] = (native, runtime)
        print(f"{asset_id}: {native.size} -> {runtime.size}")

    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    build_contact_sheet(outputs).convert("RGB").save(CONTACT_SHEET)
    print(f"contact_sheet: {CONTACT_SHEET}")


if __name__ == "__main__":
    main()
