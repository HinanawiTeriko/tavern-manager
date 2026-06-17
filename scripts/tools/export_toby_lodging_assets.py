from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "investigation" / "toby_lodging"
MANIFEST = SOURCE / "toby_lodging_art_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "toby_lodging_investigation_contact_sheet.png"
SCENE_PREVIEW = ROOT / "docs" / "art" / "toby_lodging_investigation_scene_preview.png"


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def load_manifest() -> dict[str, Any]:
    if not MANIFEST.exists():
        raise FileNotFoundError(f"missing manifest: {MANIFEST}")
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def load_source(entry: dict[str, Any]) -> Image.Image:
    path = ROOT / entry["source"]
    if not path.exists():
        raise FileNotFoundError(f"missing AI source: {path}")
    return Image.open(path).convert("RGBA")


def save_reference(image: Image.Image, entry: dict[str, Any]) -> None:
    reference = ROOT / entry["reference"]
    reference.parent.mkdir(parents=True, exist_ok=True)
    image.save(reference)


def crop_explicit(image: Image.Image, source_rect: list[int]) -> Image.Image:
    x, y, width, height = source_rect
    if width <= 0 or height <= 0:
        raise ValueError(f"invalid source_rect: {source_rect}")
    if x < 0 or y < 0 or x + width > image.width or y + height > image.height:
        raise ValueError(f"source_rect outside image bounds: {source_rect} / {image.size}")
    return image.crop((x, y, x + width, y + height))


def quantize_rgba(image: Image.Image, colors: int) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    rgb = Image.new("RGB", rgba.size, (0, 0, 0))
    rgb.paste(rgba.convert("RGB"), mask=alpha)
    quantized = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    quantized.putalpha(alpha)
    return quantized


def quantize_visible(image: Image.Image, colors: int) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    rgb = Image.new("RGB", rgba.size, (0, 0, 0))
    rgb.paste(rgba.convert("RGB"), mask=alpha)
    quantized = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    quantized.putalpha(alpha.point(lambda value: 255 if value >= 40 else 0))
    pixels = quantized.load()
    for y in range(quantized.height):
        for x in range(quantized.width):
            red, green, blue, alpha_value = pixels[x, y]
            if alpha_value == 0:
                pixels[x, y] = (0, 0, 0, 0)
    return quantized


def is_chroma_pixel(red: int, green: int, blue: int, background_rgb: tuple[int, int, int], tolerance: int) -> bool:
    br, bg, bb = background_rgb
    if abs(red - br) + abs(green - bg) + abs(blue - bb) <= tolerance:
        return True
    return red >= 180 and blue >= 180 and green <= 90


def remove_chroma_background(image: Image.Image, background_rgb: tuple[int, int, int], tolerance: int) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0 or is_chroma_pixel(red, green, blue, background_rgb, tolerance):
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (red, green, blue, 255)
    return rgba


def normalize_background(reference: Image.Image, entry: dict[str, Any]) -> Image.Image:
    native_size = tuple(entry["native_size"])
    crop = crop_explicit(reference, entry["source_rect"])
    fitted = ImageOps.fit(crop.convert("RGB"), native_size, Image.Resampling.LANCZOS, centering=(0.5, 0.54))
    sharpened = fitted.filter(ImageFilter.UnsharpMask(radius=1, percent=145, threshold=2))
    balanced = ImageEnhance.Contrast(sharpened).enhance(1.12)
    balanced = ImageEnhance.Color(balanced).enhance(0.78)
    balanced = ImageEnhance.Brightness(balanced).enhance(0.72)
    native = quantize_rgba(balanced, 64)
    pixels = native.load()
    for y in range(native.height):
        for x in range(native.width):
            red, green, blue, alpha = pixels[x, y]
            red = int(red * 0.70 + 4)
            green = int(green * 0.76 + 8)
            blue = int(blue * 0.84 + 13)
            if y < 22 or y > 156:
                red = int(red * 0.76)
                green = int(green * 0.78)
                blue = int(blue * 0.84)
            if 94 <= x <= 152 and 46 <= y <= 104:
                red = int(red * 1.12 + 10)
                green = int(green * 1.06 + 4)
                blue = int(blue * 0.88)
            if (
                ((20 <= x <= 88 and 32 <= y <= 116) or (104 <= x <= 152 and 50 <= y <= 96))
                and red >= 48
                and green >= 24
                and red >= green * 1.04
                and red >= blue * 0.90
            ):
                red = min(158, int(red * 1.04 + 4))
                green = min(96, int(green * 0.96 + 2))
                blue = min(58, int(blue * 0.66))
            if red >= 82 and green >= 42 and blue <= 72:
                red = min(red, 158)
                green = min(green, 96)
                blue = min(blue, 70)
            elif max(red, green, blue) > 206:
                scale = 206.0 / max(red, green, blue)
                red = int(red * scale)
                green = int(green * scale)
                blue = int(blue * scale)
            if y > 122:
                red = int(red * 0.88)
                green = int(green * 0.90)
                blue = int(blue * 0.92)
            pixels[x, y] = (max(4, red), max(6, green), max(8, blue), alpha)
    return quantize_rgba(native, 60)


def fit_transparent_crop(
    crop: Image.Image,
    native_size: tuple[int, int],
    background_rgb: tuple[int, int, int],
    tolerance: int,
) -> Image.Image:
    clean = remove_chroma_background(crop, background_rgb, tolerance)
    alpha_box = clean.getchannel("A").getbbox()
    if alpha_box is None:
        raise ValueError("source crop has no visible pixels after chroma cleanup")
    trimmed = clean.crop(alpha_box)
    fitted = ImageOps.contain(trimmed, native_size, Image.Resampling.LANCZOS)
    native = Image.new("RGBA", native_size, (0, 0, 0, 0))
    x = (native.width - fitted.width) // 2
    y = (native.height - fitted.height) // 2
    native.alpha_composite(fitted, (x, y))
    return native


def apply_item_grade(image: Image.Image, item_id: str) -> Image.Image:
    graded = ImageEnhance.Contrast(image.convert("RGBA")).enhance(0.92)
    pixels = graded.load()
    for y in range(graded.height):
        for x in range(graded.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                pixels[x, y] = (0, 0, 0, 0)
                continue
            red = int(red * 0.58 + 9)
            green = int(green * 0.64 + 13)
            blue = int(blue * 0.70 + 19)
            if (item_id in {"oil_lamp", "hard_bread", "contract_complete"} or item_id.startswith("contract_fragment_")) and red >= green:
                red += 8
                green += 3
                blue = int(blue * 0.90)
            if item_id == "oversized_coat":
                red = int(red * 0.72)
                green = int(green * 0.84)
                blue = int(blue * 0.90 + 4)
            maximum = max(red, green, blue)
            if maximum > 206:
                scale = 206.0 / maximum
                red = int(red * scale)
                green = int(green * scale)
                blue = int(blue * scale)
            pixels[x, y] = (max(0, red), max(0, green), max(0, blue), alpha)
    return quantize_visible(graded, 14)


def apply_button_state(image: Image.Image, state: str) -> Image.Image:
    if state == "hover":
        adjusted = ImageEnhance.Brightness(image).enhance(1.10)
        adjusted = ImageEnhance.Contrast(adjusted).enhance(1.06)
    elif state == "pressed":
        adjusted = ImageEnhance.Brightness(image).enhance(0.78)
        adjusted = ImageEnhance.Contrast(adjusted).enhance(1.10)
    else:
        adjusted = ImageEnhance.Brightness(image).enhance(0.88)
        adjusted = ImageEnhance.Contrast(adjusted).enhance(0.96)
    pixels = adjusted.load()
    for y in range(adjusted.height):
        for x in range(adjusted.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                pixels[x, y] = (0, 0, 0, 0)
                continue
            red = int(red * 0.62 + 8)
            green = int(green * 0.62 + 10)
            blue = int(blue * 0.58 + 16)
            if state == "hover":
                red += 10
                green += 5
            elif state == "pressed":
                red = int(red * 0.76)
                green = int(green * 0.80)
                blue = int(blue * 0.86)
            maximum = max(red, green, blue)
            if maximum > 204:
                scale = 204.0 / maximum
                red = int(red * scale)
                green = int(green * scale)
                blue = int(blue * scale)
            pixels[x, y] = (max(0, red), max(0, green), max(0, blue), alpha)
    return quantize_visible(adjusted, 18)


def save_nearest(native: Image.Image, native_path: Path, runtime_path: Path, runtime_size: tuple[int, int]) -> Image.Image:
    native_path.parent.mkdir(parents=True, exist_ok=True)
    runtime_path.parent.mkdir(parents=True, exist_ok=True)
    native.save(native_path)
    runtime = native.resize(runtime_size, Image.Resampling.NEAREST)
    expected = native.resize(runtime_size, Image.Resampling.NEAREST)
    if runtime.tobytes() != expected.tobytes():
        raise ValueError(f"{runtime_path.name}: runtime is not exact nearest-neighbor output")
    runtime.save(runtime_path)
    return runtime


def export_background(manifest: dict[str, Any]) -> tuple[Image.Image, Image.Image, Image.Image]:
    entry = manifest["background"]
    reference = load_source(entry)
    save_reference(reference, entry)
    native = normalize_background(reference, entry)
    runtime = save_nearest(native, ROOT / entry["native"], ROOT / entry["runtime"], tuple(entry["runtime_size"]))
    return reference, native, runtime


def export_items(manifest: dict[str, Any]) -> list[tuple[dict[str, Any], Image.Image, Image.Image]]:
    background_rgb = tuple(manifest["background_rgb"])
    tolerance = int(manifest["background_tolerance"])
    outputs: list[tuple[dict[str, Any], Image.Image, Image.Image]] = []
    cached_sources: dict[str, Image.Image] = {}
    saved_references: set[str] = set()
    for item in manifest["items"]:
        source_key = item["source"]
        if source_key not in cached_sources:
            cached_sources[source_key] = load_source(item)
        source = cached_sources[source_key]
        reference_key = item["reference"]
        if reference_key not in saved_references:
            save_reference(source, item)
            saved_references.add(reference_key)
        crop = crop_explicit(source, item["source_rect"])
        native = fit_transparent_crop(crop, tuple(item["native_size"]), background_rgb, tolerance)
        native = apply_item_grade(native, item["id"])
        runtime = save_nearest(native, ROOT / item["native"], ROOT / item["runtime"], tuple(item["runtime_size"]))
        outputs.append((item, native, runtime))
        print(f"{item['id']}: {native.size} -> {runtime.size}")
    return outputs


def export_leave_button(manifest: dict[str, Any]) -> list[tuple[dict[str, Any], Image.Image, Image.Image]]:
    button = manifest["leave_button"]
    first_state = button["states"][0]
    source = load_source(first_state)
    save_reference(source, first_state)
    crop = crop_explicit(source, button["source_rect"])
    background_rgb = tuple(manifest["background_rgb"])
    tolerance = int(manifest["background_tolerance"])
    outputs: list[tuple[dict[str, Any], Image.Image, Image.Image]] = []
    for state in button["states"]:
        native = fit_transparent_crop(crop, tuple(state["native_size"]), background_rgb, tolerance)
        native = apply_button_state(native, state["state"])
        runtime = save_nearest(native, ROOT / state["native"], ROOT / state["runtime"], tuple(state["runtime_size"]))
        outputs.append((state, native, runtime))
        print(f"leave_button_{state['state']}: {native.size} -> {runtime.size}")
    return outputs


def make_scene_preview(
    background_runtime: Image.Image,
    item_outputs: list[tuple[dict[str, Any], Image.Image, Image.Image]],
    manifest: dict[str, Any],
) -> Image.Image:
    preview = background_runtime.convert("RGBA").copy()
    runtimes = {item["id"]: runtime for item, _native, runtime in item_outputs}
    review = manifest["review"]
    for item_id, position in review["item_positions_runtime"].items():
        runtime = runtimes.get(item_id)
        if runtime is None:
            continue
        x = int(position[0] - runtime.width * 0.5)
        y = int(position[1] - runtime.height * 0.5)
        preview.alpha_composite(runtime, (x, y))
    SCENE_PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    preview.save(SCENE_PREVIEW)
    return preview


def make_contact_sheet(
    background_reference: Image.Image,
    background_native: Image.Image,
    background_runtime: Image.Image,
    item_outputs: list[tuple[dict[str, Any], Image.Image, Image.Image]],
    button_outputs: list[tuple[dict[str, Any], Image.Image, Image.Image]],
    scene_preview: Image.Image,
) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (1000, 880), (16, 14, 12, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((18, 14), "Toby lodging investigation AI art pipeline", fill=(226, 210, 178, 255))
    draw.text((18, 42), "background source", fill=(226, 210, 178, 255))
    source_preview = ImageOps.contain(background_reference.convert("RGBA"), (300, 170), Image.Resampling.LANCZOS)
    sheet.alpha_composite(source_preview, (18, 66))
    draw.text((348, 42), "native 2x preview", fill=(226, 210, 178, 255))
    native_preview = background_native.resize((640, 360), Image.Resampling.NEAREST)
    native_preview = ImageOps.contain(native_preview, (300, 170), Image.Resampling.NEAREST)
    sheet.alpha_composite(native_preview, (348, 66))
    draw.text((678, 42), "runtime scene preview", fill=(226, 210, 178, 255))
    scene_small = ImageOps.contain(scene_preview, (300, 170), Image.Resampling.NEAREST)
    sheet.alpha_composite(scene_small, (678, 66))

    draw.text((18, 254), "items: native 4x previews", fill=(226, 210, 178, 255))
    for index, (item, native, _runtime) in enumerate(item_outputs):
        column = index % 3
        row = index // 3
        x = 18 + column * 316
        y = 282 + row * 112
        draw.text((x, y), item["id"], fill=(226, 210, 178, 255))
        preview = native.resize((native.width * 4, native.height * 4), Image.Resampling.NEAREST)
        preview = ImageOps.contain(preview, (220, 72), Image.Resampling.NEAREST)
        sheet.alpha_composite(preview, (x, y + 26))

    draw.text((18, 648), "leave button states", fill=(226, 210, 178, 255))
    for index, (state, _native, runtime) in enumerate(button_outputs):
        x = 18 + index * 316
        y = 680
        draw.text((x, y), state["state"], fill=(226, 210, 178, 255))
        preview = ImageOps.contain(runtime, (280, 100), Image.Resampling.NEAREST)
        sheet.alpha_composite(preview, (x, y + 28))

    sheet.convert("RGB").save(CONTACT_SHEET)


def main() -> None:
    manifest = load_manifest()
    background_reference, background_native, background_runtime = export_background(manifest)
    item_outputs = export_items(manifest)
    button_outputs = export_leave_button(manifest)
    scene_preview = make_scene_preview(background_runtime, item_outputs, manifest)
    make_contact_sheet(background_reference, background_native, background_runtime, item_outputs, button_outputs, scene_preview)
    print(f"exported toby lodging background: {manifest['background']['native']} -> {manifest['background']['runtime']}")
    print(f"scene preview: {rel(SCENE_PREVIEW)}")
    print(f"contact sheet: {rel(CONTACT_SHEET)}")


if __name__ == "__main__":
    main()
