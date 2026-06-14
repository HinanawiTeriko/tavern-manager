from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "title"
REFERENCE = SOURCE / "reference"
NATIVE_SIZE = (320, 180)
MARKER_SCALE = 2
MARKER_SIZE = (122, 14)
ACCEPTED_MARKER_REFERENCE = ROOT / "assets" / "textures" / "ui" / "menu_brush_hover_marker.png"
LOGO_DIAGNOSTIC = REFERENCE / "title_pixel_logo_extracted.png"
MENU_BANDS_DIAGNOSTIC = REFERENCE / "title_pixel_menu_bands_extracted.png"
OBSOLETE_DIAGNOSTICS = [
    REFERENCE / "title_pixel_logo_cutout.png",
    REFERENCE / "title_pixel_menu_bands_cutout.png",
]
NATIVE_BAND_TOPS = [36, 62, 88, 114]
SOURCE_BAND_WINDOWS = [(30, 61), (60, 91), (90, 121), (120, 151)]
LOGO_MIN_VISIBLE_PIXELS = 5_500
LOGO_MIN_BBOX_WIDTH = 175
LOGO_MIN_BBOX_HEIGHT = 85
MENU_BAND_MIN_VISIBLE_PIXELS = 1_300
MENU_BAND_MIN_BBOX_WIDTH = 70
MENU_BAND_MIN_BBOX_HEIGHT = 20
GLOW_MIN_VISIBLE_PIXELS = 8_000
GLOW_MAX_VISIBLE_PIXELS = 20_000
GLOW_MIN_BBOX_WIDTH = 180
GLOW_MIN_BBOX_HEIGHT = 120
GLOW_MAX_BBOX_WIDTH = 240
GLOW_MAX_BBOX_HEIGHT = 170
MARKER_MIN_VISIBLE_PIXELS = 900
MARKER_MIN_BBOX_WIDTH = 100
MARKER_MIN_BBOX_HEIGHT = 10
EXTRACTED_LOGO_MIN_VISIBLE_PIXELS = 150_000
EXTRACTED_LOGO_MIN_BBOX_WIDTH = 900
EXTRACTED_LOGO_MIN_BBOX_HEIGHT = 450
EXTRACTED_MENU_BAND_MIN_VISIBLE_PIXELS = 37_000
EXTRACTED_MENU_BAND_MIN_BBOX_WIDTH = 370
EXTRACTED_MENU_BAND_MIN_BBOX_HEIGHT = 100


def fit_cover(path: Path, mode: str) -> Image.Image:
    with Image.open(path) as image:
        return ImageOps.fit(
            image.convert(mode),
            NATIVE_SIZE,
            method=Image.Resampling.NEAREST,
            centering=(0.5, 0.5),
        )


def scaled_box(
    box: tuple[int, int, int, int],
    from_size: tuple[int, int],
    to_size: tuple[int, int],
) -> tuple[int, int, int, int]:
    return (
        round(box[0] * to_size[0] / from_size[0]),
        round(box[1] * to_size[1] / from_size[1]),
        round(box[2] * to_size[0] / from_size[0]),
        round(box[3] * to_size[1] / from_size[1]),
    )


def visible_pixel_count(image: Image.Image) -> int:
    return sum(image.convert("RGBA").getchannel("A").histogram()[1:])


def bbox_size(box: tuple[int, int, int, int] | None) -> tuple[int, int]:
    if box is None:
        return (0, 0)
    return (box[2] - box[0], box[3] - box[1])


def visible_row_groups(image: Image.Image) -> list[tuple[int, int]]:
    alpha = image.convert("RGBA").getchannel("A")
    rows = [
        y
        for y in range(alpha.height)
        if alpha.crop((0, y, alpha.width, y + 1)).getbbox() is not None
    ]
    groups: list[tuple[int, int]] = []
    for row in rows:
        if not groups or row != groups[-1][1] + 1:
            groups.append((row, row))
        else:
            groups[-1] = (groups[-1][0], row)
    return groups


def isolated_alpha_pixels(image: Image.Image) -> int:
    alpha = image.convert("RGBA").getchannel("A")
    pixels = alpha.load()
    isolated = 0
    for y in range(alpha.height):
        for x in range(alpha.width):
            if pixels[x, y] == 0:
                continue
            neighbors = [
                (neighbor_x, neighbor_y)
                for neighbor_y in range(max(0, y - 1), min(alpha.height, y + 2))
                for neighbor_x in range(max(0, x - 1), min(alpha.width, x + 2))
                if (neighbor_x, neighbor_y) != (x, y)
            ]
            if all(pixels[neighbor_x, neighbor_y] == 0 for neighbor_x, neighbor_y in neighbors):
                isolated += 1
    return isolated


def validate_alpha(image: Image.Image, label: str) -> None:
    if "A" not in image.getbands():
        raise ValueError(f"{label}: expected alpha channel")
    alpha_extrema = image.getchannel("A").getextrema()
    if alpha_extrema[0] != 0 or alpha_extrema[1] == 0:
        raise ValueError(f"{label}: expected both transparent and visible pixels")


def validate_minimum_visual_size(
    image: Image.Image,
    label: str,
    min_pixels: int,
    min_width: int,
    min_height: int,
) -> None:
    width, height = bbox_size(image.convert("RGBA").getchannel("A").getbbox())
    pixels = visible_pixel_count(image)
    if pixels < min_pixels:
        raise ValueError(f"{label}: expected at least {min_pixels} visible pixels, got {pixels}")
    if width < min_width or height < min_height:
        raise ValueError(f"{label}: alpha bbox {width}x{height} is smaller than {min_width}x{min_height}")


def validate_menu_bands(
    image: Image.Image,
    label: str,
    min_pixels: int,
    min_width: int,
    min_height: int,
    expected_tops: list[int] | None = None,
) -> None:
    groups = visible_row_groups(image)
    if len(groups) != 4:
        raise ValueError(f"{label}: expected 4 separated bands, got {groups}")
    if expected_tops is not None and [top for top, _ in groups] != expected_tops:
        raise ValueError(f"{label}: wrong band rows {groups}")
    for index, (top, bottom) in enumerate(groups, start=1):
        band = image.crop((0, top, image.width, bottom + 1))
        validate_minimum_visual_size(band, f"{label}[{index}]", min_pixels, min_width, min_height)


def validate_native_outputs(outputs: dict[Path, Image.Image]) -> None:
    expected_sizes = {
        SOURCE / "title_pixel_bg_clean_native.png": NATIVE_SIZE,
        SOURCE / "title_pixel_glow_mask_native.png": NATIVE_SIZE,
        SOURCE / "title_pixel_logo_native.png": NATIVE_SIZE,
        SOURCE / "title_pixel_menu_bands_native.png": NATIVE_SIZE,
        SOURCE / "title_pixel_menu_marker_native.png": MARKER_SIZE,
    }
    for path, expected_size in expected_sizes.items():
        if outputs[path].size != expected_size:
            raise ValueError(f"{path.stem}: expected {expected_size}, got {outputs[path].size}")

    transparent_paths = [
        SOURCE / "title_pixel_glow_mask_native.png",
        SOURCE / "title_pixel_logo_native.png",
        SOURCE / "title_pixel_menu_bands_native.png",
        SOURCE / "title_pixel_menu_marker_native.png",
    ]
    for path in transparent_paths:
        image = outputs[path]
        validate_alpha(image, path.stem)
        isolated = isolated_alpha_pixels(image)
        if isolated:
            raise ValueError(f"{path.stem}: contains {isolated} isolated authored alpha pixels")

    logo = outputs[SOURCE / "title_pixel_logo_native.png"]
    validate_minimum_visual_size(logo, "title_pixel_logo", LOGO_MIN_VISIBLE_PIXELS, LOGO_MIN_BBOX_WIDTH, LOGO_MIN_BBOX_HEIGHT)

    bands = outputs[SOURCE / "title_pixel_menu_bands_native.png"]
    validate_menu_bands(
        bands,
        "title_pixel_menu_bands",
        MENU_BAND_MIN_VISIBLE_PIXELS,
        MENU_BAND_MIN_BBOX_WIDTH,
        MENU_BAND_MIN_BBOX_HEIGHT,
        NATIVE_BAND_TOPS,
    )

    glow = outputs[SOURCE / "title_pixel_glow_mask_native.png"]
    validate_minimum_visual_size(glow, "title_pixel_glow_mask", GLOW_MIN_VISIBLE_PIXELS, GLOW_MIN_BBOX_WIDTH, GLOW_MIN_BBOX_HEIGHT)
    if visible_pixel_count(glow) > GLOW_MAX_VISIBLE_PIXELS:
        raise ValueError(f"title_pixel_glow_mask: coverage exceeds {GLOW_MAX_VISIBLE_PIXELS} pixels")
    glow_width, glow_height = bbox_size(glow.getchannel("A").getbbox())
    if glow_width > GLOW_MAX_BBOX_WIDTH or glow_height > GLOW_MAX_BBOX_HEIGHT:
        raise ValueError(f"title_pixel_glow_mask: alpha bbox {glow_width}x{glow_height} is too broad")

    marker = outputs[SOURCE / "title_pixel_menu_marker_native.png"]
    validate_minimum_visual_size(marker, "title_pixel_menu_marker", MARKER_MIN_VISIBLE_PIXELS, MARKER_MIN_BBOX_WIDTH, MARKER_MIN_BBOX_HEIGHT)


def validate_diagnostic_outputs(outputs: dict[Path, Image.Image]) -> None:
    logo = outputs[LOGO_DIAGNOSTIC]
    validate_alpha(logo, LOGO_DIAGNOSTIC.stem)
    validate_minimum_visual_size(
        logo,
        LOGO_DIAGNOSTIC.stem,
        EXTRACTED_LOGO_MIN_VISIBLE_PIXELS,
        EXTRACTED_LOGO_MIN_BBOX_WIDTH,
        EXTRACTED_LOGO_MIN_BBOX_HEIGHT,
    )

    bands = outputs[MENU_BANDS_DIAGNOSTIC]
    validate_alpha(bands, MENU_BANDS_DIAGNOSTIC.stem)
    validate_menu_bands(
        bands,
        MENU_BANDS_DIAGNOSTIC.stem,
        EXTRACTED_MENU_BAND_MIN_VISIBLE_PIXELS,
        EXTRACTED_MENU_BAND_MIN_BBOX_WIDTH,
        EXTRACTED_MENU_BAND_MIN_BBOX_HEIGHT,
    )


def remove_isolated_alpha(image: Image.Image) -> Image.Image:
    cleaned = image.convert("RGBA")
    while True:
        alpha = cleaned.getchannel("A")
        pixels = alpha.load()
        isolated: list[tuple[int, int]] = []
        for y in range(alpha.height):
            for x in range(alpha.width):
                if pixels[x, y] == 0:
                    continue
                neighbors = [
                    (neighbor_x, neighbor_y)
                    for neighbor_y in range(max(0, y - 1), min(alpha.height, y + 2))
                    for neighbor_x in range(max(0, x - 1), min(alpha.width, x + 2))
                    if (neighbor_x, neighbor_y) != (x, y)
                ]
                if all(pixels[neighbor_x, neighbor_y] == 0 for neighbor_x, neighbor_y in neighbors):
                    isolated.append((x, y))
        if not isolated:
            return cleaned
        for point in isolated:
            cleaned.putpixel(point, (0, 0, 0, 0))


def extract_logo(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    output = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    native_logo_region = (10, 8, 202, 113)
    logo_region = scaled_box(native_logo_region, NATIVE_SIZE, rgba.size)
    lower_logo_y = round(75 * rgba.height / NATIVE_SIZE[1])
    lower_logo_x = round(48 * rgba.width / NATIVE_SIZE[0])
    for y in range(logo_region[1], logo_region[3]):
        for x in range(logo_region[0], logo_region[2]):
            if y >= lower_logo_y and x < lower_logo_x:
                continue
            red, green, blue, _ = rgba.getpixel((x, y))
            if (
                red >= 200
                and green >= 140
                and blue <= 170
                and red - blue >= 70
                and green - blue >= 25
            ):
                output.putpixel((x, y), (red, green, blue, 255))
    return remove_isolated_alpha(output)


def is_dark_band_pixel(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, _ = pixel
    return red <= 20 and green <= 60 and blue <= 70


def extract_menu_band(image: Image.Image, source_window: tuple[int, int]) -> Image.Image:
    rgba = image.convert("RGBA")
    output = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    native_box = (234, source_window[0], 320, source_window[1])
    box = scaled_box(native_box, NATIVE_SIZE, rgba.size)
    for y in range(box[1], box[3]):
        for x in range(box[0], box[2]):
            pixel = rgba.getpixel((x, y))
            if is_dark_band_pixel(pixel):
                output.putpixel((x, y), pixel[:3] + (255,))
    return remove_isolated_alpha(output)


def extract_menu_bands(image: Image.Image) -> list[Image.Image]:
    return [extract_menu_band(image, source_window) for source_window in SOURCE_BAND_WINDOWS]


def combine_layers(layers: list[Image.Image], size: tuple[int, int]) -> Image.Image:
    output = Image.new("RGBA", size, (0, 0, 0, 0))
    for layer in layers:
        output.alpha_composite(layer)
    return output


def build_native_menu_bands(composite: Image.Image) -> Image.Image:
    output = Image.new("RGBA", NATIVE_SIZE, (0, 0, 0, 0))
    for band, target_top in zip(extract_menu_bands(composite), NATIVE_BAND_TOPS):
        alpha_box = band.getchannel("A").getbbox()
        if alpha_box is None:
            raise ValueError("Composite menu-band extraction produced an empty band")
        output.alpha_composite(band.crop(alpha_box), (alpha_box[0], target_top))
    return output


def build_glow(background: Image.Image) -> Image.Image:
    alpha = Image.new("L", NATIVE_SIZE, 0)
    alpha_pixels = alpha.load()
    for y in range(NATIVE_SIZE[1]):
        for x in range(NATIVE_SIZE[0]):
            red, green, blue = background.getpixel((x, y))
            warmth = max(0, red - blue - 24)
            brightness = max(0, red - 72)
            alpha_pixels[x, y] = min(112, ((warmth + brightness) // 24) * 16)
    alpha = alpha.filter(ImageFilter.MaxFilter(7))
    glow = Image.new("RGBA", NATIVE_SIZE, (255, 138, 32, 0))
    glow.putalpha(alpha)
    return glow


def build_marker() -> Image.Image:
    if ACCEPTED_MARKER_REFERENCE.exists():
        with Image.open(ACCEPTED_MARKER_REFERENCE) as image:
            source = image.convert("RGBA")
        runtime_size = (MARKER_SIZE[0] * MARKER_SCALE, MARKER_SIZE[1] * MARKER_SCALE)
        padded = Image.new("RGBA", runtime_size, (0, 0, 0, 0))
        padded.alpha_composite(source.crop((0, 0, min(source.width, runtime_size[0]), min(source.height, runtime_size[1]))))
        return padded.resize(MARKER_SIZE, Image.Resampling.NEAREST)

    marker = Image.new("RGBA", MARKER_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(marker)
    draw.polygon([(0, 9), (13, 6), (31, 4), (56, 1), (99, 1), (121, 5), (121, 8), (83, 8), (64, 10), (26, 12), (0, 11)], fill=(224, 133, 0, 255))
    draw.polygon([(7, 7), (25, 4), (48, 2), (98, 2), (116, 5), (105, 7), (42, 7), (18, 10), (7, 10)], fill=(255, 184, 24, 255))
    draw.rectangle((38, 4, 91, 5), fill=(255, 224, 35, 255))
    draw.rectangle((52, 6, 86, 7), fill=(255, 196, 20, 255))
    draw.rectangle((21, 11, 38, 13), fill=(170, 72, 0, 255))
    draw.rectangle((114, 9, 121, 10), fill=(180, 76, 0, 255))
    return marker


def prepare_outputs() -> dict[Path, Image.Image]:
    with Image.open(REFERENCE / "title_pixel_composite_reference.png") as image:
        composite_reference = image.convert("RGBA")
    composite_native = fit_cover(REFERENCE / "title_pixel_composite_reference.png", "RGBA")
    background_native = fit_cover(REFERENCE / "title_pixel_bg_clean_reference.png", "RGB")
    return {
        LOGO_DIAGNOSTIC: extract_logo(composite_reference),
        MENU_BANDS_DIAGNOSTIC: combine_layers(extract_menu_bands(composite_reference), composite_reference.size),
        SOURCE / "title_pixel_bg_clean_native.png": background_native,
        SOURCE / "title_pixel_glow_mask_native.png": build_glow(background_native),
        SOURCE / "title_pixel_logo_native.png": extract_logo(composite_native),
        SOURCE / "title_pixel_menu_bands_native.png": build_native_menu_bands(composite_native),
        SOURCE / "title_pixel_menu_marker_native.png": build_marker(),
    }


def main() -> None:
    outputs = prepare_outputs()
    validate_diagnostic_outputs(outputs)
    validate_native_outputs(outputs)
    SOURCE.mkdir(parents=True, exist_ok=True)
    for path, image in outputs.items():
        image.save(path)
    for path in OBSOLETE_DIAGNOSTICS:
        path.unlink(missing_ok=True)
    print("Prepared native title sources on the 320x180 grid")


if __name__ == "__main__":
    main()
