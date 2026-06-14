from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "source" / "seasoning_particles" / "seasoning_particle_manifest.json"
ELEMENTS = ("dust", "flake", "mist", "spark", "settle_cloud")
VARIANTS_PER_ELEMENT = 4
CHROMA_KEY = (255, 0, 255)
ELEMENT_TARGET_SIZES = {
    "dust": (11, 11),
    "flake": (18, 18),
    "mist": (19, 18),
    "spark": (18, 18),
    "settle_cloud": (21, 18),
}


def project_path(path: str) -> Path:
    return ROOT / path


def remove_chroma(image: Image.Image, threshold: int = 92) -> Image.Image:
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


def harden_alpha(image: Image.Image, threshold: int = 30) -> Image.Image:
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


def quantize_visible(image: Image.Image, colors: int = 16) -> Image.Image:
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


def blend_channel(source: int, target: int, amount: float) -> int:
    return int(round(source + (target - source) * amount))


def blend_rgb(source: tuple[int, int, int], target: tuple[int, int, int], amount: float) -> tuple[int, int, int]:
    return (
        blend_channel(source[0], target[0], amount),
        blend_channel(source[1], target[1], amount),
        blend_channel(source[2], target[2], amount),
    )


def normalize_tintable_neutral(image: Image.Image, element: str) -> None:
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                continue
            luminance = (0.299 * red + 0.587 * green + 0.114 * blue) / 255.0
            if luminance < 0.22:
                color = (50, 43, 36)
            elif element == "mist":
                base = (226, 216, 190)
                color = blend_rgb((118, 104, 84), base, min(1.0, luminance * 1.18))
            elif element == "flake":
                base = (207, 205, 166)
                color = blend_rgb((82, 74, 52), base, min(1.0, luminance * 1.12))
            elif element == "settle_cloud":
                base = (235, 219, 180)
                color = blend_rgb((100, 82, 58), base, min(1.0, luminance * 1.16))
            else:
                base = (232, 214, 168)
                color = blend_rgb((108, 68, 42), base, min(1.0, luminance * 1.2))
            pixels[x, y] = (*color, alpha)


def normalize_spark_gold(image: Image.Image) -> None:
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                continue
            luminance = (0.299 * red + 0.587 * green + 0.114 * blue) / 255.0
            if luminance < 0.25:
                color = (86, 38, 24)
            elif luminance > 0.82:
                color = (255, 244, 150)
            elif luminance > 0.56:
                color = (255, 180, 56)
            else:
                color = (189, 76, 34)
            pixels[x, y] = (*color, alpha)


def normalize_sprite(source: Image.Image, rect: list[int], native_size: tuple[int, int], element: str) -> Image.Image:
    left, top, right, bottom = rect
    if left < 0 or top < 0 or right > source.width or bottom > source.height or left >= right or top >= bottom:
        raise ValueError(f"invalid source_rect: {rect}")
    cutout = trim_to_visible(remove_chroma(source.crop((left, top, right, bottom))))
    target_size = ELEMENT_TARGET_SIZES.get(element, native_size)
    fitted = ImageOps.contain(cutout, target_size, Image.Resampling.LANCZOS)
    if element == "spark":
        normalize_spark_gold(fitted)
    else:
        normalize_tintable_neutral(fitted, element)
    fitted = harden_alpha(quantize_visible(fitted, 16))
    if element == "spark":
        normalize_spark_gold(fitted)
    else:
        normalize_tintable_neutral(fitted, element)
    native = Image.new("RGBA", native_size, (0, 0, 0, 0))
    native.alpha_composite(fitted, ((native_size[0] - fitted.width) // 2, (native_size[1] - fitted.height) // 2))
    return native


def backed_preview(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    preview = ImageOps.contain(image.convert("RGBA"), size, Image.Resampling.NEAREST)
    backing = Image.new("RGBA", size, (22, 28, 32, 255))
    backing.alpha_composite(preview, ((size[0] - preview.width) // 2, (size[1] - preview.height) // 2))
    return backing


def make_contact_sheet(raw_source: Image.Image, native: Image.Image, runtime: Image.Image, out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (780, 520), (16, 18, 20, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((16, 12), "Seasoning shaker single-particle source and runtime sprites", fill=(222, 218, 196, 255))
    raw_preview = ImageOps.contain(raw_source.convert("RGBA"), (300, 300), Image.Resampling.LANCZOS)
    sheet.alpha_composite(raw_preview, (16, 44))
    draw.text((16, 354), "generated raw source", fill=(164, 158, 136, 255))

    native_preview = native.resize((native.width * 4, native.height * 4), Image.Resampling.NEAREST)
    sheet.alpha_composite(backed_preview(native_preview, (420, 420)), (336, 44))
    draw.text((336, 474), "native atlas preview 4x", fill=(164, 158, 136, 255))
    draw.text((336, 496), f"runtime atlas: {runtime.width}x{runtime.height}", fill=(164, 158, 136, 255))
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
            particle = normalize_sprite(raw_source, sprite["source_rect"], native_slot_size, element)
            native_atlas.alpha_composite(particle, (variant_index * native_slot_size[0], element_index * native_slot_size[1]))

    native_path = project_path(manifest["native_atlas"])
    runtime_path = project_path(manifest["runtime_atlas"])
    native_path.parent.mkdir(parents=True, exist_ok=True)
    runtime_path.parent.mkdir(parents=True, exist_ok=True)
    native_atlas.save(native_path)
    runtime_atlas = native_atlas.resize((native_atlas.width * scale, native_atlas.height * scale), Image.Resampling.NEAREST)
    runtime_atlas.save(runtime_path)
    make_contact_sheet(raw_source, native_atlas, runtime_atlas, project_path(manifest["contact_sheet"]))
    print(f"seasoning particles native: {native_path.relative_to(ROOT).as_posix()}")
    print(f"seasoning particles runtime: {runtime_path.relative_to(ROOT).as_posix()}")
    print(f"seasoning particles contact sheet: {project_path(manifest['contact_sheet']).relative_to(ROOT).as_posix()}")


if __name__ == "__main__":
    main()
