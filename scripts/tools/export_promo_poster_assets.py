from __future__ import annotations

from io import BytesIO
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageEnhance, ImageFilter, ImageOps, ImageStat


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_sources" / "generated_raw" / "promo_poster" / "promo_poster_source.png"
SOURCE = ROOT / "assets" / "source" / "promo_poster"
RUNTIME = ROOT / "assets" / "textures" / "promo_poster"
TITLE_REFERENCE = ROOT / "assets" / "source" / "title" / "title_pixel_bg_clean_native.png"

ASSET_ID = "last_call_below_promo_poster"
NATIVE_SIZE = (640, 360)
RUNTIME_SIZE = (1920, 1080)
SCALE = 3
PRODUCTION_COLORS = 72
MAX_NATIVE_COLORS = 96
MAX_RUNTIME_BYTES = 5 * 1024 * 1024
MIN_DARK_PIXELS = 70_000
MIN_COOL_PIXELS = 9_000
MIN_WARM_PIXELS = 9_000
MIN_EDGE_CHANGE_RATIO = 0.08
MIN_REFERENCE_WIDTH = 1280
MIN_REFERENCE_HEIGHT = 720
MIN_REFERENCE_DETAIL_RESIDUAL = 1.0
REFERENCE_TILE_SIZE = 40
MIN_REFERENCE_TILE_SIGNATURES = 36

NATIVE_PATH = SOURCE / f"{ASSET_ID}_native.png"
RUNTIME_PATH = RUNTIME / f"{ASSET_ID}.png"
CONTACT_SHEET_PATH = SOURCE / f"{ASSET_ID}_contact_sheet.png"
MANIFEST_PATH = SOURCE / "promo_poster_manifest.json"


def load_raw() -> Image.Image:
    if not RAW.exists():
        raise FileNotFoundError(f"Missing promo poster raw source: {RAW}")
    with Image.open(RAW) as image:
        raw = image.convert("RGB")
    validate_reference(raw)
    return raw


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


def color_count(image: Image.Image) -> int:
    colors = image.convert("RGB").getcolors(maxcolors=65536)
    return len(colors) if colors is not None else 65536


def validate_reference(image: Image.Image) -> None:
    if image.width < MIN_REFERENCE_WIDTH or image.height < MIN_REFERENCE_HEIGHT:
        raise ValueError(
            "promo_poster_source: raw source must be at least "
            f"{MIN_REFERENCE_WIDTH}x{MIN_REFERENCE_HEIGHT}, got {image.size}"
        )

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

    tile_signatures: set[tuple[int, int, int]] = set()
    for top in range(0, NATIVE_SIZE[1], REFERENCE_TILE_SIZE):
        for left in range(0, NATIVE_SIZE[0], REFERENCE_TILE_SIZE):
            block = normalized.crop(
                (
                    left,
                    top,
                    min(left + REFERENCE_TILE_SIZE, normalized.width),
                    min(top + REFERENCE_TILE_SIZE, normalized.height),
                )
            )
            statistics = ImageStat.Stat(block)
            tile_signatures.add(
                (
                    int(statistics.mean[0] / 16.0),
                    int(statistics.stddev[0] / 3.0),
                    int(edge_change_ratio(block) / 0.04),
                )
            )

    if (
        detail_residual < MIN_REFERENCE_DETAIL_RESIDUAL
        or len(tile_signatures) < MIN_REFERENCE_TILE_SIGNATURES
    ):
        raise ValueError("promo_poster_source: raw source is blank or low-complexity")


def normalize_reference(image: Image.Image) -> Image.Image:
    intermediate = ImageOps.fit(
        image,
        (960, 540),
        method=Image.Resampling.LANCZOS,
        centering=(0.5, 0.5),
    )
    intermediate = intermediate.filter(ImageFilter.GaussianBlur(0.22))
    return intermediate.resize(NATIVE_SIZE, Image.Resampling.LANCZOS)


def grade_native(image: Image.Image) -> Image.Image:
    rgb = ImageEnhance.Contrast(image).enhance(1.10)
    rgb = ImageEnhance.Color(rgb).enhance(0.90)
    rgb = ImageEnhance.Brightness(rgb).enhance(0.96)
    pixels = rgb.load()
    for y in range(rgb.height):
        for x in range(rgb.width):
            red, green, blue = pixels[x, y]
            maximum = max(red, green, blue)
            cool = blue >= red * 1.04 and green >= red * 0.80
            warm = red >= blue * 1.45 and green >= blue * 1.04 and red >= 70

            if maximum <= 30:
                pixels[x, y] = (4, 17, 21)
            elif maximum <= 48 and cool:
                pixels[x, y] = (8, min(48, green), min(58, blue))
            elif cool:
                pixels[x, y] = (
                    min(red, 74),
                    min(142, round(green * 1.02)),
                    min(162, round(blue * 1.03)),
                )
            elif warm:
                pixels[x, y] = (
                    min(218, round(red * 1.04)),
                    min(150, round(green * 1.02)),
                    min(blue, 88),
                )
    return rgb


def quantize_native(image: Image.Image) -> Image.Image:
    quantized = image.quantize(
        colors=PRODUCTION_COLORS,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGBA")

    source = image.load()
    output = quantized.load()
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue = source[x, y]
            warm = red >= 95 and green >= 42 and red >= blue * 1.55 and green >= blue * 1.05
            if not warm:
                continue
            luminance = red * 0.55 + green * 0.35 + blue * 0.10
            if luminance >= 188:
                output[x, y] = (255, 205, 76, 255)
            elif luminance >= 136:
                output[x, y] = (232, 148, 34, 255)
            elif luminance >= 90:
                output[x, y] = (158, 82, 20, 255)
            else:
                output[x, y] = (92, 45, 15, 255)
    return quantized


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
                and blue >= red * 1.04
                and green >= red * 0.80
            )
            warm += (
                red >= 95
                and green >= 42
                and red >= blue * 1.45
                and green >= blue * 1.04
            )
    return dark, cool, warm


def validate_native(image: Image.Image) -> None:
    if image.size != NATIVE_SIZE:
        raise ValueError(f"{ASSET_ID}: expected native size {NATIVE_SIZE}, got {image.size}")
    if "A" not in image.getbands():
        raise ValueError(f"{ASSET_ID}: native source must be RGBA")
    colors = color_count(image)
    if not 24 <= colors <= MAX_NATIVE_COLORS:
        raise ValueError(f"{ASSET_ID}: invalid native color count {colors}")
    dark, cool, warm = pixel_counts(image)
    if dark < MIN_DARK_PIXELS:
        raise ValueError(f"{ASSET_ID}: insufficient dark mass ({dark})")
    if cool < MIN_COOL_PIXELS:
        raise ValueError(f"{ASSET_ID}: insufficient teal depth ({cool})")
    if warm < MIN_WARM_PIXELS:
        raise ValueError(f"{ASSET_ID}: missing warm focal accents ({warm})")
    ratio = edge_change_ratio(image)
    if ratio < MIN_EDGE_CHANGE_RATIO:
        raise ValueError(f"{ASSET_ID}: likely over-smoothed ({ratio:.3f})")


def build_runtime(native: Image.Image) -> Image.Image:
    runtime = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
    validate_runtime(native, runtime)
    return runtime


def png_byte_length(image: Image.Image) -> int:
    buffer = BytesIO()
    image.save(buffer, format="PNG", optimize=True)
    return len(buffer.getvalue())


def validate_runtime(native: Image.Image, runtime: Image.Image) -> None:
    if runtime.size != RUNTIME_SIZE:
        raise ValueError(f"{ASSET_ID}: expected runtime size {RUNTIME_SIZE}, got {runtime.size}")
    expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
    if runtime.mode != expected.mode or runtime.tobytes() != expected.tobytes():
        raise ValueError(f"{ASSET_ID}: runtime is not an exact nearest-neighbor export")
    byte_length = png_byte_length(runtime)
    if byte_length > MAX_RUNTIME_BYTES:
        raise ValueError(
            f"{ASSET_ID}: optimized PNG is {byte_length} bytes, above {MAX_RUNTIME_BYTES}"
        )


def build_native() -> Image.Image:
    return quantize_native(grade_native(normalize_reference(load_raw())))


def build_contact_sheet(native: Image.Image, runtime: Image.Image) -> Image.Image:
    sheet = Image.new("RGB", (NATIVE_SIZE[0] * 3, NATIVE_SIZE[1]), (2, 12, 16))
    if TITLE_REFERENCE.exists():
        with Image.open(TITLE_REFERENCE) as image:
            title_reference = image.convert("RGB").resize(
                NATIVE_SIZE,
                Image.Resampling.NEAREST,
            )
        sheet.paste(title_reference, (0, 0))
    raw_preview = normalize_reference(load_raw()).convert("RGB")
    runtime_preview = runtime.resize(NATIVE_SIZE, Image.Resampling.NEAREST).convert("RGB")
    sheet.paste(raw_preview, (NATIVE_SIZE[0], 0))
    sheet.paste(runtime_preview, (NATIVE_SIZE[0] * 2, 0))
    return sheet


def manifest_data() -> dict[str, object]:
    return {
        "assets": [
            {
                "id": ASSET_ID,
                "source_file": "art_sources/generated_raw/promo_poster/promo_poster_source.png",
                "native_file": f"assets/source/promo_poster/{ASSET_ID}_native.png",
                "output_file": f"assets/textures/promo_poster/{ASSET_ID}.png",
                "size": list(RUNTIME_SIZE),
                "native_size": list(NATIVE_SIZE),
                "safe_area": {
                    "x": 96,
                    "y": 54,
                    "width": 1728,
                    "height": 972,
                },
                "intended_godot_use": "external_promo_only_not_referenced_by_runtime_scenes",
            }
        ]
    }


def build_outputs() -> dict[Path, Image.Image | dict[str, object]]:
    native = build_native()
    validate_native(native)
    runtime = build_runtime(native)
    contact_sheet = build_contact_sheet(native, runtime)
    return {
        NATIVE_PATH: native,
        RUNTIME_PATH: runtime,
        CONTACT_SHEET_PATH: contact_sheet,
        MANIFEST_PATH: manifest_data(),
    }


def save_outputs(outputs: dict[Path, Image.Image | dict[str, object]]) -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    for path, output in outputs.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(output, Image.Image):
            output.save(path, optimize=True)
        else:
            path.write_text(
                json.dumps(output, indent=2, sort_keys=True) + "\n",
                encoding="utf-8",
            )


def main() -> None:
    outputs = build_outputs()
    save_outputs(outputs)
    runtime_bytes = RUNTIME_PATH.stat().st_size
    print(
        f"{ASSET_ID}: {NATIVE_SIZE} -> {RUNTIME_SIZE} nearest, "
        f"{runtime_bytes} bytes"
    )


if __name__ == "__main__":
    main()
