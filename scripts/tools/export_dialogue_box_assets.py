from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageEnhance, ImageOps


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "ui" / "dialogue_box"
MANIFEST = SOURCE / "dialogue_box_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "dialogue_box_contact_sheet.png"
SCENE_PREVIEW = ROOT / "docs" / "art" / "dialogue_box_scene_preview.png"


def load_manifest() -> dict[str, Any]:
    if not MANIFEST.exists():
        raise FileNotFoundError(f"missing manifest: {MANIFEST}")
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def is_chroma_key_pixel(red: int, green: int, blue: int, background_rgb: tuple[int, int, int], tolerance: int) -> bool:
    br, bg, bb = background_rgb
    distance = abs(red - br) + abs(green - bg) + abs(blue - bb)
    if distance <= tolerance:
        return True
    return red >= 12 and blue >= 12 and blue >= red * 0.70 and red >= blue * 0.50 and green <= min(red, blue) * 0.45


def remove_chroma_background(image: Image.Image, background_rgb: tuple[int, int, int], tolerance: int) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0 or is_chroma_key_pixel(red, green, blue, background_rgb, tolerance):
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (red, green, blue, 255)
    return rgba


def quantize_visible(image: Image.Image, colors: int = 22) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A").point(lambda value: 255 if value >= 44 else 0)
    rgb = Image.new("RGB", rgba.size, (0, 0, 0))
    rgb.paste(rgba.convert("RGB"), mask=alpha)
    quantized = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    quantized.putalpha(alpha)
    pixels = quantized.load()
    for y in range(quantized.height):
        for x in range(quantized.width):
            red, green, blue, alpha_value = pixels[x, y]
            if alpha_value == 0 or is_chroma_key_pixel(red, green, blue, (255, 0, 255), 58):
                pixels[x, y] = (0, 0, 0, 0)
    return quantized


def apply_dialogue_grade(image: Image.Image, item_id: str) -> Image.Image:
    graded = ImageEnhance.Contrast(image.convert("RGBA")).enhance(0.92)
    pixels = graded.load()
    for y in range(graded.height):
        for x in range(graded.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                pixels[x, y] = (0, 0, 0, 0)
                continue
            red = int(red * 0.76 + 6)
            green = int(green * 0.72 + 10)
            blue = int(blue * 0.76 + 14)
            if red > green * 1.18 and red > blue * 1.25:
                red = int(red * 1.08 + 6)
                green = int(green * 1.02 + 2)
                blue = int(blue * 0.88)
            elif blue >= red * 0.72:
                red = int(red * 0.80)
                green = int(green * 0.92 + 4)
                blue = int(blue * 1.05 + 4)
            if item_id.endswith("_hover"):
                red = int(red * 1.15 + 10)
                green = int(green * 1.09 + 6)
                blue = int(blue * 0.96)
            elif item_id.endswith("_pressed"):
                red = int(red * 0.72)
                green = int(green * 0.76)
                blue = int(blue * 0.82)
            maximum = max(red, green, blue)
            if maximum > 214:
                scale = 214.0 / maximum
                red = int(red * scale)
                green = int(green * scale)
                blue = int(blue * scale)
            pixels[x, y] = (max(0, red), max(0, green), max(0, blue), alpha)
    return graded


def fit_to_native(crop: Image.Image, item: dict[str, Any], background_rgb: tuple[int, int, int], tolerance: int) -> Image.Image:
    clean = remove_chroma_background(crop, background_rgb, tolerance)
    alpha_box = clean.getchannel("A").getbbox()
    if alpha_box is None:
        raise ValueError(f"{item['id']}: crop has no visible pixels after chroma cleanup")
    trimmed = clean.crop(alpha_box)
    native_size = tuple(item["native_size"])
    if item["id"] == "dialogue_progress_arrow":
        fitted = ImageOps.contain(trimmed, native_size, Image.Resampling.LANCZOS)
    else:
        fitted = trimmed.resize(native_size, Image.Resampling.LANCZOS)
    native = Image.new("RGBA", native_size, (0, 0, 0, 0))
    x = (native.width - fitted.width) // 2
    y = (native.height - fitted.height) // 2
    native.alpha_composite(fitted, (x, y))
    native = apply_dialogue_grade(native, item["id"])
    return quantize_visible(native, 22)


def export_item(reference: Image.Image, item: dict[str, Any], background_rgb: tuple[int, int, int], tolerance: int, scale: int) -> tuple[Image.Image, Image.Image]:
    source_path = ROOT / item["source"]
    if not source_path.exists():
        raise FileNotFoundError(f"missing source image for {item['id']}: {source_path}")
    x, y, width, height = item["source_rect"]
    crop = reference.crop((x, y, x + width, y + height))
    native = fit_to_native(crop, item, background_rgb, tolerance)
    expected_native_size = tuple(item["native_size"])
    if native.size != expected_native_size:
        raise ValueError(f"{item['id']}: native size {native.size} != {expected_native_size}")
    if native.getchannel("A").getbbox() is None:
        raise ValueError(f"{item['id']}: native output is empty")
    runtime = native.resize((native.width * scale, native.height * scale), Image.Resampling.NEAREST)
    if runtime.size != tuple(item["runtime_size"]):
        raise ValueError(f"{item['id']}: runtime size {runtime.size} != {tuple(item['runtime_size'])}")
    if runtime.tobytes() != native.resize(runtime.size, Image.Resampling.NEAREST).tobytes():
        raise ValueError(f"{item['id']}: runtime is not exact nearest-neighbor output")
    return native, runtime


def make_contact_sheet(outputs: list[tuple[dict[str, Any], Image.Image, Image.Image]]) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    cell_width = 280
    cell_height = 172
    sheet = Image.new("RGBA", (cell_width * 3, 92 + cell_height * 2), (18, 14, 12, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((16, 16), "Dialogue box AI pixel pipeline", fill=(226, 210, 178, 255))
    draw.text((16, 42), "native 4x preview over runtime parity assets", fill=(169, 151, 124, 255))
    for index, (item, native, runtime) in enumerate(outputs):
        column = index % 3
        row = index // 3
        origin_x = column * cell_width + 14
        origin_y = 76 + row * cell_height
        draw.text((origin_x, origin_y), item["id"], fill=(226, 210, 178, 255))
        native_preview = native.resize((native.width * 4, native.height * 4), Image.Resampling.NEAREST)
        native_preview = ImageOps.contain(native_preview, (220, 56), Image.Resampling.NEAREST)
        runtime_preview = ImageOps.contain(runtime, (220, 56), Image.Resampling.NEAREST)
        sheet.alpha_composite(native_preview, (origin_x, origin_y + 24))
        sheet.alpha_composite(runtime_preview, (origin_x, origin_y + 88))
    sheet.convert("RGB").save(CONTACT_SHEET)


def make_scene_preview(outputs: list[tuple[dict[str, Any], Image.Image, Image.Image]]) -> None:
    by_id = {item["id"]: runtime for item, _native, runtime in outputs}
    preview = Image.new("RGBA", (1280, 720), (16, 18, 17, 255))
    draw = ImageDraw.Draw(preview)
    for y in range(0, 720, 8):
        color = (12 + y // 80, 23 + y // 90, 25 + y // 70, 255)
        draw.rectangle((0, y, 1280, y + 7), fill=color)
    panel = by_id["dialogue_panel"]
    preview.alpha_composite(panel, ((preview.width - panel.width) // 2, 488))
    nameplate = by_id["dialogue_nameplate"]
    preview.alpha_composite(nameplate, (92, 462))
    response = by_id["dialogue_response_hover"]
    preview.alpha_composite(response, ((preview.width - response.width) // 2, 356))
    arrow = by_id["dialogue_progress_arrow"]
    preview.alpha_composite(arrow, (1068, 610))
    SCENE_PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    preview.save(SCENE_PREVIEW)


def main() -> None:
    manifest = load_manifest()
    reference_path = ROOT / manifest["reference"]
    if not reference_path.exists():
        raise FileNotFoundError(f"missing reference: {reference_path}")
    reference = Image.open(reference_path).convert("RGBA")
    scale = int(manifest["scale"])
    background_rgb = tuple(manifest["background_rgb"])
    tolerance = int(manifest["background_tolerance"])
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
    make_contact_sheet(outputs)
    make_scene_preview(outputs)
    print(f"contact sheet: {CONTACT_SHEET.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
