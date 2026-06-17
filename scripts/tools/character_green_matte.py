from __future__ import annotations

from collections import deque

from PIL import Image


EDGE_OFFSETS = [
    (-1, 0),
    (1, 0),
    (0, -1),
    (0, 1),
    (-1, -1),
    (1, -1),
    (-1, 1),
    (1, 1),
]


def flattened_pixels(image: Image.Image):
    if hasattr(image, "get_flattened_data"):
        return image.get_flattened_data()
    return image.getdata()


def is_dark_green_screen_fringe(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    return alpha > 0 and green >= 24 and green > red + 6 and green > blue + 4


def has_transparent_neighbor(transparent: list[list[bool]], x: int, y: int) -> bool:
    height = len(transparent)
    width = len(transparent[0]) if height else 0
    for dx, dy in EDGE_OFFSETS:
        xx = x + dx
        yy = y + dy
        if 0 <= xx < width and 0 <= yy < height and transparent[yy][xx]:
            return True
    return False


def neutralized_green_spill(pixel: tuple[int, int, int, int]) -> tuple[int, int, int]:
    red, green, blue, _alpha = pixel
    return (red, min(green, max(red, blue) + 4), blue)


def color_distance(left: tuple[int, int, int], right: tuple[int, int, int]) -> int:
    red_delta = left[0] - right[0]
    green_delta = left[1] - right[1]
    blue_delta = left[2] - right[2]
    return red_delta * red_delta * 2 + green_delta * green_delta * 3 + blue_delta * blue_delta * 2


def replacement_palette(image: Image.Image) -> list[tuple[int, int, int]]:
    palette: list[tuple[int, int, int]] = []
    seen: set[tuple[int, int, int]] = set()
    for red, green, blue, alpha in flattened_pixels(image.convert("RGBA")):
        pixel = (red, green, blue, alpha)
        color = (red, green, blue)
        if alpha > 0 and not is_source_green_spill(pixel) and color not in seen:
            palette.append(color)
            seen.add(color)
    return palette


def nearest_palette_color(
    target: tuple[int, int, int],
    palette: list[tuple[int, int, int]],
) -> tuple[int, int, int]:
    if not palette:
        return target
    return min(palette, key=lambda color: color_distance(color, target))


def is_green_screen_background(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    if alpha == 0:
        return True
    if green >= 170 and green > max(red, blue) * 1.3 and green > max(red, blue) + 36:
        return True
    return (
        green >= 96
        and red <= 150
        and blue <= 150
        and green > red * 1.18
        and green > blue * 1.18
        and green > max(red, blue) + 18
    )


def is_definite_green_screen_key(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    return alpha > 0 and green >= 170 and red <= 96 and blue <= 96 and green > max(red, blue) + 80


def is_source_green_spill(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    if alpha == 0:
        return False
    if max(red, green, blue) <= 40 and green > red and green > blue:
        return True
    if green >= 24 and green > red + 6 and green > blue + 4:
        return True
    return green >= red and green >= blue and green >= 12 and max(red, green, blue) <= 96 and green > min(red, blue) + 3


def flood_fill_green_background(image: Image.Image) -> list[list[bool]]:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    background = [[False for _x in range(rgba.width)] for _y in range(rgba.height)]
    queue: deque[tuple[int, int]] = deque()

    for x in range(rgba.width):
        for y in (0, rgba.height - 1):
            if not background[y][x] and is_green_screen_background(pixels[x, y]):
                background[y][x] = True
                queue.append((x, y))
    for y in range(rgba.height):
        for x in (0, rgba.width - 1):
            if not background[y][x] and is_green_screen_background(pixels[x, y]):
                background[y][x] = True
                queue.append((x, y))

    while queue:
        x, y = queue.popleft()
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            xx = x + dx
            yy = y + dy
            if 0 <= xx < rgba.width and 0 <= yy < rgba.height and not background[yy][xx]:
                if is_green_screen_background(pixels[xx, yy]):
                    background[yy][xx] = True
                    queue.append((xx, yy))
    return background


def distance_to_background(background: list[list[bool]], x: int, y: int, max_distance: int) -> int | None:
    height = len(background)
    width = len(background[0]) if height else 0
    for distance in range(1, max_distance + 1):
        for yy in range(max(0, y - distance), min(height, y + distance + 1)):
            for xx in range(max(0, x - distance), min(width, x + distance + 1)):
                if abs(xx - x) != distance and abs(yy - y) != distance:
                    continue
                if background[yy][xx]:
                    return distance
    return None


def local_replacement_palette(
    image: Image.Image,
    background: list[list[bool]],
    x: int,
    y: int,
    radius: int,
) -> list[tuple[int, int, int]]:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    colors: list[tuple[int, int, int]] = []
    seen: set[tuple[int, int, int]] = set()
    for yy in range(max(0, y - radius), min(rgba.height, y + radius + 1)):
        for xx in range(max(0, x - radius), min(rgba.width, x + radius + 1)):
            if background[yy][xx]:
                continue
            red, green, blue, alpha = pixels[xx, yy]
            color = (red, green, blue)
            if alpha > 0 and not is_source_green_spill((red, green, blue, alpha)) and color not in seen:
                colors.append(color)
                seen.add(color)
    return colors


def has_transparent_within(transparent: list[list[bool]], x: int, y: int, max_distance: int) -> bool:
    height = len(transparent)
    width = len(transparent[0]) if height else 0
    for distance in range(1, max_distance + 1):
        for yy in range(max(0, y - distance), min(height, y + distance + 1)):
            for xx in range(max(0, x - distance), min(width, x + distance + 1)):
                if abs(xx - x) != distance and abs(yy - y) != distance:
                    continue
                if transparent[yy][xx]:
                    return True
    return False


def despill_green_near_alpha(image: Image.Image, spill_radius: int = 1) -> Image.Image:
    rgba = image.convert("RGBA")
    transparent = [
        [rgba.getpixel((x, y))[3] == 0 for x in range(rgba.width)]
        for y in range(rgba.height)
    ]
    palette = replacement_palette(rgba)
    cleaned = rgba.copy()
    source = rgba.load()
    pixels = cleaned.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            pixel = source[x, y]
            if not is_source_green_spill(pixel):
                continue
            if not has_transparent_within(transparent, x, y, spill_radius):
                continue
            red, green, blue = nearest_palette_color(neutralized_green_spill(pixel), palette)
            pixels[x, y] = (red, green, blue, pixel[3])
    return cleaned


def source_level_green_matte(
    image: Image.Image,
    spill_radius: int = 4,
    replacement_radius: int = 6,
) -> Image.Image:
    rgba = image.convert("RGBA")
    background = flood_fill_green_background(rgba)
    source = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            if is_definite_green_screen_key(source[x, y]):
                background[y][x] = True
    global_palette = replacement_palette(rgba)
    cleaned = rgba.copy()
    pixels = cleaned.load()

    for y in range(rgba.height):
        for x in range(rgba.width):
            if background[y][x]:
                pixels[x, y] = (0, 0, 0, 0)
                continue
            pixel = source[x, y]
            if not is_source_green_spill(pixel):
                continue
            if distance_to_background(background, x, y, spill_radius) is None:
                continue
            local_palette = local_replacement_palette(rgba, background, x, y, replacement_radius)
            palette = local_palette or global_palette
            red, green, blue = nearest_palette_color(neutralized_green_spill(pixel), palette)
            pixels[x, y] = (red, green, blue, pixel[3])
    return cleaned


def despill_green_edges(image: Image.Image) -> Image.Image:
    return despill_green_near_alpha(image, spill_radius=1)
