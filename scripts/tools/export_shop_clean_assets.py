import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "assets" / "source" / "daymap" / "shop_clean"
RUNTIME_DIR = ROOT / "assets" / "textures" / "daymap" / "shop_clean"
MANIFEST_PATH = SOURCE_DIR / "shop_clean_manifest.json"


def load_manifest() -> dict:
    return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))


def remove_green_key(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            is_key = g > 145 and r < 95 and b < 95 and g > (r * 1.55 + 35) and g > (b * 1.55 + 35)
            if is_key:
                pixels[x, y] = (r, g, b, 0)
            elif g > 120 and r < 130 and b < 130 and g > r * 1.25 and g > b * 1.25:
                # Despill chroma bleed without changing the crop boundary.
                pixels[x, y] = (r, min(g, max(r, b) + 24), b, a)
    return rgba


def remove_green_remnants(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            is_dark_key_remnant = r <= 8 and b <= 10 and g >= 10 and g >= r + 10 and g >= b + 10
            if is_dark_key_remnant:
                pixels[x, y] = (r, g, b, 0)
    return rgba


def harden_alpha(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    r, g, b, a = rgba.split()
    a = a.point(lambda value: 255 if value >= 36 else 0)
    rgba.putalpha(a)
    return rgba


def quantize_visible_rgb(image: Image.Image, colors: int = 64) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    matte = Image.new("RGBA", rgba.size, (0, 0, 0, 255))
    matte.alpha_composite(rgba)
    quantized = matte.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    quantized.putalpha(alpha)
    return quantized


def cover_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    fitted = ImageOps.fit(image.convert("RGB"), size, method=Image.Resampling.BICUBIC, centering=(0.5, 0.5))
    return quantize_visible_rgb(fitted.convert("RGBA"), 64).convert("RGB")


def clear_native_boxes(image: Image.Image, boxes: list[list[int]]) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    for box in boxes:
        left, top, right, bottom = box
        if left < 0 or top < 0 or right > width or bottom > height or left >= right or top >= bottom:
            raise ValueError(f"Invalid clear_native_box {box} for native size {rgba.size}")
        for y in range(top, bottom):
            for x in range(left, right):
                r, g, b, _a = pixels[x, y]
                pixels[x, y] = (r, g, b, 0)
    return rgba


def crop_asset(source: Image.Image, source_box: list[int] | None, transparent: bool) -> Image.Image:
    if source_box is None:
        return source.copy()
    left, top, right, bottom = source_box
    width, height = source.size
    if left < 0 or top < 0 or right > width or bottom > height or left >= right or top >= bottom:
        raise ValueError(f"Invalid source_box {source_box} for source size {source.size}")
    crop = source.crop((left, top, right, bottom))
    if transparent:
        crop = remove_green_key(crop)
    return crop


def export_asset(asset_id: str, spec: dict, sources: dict[str, Image.Image], scale: int) -> None:
    native_size = tuple(spec["native_size"])
    runtime_size = tuple(spec["runtime_size"])
    transparent = bool(spec["transparent"])
    source = sources[spec["source"]]

    cropped = crop_asset(source, spec.get("source_box"), transparent)
    if transparent:
        resample = Image.Resampling.NEAREST if spec.get("resample") == "nearest" else Image.Resampling.LANCZOS
        native = cropped.resize(native_size, resample)
        native = harden_alpha(native)
        native = remove_green_remnants(native)
        native = quantize_visible_rgb(native, 64)
        native = remove_green_remnants(native)
        native = clear_native_boxes(native, spec.get("clear_native_boxes", []))
    else:
        native = cover_resize(cropped, native_size)

    expected_runtime = (native_size[0] * scale, native_size[1] * scale)
    if runtime_size != expected_runtime:
        raise ValueError(f"{asset_id}: runtime_size {runtime_size} does not match {scale}x {expected_runtime}")

    runtime = native.resize(runtime_size, Image.Resampling.NEAREST)
    native_path = SOURCE_DIR / f"{asset_id}_native.png"
    runtime_path = RUNTIME_DIR / f"{asset_id}.png"
    native.save(native_path)
    runtime.save(runtime_path)


def visible_pixels(image: Image.Image) -> int:
    if "A" not in image.getbands():
        return image.size[0] * image.size[1]
    return sum(image.convert("RGBA").getchannel("A").histogram()[1:])


def make_contact_sheet(manifest: dict) -> None:
    preview_dir = ROOT / manifest["preview_dir"]
    preview_dir.mkdir(parents=True, exist_ok=True)
    assets = list(manifest["assets"].keys())
    thumb_w = 180
    label_h = 34
    padding = 14
    columns = 4
    rows = (len(assets) + columns - 1) // columns
    sheet = Image.new("RGBA", (columns * thumb_w, rows * (thumb_w + label_h + padding)), (18, 22, 20, 255))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("arial.ttf", 11)
    except OSError:
        font = ImageFont.load_default()

    for index, asset_id in enumerate(assets):
        image = Image.open(RUNTIME_DIR / f"{asset_id}.png").convert("RGBA")
        image.thumbnail((thumb_w - padding * 2, thumb_w - label_h - padding), Image.Resampling.NEAREST)
        col = index % columns
        row = index // columns
        x = col * thumb_w + (thumb_w - image.size[0]) // 2
        y = row * (thumb_w + label_h + padding) + padding
        checker = Image.new("RGBA", image.size, (48, 60, 55, 255))
        sheet.alpha_composite(checker, (x, y))
        sheet.alpha_composite(image, (x, y))
        # Small labels are preview-only and are not runtime assets.
        label_y = row * (thumb_w + label_h + padding) + thumb_w - label_h
        sheet.alpha_composite(Image.new("RGBA", (thumb_w, label_h), (9, 13, 12, 255)), (col * thumb_w, label_y))
        label = asset_id.removeprefix("shop_clean_")
        if len(label) > 30:
            label = f"{label[:27]}..."
        draw.text((col * thumb_w + 8, label_y + 8), label, fill=(214, 218, 195, 255), font=font)
    sheet.save(preview_dir / "contact_sheet_runtime.png")


def main() -> None:
    manifest = load_manifest()
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    source_paths = {key: ROOT / value for key, value in manifest["source_files"].items()}
    sources = {key: Image.open(path).convert("RGBA") for key, path in source_paths.items()}
    scale = int(manifest.get("scale", 4))

    for asset_id, spec in manifest["assets"].items():
        export_asset(asset_id, spec, sources, scale)

    for asset_id, spec in manifest["assets"].items():
        native = Image.open(SOURCE_DIR / f"{asset_id}_native.png")
        runtime = Image.open(RUNTIME_DIR / f"{asset_id}.png")
        if native.size != tuple(spec["native_size"]):
            raise ValueError(f"{asset_id}: native size {native.size}")
        if runtime.size != tuple(spec["runtime_size"]):
            raise ValueError(f"{asset_id}: runtime size {runtime.size}")
        if spec["transparent"] and visible_pixels(native) == 0:
            raise ValueError(f"{asset_id}: transparent asset is empty")
        print(f"{asset_id}: native={native.size} runtime={runtime.size}")

    make_contact_sheet(manifest)
    print(f"contact sheet: {ROOT / manifest['preview_dir'] / 'contact_sheet_runtime.png'}")


if __name__ == "__main__":
    main()
