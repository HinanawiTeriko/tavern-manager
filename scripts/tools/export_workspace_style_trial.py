from __future__ import annotations

from collections import Counter
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "source" / "workspace_style_trial" / "workspace_style_trial_manifest.json"
BACKING = (48, 42, 34, 255)
SHEET_BG = (18, 14, 11, 255)
TEXT = (208, 200, 184, 255)
OUTLINE = (20, 16, 12, 255)


def project_path(path: str) -> Path:
    return ROOT / path


def validate_rect(rect: tuple[int, int, int, int], image: Image.Image, item_id: str) -> None:
    left, top, right, bottom = rect
    if left < 0 or top < 0 or right > image.width or bottom > image.height:
        raise ValueError(f"{item_id}: sheet_rect outside sheet bounds")
    if left >= right or top >= bottom:
        raise ValueError(f"{item_id}: sheet_rect must have positive area")


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


def alpha_bounds(image: Image.Image) -> tuple[int, int, int, int]:
    rgba = image.convert("RGBA")
    xs: list[int] = []
    ys: list[int] = []
    data = rgba.get_flattened_data() if hasattr(rgba, "get_flattened_data") else rgba.getdata()
    for index, pixel in enumerate(data):
        if pixel[3] > 0:
            xs.append(index % rgba.width)
            ys.append(index // rgba.width)
    if not xs:
        return (0, 0, 0, 0)
    return (min(xs), min(ys), max(xs) + 1, max(ys) + 1)


def trim_alpha(image: Image.Image) -> Image.Image:
    left, top, right, bottom = alpha_bounds(image)
    if right <= left or bottom <= top:
        return image
    return image.crop((left, top, right, bottom))


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


def export_item(item_id: str, spec: dict, sheet: Image.Image, native_size: tuple[int, int], preview_scale: int) -> dict:
    rect = tuple(int(v) for v in spec["sheet_rect"])
    validate_rect(rect, sheet, item_id)
    crop = sheet.crop(rect)
    cutout = trim_alpha(remove_chroma(crop))
    target = int(spec["target_longest"])
    fitted = ImageOps.contain(cutout, (target, target), method=Image.Resampling.NEAREST)
    fitted = add_pixel_outline(harden_alpha(quantize_visible(fitted, 14)))
    native = Image.new("RGBA", native_size, (0, 0, 0, 0))
    native.alpha_composite(fitted, ((native_size[0] - fitted.width) // 2, (native_size[1] - fitted.height) // 2))
    preview = native.resize((native.width * preview_scale, native.height * preview_scale), Image.Resampling.NEAREST)
    native_path = project_path(spec["native"])
    preview_path = project_path(spec["preview"])
    native_path.parent.mkdir(parents=True, exist_ok=True)
    preview_path.parent.mkdir(parents=True, exist_ok=True)
    native.save(native_path)
    preview.save(preview_path)
    return {
        "id": item_id,
        "kind": spec["kind"],
        "target_longest": target,
        "crop": crop,
        "native": native,
        "preview": preview,
    }


def backed(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    preview = ImageOps.contain(image.convert("RGBA"), size, Image.Resampling.LANCZOS)
    result = Image.new("RGBA", size, BACKING)
    result.alpha_composite(preview, ((size[0] - preview.width) // 2, (size[1] - preview.height) // 2))
    return result


def make_contact_sheet(exports: list[dict], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    row_height = 128
    sheet = Image.new("RGBA", (680, 34 + row_height * len(exports)), SHEET_BG)
    draw = ImageDraw.Draw(sheet)
    headers = [("id", 12), ("kind/target", 96), ("reference crop", 210), ("native 4x", 354), ("preview", 498)]
    for label, x in headers:
        draw.text((x, 10), label, fill=TEXT)
    for row, exported in enumerate(exports):
        y = 34 + row * row_height
        draw.text((12, y + 42), exported["id"], fill=TEXT)
        draw.text((96, y + 38), f'{exported["kind"]}\n{exported["target_longest"]}px', fill=TEXT)
        native_4x = exported["native"].resize((192, 192), Image.Resampling.NEAREST)
        previews = [
            backed(exported["crop"], (112, 112)),
            backed(native_4x, (112, 112)),
            backed(exported["preview"], (112, 112)),
        ]
        for preview, x in zip(previews, [210, 354, 498]):
            sheet.alpha_composite(preview, (x, y))
    sheet.convert("RGB").save(path)


def main() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    sheet = Image.open(project_path(manifest["source_sheet"])).convert("RGBA")
    native_size = tuple(int(v) for v in manifest["native_size"])
    preview_scale = int(manifest["preview_scale"])
    exports = [
        export_item(item_id, spec, sheet, native_size, preview_scale)
        for item_id, spec in manifest["items"].items()
    ]
    make_contact_sheet(exports, project_path(manifest["contact_sheet"]))
    print("exported workspace style trial: " + ", ".join(exported["id"] for exported in exports))


if __name__ == "__main__":
    main()
