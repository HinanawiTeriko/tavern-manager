from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "source" / "grill_vapor" / "grill_vapor_manifest.json"
TIERS = ("steam", "smoke", "char")
VARIANTS_PER_TIER = 4
CHROMA_KEY = (255, 0, 255)


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


def normalize_char_embers(image: Image.Image) -> None:
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                continue
            if red >= 135 and green >= 52 and blue <= 105 and red > blue * 1.35 and green > blue * 0.7:
                pixels[x, y] = (236, 116, 36, 255)


def normalize_sprite(source: Image.Image, rect: list[int], native_size: tuple[int, int], tier: str) -> Image.Image:
    left, top, right, bottom = rect
    if left < 0 or top < 0 or right > source.width or bottom > source.height or left >= right or top >= bottom:
        raise ValueError(f"invalid source_rect: {rect}")
    cutout = remove_chroma(source.crop((left, top, right, bottom)))
    fitted = ImageOps.contain(cutout, native_size, Image.Resampling.LANCZOS)
    if tier == "char":
        normalize_char_embers(fitted)
    fitted = harden_alpha(quantize_visible(fitted, 18))
    if tier == "char":
        normalize_char_embers(fitted)
    native = Image.new("RGBA", native_size, (0, 0, 0, 0))
    native.alpha_composite(fitted, ((native_size[0] - fitted.width) // 2, (native_size[1] - fitted.height) // 2))
    if tier == "char":
        normalize_char_embers(native)
    return native


def backed_preview(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    preview = ImageOps.contain(image.convert("RGBA"), size, Image.Resampling.NEAREST)
    backing = Image.new("RGBA", size, (22, 28, 32, 255))
    backing.alpha_composite(preview, ((size[0] - preview.width) // 2, (size[1] - preview.height) // 2))
    return backing


def make_contact_sheet(raw_source: Image.Image, native: Image.Image, runtime: Image.Image, out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (720, 408), (16, 18, 20, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((16, 12), "Grill vapor single-wisp source and runtime sprites", fill=(222, 218, 196, 255))
    raw_preview = ImageOps.contain(raw_source.convert("RGBA"), (240, 240), Image.Resampling.LANCZOS)
    sheet.alpha_composite(raw_preview, (16, 44))
    draw.text((16, 292), "generated raw source", fill=(164, 158, 136, 255))

    native_preview = native.resize((native.width * 5, native.height * 5), Image.Resampling.NEAREST)
    sheet.alpha_composite(backed_preview(native_preview, (400, 300)), (296, 44))
    draw.text((296, 354), "native atlas preview 5x", fill=(164, 158, 136, 255))
    draw.text((296, 380), f"runtime atlas: {runtime.width}x{runtime.height}", fill=(164, 158, 136, 255))
    sheet.convert("RGB").save(out_path)


def main() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    raw_source = Image.open(project_path(manifest["raw_source"])).convert("RGBA")
    native_slot_size = tuple(int(v) for v in manifest["native_slot_size"])
    scale = int(manifest["scale"])
    native_atlas = Image.new(
        "RGBA",
        (native_slot_size[0] * VARIANTS_PER_TIER, native_slot_size[1] * len(TIERS)),
        (0, 0, 0, 0),
    )
    for tier_index, tier in enumerate(TIERS):
        for variant_index in range(VARIANTS_PER_TIER):
            sprite_id = f"{tier}_{variant_index}"
            sprite = manifest["sprites"][sprite_id]
            vapor = normalize_sprite(raw_source, sprite["source_rect"], native_slot_size, tier)
            native_atlas.alpha_composite(vapor, (variant_index * native_slot_size[0], tier_index * native_slot_size[1]))

    native_path = project_path(manifest["native_atlas"])
    runtime_path = project_path(manifest["runtime_atlas"])
    native_path.parent.mkdir(parents=True, exist_ok=True)
    runtime_path.parent.mkdir(parents=True, exist_ok=True)
    native_atlas.save(native_path)
    runtime_atlas = native_atlas.resize((native_atlas.width * scale, native_atlas.height * scale), Image.Resampling.NEAREST)
    runtime_atlas.save(runtime_path)
    make_contact_sheet(raw_source, native_atlas, runtime_atlas, project_path(manifest["contact_sheet"]))
    print(f"grill vapor native: {native_path.relative_to(ROOT).as_posix()}")
    print(f"grill vapor runtime: {runtime_path.relative_to(ROOT).as_posix()}")
    print(f"grill vapor contact sheet: {project_path(manifest['contact_sheet']).relative_to(ROOT).as_posix()}")


if __name__ == "__main__":
    main()
