from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageEnhance


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "ui" / "dialogue_box"
MANIFEST = SOURCE / "dialogue_box_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "dialogue_box_contact_sheet.png"
SCENE_PREVIEW = ROOT / "docs" / "art" / "dialogue_box_scene_preview.png"
CHARACTER_COMPARE = ROOT / "docs" / "art" / "dialogue_box_character_compare.png"
SOURCE_TO_NATIVE_RESAMPLE = Image.Resampling.BOX
CHARACTER_REFERENCES = [
    (
        "Vera native",
        ROOT / "assets" / "source" / "tavern" / "characters" / "vera" / "vera_neutral_native.png",
    ),
    (
        "Marco native",
        ROOT / "assets" / "source" / "tavern" / "regular_customers" / "regular_marco_neutral_native.png",
    ),
]


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
            maximum = max(red, green, blue)
            if maximum > 214:
                scale = 214.0 / maximum
                red = int(red * scale)
                green = int(green * scale)
                blue = int(blue * scale)
            pixels[x, y] = (max(0, red), max(0, green), max(0, blue), alpha)
    return graded


def validate_margins(size: tuple[int, int], margins: tuple[int, int, int, int], item_id: str, label: str) -> None:
    left, top, right, bottom = margins
    if min(margins) < 0:
        raise ValueError(f"{item_id}: {label} margins must be non-negative")
    if left + right >= size[0] or top + bottom >= size[1]:
        raise ValueError(f"{item_id}: {label} margins {margins} do not fit size {size}")


def nine_slice_resize(clean: Image.Image, item: dict[str, Any]) -> Image.Image:
    source_size = clean.size
    target_size = tuple(item["native_size"])
    source_margins = tuple(item["source_slice_margins"])
    target_margins = tuple(item["nine_slice_margins"])
    validate_margins(source_size, source_margins, item["id"], "source_slice")
    validate_margins(target_size, target_margins, item["id"], "native nine-slice")

    src_left, src_top, src_right, src_bottom = source_margins
    dst_left, dst_top, dst_right, dst_bottom = target_margins
    src_x = [0, src_left, source_size[0] - src_right, source_size[0]]
    src_y = [0, src_top, source_size[1] - src_bottom, source_size[1]]
    dst_x = [0, dst_left, target_size[0] - dst_right, target_size[0]]
    dst_y = [0, dst_top, target_size[1] - dst_bottom, target_size[1]]

    native = Image.new("RGBA", target_size, (0, 0, 0, 0))
    for row in range(3):
        for col in range(3):
            src_box = (src_x[col], src_y[row], src_x[col + 1], src_y[row + 1])
            dst_box = (dst_x[col], dst_y[row], dst_x[col + 1], dst_y[row + 1])
            dst_w = dst_box[2] - dst_box[0]
            dst_h = dst_box[3] - dst_box[1]
            if dst_w <= 0 or dst_h <= 0:
                continue
            patch = clean.crop(src_box)
            if patch.size != (dst_w, dst_h):
                patch = patch.resize((dst_w, dst_h), SOURCE_TO_NATIVE_RESAMPLE)
            native.alpha_composite(patch, (dst_box[0], dst_box[1]))
    return native


def contain_visible_native_grid(clean: Image.Image, native_size: tuple[int, int], item_id: str) -> Image.Image:
    alpha_box = clean.getchannel("A").getbbox()
    if alpha_box is None:
        raise ValueError(f"{item_id}: crop has no visible pixels after chroma cleanup")
    visible = clean.crop(alpha_box)
    scale = min(native_size[0] / visible.width, native_size[1] / visible.height)
    fitted_size = (
        max(1, min(native_size[0], int(round(visible.width * scale)))),
        max(1, min(native_size[1], int(round(visible.height * scale)))),
    )
    fitted = visible.resize(fitted_size, SOURCE_TO_NATIVE_RESAMPLE)
    native = Image.new("RGBA", native_size, (0, 0, 0, 0))
    native.alpha_composite(fitted, ((native.width - fitted.width) // 2, (native.height - fitted.height) // 2))
    return native


def fit_to_native(crop: Image.Image, item: dict[str, Any], background_rgb: tuple[int, int, int], tolerance: int) -> Image.Image:
    clean = remove_chroma_background(crop, background_rgb, tolerance)
    native_size = tuple(item["native_size"])
    if "source_slice_margins" in item:
        native = nine_slice_resize(clean, item)
    else:
        native = contain_visible_native_grid(clean, native_size, item["id"])
    native = apply_dialogue_grade(native, item["id"])
    return quantize_visible(native, int(item.get("palette_colors", 22)))


def export_item(item: dict[str, Any], background_rgb: tuple[int, int, int], tolerance: int, scale: int) -> tuple[Image.Image, Image.Image]:
    source_path = ROOT / item["source"]
    if not source_path.exists():
        raise FileNotFoundError(f"missing source image for {item['id']}: {source_path}")
    with Image.open(source_path) as source_file:
        source = source_file.convert("RGBA")
    x, y, width, height = item["source_rect"]
    if x < 0 or y < 0 or width <= 0 or height <= 0 or x + width > source.width or y + height > source.height:
        raise ValueError(f"{item['id']}: source_rect {item['source_rect']} does not fit {source_path.relative_to(ROOT)} size {source.size}")
    crop = source.crop((x, y, x + width, y + height))
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


def make_checkerboard(size: tuple[int, int], tile: int = 16) -> Image.Image:
    checker = Image.new("RGBA", size, (50, 50, 50, 255))
    draw = ImageDraw.Draw(checker)
    for y in range(0, size[1], tile):
        for x in range(0, size[0], tile):
            color = (34, 34, 34, 255) if ((x // tile) + (y // tile)) % 2 == 0 else (60, 60, 60, 255)
            draw.rectangle((x, y, x + tile - 1, y + tile - 1), fill=color)
    return checker


def paste_on_checkerboard(sheet: Image.Image, image: Image.Image, position: tuple[int, int]) -> None:
    preview = make_checkerboard(image.size, 16)
    preview.alpha_composite(image.convert("RGBA"), (0, 0))
    sheet.alpha_composite(preview, position)


def make_contact_sheet(outputs: list[tuple[dict[str, Any], Image.Image, Image.Image]]) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (900, 500), (18, 14, 12, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((16, 16), "Dialogue box UI pipeline v1", fill=(226, 210, 178, 255))
    draw.text((16, 42), "one shipped panel component, native shown at exact 2x; runtime is exact 4x nearest", fill=(169, 151, 124, 255))
    for index, (item, native, runtime) in enumerate(outputs):
        del runtime
        origin_x = 24
        origin_y = 82 + index * 140
        draw.text((origin_x, origin_y), item["id"], fill=(226, 210, 178, 255))
        native_preview = native.resize((native.width * 2, native.height * 2), Image.Resampling.NEAREST)
        sheet.alpha_composite(native_preview, (origin_x, origin_y + 24))
    sheet.convert("RGB").save(CONTACT_SHEET)


def make_character_compare_sheet(outputs: list[tuple[dict[str, Any], Image.Image, Image.Image]]) -> None:
    by_id = {item["id"]: native for item, native, _runtime in outputs}
    panel = by_id["dialogue_panel"].resize((600, 108), Image.Resampling.NEAREST)
    sheet = Image.new("RGBA", (980, 560), (18, 14, 12, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((18, 16), "Dialogue panel vs character native pixel density", fill=(226, 210, 178, 255))
    draw.text((18, 40), "all previews use exact nearest-neighbor enlargement; no runtime scene text is baked here", fill=(169, 151, 124, 255))
    draw.text((24, 76), "dialogue_panel_native.png x2", fill=(226, 210, 178, 255))
    paste_on_checkerboard(sheet, panel, (24, 100))

    x = 24
    y = 242
    for label, path in CHARACTER_REFERENCES:
        if not path.exists():
            raise FileNotFoundError(f"missing character comparison reference: {path}")
        with Image.open(path) as character_file:
            character = character_file.convert("RGBA")
        preview = character.resize((character.width * 2, character.height * 2), Image.Resampling.NEAREST)
        draw.text((x, y), f"{label} x2", fill=(226, 210, 178, 255))
        paste_on_checkerboard(sheet, preview, (x, y + 24))
        x += preview.width + 40
    CHARACTER_COMPARE.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(CHARACTER_COMPARE)


def make_scene_preview(outputs: list[tuple[dict[str, Any], Image.Image, Image.Image]]) -> None:
    by_id = {item["id"]: runtime for item, _native, runtime in outputs}
    preview = Image.new("RGBA", (1280, 720), (16, 18, 17, 255))
    draw = ImageDraw.Draw(preview)
    for y in range(0, 720, 8):
        color = (12 + y // 80, 23 + y // 90, 25 + y // 70, 255)
        draw.rectangle((0, y, 1280, y + 7), fill=color)
    panel = by_id["dialogue_panel"]
    preview.alpha_composite(panel, ((preview.width - panel.width) // 2, 488))
    SCENE_PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    preview.save(SCENE_PREVIEW)


def main() -> None:
    manifest = load_manifest()
    reference_path = ROOT / manifest["reference"]
    if not reference_path.exists():
        raise FileNotFoundError(f"missing reference: {reference_path}")
    scale = int(manifest["scale"])
    background_rgb = tuple(manifest["background_rgb"])
    tolerance = int(manifest["background_tolerance"])
    outputs: list[tuple[dict[str, Any], Image.Image, Image.Image]] = []
    for item in manifest["items"]:
        native, runtime = export_item(item, background_rgb, tolerance, scale)
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
    make_character_compare_sheet(outputs)
    print(f"contact sheet: {CONTACT_SHEET.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
