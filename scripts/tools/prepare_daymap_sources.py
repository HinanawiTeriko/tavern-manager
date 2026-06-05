from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageOps


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "daymap"
REFERENCE = SOURCE / "reference"
NATIVE_SIZE = (320, 180)
MARKER_SIZE = (24, 24)
MARKER_STATE_SIZE = (32, 32)
REFERENCE_IMAGE = REFERENCE / "daymap_reference.png"
MARKER_SHEET_IMAGE = REFERENCE / "daymap_marker_sheet_reference.png"
NATIVE_BACKGROUND = SOURCE / "daymap_bg_native.png"
SOURCE_MARKERS = SOURCE / "markers"
MIN_NATIVE_COLORS = 1000
MIN_EDGE_CHANGE_RATIO = 0.18
MIN_MARKER_VISIBLE_PIXELS = 40
MAX_MARKER_COLORS = 16
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


def load_marker_sheet() -> Image.Image:
    if not MARKER_SHEET_IMAGE.exists():
        raise FileNotFoundError(f"Missing DayMap marker sheet reference: {MARKER_SHEET_IMAGE}")
    with Image.open(MARKER_SHEET_IMAGE) as image:
        return image.convert("RGBA")


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
    alpha = native.getchannel("A")
    alpha = alpha.point(lambda value: 255 if value >= 44 else 0)
    quantized_rgb = native.convert("RGB").quantize(colors=MAX_MARKER_COLORS - 1, method=Image.Quantize.MEDIANCUT).convert("RGB")
    quantized = quantized_rgb.convert("RGBA")
    quantized.putalpha(alpha)
    pixels = quantized.load()
    for y in range(quantized.height):
        for x in range(quantized.width):
            if pixels[x, y][3] == 0:
                pixels[x, y] = (0, 0, 0, 0)
    return quantized


def build_marker_sources(sheet: Image.Image) -> dict[str, Image.Image]:
    markers: dict[str, Image.Image] = {}
    cell_width = sheet.width / 4
    cell_height = sheet.height / 2
    for index, marker in enumerate(MARKERS):
        column = index % 4
        row = index // 4
        box = (
            round(column * cell_width),
            round(row * cell_height),
            round((column + 1) * cell_width),
            round((row + 1) * cell_height),
        )
        markers[marker] = fit_icon_to_native(sheet.crop(box))
    return markers


def build_marker_base() -> Image.Image:
    image = Image.new("RGBA", MARKER_STATE_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image, "RGBA")
    draw.polygon(
        [(6, 11), (13, 6), (23, 7), (29, 13), (27, 22), (19, 28), (8, 25), (3, 17)],
        fill=(7, 25, 29, 190),
    )
    draw.line([(7, 12), (14, 8), (23, 9), (27, 14)], fill=(19, 58, 63, 130), width=2)
    draw.line([(6, 21), (15, 25), (24, 22)], fill=(2, 11, 13, 150), width=2)
    return image


def build_brush_ring(selected: bool) -> Image.Image:
    image = Image.new("RGBA", MARKER_STATE_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image, "RGBA")
    amber = (239, 158, 51, 210 if selected else 150)
    dark = (72, 38, 12, 180 if selected else 120)
    strokes = [
        [(7, 11), (12, 6), (20, 6), (25, 10)],
        [(26, 12), (29, 17), (26, 23)],
        [(23, 26), (16, 29), (8, 25)],
        [(5, 23), (3, 16), (6, 10)],
    ]
    if selected:
        strokes += [
            [(10, 4), (18, 3), (25, 7)],
            [(28, 21), (22, 29), (13, 30)],
        ]
    for points in strokes:
        draw.line(points, fill=dark, width=3, joint="curve")
        draw.line(points, fill=amber, width=1, joint="curve")
    return image


def build_reveal_burst() -> Image.Image:
    image = Image.new("RGBA", MARKER_STATE_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image, "RGBA")
    for start, end in [
        ((16, 2), (16, 9)),
        ((24, 5), (21, 11)),
        ((30, 15), (23, 16)),
        ((25, 27), (21, 22)),
        ((16, 30), (16, 23)),
        ((6, 25), (11, 21)),
        ((2, 16), (9, 16)),
        ((7, 6), (11, 11)),
    ]:
        draw.line([start, end], fill=(238, 155, 45, 190), width=2)
    draw.polygon([(13, 13), (18, 11), (22, 16), (18, 21), (12, 20), (10, 15)], fill=(239, 158, 51, 80))
    return image


def build_marker_state_sources() -> dict[str, Image.Image]:
    return {
        "marker_base": build_marker_base(),
        "marker_hover_ring": build_brush_ring(False),
        "marker_selected_ring": build_brush_ring(True),
        "marker_reveal_burst": build_reveal_burst(),
    }


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
    colors = image.convert("RGB").getcolors(maxcolors=65536)
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
    native = build_native_background(load_reference())
    validate_native_background(native)
    markers = build_marker_sources(load_marker_sheet())
    validate_marker_sources(markers)
    states = build_marker_state_sources()
    validate_marker_states(states)
    SOURCE.mkdir(parents=True, exist_ok=True)
    SOURCE_MARKERS.mkdir(parents=True, exist_ok=True)
    native.save(NATIVE_BACKGROUND)
    for marker, image in markers.items():
        image.save(SOURCE_MARKERS / f"{marker}_native.png")
    for state, image in states.items():
        image.save(SOURCE_MARKERS / f"{state}_native.png")
    print(f"Prepared {NATIVE_BACKGROUND.relative_to(ROOT)} from {REFERENCE_IMAGE.relative_to(ROOT)}")
    print(f"Prepared {len(markers)} DayMap marker sources from {MARKER_SHEET_IMAGE.relative_to(ROOT)}")
    print(f"Prepared {len(states)} DayMap marker state sources")


if __name__ == "__main__":
    main()
