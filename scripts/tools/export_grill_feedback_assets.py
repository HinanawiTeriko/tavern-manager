from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "source" / "grill_feedback" / "grill_feedback_manifest.json"
ELEMENTS = ("oil_spark", "done_spark", "char_spark", "heat_glow", "flame")
VARIANTS_PER_ELEMENT = 4
CHROMA_KEY = (255, 0, 255)
ELEMENT_TARGET_SIZES = {
    "oil_spark": (22, 22),
    "done_spark": (27, 27),
    "char_spark": (20, 20),
    "heat_glow": (40, 12),
    "flame": (20, 29),
}


def project_path(path: str) -> Path:
    return ROOT / path


def remove_chroma(image: Image.Image, threshold: int = 96) -> Image.Image:
    rgba = image.convert("RGBA")
    max_distance_sq = threshold * threshold
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                pixels[x, y] = (0, 0, 0, 0)
                continue
            dr = red - CHROMA_KEY[0]
            dg = green - CHROMA_KEY[1]
            db = blue - CHROMA_KEY[2]
            if dr * dr + dg * dg + db * db <= max_distance_sq:
                pixels[x, y] = (0, 0, 0, 0)
    return rgba


def harden_alpha(image: Image.Image, threshold: int = 28) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha <= threshold:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (red, green, blue, 255)
    return rgba


def quantize_visible(image: Image.Image, colors: int = 18) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    if alpha.getbbox() is None:
        return rgba
    rgb = Image.new("RGB", rgba.size, (0, 0, 0))
    rgb.paste(rgba.convert("RGB"), mask=alpha)
    quantized = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    quantized.putalpha(alpha)
    return quantized


def trim_to_visible(image: Image.Image) -> Image.Image:
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        return image
    return image.crop(bounds)


def normalize_element_colors(image: Image.Image, element: str) -> None:
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                continue
            if element == "char_spark":
                if red >= 150 and green >= 45 and blue <= 85:
                    pixels[x, y] = (235, 84, 24, 255)
                elif red < 95 and green < 90 and blue < 90:
                    pixels[x, y] = (35, 31, 29, 255)
            elif element == "heat_glow":
                if red >= 160 and green >= 55 and blue <= 90:
                    pixels[x, y] = (244, 112, 20, 255)
            else:
                if red >= 150 and green >= 70 and blue <= 115:
                    pixels[x, y] = (250, 132, 24, 255)
                if red >= 210 and green >= 165 and blue <= 120:
                    pixels[x, y] = (255, 232, 84, 255)


def normalize_sprite(source: Image.Image, rect: list[int], native_size: tuple[int, int], element: str) -> Image.Image:
    left, top, right, bottom = rect
    if left < 0 or top < 0 or right > source.width or bottom > source.height or left >= right or top >= bottom:
        raise ValueError(f"invalid source_rect: {rect}")
    cutout = trim_to_visible(remove_chroma(source.crop((left, top, right, bottom))))
    target_size = ELEMENT_TARGET_SIZES.get(element, native_size)
    fitted = ImageOps.contain(cutout, target_size, Image.Resampling.LANCZOS)
    normalize_element_colors(fitted, element)
    fitted = harden_alpha(quantize_visible(fitted, 18))
    normalize_element_colors(fitted, element)
    native = Image.new("RGBA", native_size, (0, 0, 0, 0))
    native.alpha_composite(fitted, ((native_size[0] - fitted.width) // 2, (native_size[1] - fitted.height) // 2))
    normalize_element_colors(native, element)
    return native


def backed_preview(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    preview = ImageOps.contain(image.convert("RGBA"), size, Image.Resampling.NEAREST)
    backing = Image.new("RGBA", size, (22, 28, 32, 255))
    backing.alpha_composite(preview, ((size[0] - preview.width) // 2, (size[1] - preview.height) // 2))
    return backing


def make_contact_sheet(raw_source: Image.Image, native: Image.Image, runtime: Image.Image, out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (760, 432), (16, 18, 20, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((16, 12), "Grill feedback generated source and runtime sprites", fill=(222, 218, 196, 255))
    raw_preview = ImageOps.contain(raw_source.convert("RGBA"), (280, 186), Image.Resampling.LANCZOS)
    sheet.alpha_composite(raw_preview, (16, 44))
    draw.text((16, 244), "generated raw source", fill=(164, 158, 136, 255))

    native_preview = native.resize((native.width * 4, native.height * 4), Image.Resampling.NEAREST)
    sheet.alpha_composite(backed_preview(native_preview, (420, 320)), (320, 44))
    draw.text((320, 380), "native atlas preview 4x", fill=(164, 158, 136, 255))
    draw.text((320, 404), f"runtime atlas: {runtime.width}x{runtime.height}", fill=(164, 158, 136, 255))
    sheet.convert("RGB").save(out_path)


def main() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    raw_source = Image.open(project_path(manifest["raw_source"])).convert("RGBA")
    native_slot_size = tuple(int(v) for v in manifest["native_slot_size"])
    scale = int(manifest["scale"])
    native_atlas = Image.new(
        "RGBA",
        (native_slot_size[0] * VARIANTS_PER_ELEMENT, native_slot_size[1] * len(ELEMENTS)),
        (0, 0, 0, 0),
    )
    for element_index, element in enumerate(ELEMENTS):
        for variant_index in range(VARIANTS_PER_ELEMENT):
            sprite_id = f"{element}_{variant_index}"
            sprite = manifest["sprites"][sprite_id]
            effect = normalize_sprite(raw_source, sprite["source_rect"], native_slot_size, element)
            native_atlas.alpha_composite(effect, (variant_index * native_slot_size[0], element_index * native_slot_size[1]))

    native_path = project_path(manifest["native_atlas"])
    runtime_path = project_path(manifest["runtime_atlas"])
    native_path.parent.mkdir(parents=True, exist_ok=True)
    runtime_path.parent.mkdir(parents=True, exist_ok=True)
    native_atlas.save(native_path)
    runtime_atlas = native_atlas.resize((native_atlas.width * scale, native_atlas.height * scale), Image.Resampling.NEAREST)
    runtime_atlas.save(runtime_path)
    make_contact_sheet(raw_source, native_atlas, runtime_atlas, project_path(manifest["contact_sheet"]))
    print(f"grill feedback native: {native_path.relative_to(ROOT).as_posix()}")
    print(f"grill feedback runtime: {runtime_path.relative_to(ROOT).as_posix()}")
    print(f"grill feedback contact sheet: {project_path(manifest['contact_sheet']).relative_to(ROOT).as_posix()}")


if __name__ == "__main__":
    main()
