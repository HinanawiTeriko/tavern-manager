from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageEnhance, ImageOps


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "daymap"
REFERENCE = SOURCE / "reference"
NATIVE_SIZE = (320, 180)
FULL_MAP_NATIVE_SIZE = (640, 360)
MARKER_SIZE = (24, 24)
MARKER_STATE_SIZE = (32, 32)
FULL_MAP_REFERENCE = REFERENCE / "daymap_full_reference_v2_generated.png"
REFERENCE_IMAGE = FULL_MAP_REFERENCE
MARKER_SHEET_IMAGE = REFERENCE / "daymap_marker_sheet_reference_v2_generated.png"
MARKER_STATE_SHEET_IMAGE = REFERENCE / "daymap_marker_states_reference_v2_generated.png"
NATIVE_BACKGROUND = SOURCE / "daymap_bg_native.png"
FULL_MAP_NATIVE = SOURCE / "daymap_full_native.png"
SOURCE_MARKERS = SOURCE / "markers"
MIN_NATIVE_COLORS = 1000
MIN_EDGE_CHANGE_RATIO = 0.18
MIN_FULL_MAP_COLORS = 64
MAX_FULL_MAP_COLORS = 160
FULL_MAP_PALETTE_COLORS = 144
MIN_FULL_MAP_EDGE_CHANGE_RATIO = 0.10
MIN_MARKER_VISIBLE_PIXELS = 40
MAX_MARKER_COLORS = 10
MARKER_STAMP_PALETTE = [
    (5, 17, 20),
    (13, 35, 39),
    (28, 55, 58),
    (54, 70, 68),
    (84, 74, 51),
    (115, 88, 45),
    (164, 111, 38),
]
MARKER_STAMP_QUANTILES = [0.18, 0.34, 0.52, 0.68, 0.84, 0.94]
MARKERS = [
    "home",
    "mushroom_forest",
    "dark_river",
    "grape_trellis",
    "mill_farm",
    "mercenary_board",
    "abandoned_mine",
    "guild_counter",
]
MARKER_STATES = [
    "marker_base",
    "marker_hover_ring",
    "marker_selected_ring",
    "marker_reveal_burst",
]


def edge_change_ratio(image: Image.Image) -> float:
    rgba = image.convert("RGBA")
    data = rgba.load()
    changes = 0
    total = 0
    for y in range(rgba.height):
        for x in range(rgba.width - 1):
            total += 1
            if data[x, y][:3] != data[x + 1, y][:3]:
                changes += 1
    for y in range(rgba.height - 1):
        for x in range(rgba.width):
            total += 1
            if data[x, y][:3] != data[x, y + 1][:3]:
                changes += 1
    return changes / total


def load_reference() -> Image.Image:
    if not REFERENCE_IMAGE.exists():
        raise FileNotFoundError(f"Missing DayMap reference: {REFERENCE_IMAGE}")
    with Image.open(REFERENCE_IMAGE) as image:
        return image.convert("RGBA")


def build_native_background(reference: Image.Image) -> Image.Image:
    return ImageOps.fit(
        reference,
        NATIVE_SIZE,
        method=Image.Resampling.NEAREST,
        centering=(0.5, 0.5),
    ).convert("RGBA")


def load_full_map_reference() -> Image.Image:
    if not FULL_MAP_REFERENCE.exists():
        raise FileNotFoundError(f"Missing DayMap full map reference: {FULL_MAP_REFERENCE}")
    with Image.open(FULL_MAP_REFERENCE) as image:
        return image.convert("RGBA")


def build_full_map_native_source(reference: Image.Image) -> Image.Image:
    native = ImageOps.fit(
        reference,
        FULL_MAP_NATIVE_SIZE,
        method=Image.Resampling.NEAREST,
        centering=(0.5, 0.5),
    ).convert("RGBA")
    return harmonize_full_map(native)


def harmonize_full_map(native: Image.Image) -> Image.Image:
    image = native.convert("RGBA")
    pixels = image.load()
    width, height = image.size
    cx = (width - 1) * 0.5
    cy = (height - 1) * 0.5
    max_dist = (cx * cx + cy * cy) ** 0.5

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            grey = int(r * 0.32 + g * 0.42 + b * 0.26)
            amber = r > g * 1.10 and g > b * 1.02 and r > 70

            r = int(r * 0.82 + grey * 0.18)
            g = int(g * 0.84 + grey * 0.16)
            b = int(b * 0.82 + grey * 0.18)

            lum = (r + g + b) / 3.0
            shadow = max(0.0, min(1.0, (95.0 - lum) / 95.0))
            r = int(r * (0.98 - shadow * 0.08) + 7 * (0.02 + shadow * 0.06))
            g = int(g * (0.98 - shadow * 0.05) + 36 * (0.02 + shadow * 0.04))
            b = int(b * (0.98 - shadow * 0.04) + 40 * (0.02 + shadow * 0.04))
            if amber:
                r = min(176, int(r * 1.05 + 8))
                g = min(132, int(g * 1.02 + 3))
                b = int(b * 0.92)

            dist = (((x - cx) ** 2 + (y - cy) ** 2) ** 0.5) / max_dist
            shade = 1.0 - max(0.0, dist - 0.44) * 0.22
            pixels[x, y] = (
                max(0, min(255, int(r * shade))),
                max(0, min(255, int(g * shade))),
                max(0, min(255, int(b * shade))),
                a,
            )
    alpha = image.getchannel("A")
    quantized_rgb = image.convert("RGB").quantize(
        colors=FULL_MAP_PALETTE_COLORS,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGB")
    quantized = quantized_rgb.convert("RGBA")
    quantized.putalpha(alpha)
    return quantized


def load_marker_sheet() -> Image.Image:
    if not MARKER_SHEET_IMAGE.exists():
        raise FileNotFoundError(f"Missing DayMap marker sheet reference: {MARKER_SHEET_IMAGE}")
    with Image.open(MARKER_SHEET_IMAGE) as image:
        return image.convert("RGBA")


def load_marker_state_sheet() -> Image.Image:
    if not MARKER_STATE_SHEET_IMAGE.exists():
        raise FileNotFoundError(f"Missing DayMap marker state sheet reference: {MARKER_STATE_SHEET_IMAGE}")
    with Image.open(MARKER_STATE_SHEET_IMAGE) as image:
        return image.convert("RGBA")


def crop_sheet_cell(sheet: Image.Image, columns: int, rows: int, index: int) -> Image.Image:
    cell_width = sheet.width / columns
    cell_height = sheet.height / rows
    column = index % columns
    row = index // columns
    box = (
        round(column * cell_width),
        round(row * cell_height),
        round((column + 1) * cell_width),
        round((row + 1) * cell_height),
    )
    return sheet.crop(box).convert("RGBA")


def remove_green_key(image: Image.Image) -> Image.Image:
    out = image.convert("RGBA")
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            red, green, blue, alpha = pixels[x, y]
            if green > 130 and green > red * 1.35 and green > blue * 1.35:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (red, green, blue, alpha)
    return out


def trim_to_alpha(image: Image.Image) -> Image.Image:
    box = image.getchannel("A").getbbox()
    if box is None:
        raise ValueError("marker sheet cell is empty after chroma-key removal")
    return image.crop(box)


def fit_icon_to_native(image: Image.Image) -> Image.Image:
    trimmed = trim_to_alpha(remove_green_key(image))
    side = max(trimmed.width, trimmed.height)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.alpha_composite(trimmed, ((side - trimmed.width) // 2, (side - trimmed.height) // 2))
    padded = ImageOps.expand(square, border=max(4, side // 18), fill=(0, 0, 0, 0))
    native = padded.resize(MARKER_SIZE, Image.Resampling.LANCZOS).convert("RGBA")
    native = ImageEnhance.Brightness(native).enhance(1.18)
    native = ImageEnhance.Contrast(native).enhance(1.12)
    alpha = native.getchannel("A").point(lambda value: 255 if value >= 44 else 0)
    return harmonize_marker_icon(native, alpha)


def fit_state_to_native(image: Image.Image) -> Image.Image:
    trimmed = trim_to_alpha(remove_green_key(image))
    side = max(trimmed.width, trimmed.height)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.alpha_composite(trimmed, ((side - trimmed.width) // 2, (side - trimmed.height) // 2))
    padded = ImageOps.expand(square, border=max(4, side // 18), fill=(0, 0, 0, 0))
    native = padded.resize(MARKER_STATE_SIZE, Image.Resampling.LANCZOS).convert("RGBA")
    native = ImageEnhance.Contrast(native).enhance(1.08)
    alpha = native.getchannel("A").point(lambda value: 255 if value >= 36 else 0)
    rgb = native.convert("RGB").quantize(
        colors=18,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGB")
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            if pixels[x, y][3] == 0:
                pixels[x, y] = (0, 0, 0, 0)
    return center_alpha_bbox(out)


def center_alpha_bbox(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    box = rgba.getchannel("A").getbbox()
    if box is None:
        return rgba
    left, top, right, bottom = box
    bbox_center_x = (left + right - 1) * 0.5
    bbox_center_y = (top + bottom - 1) * 0.5
    image_center_x = (rgba.width - 1) * 0.5
    image_center_y = (rgba.height - 1) * 0.5
    shift_x = int(round(image_center_x - bbox_center_x))
    shift_y = int(round(image_center_y - bbox_center_y))
    if shift_x == 0 and shift_y == 0:
        return rgba
    centered = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    centered.alpha_composite(rgba, (shift_x, shift_y))
    return centered


def harmonize_marker_icon(native: Image.Image, alpha: Image.Image) -> Image.Image:
    source = native.convert("RGBA")
    alpha = alpha.convert("L")
    visible_luma: list[int] = []
    source_pixels = source.load()
    alpha_pixels = alpha.load()
    for y in range(source.height):
        for x in range(source.width):
            if alpha_pixels[x, y] == 0:
                continue
            r, g, b, _a = source_pixels[x, y]
            visible_luma.append(int(r * 0.32 + g * 0.42 + b * 0.26))
    if not visible_luma:
        raise ValueError("marker icon is empty after alpha cleanup")

    ordered = sorted(visible_luma)
    thresholds = [ordered[min(len(ordered) - 1, int((len(ordered) - 1) * quantile))] for quantile in MARKER_STAMP_QUANTILES]
    out = Image.new("RGBA", source.size, (0, 0, 0, 0))
    out_pixels = out.load()
    for y in range(source.height):
        for x in range(source.width):
            if alpha_pixels[x, y] == 0:
                continue
            r, g, b, _a = source_pixels[x, y]
            luma = int(r * 0.32 + g * 0.42 + b * 0.26)
            palette_index = 0
            while palette_index < len(thresholds) and luma > thresholds[palette_index]:
                palette_index += 1
            out_pixels[x, y] = (*MARKER_STAMP_PALETTE[palette_index], 255)
    return out


def build_marker_sources(sheet: Image.Image) -> dict[str, Image.Image]:
    markers: dict[str, Image.Image] = {}
    for index, marker in enumerate(MARKERS):
        markers[marker] = fit_icon_to_native(crop_sheet_cell(sheet, 4, 2, index))
    return markers


def build_marker_state_sources(sheet: Image.Image) -> dict[str, Image.Image]:
    states: dict[str, Image.Image] = {}
    for index, state in enumerate(MARKER_STATES):
        states[state] = fit_state_to_native(crop_sheet_cell(sheet, 4, 1, index))
    return states


def visible_pixel_count(image: Image.Image) -> int:
    return sum(image.convert("RGBA").getchannel("A").histogram()[1:])


def color_count(image: Image.Image) -> int:
    colors = image.convert("RGBA").getcolors(maxcolors=65536)
    return len(colors) if colors is not None else 65536


def validate_native_background(image: Image.Image) -> None:
    if image.size != NATIVE_SIZE:
        raise ValueError(f"daymap_bg_native: expected {NATIVE_SIZE}, got {image.size}")
    alpha_extrema = image.getchannel("A").getextrema()
    if alpha_extrema[0] < 250:
        raise ValueError("daymap_bg_native: expected opaque background")
    colors = image.convert("RGB").getcolors(maxcolors=image.width * image.height)
    if colors is None:
        raise ValueError("daymap_bg_native: too many native colors to count")
    if len(colors) < MIN_NATIVE_COLORS:
        raise ValueError(
            f"daymap_bg_native: expected at least {MIN_NATIVE_COLORS} colors, got {len(colors)}"
        )
    ratio = edge_change_ratio(image)
    if ratio < MIN_EDGE_CHANGE_RATIO:
        raise ValueError(
            f"daymap_bg_native: edge change ratio {ratio:.3f} below {MIN_EDGE_CHANGE_RATIO}"
        )


def validate_full_map_source(image: Image.Image) -> None:
    if image.size != FULL_MAP_NATIVE_SIZE:
        raise ValueError(f"daymap_full_native: expected {FULL_MAP_NATIVE_SIZE}, got {image.size}")
    alpha_extrema = image.getchannel("A").getextrema()
    if alpha_extrema[0] < 250:
        raise ValueError("daymap_full_native: expected opaque full map")
    colors = image.convert("RGB").getcolors(maxcolors=image.width * image.height)
    if colors is None:
        raise ValueError("daymap_full_native: too many native colors to count")
    if len(colors) < MIN_FULL_MAP_COLORS:
        raise ValueError(
            f"daymap_full_native: expected at least {MIN_FULL_MAP_COLORS} colors, got {len(colors)}"
        )
    if len(colors) > MAX_FULL_MAP_COLORS:
        raise ValueError(
            f"daymap_full_native: expected at most {MAX_FULL_MAP_COLORS} colors, got {len(colors)}"
        )
    ratio = edge_change_ratio(image)
    if ratio < MIN_FULL_MAP_EDGE_CHANGE_RATIO:
        raise ValueError(
            f"daymap_full_native: edge change ratio {ratio:.3f} below {MIN_FULL_MAP_EDGE_CHANGE_RATIO}"
        )


def validate_marker_sources(markers: dict[str, Image.Image]) -> None:
    for marker, image in markers.items():
        if image.size != MARKER_SIZE:
            raise ValueError(f"{marker}: expected {MARKER_SIZE}, got {image.size}")
        alpha_extrema = image.getchannel("A").getextrema()
        if alpha_extrema[0] != 0 or alpha_extrema[1] == 0:
            raise ValueError(f"{marker}: expected transparent and visible pixels")
        if visible_pixel_count(image) < MIN_MARKER_VISIBLE_PIXELS:
            raise ValueError(f"{marker}: too few visible pixels")
        if color_count(image) > MAX_MARKER_COLORS:
            raise ValueError(f"{marker}: too many native colors")


def validate_marker_states(states: dict[str, Image.Image]) -> None:
    for state, image in states.items():
        if image.size != MARKER_STATE_SIZE:
            raise ValueError(f"{state}: expected {MARKER_STATE_SIZE}, got {image.size}")
        alpha_extrema = image.getchannel("A").getextrema()
        if alpha_extrema[0] != 0 or alpha_extrema[1] == 0:
            raise ValueError(f"{state}: expected transparent and visible pixels")
        if visible_pixel_count(image) < 20:
            raise ValueError(f"{state}: too few visible pixels")


def main() -> None:
    full_reference = load_full_map_reference()
    native = build_native_background(full_reference)
    validate_native_background(native)
    full_map_native = build_full_map_native_source(full_reference)
    validate_full_map_source(full_map_native)
    markers = build_marker_sources(load_marker_sheet())
    validate_marker_sources(markers)
    states = build_marker_state_sources(load_marker_state_sheet())
    validate_marker_states(states)
    SOURCE.mkdir(parents=True, exist_ok=True)
    SOURCE_MARKERS.mkdir(parents=True, exist_ok=True)
    native.save(NATIVE_BACKGROUND)
    full_map_native.save(FULL_MAP_NATIVE)
    for marker, image in markers.items():
        image.save(SOURCE_MARKERS / f"{marker}_native.png")
    for state, image in states.items():
        image.save(SOURCE_MARKERS / f"{state}_native.png")
    print(f"Prepared {NATIVE_BACKGROUND.relative_to(ROOT)} from {REFERENCE_IMAGE.relative_to(ROOT)}")
    print(f"Prepared {FULL_MAP_NATIVE.relative_to(ROOT)} from {FULL_MAP_REFERENCE.relative_to(ROOT)}")
    print(f"Prepared {len(markers)} DayMap marker sources from {MARKER_SHEET_IMAGE.relative_to(ROOT)}")
    print(f"Prepared {len(states)} DayMap marker state sources from {MARKER_STATE_SHEET_IMAGE.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
