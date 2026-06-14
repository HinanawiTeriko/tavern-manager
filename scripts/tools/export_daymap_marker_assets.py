from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageEnhance, ImageOps

from prepare_daymap_sources import (
    MARKER_SIZE,
    center_alpha_bbox,
    color_count,
    harmonize_marker_icon,
    visible_pixel_count,
)


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "assets" / "source" / "daymap" / "markers" / "daymap_story_marker_manifest.json"
SOURCE_IMAGE = ROOT / "art_sources" / "generated_raw" / "daymap_markers" / "daymap_story_markers_source_v1.png"
CONTACT_SHEET = ROOT / "docs" / "art" / "daymap_story_marker_contact_sheet.png"
RUNTIME_SCALE = 4
MIN_VISIBLE_PIXELS = 35
MAX_COLORS = 10
MAGENTA_KEY = (255, 0, 255)


def repo_path(relative_path: str) -> Path:
    return ROOT / relative_path


def load_manifest() -> dict:
    with MANIFEST_PATH.open("r", encoding="utf-8") as file:
        return json.load(file)


def load_source_image(manifest: dict) -> Image.Image:
    source_path = repo_path(str(manifest.get("source_image", SOURCE_IMAGE.relative_to(ROOT).as_posix())))
    if not source_path.exists():
        raise FileNotFoundError(f"Missing retained DayMap marker source sheet: {source_path}")
    with Image.open(source_path) as image:
        return image.convert("RGBA")


def remove_magenta_key(image: Image.Image) -> Image.Image:
    out = image.convert("RGBA")
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            red, green, blue, alpha = pixels[x, y]
            is_key = red >= 190 and blue >= 180 and green <= 120 and red > green * 1.45 and blue > green * 1.45
            if is_key:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (red, green, blue, alpha)
    return out


def crop_source(source: Image.Image, source_crop: list[int]) -> Image.Image:
    if len(source_crop) != 4:
        raise ValueError(f"source_crop must have four integer values, got {source_crop}")
    left, top, right, bottom = source_crop
    if left < 0 or top < 0 or right > source.width or bottom > source.height or left >= right or top >= bottom:
        raise ValueError(f"source_crop is outside the source image bounds: {source_crop}")
    return source.crop((left, top, right, bottom)).convert("RGBA")


def trim_to_alpha(image: Image.Image) -> Image.Image:
    box = image.getchannel("A").getbbox()
    if box is None:
        raise ValueError("story marker crop is empty after magenta-key removal")
    return image.crop(box)


def fit_icon_to_native(image: Image.Image) -> Image.Image:
    trimmed = trim_to_alpha(remove_magenta_key(image))
    side = max(trimmed.width, trimmed.height)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.alpha_composite(trimmed, ((side - trimmed.width) // 2, (side - trimmed.height) // 2))
    padded = ImageOps.expand(square, border=max(6, side // 14), fill=(0, 0, 0, 0))
    native = padded.resize(MARKER_SIZE, Image.Resampling.LANCZOS).convert("RGBA")
    native = ImageEnhance.Brightness(native).enhance(1.15)
    native = ImageEnhance.Contrast(native).enhance(1.16)
    alpha = native.getchannel("A").point(lambda value: 255 if value >= 42 else 0)
    harmonized = harmonize_marker_icon(native, alpha)
    return center_alpha_bbox(harmonized)


def export_runtime(native: Image.Image, output_size: tuple[int, int]) -> Image.Image:
    return native.resize(output_size, Image.Resampling.NEAREST)


def validate_native(marker_id: str, image: Image.Image) -> None:
    if image.size != MARKER_SIZE:
        raise ValueError(f"{marker_id}: expected native size {MARKER_SIZE}, got {image.size}")
    alpha_min, alpha_max = image.getchannel("A").getextrema()
    if alpha_min != 0 or alpha_max == 0:
        raise ValueError(f"{marker_id}: expected transparent padding and visible marker pixels")
    if visible_pixel_count(image) < MIN_VISIBLE_PIXELS:
        raise ValueError(f"{marker_id}: too few visible pixels")
    if color_count(image) > MAX_COLORS:
        raise ValueError(f"{marker_id}: too many colors for DayMap marker style")


def build_contact_sheet(previews: list[tuple[Image.Image, Image.Image]]) -> Image.Image:
    cell = 112
    gap = 12
    width = len(previews) * cell + (len(previews) + 1) * gap
    height = cell * 2 + gap * 3
    sheet = Image.new("RGBA", (width, height), (9, 23, 26, 255))
    for index, (source_preview, runtime_icon) in enumerate(previews):
        x = gap + index * (cell + gap)
        source_thumb = remove_magenta_key(source_preview)
        source_thumb = ImageOps.contain(source_thumb, (96, 96), Image.Resampling.LANCZOS)
        top_plate = Image.new("RGBA", (cell, cell), (13, 35, 39, 255))
        top_plate.alpha_composite(source_thumb, ((cell - source_thumb.width) // 2, (cell - source_thumb.height) // 2))
        bottom_plate = Image.new("RGBA", (cell, cell), (13, 35, 39, 255))
        bottom_plate.alpha_composite(runtime_icon, ((cell - runtime_icon.width) // 2, (cell - runtime_icon.height) // 2))
        sheet.alpha_composite(top_plate, (x, gap))
        sheet.alpha_composite(bottom_plate, (x, gap * 2 + cell))
    return sheet


def main() -> None:
    manifest = load_manifest()
    source = load_source_image(manifest)
    previews: list[tuple[Image.Image, Image.Image]] = []
    for marker_id, entry in manifest["assets"].items():
        source_crop = entry["source_crop"]
        source_part = crop_source(source, source_crop)
        native = fit_icon_to_native(source_part)
        validate_native(marker_id, native)

        native_path = repo_path(entry["native_file"])
        runtime_path = repo_path(entry["output_file"])
        output_size = tuple(entry["size"])
        runtime = export_runtime(native, output_size)

        native_path.parent.mkdir(parents=True, exist_ok=True)
        runtime_path.parent.mkdir(parents=True, exist_ok=True)
        native.save(native_path)
        runtime.save(runtime_path)
        previews.append((source_part, runtime))
        print(f"{marker_id}: {source_crop} -> {native.size} -> {runtime.size}")

    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    build_contact_sheet(previews).save(CONTACT_SHEET)
    print(f"Contact sheet: {CONTACT_SHEET.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
