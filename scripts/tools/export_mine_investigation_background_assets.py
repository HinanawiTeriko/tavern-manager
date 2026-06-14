from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "investigation" / "mine_background"
MANIFEST = SOURCE / "mine_background_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "mine_investigation_background_contact_sheet.png"
ITEM_RUNTIME = ROOT / "assets" / "ui" / "generated" / "investigation" / "mine_items"


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def load_manifest() -> dict[str, Any]:
    if not MANIFEST.exists():
        raise FileNotFoundError(f"missing manifest: {MANIFEST}")
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def quantize_rgba(image: Image.Image, colors: int) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    rgb = Image.new("RGB", rgba.size, (0, 0, 0))
    rgb.paste(rgba.convert("RGB"), mask=alpha)
    quantized = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    quantized.putalpha(alpha)
    return quantized


def normalize_background(reference: Image.Image, native_size: tuple[int, int]) -> Image.Image:
    fitted = ImageOps.fit(reference.convert("RGB"), native_size, Image.Resampling.LANCZOS, centering=(0.5, 0.52))
    sharpened = fitted.filter(ImageFilter.UnsharpMask(radius=1, percent=160, threshold=2))
    contrast = ImageEnhance.Contrast(sharpened).enhance(1.18)
    color = ImageEnhance.Color(contrast).enhance(0.86)
    balanced = ImageEnhance.Brightness(color).enhance(0.82)
    native = quantize_rgba(balanced, 72)
    source_pixels = fitted.load()
    pixels = native.load()

    def has_blood_hint(px: int, py: int) -> bool:
        if not (180 <= px <= 236 and 116 <= py <= 138):
            return False
        source_red, source_green, source_blue = source_pixels[px, py]
        return (
            source_red >= 25
            and source_red >= max(source_green, source_blue) + 3
            and source_red >= source_green * 1.08
            and source_red >= source_blue * 1.04
        )

    for y in range(native.height):
        for x in range(native.width):
            red, green, blue, alpha = pixels[x, y]
            if y < 34:
                red = int(red * 0.70)
                green = int(green * 0.74)
                blue = int(blue * 0.84)
            if y > 156:
                red = int(red * 0.74)
                green = int(green * 0.76)
                blue = int(blue * 0.82)
            if 36 <= y <= 146 and 16 <= x <= 304:
                blue = min(130, max(blue, int(green * 0.78)))
            if red >= 118 and green >= 58 and blue <= 64:
                red = min(160, red)
                green = min(96, green)
                blue = min(62, blue)
            elif red > 145 and green > 145 and blue > 145:
                red = min(red, 112)
                green = min(green, 118)
                blue = min(blue, 128)
            is_blood_source = any(
                has_blood_hint(nx, ny)
                for ny in range(max(0, y - 1), min(native.height, y + 2))
                for nx in range(max(0, x - 1), min(native.width, x + 2))
            )
            if is_blood_source:
                red = max(red, 68)
                green = min(green, 34)
                blue = min(blue, 30)
            elif 58 <= x <= 244 and 132 <= y <= 156 and red >= green * 1.08 and red >= blue * 1.08:
                red = min(red, max(28, int((green + blue) * 0.55)))
            pixels[x, y] = (max(5, red), max(6, green), max(8, blue), alpha)
    return native


def item_preview_size(
    item: Image.Image,
    item_id: str,
    collision_sizes: dict[str, list[int]],
    visual_scales: dict[str, float],
) -> tuple[int, int]:
    collision_size = collision_sizes.get(item_id)
    if collision_size is None:
        return (max(12, item.width // 2), max(12, item.height // 2))
    visual_scale = float(visual_scales.get(item_id, 0.84))
    width = max(8, int(round(collision_size[0] * visual_scale * 0.5)))
    height = max(8, int(round(collision_size[1] * visual_scale * 0.5)))
    return (width, height)


def is_chroma_key(red: int, green: int, blue: int) -> bool:
    return abs(red - 255) + green + abs(blue - 255) <= 22


def magenta_distance(red: int, green: int, blue: int) -> int:
    return max(abs(red - 255), green, abs(blue - 255))


def shadow_alpha_from_pixel(red: int, green: int, blue: int) -> int:
    return max(0, min(210, int(magenta_distance(red, green, blue) * 0.92)))


def normalize_shadow(reference: Image.Image, native_size: tuple[int, int], source_rect: list[int]) -> Image.Image:
    x, y, width, height = source_rect
    rgba = reference.crop((x, y, x + width, y + height)).convert("RGBA")
    cleaned = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    source_pixels = rgba.load()
    target_pixels = cleaned.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = source_pixels[x, y]
            if alpha == 0 or is_chroma_key(red, green, blue):
                continue
            shadow_alpha = shadow_alpha_from_pixel(red, green, blue)
            if shadow_alpha >= 12:
                target_pixels[x, y] = (5, 8, 11, shadow_alpha)
    fitted = ImageOps.fit(cleaned, (native_size[0] - 2, native_size[1] - 2), Image.Resampling.LANCZOS, centering=(0.5, 0.5))
    native = Image.new("RGBA", native_size, (0, 0, 0, 0))
    x = (native.width - fitted.width) // 2
    y = (native.height - fitted.height) // 2
    native.alpha_composite(fitted, (x, y))
    alpha = native.getchannel("A").point(lambda value: 0 if value < 6 else min(210, value))
    native.putalpha(alpha)
    pixels = native.load()
    for y in range(native.height):
        for x in range(native.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (5, 8, 11, alpha)
    if native.getchannel("A").getbbox() is None:
        raise ValueError("shadow source has no visible pixels after chroma cleanup")
    return native


def save_nearest(native: Image.Image, native_path: Path, runtime_path: Path, runtime_size: tuple[int, int]) -> Image.Image:
    native_path.parent.mkdir(parents=True, exist_ok=True)
    runtime_path.parent.mkdir(parents=True, exist_ok=True)
    native.save(native_path)
    runtime = native.resize(runtime_size, Image.Resampling.NEAREST)
    expected = native.resize(runtime_size, Image.Resampling.NEAREST)
    if runtime.tobytes() != expected.tobytes():
        raise ValueError(f"{runtime_path.name}: runtime is not exact nearest output")
    runtime.save(runtime_path)
    return runtime


def paste_item_overlay(
    sheet: Image.Image,
    background_preview: Image.Image,
    shadow_runtime: Image.Image,
    positions: dict[str, list[int]],
    collision_sizes: dict[str, list[int]],
    visual_scales: dict[str, float],
    origin: tuple[int, int],
) -> None:
    preview = background_preview.copy()
    for item_id, position in positions.items():
        item_path = ITEM_RUNTIME / f"{item_id}.png"
        if not item_path.exists():
            continue
        item = Image.open(item_path).convert("RGBA")
        x = int(position[0] * 0.5)
        y = int(position[1] * 0.5)
        item_preview = ImageOps.contain(item, item_preview_size(item, item_id, collision_sizes, visual_scales), Image.Resampling.NEAREST)
        preview.alpha_composite(item_preview, (x - item_preview.width // 2, y - item_preview.height // 2))
    sheet.alpha_composite(preview, origin)


def make_contact_sheet(reference: Image.Image, background_native: Image.Image, background_runtime: Image.Image, shadow_native: Image.Image, shadow_runtime: Image.Image, manifest: dict[str, Any]) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (980, 780), (16, 14, 12, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((20, 16), "Mine investigation background and contact shadow pipeline", fill=(226, 210, 178, 255))
    draw.text((20, 48), "AI reference", fill=(226, 210, 178, 255))
    reference_preview = ImageOps.contain(reference.convert("RGBA"), (440, 248), Image.Resampling.LANCZOS)
    sheet.alpha_composite(reference_preview, (20, 72))
    draw.text((510, 48), "native 2x preview", fill=(226, 210, 178, 255))
    native_preview = background_native.resize((640, 360), Image.Resampling.NEAREST)
    native_preview = ImageOps.contain(native_preview, (440, 248), Image.Resampling.NEAREST)
    sheet.alpha_composite(native_preview, (510, 72))
    draw.text((20, 348), "runtime item overlay preview", fill=(226, 210, 178, 255))
    overlay_bg = ImageOps.contain(background_runtime.convert("RGBA"), (640, 360), Image.Resampling.NEAREST)
    paste_item_overlay(
        sheet,
        overlay_bg,
        shadow_runtime,
        manifest["review"]["item_overlay_positions_runtime"],
        manifest["review"].get("item_collision_sizes_runtime", {}),
        manifest["review"].get("item_visual_scales", {}),
        (20, 374),
    )
    draw.text((700, 348), "contact shadow disabled", fill=(169, 151, 124, 255))
    sheet.convert("RGB").save(CONTACT_SHEET)


def main() -> None:
    manifest = load_manifest()
    background_entry = manifest["background"]
    shadow_entry = manifest["shadow"]
    background_reference_path = ROOT / background_entry["reference"]
    shadow_reference_path = ROOT / shadow_entry["reference"]
    if not background_reference_path.exists():
        raise FileNotFoundError(f"missing background reference: {background_reference_path}")
    if not shadow_reference_path.exists():
        raise FileNotFoundError(f"missing shadow reference: {shadow_reference_path}")
    background_reference = Image.open(background_reference_path).convert("RGBA")
    shadow_reference = Image.open(shadow_reference_path).convert("RGBA")
    background_native_size = tuple(background_entry["native_size"])
    background_runtime_size = tuple(background_entry["runtime_size"])
    shadow_native_size = tuple(shadow_entry["native_size"])
    shadow_runtime_size = tuple(shadow_entry["runtime_size"])
    background_native = normalize_background(background_reference, background_native_size)
    shadow_native = normalize_shadow(shadow_reference, shadow_native_size, shadow_entry["source_rect"])
    background_runtime = save_nearest(background_native, ROOT / background_entry["native"], ROOT / background_entry["runtime"], background_runtime_size)
    shadow_runtime = save_nearest(shadow_native, ROOT / shadow_entry["native"], ROOT / shadow_entry["runtime"], shadow_runtime_size)
    make_contact_sheet(background_reference, background_native, background_runtime, shadow_native, shadow_runtime, manifest)
    print(f"exported mine background: {background_entry['native']} -> {background_entry['runtime']}")
    print(f"exported mine item shadow: {shadow_entry['native']} -> {shadow_entry['runtime']}")
    print(f"contact sheet: {rel(CONTACT_SHEET)}")


if __name__ == "__main__":
    main()
