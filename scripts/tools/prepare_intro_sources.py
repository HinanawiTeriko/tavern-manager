from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops, ImageEnhance, ImageFilter, ImageOps, ImageStat


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "intro"
REFERENCE = SOURCE / "reference"
NATIVE_SIZE = (320, 180)
STILLS = [
    "intro_descent",
    "intro_hearth_memory",
    "intro_tavern_dark",
    "intro_rusted_key",
    "intro_threshold",
]
REFERENCE_NAMES = [*STILLS, "tavern_continuity_master"]
MAX_COLORS = 56
BASE_COLORS = 52
MIN_DARK_PIXELS = 18_000
MIN_COOL_PIXELS = 4_000
MIN_WARM_PIXELS = {
    "intro_descent": 20,
    "intro_hearth_memory": 200,
    "intro_tavern_dark": 0,
    "intro_rusted_key": 10,
    "intro_threshold": 0,
}
MIN_REFERENCE_DETAIL_RESIDUAL = 1.0
MIN_TEXTURED_BLOCKS = 96

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
    if image.width < 1280 or image.height < 720:
        raise ValueError(f"{name}: approved reference is smaller than 1280x720")
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
    textured_blocks = 0
    for top in range(0, NATIVE_SIZE[1], 10):
        for left in range(0, NATIVE_SIZE[0], 10):
            block = normalized.crop((left, top, left + 10, top + 10))
            textured_blocks += ImageStat.Stat(block).stddev[0] >= 5.0
    if (
        tonal_range < 24
        or detail_residual < MIN_REFERENCE_DETAIL_RESIDUAL
        or textured_blocks < MIN_TEXTURED_BLOCKS
    ):
        raise ValueError(f"{name}: approved reference is blank or low-complexity")


def normalize_reference(image: Image.Image) -> Image.Image:
    intermediate = ImageOps.fit(
        image,
        (640, 360),
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
        colors=BASE_COLORS,
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
    sheet = Image.new("RGB", (960, 360), (2, 12, 16))
    positions = [(0, 0), (320, 0), (640, 0), (160, 180), (480, 180)]
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
    if not 24 <= color_total <= 64:
        raise ValueError(f"{name}: invalid native color count {color_total}")
    dark, cool, warm = pixel_counts(image)
    if dark < MIN_DARK_PIXELS:
        raise ValueError(f"{name}: insufficient dark mass ({dark})")
    if cool < MIN_COOL_PIXELS:
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
    if alpha.getpixel((160, 90)) >= 40 or alpha.getpixel((0, 0)) <= 80:
        raise ValueError("intro_vignette: invalid center or corner alpha")


def prepare_outputs() -> dict[Path, Image.Image]:
    load_reference("tavern_continuity_master")
    stills = {name: build_native(name) for name in STILLS}
    for name, image in stills.items():
        validate_still(name, image)
    vignette = build_vignette()
    validate_vignette(vignette)
    contact_sheet = build_contact_sheet(stills)
    if contact_sheet.size != (960, 360):
        raise ValueError("intro_contact_sheet: invalid size")
    return {
        **{SOURCE / f"{name}_native.png": image for name, image in stills.items()},
        SOURCE / "intro_vignette_native.png": vignette,
        SOURCE / "intro_contact_sheet.png": contact_sheet,
    }


def main() -> None:
    outputs = prepare_outputs()
    SOURCE.mkdir(parents=True, exist_ok=True)
    for path, image in outputs.items():
        image.save(path)
        print(f"prepared {path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
