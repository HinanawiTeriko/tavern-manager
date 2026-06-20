from __future__ import annotations

from collections import Counter
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "source" / "tavern" / "items" / "tavern_recipe_item_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_recipe_items_contact_sheet.png"
OUTLINE = (20, 16, 12, 255)


def project_path(path: str) -> Path:
    return ROOT / path


def validate_rect(rect: tuple[int, int, int, int], image: Image.Image, item_id: str) -> None:
    left, top, right, bottom = rect
    if left < 0 or top < 0 or right > image.width or bottom > image.height:
        raise ValueError(f"{item_id}: source_rect outside source bounds")
    if left >= right or top >= bottom:
        raise ValueError(f"{item_id}: source_rect must have positive area")


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


def remove_chroma(image: Image.Image, threshold: int) -> Image.Image:
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


def normalize_cutout(cutout: Image.Image, spec: dict) -> Image.Image:
    native_width, native_height = (int(v) for v in spec["native_size"])
    if "source_rect" not in spec and cutout.size == (native_width, native_height):
        return harden_alpha(cutout)
    padding = int(spec.get("padding", 1))
    fitted_size = (native_width - padding * 2, native_height - padding * 2)
    fitted = ImageOps.contain(cutout.convert("RGBA"), fitted_size, method=Image.Resampling.LANCZOS)
    fitted = harden_alpha(quantize_visible(fitted, 14))
    fitted = add_pixel_outline(fitted)
    native = Image.new("RGBA", (native_width, native_height), (0, 0, 0, 0))
    native.alpha_composite(fitted, ((native_width - fitted.width) // 2, (native_height - fitted.height) // 2))
    return native


def export_item(item_id: str, spec: dict) -> dict:
    source = Image.open(project_path(spec["source_file"])).convert("RGBA")
    if "source_rect" in spec:
        rect = tuple(int(v) for v in spec["source_rect"])
        validate_rect(rect, source, item_id)
        crop = source.crop(rect)
        cutout = remove_chroma(crop, int(spec.get("chroma_threshold", 72)))
    else:
        crop = source.copy()
        cutout = crop.copy()
    native = normalize_cutout(cutout, spec)
    scale = int(spec["scale"])
    runtime = native.resize((native.width * scale, native.height * scale), Image.Resampling.NEAREST)
    native_path = project_path(spec["native"])
    runtime_path = project_path(spec["runtime"])
    native_path.parent.mkdir(parents=True, exist_ok=True)
    runtime_path.parent.mkdir(parents=True, exist_ok=True)
    native.save(native_path)
    runtime.save(runtime_path)
    return {
        "id": item_id,
        "source": source,
        "crop": crop,
        "native": native,
        "runtime": runtime,
    }


def backed_preview(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    preview = ImageOps.contain(image.convert("RGBA"), size, Image.Resampling.NEAREST)
    backing = Image.new("RGBA", size, (48, 42, 34, 255))
    backing.alpha_composite(preview, ((size[0] - preview.width) // 2, (size[1] - preview.height) // 2))
    return backing


def make_contact_sheet(exports: list[dict]) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    row_height = 128
    sheet = Image.new("RGBA", (660, 36 + row_height * len(exports)), (18, 14, 11, 255))
    draw = ImageDraw.Draw(sheet)
    headers = [("id", 12), ("crop/source", 218), ("native 4x", 362), ("runtime", 506)]
    for label, x in headers:
        draw.text((x, 10), label, fill=(208, 200, 184, 255))
    for row, exported in enumerate(exports):
        y = 34 + row * row_height
        draw.text((12, y + 42), exported["id"], fill=(208, 200, 184, 255))
        previews = [
            backed_preview(exported["crop"], (112, 112)),
            backed_preview(exported["native"].resize((96, 96), Image.Resampling.NEAREST), (112, 112)),
            backed_preview(exported["runtime"], (112, 112)),
        ]
        for preview, x in zip(previews, [218, 362, 506]):
            sheet.alpha_composite(preview, (x, y))
    sheet.convert("RGB").save(CONTACT_SHEET)


def main() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    exports = [export_item(item_id, spec) for item_id, spec in manifest["items"].items()]
    make_contact_sheet(exports)
    print("exported tavern recipe item art: " + ", ".join(exported["id"] for exported in exports))


if __name__ == "__main__":
    main()
