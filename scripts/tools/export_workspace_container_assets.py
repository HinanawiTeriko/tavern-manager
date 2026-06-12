from __future__ import annotations

from collections import Counter
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "source" / "workspace" / "workspace_container_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "workspace_container_contact_sheet.png"
OUTLINE = (20, 16, 12, 255)


def project_path(path: str) -> Path:
    return ROOT / path


def validate_rect(rect: tuple[int, int, int, int], image: Image.Image, prop_id: str) -> None:
    left, top, right, bottom = rect
    if left < 0 or top < 0 or right > image.width or bottom > image.height:
        raise ValueError(f"{prop_id}: source_rect outside source bounds")
    if left >= right or top >= bottom:
        raise ValueError(f"{prop_id}: source_rect must have positive area")


def detect_chroma_key(image: Image.Image) -> tuple[int, int, int] | None:
    rgba = image.convert("RGBA")
    pixels: list[tuple[int, int, int]] = []
    for x in range(rgba.width):
        for y in (0, rgba.height - 1):
            red, green, blue, alpha = rgba.getpixel((x, y))
            if alpha > 0:
                pixels.append((red, green, blue))
    for y in range(rgba.height):
        for x in (0, rgba.width - 1):
            red, green, blue, alpha = rgba.getpixel((x, y))
            if alpha > 0:
                pixels.append((red, green, blue))
    if not pixels:
        return None
    return Counter(pixels).most_common(1)[0][0]


def remove_chroma(image: Image.Image, threshold: int = 72) -> Image.Image:
    rgba = image.convert("RGBA")
    key = detect_chroma_key(rgba)
    if key is None:
        return rgba
    max_distance_sq = threshold * threshold
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                pixels[x, y] = (0, 0, 0, 0)
                continue
            dr = red - key[0]
            dg = green - key[1]
            db = blue - key[2]
            if dr * dr + dg * dg + db * db <= max_distance_sq:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (red, green, blue, 255)
    return rgba


def harden_alpha(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha < 48:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (red, green, blue, 255)
    return rgba


def quantize_visible(image: Image.Image, colors: int = 14) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    rgb = Image.new("RGB", rgba.size, (0, 0, 0))
    rgb.paste(rgba.convert("RGB"), mask=alpha)
    quantized = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    quantized.putalpha(alpha)
    return quantized


def add_pixel_outline(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    out = rgba.copy()
    src = rgba.load()
    dst = out.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            if src[x, y][3] > 0:
                continue
            for ny in range(max(0, y - 1), min(rgba.height, y + 2)):
                for nx in range(max(0, x - 1), min(rgba.width, x + 2)):
                    if src[nx, ny][3] > 0:
                        dst[x, y] = OUTLINE
                        break
                if dst[x, y][3] > 0:
                    break
    return out


def materialize_reference(prop_id: str, spec: dict) -> Image.Image:
    source = Image.open(project_path(spec["source_sheet"])).convert("RGBA")
    rect = tuple(int(v) for v in spec["source_rect"])
    validate_rect(rect, source, prop_id)
    reference_path = project_path(spec["reference"])
    reference_path.parent.mkdir(parents=True, exist_ok=True)
    source.crop(rect).save(reference_path)
    return Image.open(reference_path).convert("RGBA")


def export_prop(prop_id: str, spec: dict) -> dict:
    reference = materialize_reference(prop_id, spec)
    cutout = remove_chroma(reference, int(spec.get("chroma_threshold", 72)))
    native_width, native_height = (int(v) for v in spec["native_size"])
    fitted = ImageOps.contain(cutout, (native_width, native_height), method=Image.Resampling.LANCZOS)
    fitted = harden_alpha(quantize_visible(fitted, 14))
    fitted = add_pixel_outline(fitted)
    native = Image.new("RGBA", (native_width, native_height), (0, 0, 0, 0))
    native.alpha_composite(fitted, ((native_width - fitted.width) // 2, (native_height - fitted.height) // 2))
    runtime = native.resize(
        (native_width * int(spec["scale"]), native_height * int(spec["scale"])),
        Image.Resampling.NEAREST,
    )
    native_path = project_path(spec["native"])
    runtime_path = project_path(spec["runtime"])
    native_path.parent.mkdir(parents=True, exist_ok=True)
    runtime_path.parent.mkdir(parents=True, exist_ok=True)
    native.save(native_path)
    runtime.save(runtime_path)
    return {
        "id": prop_id,
        "reference": reference,
        "native": native,
        "runtime": runtime,
    }


def backed_preview(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    preview = ImageOps.contain(image.convert("RGBA"), size, Image.Resampling.LANCZOS)
    backing = Image.new("RGBA", size, (48, 42, 34, 255))
    backing.alpha_composite(preview, ((size[0] - preview.width) // 2, (size[1] - preview.height) // 2))
    return backing


def make_contact_sheet(exports: list[dict]) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    row_height = 150
    sheet = Image.new("RGBA", (600, 36 + row_height * len(exports)), (18, 14, 11, 255))
    draw = ImageDraw.Draw(sheet)
    headers = [("id", 12), ("reference", 96), ("native 4x", 264), ("runtime", 432)]
    for label, x in headers:
        draw.text((x, 10), label, fill=(208, 200, 184, 255))
    for row, exported in enumerate(exports):
        y = 34 + row * row_height
        draw.text((12, y + 56), exported["id"], fill=(208, 200, 184, 255))
        previews = [
            backed_preview(exported["reference"], (128, 128)),
            backed_preview(exported["native"].resize(
                (exported["native"].width * 4, exported["native"].height * 4),
                Image.Resampling.NEAREST,
            ), (128, 128)),
            backed_preview(exported["runtime"], (128, 128)),
        ]
        for preview, x in zip(previews, [96, 264, 432]):
            sheet.alpha_composite(preview, (x, y))
    sheet.convert("RGB").save(CONTACT_SHEET)


def main() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    exports = [
        export_prop(prop_id, spec)
        for prop_id, spec in manifest["props"].items()
    ]
    make_contact_sheet(exports)
    print("exported workspace props: " + ", ".join(exported["id"] for exported in exports))


if __name__ == "__main__":
    main()
