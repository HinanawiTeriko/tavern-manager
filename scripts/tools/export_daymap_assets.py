from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "daymap"
SOURCE_MARKERS = SOURCE / "markers"
RUNTIME = ROOT / "assets" / "textures" / "daymap"
RUNTIME_MARKERS = RUNTIME / "markers"
SCALE = 4
BG_SIZE = (320, 180)
MARKER_SIZE = (24, 24)
RUNTIME_BG_SIZE = (1280, 720)
RUNTIME_MARKER_SIZE = (96, 96)

COLORS = {
    "void": (9, 18, 21, 255),
    "deep_teal": (12, 38, 44, 255),
    "teal": (21, 78, 82, 255),
    "table": (30, 24, 20, 255),
    "wood": (52, 42, 31, 255),
    "paper_dark": (78, 58, 38, 255),
    "paper": (114, 83, 49, 255),
    "paper_light": (144, 101, 54, 255),
    "ink": (24, 18, 14, 255),
    "ink_soft": (55, 39, 25, 255),
    "amber": (232, 160, 64, 255),
    "amber_dim": (128, 76, 32, 255),
    "river": (44, 112, 124, 255),
    "green": (88, 132, 58, 255),
    "red": (160, 64, 70, 255),
    "wheat": (196, 144, 72, 255),
    "transparent": (0, 0, 0, 0),
}

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


def visible_pixel_count(image: Image.Image) -> int:
    alpha = image.convert("RGBA").getchannel("A")
    return sum(alpha.histogram()[1:])


def color_count(image: Image.Image) -> int:
    colors = image.convert("RGBA").getcolors(maxcolors=65536)
    return len(colors) if colors is not None else 65536


def draw_pixel_clusters(draw: ImageDraw.ImageDraw) -> None:
    clusters = [
        (12, 12, 22, 16, "teal"),
        (34, 24, 46, 28, "deep_teal"),
        (266, 14, 304, 22, "deep_teal"),
        (16, 152, 54, 164, "deep_teal"),
        (276, 140, 314, 154, "teal"),
        (58, 8, 68, 14, "wood"),
        (224, 166, 246, 171, "wood"),
    ]
    for x0, y0, x1, y1, color in clusters:
        draw.rectangle((x0, y0, x1, y1), fill=COLORS[color])


def draw_background() -> Image.Image:
    image = Image.new("RGBA", BG_SIZE, COLORS["table"])
    draw = ImageDraw.Draw(image, "RGBA")

    # Dungeon-dark tavern table and vignette blocks.
    draw.rectangle((0, 0, 319, 34), fill=COLORS["void"])
    draw.rectangle((0, 146, 319, 179), fill=COLORS["void"])
    draw.rectangle((0, 0, 42, 179), fill=COLORS["deep_teal"])
    draw.rectangle((278, 0, 319, 179), fill=COLORS["deep_teal"])
    draw.rectangle((0, 0, 319, 13), fill=COLORS["deep_teal"])
    draw.rectangle((0, 166, 319, 179), fill=COLORS["deep_teal"])
    draw_pixel_clusters(draw)

    # Muted parchment plate with jagged edges.
    paper = [
        (38, 31),
        (58, 24),
        (96, 27),
        (134, 21),
        (176, 26),
        (215, 22),
        (260, 29),
        (284, 45),
        (279, 78),
        (289, 105),
        (275, 148),
        (238, 155),
        (190, 151),
        (150, 160),
        (108, 152),
        (61, 157),
        (35, 137),
        (43, 105),
        (31, 77),
    ]
    draw.polygon(paper, fill=COLORS["paper_dark"])
    inner_paper = [
        (47, 39),
        (83, 33),
        (128, 34),
        (180, 33),
        (232, 35),
        (271, 48),
        (263, 83),
        (274, 108),
        (259, 139),
        (218, 144),
        (165, 145),
        (125, 151),
        (77, 145),
        (47, 129),
        (53, 99),
        (43, 74),
    ]
    draw.polygon(inner_paper, fill=COLORS["paper"])
    draw.line(paper + [paper[0]], fill=COLORS["ink"], width=2)

    # Amber lantern wash from upper left.
    for rect, color in [
        ((45, 37, 98, 76), "paper_light"),
        ((54, 45, 84, 62), "amber_dim"),
        ((18, 44, 23, 58), "amber"),
        ((21, 58, 21, 76), "amber_dim"),
    ]:
        draw.rectangle(rect, fill=COLORS[color])

    # Map roads and landmarks, intentionally text-free.
    path = [(76, 84), (112, 70), (151, 82), (189, 67), (230, 91), (245, 124)]
    for a, b in zip(path, path[1:]):
        draw.line((*a, *b), fill=COLORS["ink_soft"], width=2)
    for x, y in path:
        draw.rectangle((x - 1, y - 1, x + 1, y + 1), fill=COLORS["ink"])

    draw.line((86, 122, 120, 106, 151, 122, 188, 111), fill=COLORS["ink_soft"], width=2)
    draw.line((193, 110, 226, 129), fill=COLORS["ink_soft"], width=2)
    draw.line((205, 48, 230, 57, 257, 53), fill=COLORS["river"], width=3)
    draw.line((204, 54, 231, 63, 258, 59), fill=COLORS["deep_teal"], width=1)
    draw.rectangle((68, 75, 84, 92), outline=COLORS["green"], width=2)
    draw.rectangle((179, 56, 199, 73), outline=COLORS["ink"], width=2)
    draw.rectangle((112, 101, 130, 118), outline=COLORS["red"], width=2)
    draw.rectangle((230, 112, 253, 134), outline=COLORS["wheat"], width=2)
    draw.rectangle((132, 64, 154, 78), outline=COLORS["amber_dim"], width=2)
    draw.rectangle((158, 116, 181, 132), outline=COLORS["ink_soft"], width=2)

    # Compass and worn paper ticks.
    draw.line((246, 42, 246, 62), fill=COLORS["ink"], width=1)
    draw.line((236, 52, 256, 52), fill=COLORS["ink"], width=1)
    draw.polygon([(246, 39), (243, 48), (249, 48)], fill=COLORS["amber"])
    for x, y in [(56, 49), (92, 137), (207, 137), (263, 77), (137, 41), (67, 111)]:
        draw.rectangle((x, y, x + 3, y + 1), fill=COLORS["paper_light"])

    return image


def blank_marker() -> Image.Image:
    return Image.new("RGBA", MARKER_SIZE, COLORS["transparent"])


def outline_rect(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], fill: str, outline: str = "ink") -> None:
    draw.rectangle(box, fill=COLORS[fill], outline=COLORS[outline])


def draw_home() -> Image.Image:
    image = blank_marker()
    draw = ImageDraw.Draw(image, "RGBA")
    draw.polygon([(5, 12), (12, 5), (19, 12)], fill=COLORS["ink"])
    draw.polygon([(7, 12), (12, 7), (17, 12)], fill=COLORS["wood"])
    outline_rect(draw, (7, 12, 17, 20), "paper_dark")
    outline_rect(draw, (10, 14, 14, 20), "amber")
    draw.rectangle((6, 6, 8, 9), fill=COLORS["amber"])
    return image


def draw_mushroom_forest() -> Image.Image:
    image = blank_marker()
    draw = ImageDraw.Draw(image, "RGBA")
    draw.rectangle((10, 11, 13, 19), fill=COLORS["paper_light"])
    draw.rectangle((6, 12, 9, 18), fill=COLORS["paper"])
    draw.rectangle((15, 13, 18, 19), fill=COLORS["paper"])
    draw.ellipse((5, 5, 15, 13), fill=COLORS["ink"])
    draw.ellipse((6, 5, 16, 12), fill=COLORS["green"])
    draw.rectangle((10, 8, 12, 9), fill=COLORS["paper_light"])
    draw.ellipse((13, 8, 20, 14), fill=COLORS["ink"])
    draw.ellipse((12, 7, 20, 13), fill=COLORS["green"])
    return image


def draw_dark_river() -> Image.Image:
    image = blank_marker()
    draw = ImageDraw.Draw(image, "RGBA")
    for y in (8, 12, 16):
        draw.line((3, y, 7, y - 2, 12, y, 17, y - 2, 21, y), fill=COLORS["ink"], width=3)
        draw.line((3, y - 1, 7, y - 3, 12, y - 1, 17, y - 3, 21, y - 1), fill=COLORS["river"], width=1)
    draw.rectangle((8, 18, 11, 20), fill=COLORS["teal"])
    return image


def draw_grape_trellis() -> Image.Image:
    image = blank_marker()
    draw = ImageDraw.Draw(image, "RGBA")
    draw.line((5, 5, 19, 19), fill=COLORS["ink"], width=2)
    draw.line((6, 5, 19, 18), fill=COLORS["green"], width=1)
    for x, y in [(10, 8), (14, 8), (8, 12), (12, 12), (16, 12), (10, 16), (14, 16)]:
        draw.rectangle((x - 2, y - 2, x + 1, y + 1), fill=COLORS["ink"])
        draw.rectangle((x - 1, y - 1, x + 1, y + 1), fill=COLORS["red"])
    return image


def draw_mill_farm() -> Image.Image:
    image = blank_marker()
    draw = ImageDraw.Draw(image, "RGBA")
    outline_rect(draw, (9, 11, 15, 20), "paper_dark")
    draw.line((12, 4, 12, 18), fill=COLORS["ink"], width=2)
    draw.line((5, 11, 19, 11), fill=COLORS["ink"], width=2)
    draw.line((7, 6, 17, 16), fill=COLORS["wheat"], width=1)
    draw.line((17, 6, 7, 16), fill=COLORS["wheat"], width=1)
    draw.rectangle((4, 18, 20, 20), fill=COLORS["wheat"])
    return image


def draw_mercenary_board() -> Image.Image:
    image = blank_marker()
    draw = ImageDraw.Draw(image, "RGBA")
    outline_rect(draw, (5, 6, 19, 17), "wood")
    outline_rect(draw, (8, 8, 16, 15), "paper_light")
    draw.rectangle((11, 4, 13, 7), fill=COLORS["ink"])
    draw.line((9, 11, 15, 11), fill=COLORS["ink_soft"], width=1)
    draw.line((9, 13, 13, 13), fill=COLORS["ink_soft"], width=1)
    draw.rectangle((6, 18, 8, 21), fill=COLORS["ink"])
    draw.rectangle((16, 18, 18, 21), fill=COLORS["ink"])
    return image


def draw_abandoned_mine() -> Image.Image:
    image = blank_marker()
    draw = ImageDraw.Draw(image, "RGBA")
    draw.polygon([(3, 20), (5, 10), (12, 4), (19, 10), (21, 20)], fill=COLORS["ink"])
    draw.polygon([(6, 19), (8, 11), (12, 8), (16, 11), (18, 19)], fill=COLORS["deep_teal"])
    draw.line((8, 12, 16, 12), fill=COLORS["wood"], width=2)
    draw.line((9, 12, 7, 19), fill=COLORS["wood"], width=2)
    draw.line((15, 12, 17, 19), fill=COLORS["wood"], width=2)
    draw.rectangle((10, 15, 14, 19), fill=COLORS["void"])
    return image


def draw_guild_counter() -> Image.Image:
    image = blank_marker()
    draw = ImageDraw.Draw(image, "RGBA")
    outline_rect(draw, (5, 12, 19, 19), "wood")
    outline_rect(draw, (7, 8, 17, 13), "paper_light")
    draw.rectangle((9, 10, 15, 11), fill=COLORS["ink_soft"])
    draw.rectangle((10, 4, 14, 8), fill=COLORS["amber"])
    draw.rectangle((11, 5, 13, 7), fill=COLORS["ink"])
    draw.rectangle((7, 19, 9, 21), fill=COLORS["ink"])
    draw.rectangle((15, 19, 17, 21), fill=COLORS["ink"])
    return image


MARKER_BUILDERS = {
    "home": draw_home,
    "mushroom_forest": draw_mushroom_forest,
    "dark_river": draw_dark_river,
    "grape_trellis": draw_grape_trellis,
    "mill_farm": draw_mill_farm,
    "mercenary_board": draw_mercenary_board,
    "abandoned_mine": draw_abandoned_mine,
    "guild_counter": draw_guild_counter,
}


def build_sources() -> dict[str, Image.Image]:
    sources = {"daymap_bg": draw_background()}
    for marker in MARKERS:
        sources[f"markers/{marker}"] = MARKER_BUILDERS[marker]()
    return sources


def validate_sources(sources: dict[str, Image.Image]) -> None:
    bg = sources["daymap_bg"].convert("RGBA")
    if bg.size != BG_SIZE:
        raise ValueError(f"daymap_bg: expected {BG_SIZE}, got {bg.size}")
    if bg.getchannel("A").getextrema()[0] < 250:
        raise ValueError("daymap_bg: expected opaque native background")
    if color_count(bg) > 64:
        raise ValueError("daymap_bg: too many native colors")

    for marker in MARKERS:
        name = f"markers/{marker}"
        image = sources[name].convert("RGBA")
        if image.size != MARKER_SIZE:
            raise ValueError(f"{name}: expected {MARKER_SIZE}, got {image.size}")
        alpha_extrema = image.getchannel("A").getextrema()
        if alpha_extrema[0] != 0 or alpha_extrema[1] == 0:
            raise ValueError(f"{name}: expected transparent and visible pixels")
        if visible_pixel_count(image) < 30:
            raise ValueError(f"{name}: too few visible pixels")
        if color_count(image) > 16:
            raise ValueError(f"{name}: too many native colors")


def build_runtimes(sources: dict[str, Image.Image]) -> dict[str, Image.Image]:
    runtimes: dict[str, Image.Image] = {}
    for name, source in sources.items():
        target_size = RUNTIME_BG_SIZE if name == "daymap_bg" else RUNTIME_MARKER_SIZE
        runtimes[name] = source.resize(target_size, Image.Resampling.NEAREST)
    return runtimes


def validate_runtime_images(sources: dict[str, Image.Image], runtimes: dict[str, Image.Image]) -> None:
    for name, source in sources.items():
        target_size = RUNTIME_BG_SIZE if name == "daymap_bg" else RUNTIME_MARKER_SIZE
        runtime = runtimes[name]
        expected = source.resize(target_size, Image.Resampling.NEAREST)
        if runtime.size != target_size:
            raise ValueError(f"{name}: wrong runtime size {runtime.size}")
        if runtime.mode != expected.mode or runtime.tobytes() != expected.tobytes():
            raise ValueError(f"{name}: runtime is not an exact nearest-neighbor export")


def source_path(name: str) -> Path:
    if name == "daymap_bg":
        return SOURCE / "daymap_bg_native.png"
    return SOURCE / f"{name}_native.png"


def runtime_path(name: str) -> Path:
    if name == "daymap_bg":
        return RUNTIME / "daymap_bg.png"
    return RUNTIME / f"{name}.png"


def save_outputs(sources: dict[str, Image.Image], runtimes: dict[str, Image.Image]) -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    SOURCE_MARKERS.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    RUNTIME_MARKERS.mkdir(parents=True, exist_ok=True)
    for name, source in sources.items():
        source.save(source_path(name))
        runtimes[name].save(runtime_path(name))
        print(f"{name}: {source.size} -> {runtimes[name].size}")


def main() -> None:
    sources = build_sources()
    validate_sources(sources)
    runtimes = build_runtimes(sources)
    validate_runtime_images(sources, runtimes)
    save_outputs(sources, runtimes)


if __name__ == "__main__":
    main()
