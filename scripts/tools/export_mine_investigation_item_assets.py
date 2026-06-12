from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageEnhance, ImageOps


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "investigation" / "mine_items"
MANIFEST = SOURCE / "mine_item_art_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "mine_investigation_item_art_contact_sheet.png"
SCENE_PREVIEW = ROOT / "docs" / "art" / "mine_investigation_item_scene_preview.png"
BACKGROUND_RUNTIME = ROOT / "assets" / "ui" / "generated" / "investigation" / "mine_background" / "mine_background.png"
SCENE_POSITIONS = {
    "broken_arrow": (260, 470),
    "dented_shield": (380, 460),
    "lost_boot": (500, 475),
    "rubble": (980, 455),
    "torn_backpack": (980, 470),
    "coins": (950, 495),
    "warhammer_token": (990, 495),
    "bloodied_paper": (1030, 480),
}


def is_chroma_key_pixel(red: int, green: int, blue: int, background_rgb: tuple[int, int, int], tolerance: int) -> bool:
    br, bg, bb = background_rgb
    distance = abs(red - br) + abs(green - bg) + abs(blue - bb)
    if distance <= tolerance:
        return True
    return red >= 10 and blue >= 10 and blue >= red * 0.70 and red >= blue * 0.50 and green <= min(red, blue) * 0.45


def load_manifest() -> dict[str, Any]:
    if not MANIFEST.exists():
        raise FileNotFoundError(f"missing manifest: {MANIFEST}")
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def remove_chroma_background(image: Image.Image, background_rgb: tuple[int, int, int], tolerance: int) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if a == 0 or is_chroma_key_pixel(r, g, b, background_rgb, tolerance):
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
    quantized.putalpha(alpha.point(lambda value: 255 if value >= 48 else 0))
    pixels = quantized.load()
    for y in range(quantized.height):
        for x in range(quantized.width):
            r, g, b, a = pixels[x, y]
            if a == 0 or is_chroma_key_pixel(r, g, b, (255, 0, 255), 58):
                pixels[x, y] = (0, 0, 0, 0)
    return quantized


def apply_mine_scene_grade(image: Image.Image) -> Image.Image:
    graded = ImageEnhance.Contrast(image.convert("RGBA")).enhance(0.88)
    pixels = graded.load()
    for y in range(graded.height):
        for x in range(graded.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                pixels[x, y] = (0, 0, 0, 0)
                continue
            # Pull props toward the cold mine palette, then keep a small warm left-side lantern bias.
            red = int(red * 0.58 + 10)
            green = int(green * 0.62 + 16)
            blue = int(blue * 0.70 + 24)
            if x < graded.width * 0.42:
                red += 16
                green += 7
                blue -= 4
            if y > graded.height * 0.70:
                red = int(red * 0.82)
                green = int(green * 0.86)
                blue = int(blue * 0.90)
            maximum = max(red, green, blue)
            if maximum > 178:
                scale = 178.0 / maximum
                red = int(red * scale)
                green = int(green * scale)
                blue = int(blue * scale)
            pixels[x, y] = (max(0, red), max(0, green), max(0, blue), alpha)
    return graded


def fit_to_native(crop: Image.Image, native_size: tuple[int, int], background_rgb: tuple[int, int, int], tolerance: int) -> Image.Image:
    clean = remove_chroma_background(crop, background_rgb, tolerance)
    alpha_box = clean.getchannel("A").getbbox()
    if alpha_box is None:
        raise ValueError("crop has no visible pixels after chroma cleanup")
    trimmed = clean.crop(alpha_box)
    fitted = ImageOps.contain(trimmed, native_size, Image.Resampling.LANCZOS)
    native = Image.new("RGBA", native_size, (0, 0, 0, 0))
    x = (native.width - fitted.width) // 2
    y = (native.height - fitted.height) // 2
    native.alpha_composite(fitted, (x, y))
    native = apply_mine_scene_grade(native)
    return quantize_visible(native, 14)


def validate_native(item_id: str, native: Image.Image, native_size: tuple[int, int]) -> None:
    if native.size != native_size:
        raise ValueError(f"{item_id}: native size {native.size} != {native_size}")
    alpha = native.getchannel("A")
    alpha_min, alpha_max = alpha.getextrema()
    if alpha_min != 0 or alpha_max == 0:
        raise ValueError(f"{item_id}: native needs transparent and visible pixels")
    if alpha.getbbox() is None:
        raise ValueError(f"{item_id}: native alpha bbox is empty")


def export_item(reference: Image.Image, item: dict[str, Any], background_rgb: tuple[int, int, int], tolerance: int, scale: int) -> tuple[Image.Image, Image.Image]:
    source = reference
    item_source = item.get("source")
    if item_source:
        source_path = ROOT / item_source
        if not source_path.exists():
            raise FileNotFoundError(f"missing source image for {item['id']}: {source_path}")
    x, y, width, height = item["source_rect"]
    crop = source.crop((x, y, x + width, y + height))
    native_size = tuple(item["native_size"])
    runtime_size = tuple(item["runtime_size"])
    native = fit_to_native(crop, native_size, background_rgb, tolerance)
    validate_native(item["id"], native, native_size)
    runtime = native.resize((native.width * scale, native.height * scale), Image.Resampling.NEAREST)
    if runtime.size != runtime_size:
        raise ValueError(f"{item['id']}: runtime size {runtime.size} != {runtime_size}")
    expected = native.resize(runtime.size, Image.Resampling.NEAREST)
    if runtime.tobytes() != expected.tobytes():
        raise ValueError(f"{item['id']}: runtime is not exact nearest-neighbor output")
    return native, runtime


def make_contact_sheet(reference: Image.Image, outputs: list[tuple[dict[str, Any], Image.Image, Image.Image]]) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    cell_width = 232
    cell_height = 260
    sheet = Image.new("RGBA", (cell_width * 4, 96 + cell_height * 2), (18, 14, 12, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((18, 16), "Mine investigation AI item art pipeline", fill=(226, 210, 178, 255))
    draw.text((18, 42), "top: native 4x preview / bottom: runtime preview source parity", fill=(169, 151, 124, 255))
    for index, (item, native, runtime) in enumerate(outputs):
        column = index % 4
        row = index // 4
        origin_x = column * cell_width + 14
        origin_y = 78 + row * cell_height
        draw.text((origin_x, origin_y), item["id"], fill=(226, 210, 178, 255))
        native_preview = native.resize((native.width * 4, native.height * 4), Image.Resampling.NEAREST)
        native_preview = ImageOps.contain(native_preview, (180, 70), Image.Resampling.NEAREST)
        runtime_preview = ImageOps.contain(runtime, (180, 70), Image.Resampling.NEAREST)
        sheet.alpha_composite(native_preview, (origin_x, origin_y + 24))
        sheet.alpha_composite(runtime_preview, (origin_x, origin_y + 104))
    sheet.convert("RGB").save(CONTACT_SHEET)


def make_scene_preview(outputs: list[tuple[dict[str, Any], Image.Image, Image.Image]]) -> None:
    if not BACKGROUND_RUNTIME.exists():
        return
    preview = Image.open(BACKGROUND_RUNTIME).convert("RGBA")
    for item, _native, runtime in outputs:
        item_id = item["id"]
        if item_id not in SCENE_POSITIONS:
            continue
        x, y = SCENE_POSITIONS[item_id]
        preview.alpha_composite(runtime, (int(x - runtime.width * 0.5), int(y - runtime.height * 0.5)))
    SCENE_PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    preview.save(SCENE_PREVIEW)


def main() -> None:
    manifest = load_manifest()
    scale = int(manifest["scale"])
    background_rgb = tuple(manifest["background_rgb"])
    tolerance = int(manifest["background_tolerance"])
    reference_path = ROOT / manifest["reference"]
    if not reference_path.exists():
        raise FileNotFoundError(f"missing reference sheet: {reference_path}")
    reference = Image.open(reference_path).convert("RGBA")

    outputs: list[tuple[dict[str, Any], Image.Image, Image.Image]] = []
    for item in manifest["items"]:
        native, runtime = export_item(reference, item, background_rgb, tolerance, scale)
        native_path = ROOT / item["native"]
        runtime_path = ROOT / item["runtime"]
        native_path.parent.mkdir(parents=True, exist_ok=True)
        runtime_path.parent.mkdir(parents=True, exist_ok=True)
        native.save(native_path)
        runtime.save(runtime_path)
        outputs.append((item, native, runtime))
        print(f"{item['id']}: {native.size} -> {runtime.size}")
    make_contact_sheet(reference, outputs)
    make_scene_preview(outputs)
    print(f"contact sheet: {CONTACT_SHEET.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
