from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops, ImageEnhance, ImageFilter, ImageOps, ImageStat


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "intro"
REFERENCE = SOURCE / "reference"
NATIVE_SIZE = (320, 140)
STILLS = [
    "intro_descent",
    "intro_hearth_memory",
    "intro_tavern_dark",
    "intro_rusted_key",
    "intro_threshold",
]
REFERENCE_NAMES = [*STILLS, "tavern_continuity_master"]
PRODUCTION_QUANTIZATION_COLORS = 52
MAX_VALIDATED_NATIVE_COLORS = 64
MIN_DARK_PIXELS = 14_000
MIN_COOL_PIXELS = {
    "intro_descent": 3_100,
    "intro_hearth_memory": 3_100,
    "intro_tavern_dark": 3_100,
    "intro_rusted_key": 3_100,
    "intro_threshold": 1_500,
}
MIN_WARM_PIXELS = {
    "intro_descent": 16,
    "intro_hearth_memory": 155,
    "intro_tavern_dark": 0,
    "intro_rusted_key": 8,
    "intro_threshold": 0,
}
MIN_REFERENCE_DETAIL_RESIDUAL = 1.0
REFERENCE_TILE_SIZE = 20
REFERENCE_MEAN_BIN = 16.0
REFERENCE_STDDEV_BIN = 3.0
REFERENCE_EDGE_BIN = 1.5
REFERENCE_EDGE_LEVEL_BIN = 0.25
MIN_REFERENCE_TILE_SIGNATURES = 28
MIN_REFERENCE_EDGE_LEVELS_PER_AXIS = 16

BRIGHTNESS = {
    "intro_descent": 1.00,
    "intro_hearth_memory": 0.96,
    "intro_tavern_dark": 1.10,
    "intro_rusted_key": 1.05,
    "intro_threshold": 1.12,
}
CONTRAST = {
    "intro_descent": 1.14,
    "intro_hearth_memory": 1.16,
    "intro_tavern_dark": 1.10,
    "intro_rusted_key": 1.13,
    "intro_threshold": 1.08,
}
SATURATION = {
    "intro_descent": 0.86,
    "intro_hearth_memory": 0.84,
    "intro_tavern_dark": 0.80,
    "intro_rusted_key": 0.82,
    "intro_threshold": 0.78,
}


def load_reference(name: str) -> Image.Image:
    if name not in REFERENCE_NAMES:
        raise ValueError(f"Unknown intro reference: {name}")
    path = REFERENCE / f"{name}.png"
    if not path.exists():
        raise FileNotFoundError(f"Missing approved intro reference: {path}")
    with Image.open(path) as image:
        reference = image.convert("RGB")
    validate_reference(name, reference)
    return reference


def edge_change_ratio(image: Image.Image) -> float:
    rgb = image.convert("RGB")
    pixels = rgb.load()
    changes = 0
    total = 0
    for y in range(rgb.height):
        for x in range(rgb.width - 1):
            total += 1
            changes += pixels[x, y] != pixels[x + 1, y]
    for y in range(rgb.height - 1):
        for x in range(rgb.width):
            total += 1
            changes += pixels[x, y] != pixels[x, y + 1]
    return changes / total


def validate_reference(name: str, image: Image.Image) -> None:
    if image.width < 1280 or image.height < 560:
        raise ValueError(f"{name}: approved reference is smaller than 1280x560")
    extrema = image.getextrema()
    tonal_range = max(high - low for low, high in extrema)
    normalized = ImageOps.fit(
        image,
        NATIVE_SIZE,
        method=Image.Resampling.LANCZOS,
        centering=(0.5, 0.5),
    ).convert("L")
    blurred = normalized.filter(ImageFilter.GaussianBlur(2.0))
    detail_histogram = ImageChops.difference(normalized, blurred).histogram()
    detail_residual = sum(
        value * count for value, count in enumerate(detail_histogram)
    ) / sum(detail_histogram)
    tile_signatures: set[tuple[int, int, int, int]] = set()
    horizontal_edge_levels: set[int] = set()
    vertical_edge_levels: set[int] = set()
    pixels = normalized.load()
    # Real scenes vary by tile in tone, contrast, and edge energy along both axes.
    # Procedural gradients, stripes, and waves repeat too few of these 2D signatures.
    for top in range(0, NATIVE_SIZE[1], REFERENCE_TILE_SIZE):
        for left in range(0, NATIVE_SIZE[0], REFERENCE_TILE_SIZE):
            right = left + REFERENCE_TILE_SIZE
            bottom = top + REFERENCE_TILE_SIZE
            block = normalized.crop((left, top, right, bottom))
            statistics = ImageStat.Stat(block)
            horizontal_edge = sum(
                abs(pixels[x + 1, y] - pixels[x, y])
                for y in range(top, bottom)
                for x in range(left, right - 1)
            ) / (REFERENCE_TILE_SIZE * (REFERENCE_TILE_SIZE - 1))
            vertical_edge = sum(
                abs(pixels[x, y + 1] - pixels[x, y])
                for y in range(top, bottom - 1)
                for x in range(left, right)
            ) / ((REFERENCE_TILE_SIZE - 1) * REFERENCE_TILE_SIZE)
            tile_signatures.add(
                (
                    int(statistics.mean[0] / REFERENCE_MEAN_BIN),
                    int(statistics.stddev[0] / REFERENCE_STDDEV_BIN),
                    int(horizontal_edge / REFERENCE_EDGE_BIN),
                    int(vertical_edge / REFERENCE_EDGE_BIN),
                )
            )
            horizontal_edge_levels.add(
                int(horizontal_edge / REFERENCE_EDGE_LEVEL_BIN)
            )
            vertical_edge_levels.add(int(vertical_edge / REFERENCE_EDGE_LEVEL_BIN))
    if (
        tonal_range < 24
        or detail_residual < MIN_REFERENCE_DETAIL_RESIDUAL
        or len(tile_signatures) < MIN_REFERENCE_TILE_SIGNATURES
        or len(horizontal_edge_levels) < MIN_REFERENCE_EDGE_LEVELS_PER_AXIS
        or len(vertical_edge_levels) < MIN_REFERENCE_EDGE_LEVELS_PER_AXIS
    ):
        raise ValueError(f"{name}: approved reference is blank or low-complexity")


def normalize_reference(image: Image.Image) -> Image.Image:
    intermediate = ImageOps.fit(
        image,
        (640, 280),
        method=Image.Resampling.LANCZOS,
        centering=(0.5, 0.5),
    )
    intermediate = intermediate.filter(ImageFilter.GaussianBlur(0.35))
    return intermediate.resize(NATIVE_SIZE, Image.Resampling.LANCZOS)


def grade_native(image: Image.Image, name: str) -> Image.Image:
    rgb = ImageEnhance.Contrast(image).enhance(CONTRAST[name])
    rgb = ImageEnhance.Color(rgb).enhance(SATURATION[name])
    rgb = ImageEnhance.Brightness(rgb).enhance(BRIGHTNESS[name])
    pixels = rgb.load()
    for y in range(rgb.height):
        for x in range(rgb.width):
            red, green, blue = pixels[x, y]
            cool = blue >= red * 1.05 and green >= red * 0.82
            warm = red >= blue * 1.45 and green >= blue * 1.05
            if name == "intro_hearth_memory" and 20 <= max(red, green, blue) <= 45:
                if max(red, green, blue) <= 30:
                    pixels[x, y] = (22, 36, 40)
                else:
                    pixels[x, y] = (28, 40, 46)
            elif cool:
                pixels[x, y] = (
                    min(red, 82),
                    min(146, round(green * 1.03)),
                    min(164, round(blue * 1.04)),
                )
            elif warm:
                pixels[x, y] = (
                    min(206, round(red * 1.03)),
                    min(140, round(green * 1.01)),
                    min(blue, 88),
                )
    return rgb


def quantize_native(image: Image.Image, name: str) -> Image.Image:
    quantized = image.quantize(
        colors=PRODUCTION_QUANTIZATION_COLORS,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGBA")
    if MIN_WARM_PIXELS[name] == 0:
        return quantized

    source = image.load()
    output = quantized.load()
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue = source[x, y]
            if (
                red >= 95
                and green >= 42
                and red >= blue * 1.6
                and green >= blue * 1.1
            ):
                output[x, y] = (
                    (174, 94, 26, 255)
                    if red + green >= 240
                    else (116, 62, 18, 255)
                )
    return quantized


def build_native(name: str) -> Image.Image:
    graded = grade_native(normalize_reference(load_reference(name)), name)
    return quantize_native(graded, name)


def build_vignette() -> Image.Image:
    alpha = Image.new("L", NATIVE_SIZE, 0)
    pixels = alpha.load()
    center_x = (NATIVE_SIZE[0] - 1) / 2
    center_y = (NATIVE_SIZE[1] - 1) / 2
    for y in range(NATIVE_SIZE[1]):
        for x in range(NATIVE_SIZE[0]):
            dx = abs(x - center_x) / center_x
            dy = abs(y - center_y) / center_y
            distance = min(1.0, (dx * dx * 0.58 + dy * dy * 0.42) ** 0.5)
            pixels[x, y] = round(max(0.0, (distance - 0.42) / 0.58) ** 1.7 * 150)
    vignette = Image.new("RGBA", NATIVE_SIZE, (0, 8, 12, 0))
    vignette.putalpha(alpha)
    return vignette


def build_contact_sheet(stills: dict[str, Image.Image]) -> Image.Image:
    sheet = Image.new("RGB", (960, 280), (2, 12, 16))
    positions = [(0, 0), (320, 0), (640, 0), (160, 140), (480, 140)]
    for name, position in zip(STILLS, positions):
        sheet.paste(stills[name].convert("RGB"), position)
    return sheet


def pixel_counts(image: Image.Image) -> tuple[int, int, int]:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    dark = 0
    cool = 0
    warm = 0
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha < 250:
                continue
            dark += max(red, green, blue) <= 58
            cool += (
                blue >= 38
                and green >= 36
                and blue >= red * 1.05
                and green >= red * 0.85
            )
            warm += (
                red >= 95
                and green >= 42
                and red >= blue * 1.6
                and green >= blue * 1.1
            )
    return dark, cool, warm


def validate_still(name: str, image: Image.Image) -> None:
    if image.size != NATIVE_SIZE:
        raise ValueError(f"{name}: expected {NATIVE_SIZE}, got {image.size}")
    colors = image.convert("RGB").getcolors(maxcolors=65536)
    color_total = len(colors) if colors is not None else 65536
    if not 24 <= color_total <= MAX_VALIDATED_NATIVE_COLORS:
        raise ValueError(f"{name}: invalid native color count {color_total}")
    dark, cool, warm = pixel_counts(image)
    if dark < MIN_DARK_PIXELS:
        raise ValueError(f"{name}: insufficient dark mass ({dark})")
    if cool < MIN_COOL_PIXELS[name]:
        raise ValueError(f"{name}: insufficient teal depth ({cool})")
    if warm < MIN_WARM_PIXELS[name]:
        raise ValueError(f"{name}: missing warm focal accents ({warm})")
    ratio = edge_change_ratio(image)
    if ratio < 0.08:
        raise ValueError(f"{name}: likely over-smoothed ({ratio:.3f})")


def validate_vignette(image: Image.Image) -> None:
    if image.size != NATIVE_SIZE or image.mode != "RGBA":
        raise ValueError("intro_vignette: invalid native image")
    alpha = image.getchannel("A")
    minimum, maximum = alpha.getextrema()
    if minimum != 0 or maximum <= 80:
        raise ValueError("intro_vignette: invalid alpha range")
    if alpha.getpixel((160, 70)) >= 40 or alpha.getpixel((0, 0)) <= 80:
        raise ValueError("intro_vignette: invalid center or corner alpha")


def prepare_outputs() -> dict[Path, Image.Image]:
    load_reference("tavern_continuity_master")
    stills = {name: build_native(name) for name in STILLS}
    for name, image in stills.items():
        validate_still(name, image)
    vignette = build_vignette()
    validate_vignette(vignette)
    contact_sheet = build_contact_sheet(stills)
    if contact_sheet.size != (960, 280):
        raise ValueError("intro_contact_sheet: invalid size")
    return {
        **{SOURCE / f"{name}_native.png": image for name, image in stills.items()},
        SOURCE / "intro_vignette_native.png": vignette,
        SOURCE / "intro_contact_sheet.png": contact_sheet,
    }


def prepare_named_outputs(names: list[str]) -> dict[Path, Image.Image]:
    unknown = [name for name in names if name not in STILLS]
    if unknown:
        raise ValueError(f"Unknown intro stills: {', '.join(unknown)}")

    outputs: dict[Path, Image.Image] = {}
    for name in names:
        image = build_native(name)
        validate_still(name, image)
        outputs[SOURCE / f"{name}_native.png"] = image
    return outputs


def main() -> None:
    outputs = prepare_outputs()
    SOURCE.mkdir(parents=True, exist_ok=True)
    for path, image in outputs.items():
        image.save(path)
        print(f"prepared {path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
