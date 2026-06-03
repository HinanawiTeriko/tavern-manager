from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "title"
OUTPUT = ROOT / "assets" / "textures" / "title"
SCALE = 4
FULL_LAYERS = [
    "title_pixel_bg_clean",
    "title_pixel_glow_mask",
    "title_pixel_logo",
    "title_pixel_menu_bands",
]
CROPPED_LAYERS = ["title_pixel_menu_marker"]
TRANSPARENT_LAYERS = {
    "title_pixel_glow_mask",
    "title_pixel_logo",
    "title_pixel_menu_bands",
    "title_pixel_menu_marker",
}
NATIVE_SIZE = (320, 180)
MARKER_SIZE = (61, 7)
NATIVE_BAND_TOPS = [36, 62, 88, 114]
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
MARKER_MIN_VISIBLE_PIXELS = 250
MARKER_MIN_BBOX_WIDTH = 60
MARKER_MIN_BBOX_HEIGHT = 5


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


def validate_menu_bands(image: Image.Image) -> None:
    groups = visible_row_groups(image)
    if [top for top, _ in groups] != NATIVE_BAND_TOPS:
        raise ValueError(f"title_pixel_menu_bands: wrong native band rows {groups}")
    for index, (top, bottom) in enumerate(groups, start=1):
        band = image.crop((0, top, image.width, bottom + 1))
        validate_minimum_visual_size(
            band,
            f"title_pixel_menu_bands[{index}]",
            MENU_BAND_MIN_VISIBLE_PIXELS,
            MENU_BAND_MIN_BBOX_WIDTH,
            MENU_BAND_MIN_BBOX_HEIGHT,
        )


def validate_source(name: str, source: Image.Image, expected_size: tuple[int, int]) -> None:
    if source.size != expected_size:
        raise ValueError(f"{name}: expected {expected_size}, got {source.size}")
    if name not in TRANSPARENT_LAYERS:
        return
    if "A" not in source.getbands():
        raise ValueError(f"{name}: expected alpha channel")
    alpha_extrema = source.getchannel("A").getextrema()
    if alpha_extrema[0] != 0 or alpha_extrema[1] == 0:
        raise ValueError(f"{name}: expected both transparent and visible pixels")
    isolated = isolated_alpha_pixels(source)
    if isolated:
        raise ValueError(f"{name}: contains {isolated} isolated authored alpha pixels")

    if name == "title_pixel_logo":
        validate_minimum_visual_size(source, name, LOGO_MIN_VISIBLE_PIXELS, LOGO_MIN_BBOX_WIDTH, LOGO_MIN_BBOX_HEIGHT)
    elif name == "title_pixel_menu_bands":
        validate_menu_bands(source)
    elif name == "title_pixel_glow_mask":
        validate_minimum_visual_size(source, name, GLOW_MIN_VISIBLE_PIXELS, GLOW_MIN_BBOX_WIDTH, GLOW_MIN_BBOX_HEIGHT)
        if visible_pixel_count(source) > GLOW_MAX_VISIBLE_PIXELS:
            raise ValueError(f"{name}: coverage exceeds {GLOW_MAX_VISIBLE_PIXELS} pixels")
        glow_width, glow_height = bbox_size(source.getchannel("A").getbbox())
        if glow_width > GLOW_MAX_BBOX_WIDTH or glow_height > GLOW_MAX_BBOX_HEIGHT:
            raise ValueError(f"{name}: alpha bbox {glow_width}x{glow_height} is too broad")
    elif name == "title_pixel_menu_marker":
        validate_minimum_visual_size(source, name, MARKER_MIN_VISIBLE_PIXELS, MARKER_MIN_BBOX_WIDTH, MARKER_MIN_BBOX_HEIGHT)


def load_sources() -> dict[str, Image.Image]:
    sources: dict[str, Image.Image] = {}
    for name in FULL_LAYERS + CROPPED_LAYERS:
        path = SOURCE / f"{name}_native.png"
        if not path.exists():
            raise FileNotFoundError(f"Missing native title source: {path}")
        with Image.open(path) as image:
            sources[name] = image.copy()
    return sources


def build_runtime_images(sources: dict[str, Image.Image]) -> dict[str, Image.Image]:
    expected_sizes = {
        **{name: NATIVE_SIZE for name in FULL_LAYERS},
        **{name: MARKER_SIZE for name in CROPPED_LAYERS},
    }
    for name, expected_size in expected_sizes.items():
        validate_source(name, sources[name], expected_size)
    return {
        name: source.resize((source.width * SCALE, source.height * SCALE), Image.Resampling.NEAREST)
        for name, source in sources.items()
    }


def validate_runtime_images(sources: dict[str, Image.Image], runtimes: dict[str, Image.Image]) -> None:
    for name, source in sources.items():
        runtime = runtimes[name]
        expected_size = (source.width * SCALE, source.height * SCALE)
        if runtime.size != expected_size:
            raise ValueError(f"{name}: wrong runtime size {runtime.size}")
        expected = source.resize(expected_size, Image.Resampling.NEAREST)
        if runtime.mode != expected.mode or runtime.tobytes() != expected.tobytes():
            raise ValueError(f"{name}: runtime is not an exact nearest-neighbor export")


def main() -> None:
    sources = load_sources()
    runtimes = build_runtime_images(sources)
    validate_runtime_images(sources, runtimes)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name, runtime in runtimes.items():
        runtime.save(OUTPUT / f"{name}.png")
        print(f"{name}: {sources[name].size} -> {runtime.size}")


if __name__ == "__main__":
    main()
