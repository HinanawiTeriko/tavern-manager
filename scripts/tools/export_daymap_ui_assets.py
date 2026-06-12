from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageEnhance, ImageOps


ROOT = Path(__file__).resolve().parents[2]
REFERENCE = ROOT / "assets" / "source" / "daymap" / "reference"
SOURCE = ROOT / "assets" / "source" / "daymap" / "ui"
RUNTIME = ROOT / "assets" / "textures" / "daymap" / "ui"
GENERATED_RAW = ROOT / "art_sources" / "generated_raw" / "daymap"
NATIVE_SIZE = (70, 18)
RUNTIME_SIZE = (280, 72)
LEDGER_NATIVE_SIZE = (33, 11)
LEDGER_RUNTIME_SIZE = (132, 44)
DETAIL_PANEL_NATIVE_SIZE = (80, 120)
DETAIL_PANEL_RUNTIME_SIZE = (320, 480)
RESULT_PANEL_NATIVE_SIZE = (175, 100)
RESULT_PANEL_RUNTIME_SIZE = (700, 400)
TAB_NATIVE_SIZE = (36, 12)
TAB_RUNTIME_SIZE = (144, 48)
SHOP_SQUARE_NATIVE_SIZE = (9, 9)
SHOP_SQUARE_RUNTIME_SIZE = (36, 36)
SHOP_STEPPER_ICON_NATIVE_SIZE = (9, 9)
SHOP_STEPPER_ICON_RUNTIME_SIZE = (36, 36)
SHOP_WIDE_NATIVE_SIZE = (18, 9)
SHOP_WIDE_RUNTIME_SIZE = (72, 36)
SHOP_PANEL_NATIVE_SIZE = (250, 84)
SHOP_PANEL_RUNTIME_SIZE = (1000, 336)
SHOP_BACKDROP_NATIVE_SIZE = (320, 180)
SHOP_BACKDROP_RUNTIME_SIZE = (1280, 720)
DOCUMENT_PANEL_NATIVE_SIZE = (155, 135)
DOCUMENT_PANEL_RUNTIME_SIZE = (620, 540)
SCROLL_TRACK_NATIVE_SIZE = (4, 80)
SCROLL_TRACK_RUNTIME_SIZE = (16, 320)
SCROLL_GRABBER_NATIVE_SIZE = (4, 16)
SCROLL_GRABBER_RUNTIME_SIZE = (16, 64)
TOPBAR_NATIVE_SIZE = (320, 15)
TOPBAR_RUNTIME_SIZE = (1280, 60)
PINNED_NOTE_PANEL_NATIVE_SIZE = (92, 96)
PINNED_NOTE_PANEL_RUNTIME_SIZE = (368, 384)
PINNED_NOTE_KNIFE_NATIVE_SIZE = (28, 28)
PINNED_NOTE_KNIFE_RUNTIME_SIZE = (112, 112)
PINNED_NOTE_CONTACT_SHEET = ROOT / "docs" / "ui" / "previews" / "daymap_pinned_note_contact_sheet.png"
DAYMAP_UI_MANIFEST = SOURCE / "daymap_ui_manifest.json"

PRIMARY_BUTTONS_REFERENCE = REFERENCE / "daymap_ui_primary_buttons_reference_v2_generated.png"
LEDGER_BUTTONS_REFERENCE = REFERENCE / "daymap_ui_ledger_buttons_reference_v2_generated.png"
TAB_BUTTONS_REFERENCE = REFERENCE / "daymap_ui_tab_buttons_reference_v2_generated.png"
SHOP_BUTTONS_REFERENCE = REFERENCE / "daymap_ui_shop_buttons_reference_v2_generated.png"
SHOP_ATLAS_REFERENCE = REFERENCE / "daymap_ui_shop_atlas_reference_v3_generated.png"
SHOP_STEPPER_ICONS_REFERENCE = REFERENCE / "daymap_ui_shop_stepper_icons_reference_v1_generated.png"
PANELS_REFERENCE = REFERENCE / "daymap_ui_panels_reference_v2_generated.png"
TOPBAR_REFERENCE = REFERENCE / "daymap_ui_topbar_reference_v2_generated.png"
PINNED_NOTE_PIERCED_SOURCE = GENERATED_RAW / "pinned_note_pierced_source.png"
PINNED_NOTE_PANEL_CROP = (80, 60, 1120, 1148)
PINNED_NOTE_KNIFE_CROP = (80, 60, 520, 540)
PARCHMENT_PALETTE = [
    (112, 78, 48),
    (124, 88, 52),
    (122, 82, 46),
    (140, 96, 54),
    (158, 111, 62),
    (178, 128, 74),
    (196, 147, 86),
    (216, 169, 101),
]
DARK_TEAL_PALETTE = [
    (6, 20, 22),
    (8, 25, 29),
    (11, 31, 35),
    (17, 45, 49),
    (28, 69, 69),
    (39, 82, 78),
]
AMBER_PALETTE = [
    (120, 52, 6),
    (166, 82, 10),
    (207, 117, 18),
    (224, 136, 25),
    (245, 165, 32),
]
BLADE_PALETTE = [
    (58, 65, 65),
    (86, 96, 94),
    (118, 133, 127),
    (156, 174, 164),
    (190, 208, 194),
]
DARK_INK = (6, 20, 22, 255)
DARK_BODY = (8, 25, 29, 255)
DARK_LIFT = (17, 45, 49, 255)
DARK_EDGE = (5, 17, 20, 255)
PARCHMENT_BODY = (124, 88, 52, 255)
PARCHMENT_LIGHT = (158, 111, 62, 255)
AMBER_NORMAL = (207, 117, 18, 255)
AMBER_HOVER = (245, 165, 32, 255)
AMBER_PRESSED = (166, 82, 10, 255)
WOOD_DARK = (93, 59, 34, 255)
WOOD_BODY = (112, 78, 48, 255)
WOOD_LIGHT = (140, 96, 54, 255)
CLAY_BODY = (124, 88, 52, 255)
CLAY_LIGHT = (158, 111, 62, 255)


def load_reference(path: Path) -> Image.Image:
    if not path.exists():
        raise FileNotFoundError(f"Missing DayMap UI reference: {path}")
    with Image.open(path) as image:
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


def trim_to_alpha(image: Image.Image) -> Image.Image:
    box = image.getchannel("A").getbbox()
    if box is None:
        raise ValueError("DayMap UI reference cell is empty after chroma-key removal")
    return image.crop(box)


def dominant_alpha_component(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    alpha = rgba.getchannel("A")
    alpha_pixels = alpha.load()
    visited = bytearray(width * height)
    best_count = 0
    best_box: tuple[int, int, int, int] | None = None

    for start_y in range(height):
        for start_x in range(width):
            offset = start_y * width + start_x
            if visited[offset] or alpha_pixels[start_x, start_y] == 0:
                visited[offset] = 1
                continue

            stack = [(start_x, start_y)]
            visited[offset] = 1
            count = 0
            min_x = max_x = start_x
            min_y = max_y = start_y

            while stack:
                x, y = stack.pop()
                count += 1
                min_x = min(min_x, x)
                max_x = max(max_x, x)
                min_y = min(min_y, y)
                max_y = max(max_y, y)
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if nx < 0 or nx >= width or ny < 0 or ny >= height:
                        continue
                    next_offset = ny * width + nx
                    if visited[next_offset]:
                        continue
                    visited[next_offset] = 1
                    if alpha_pixels[nx, ny] > 0:
                        stack.append((nx, ny))

            if count > best_count:
                best_count = count
                best_box = (min_x, min_y, max_x + 1, max_y + 1)

    if best_box is None:
        raise ValueError("DayMap UI reference cell has no alpha component")
    return rgba.crop(best_box)


def alpha_component_boxes(image: Image.Image, min_pixels: int = 256) -> list[tuple[int, int, int, int, int]]:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    alpha = rgba.getchannel("A")
    alpha_pixels = alpha.load()
    visited = bytearray(width * height)
    components: list[tuple[int, int, int, int, int]] = []

    for start_y in range(height):
        for start_x in range(width):
            offset = start_y * width + start_x
            if visited[offset] or alpha_pixels[start_x, start_y] == 0:
                visited[offset] = 1
                continue

            stack = [(start_x, start_y)]
            visited[offset] = 1
            count = 0
            min_x = max_x = start_x
            min_y = max_y = start_y

            while stack:
                x, y = stack.pop()
                count += 1
                min_x = min(min_x, x)
                max_x = max(max_x, x)
                min_y = min(min_y, y)
                max_y = max(max_y, y)
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if nx < 0 or nx >= width or ny < 0 or ny >= height:
                        continue
                    next_offset = ny * width + nx
                    if visited[next_offset]:
                        continue
                    visited[next_offset] = 1
                    if alpha_pixels[nx, ny] > 0:
                        stack.append((nx, ny))

            if count >= min_pixels:
                components.append((min_x, min_y, max_x + 1, max_y + 1, count))

    return components


def extract_panel_components(sheet: Image.Image) -> list[Image.Image]:
    keyed = remove_green_key(sheet)
    components = alpha_component_boxes(keyed, 1024)
    if len(components) < 2:
        raise ValueError("DayMap panel reference must contain two complete alpha components")
    largest = sorted(components, key=lambda box: box[4], reverse=True)[:2]
    ordered = sorted(largest, key=lambda box: box[0])
    return [keyed.crop(box[:4]).convert("RGBA") for box in ordered]


def clear_transparent_pixels(image: Image.Image) -> Image.Image:
    out = image.convert("RGBA")
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            if pixels[x, y][3] == 0:
                pixels[x, y] = (0, 0, 0, 0)
    return out


def fill_rect(image: Image.Image, box: tuple[int, int, int, int], color: tuple[int, int, int, int]) -> None:
    pixels = image.load()
    left, top, right, bottom = box
    for y in range(max(0, top), min(image.height, bottom)):
        for x in range(max(0, left), min(image.width, right)):
            pixels[x, y] = color


def set_pixel(image: Image.Image, x: int, y: int, color: tuple[int, int, int, int]) -> None:
    if 0 <= x < image.width and 0 <= y < image.height:
        image.putpixel((x, y), color)


def make_primary_button_native(state: str) -> Image.Image:
    image = Image.new("RGBA", NATIVE_SIZE, (0, 0, 0, 0))
    amber = AMBER_HOVER if state == "hover" else AMBER_PRESSED if state == "pressed" else AMBER_NORMAL
    body = (11, 31, 35, 255) if state == "hover" else DARK_BODY
    shadow_offset = 1 if state == "pressed" else 0

    fill_rect(image, (4, 0 + shadow_offset, 66, 18), DARK_EDGE)
    fill_rect(image, (2, 3 + shadow_offset, 68, 15), DARK_EDGE)
    fill_rect(image, (5, 2 + shadow_offset, 65, 15), body)
    fill_rect(image, (8, 4 + shadow_offset, 62, 13), DARK_LIFT)
    fill_rect(image, (10, 6 + shadow_offset, 60, 12), body)

    fill_rect(image, (9, 3 + shadow_offset, 61, 4 + shadow_offset), amber)
    fill_rect(image, (11, 14 + shadow_offset, 59, 15 + shadow_offset), amber)
    fill_rect(image, (7, 5 + shadow_offset, 9, 8 + shadow_offset), amber)
    fill_rect(image, (61, 5 + shadow_offset, 63, 8 + shadow_offset), amber)
    fill_rect(image, (14, 5 + shadow_offset, 22, 6 + shadow_offset), (28, 69, 69, 255))
    fill_rect(image, (42, 11 + shadow_offset, 56, 12 + shadow_offset), (28, 69, 69, 255))

    for x, y in [(2, 3), (3, 1), (67, 3), (66, 1), (3, 15), (66, 15), (6, 17), (63, 17)]:
        set_pixel(image, x, min(image.height - 1, y + shadow_offset), DARK_EDGE)
    for x, y in [(5, 5), (64, 5), (5, 12), (64, 12)]:
        set_pixel(image, x, min(image.height - 1, y + shadow_offset), amber)
    return image


def make_ledger_button_native(state: str) -> Image.Image:
    image = Image.new("RGBA", LEDGER_NATIVE_SIZE, (0, 0, 0, 0))
    amber = AMBER_HOVER if state == "hover" else AMBER_PRESSED if state == "pressed" else AMBER_NORMAL
    body = (11, 31, 35, 255) if state == "hover" else DARK_BODY
    page = (140, 96, 54, 255) if state == "pressed" else PARCHMENT_LIGHT if state == "hover" else PARCHMENT_BODY
    page_light = (178, 128, 74, 255) if state == "hover" else PARCHMENT_LIGHT
    page_shadow = (93, 59, 34, 255)
    page_rule = (115, 88, 45, 255)
    spine_highlight = (39, 82, 78, 255)

    fill_rect(image, (2, 0, 31, 11), DARK_EDGE)
    fill_rect(image, (1, 2, 32, 10), DARK_EDGE)
    fill_rect(image, (3, 1, 30, 10), body)
    fill_rect(image, (4, 2, 9, 9), DARK_LIFT)
    fill_rect(image, (5, 3, 7, 8), spine_highlight)

    fill_rect(image, (8, 2, 25, 9), page)
    fill_rect(image, (9, 3, 15, 8), page_light)
    fill_rect(image, (17, 3, 24, 8), PARCHMENT_BODY)
    fill_rect(image, (16, 2, 17, 9), page_shadow)
    for y in [4, 6]:
        fill_rect(image, (10, y, 15, y + 1), page_rule)
        fill_rect(image, (18, y, 24, y + 1), page_rule)

    fill_rect(image, (25, 2, 30, 9), amber)
    fill_rect(image, (26, 3, 29, 8), AMBER_HOVER if state == "hover" else AMBER_NORMAL)
    fill_rect(image, (30, 2, 31, 9), DARK_LIFT)
    for x, y in [(4, 2), (4, 8), (29, 2), (29, 8)]:
        set_pixel(image, x, y, AMBER_HOVER if state == "hover" else AMBER_NORMAL)
    for x, y in [(6, 4), (6, 6), (11, 3), (21, 7), (27, 5)]:
        set_pixel(image, x, y, (245, 165, 32, 255) if state == "hover" else (224, 136, 25, 255))
    set_pixel(image, 1, 0, (0, 0, 0, 0))
    set_pixel(image, 32, 0, (0, 0, 0, 0))
    set_pixel(image, 0, 10, (0, 0, 0, 0))
    set_pixel(image, 32, 10, (0, 0, 0, 0))
    return image


def make_document_panel_native() -> Image.Image:
    image = Image.new("RGBA", DOCUMENT_PANEL_NATIVE_SIZE, (0, 0, 0, 0))
    width, height = image.size
    fill_rect(image, (0, 0, width, height), DARK_EDGE)
    fill_rect(image, (2, 2, width - 2, height - 2), DARK_BODY)
    fill_rect(image, (5, 5, width - 5, height - 5), DARK_LIFT)
    fill_rect(image, (10, 20, width - 10, height - 14), DARK_BODY)

    left_page = (13, 24, 75, 104)
    right_page = (80, 24, 142, 104)
    for box in [left_page, right_page]:
        fill_rect(image, box, PARCHMENT_BODY)
        fill_rect(image, (box[0] + 2, box[1] + 2, box[2] - 2, box[3] - 2), PARCHMENT_LIGHT)
        fill_rect(image, (box[0] + 5, box[1] + 8, box[2] - 5, box[3] - 8), (140, 96, 54, 255))
        for y in range(box[1] + 13, box[3] - 10, 9):
            fill_rect(image, (box[0] + 7, y, box[2] - 7, y + 1), (112, 78, 48, 255))
    fill_rect(image, (76, 24, 79, 104), (93, 59, 34, 255))
    fill_rect(image, (78, 24, 80, 104), DARK_EDGE)
    fill_rect(image, (18, 12, width - 18, 13), AMBER_NORMAL)
    fill_rect(image, (18, height - 13, width - 18, height - 12), AMBER_PRESSED)
    for x, y in [(6, 6), (width - 7, 6), (6, height - 7), (width - 7, height - 7)]:
        set_pixel(image, x, y, AMBER_HOVER)
    for x in range(27, width - 27, 18):
        set_pixel(image, x, 9, AMBER_HOVER)
        set_pixel(image, x + 4, height - 9, AMBER_NORMAL)
    return image


def palette_pick(palette: list[tuple[int, int, int]], luma: float) -> tuple[int, int, int]:
    index = min(len(palette) - 1, max(0, int((luma / 256.0) * len(palette))))
    return palette[index]


def harmonize_ui_palette(image: Image.Image, profile: str = "default") -> Image.Image:
    out = image.convert("RGBA")
    pixels = out.load()
    visible_lumas: list[float] = []
    for y in range(out.height):
        for x in range(out.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha > 0:
                visible_lumas.append(red * 0.32 + green * 0.42 + blue * 0.26)

    accent_cutoff: float | None = None
    if visible_lumas and profile in ["ledger", "topbar"]:
        ordered = sorted(visible_lumas)
        quantile = 0.975 if profile == "ledger" else 0.985
        accent_cutoff = ordered[min(len(ordered) - 1, int((len(ordered) - 1) * quantile))]

    if profile == "ledger":
        parchment_threshold = 42.0
    elif profile == "panel":
        parchment_threshold = 55.0
    elif profile == "symbol":
        parchment_threshold = 999.0
    else:
        parchment_threshold = 72.0

    for y in range(out.height):
        for x in range(out.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                continue
            luma = red * 0.32 + green * 0.42 + blue * 0.26
            amberish = red >= 180 and 78 <= green <= 138 and blue <= 70 and red > blue * 2.0
            symbol_accent = (
                profile == "symbol"
                and luma >= 44.0
                and red >= 95
                and green >= 45
                and blue <= 120
                and red > blue * 1.45
            )
            scroll_accent = (
                profile == "scroll"
                and luma >= 92.0
                and red >= 85
                and green >= 45
                and blue <= 95
                and red > blue * 1.35
            )
            topbar_accent = profile == "topbar" and luma >= 55.0 and red >= green * 0.85
            source_highlight_accent = accent_cutoff is not None and luma >= accent_cutoff
            if symbol_accent or scroll_accent or (amberish and profile != "panel") or topbar_accent or source_highlight_accent:
                pixels[x, y] = (*palette_pick(AMBER_PALETTE, luma), alpha)
            elif profile == "topbar":
                pixels[x, y] = (*palette_pick(DARK_TEAL_PALETTE, min(255.0, luma * 4.5)), alpha)
            elif luma >= parchment_threshold:
                pixels[x, y] = (*palette_pick(PARCHMENT_PALETTE, luma), alpha)
            else:
                pixels[x, y] = (*palette_pick(DARK_TEAL_PALETTE, luma), alpha)
    return clear_transparent_pixels(out)


def crop_explicit_source(
    image: Image.Image,
    box: tuple[int, int, int, int],
    label: str,
) -> Image.Image:
    left, top, right, bottom = box
    if left < 0 or top < 0 or right > image.width or bottom > image.height or left >= right or top >= bottom:
        raise ValueError(f"{label}: crop {box} is outside source size {image.size}")
    return image.crop(box).convert("RGBA")


def harmonize_pinned_note_palette(image: Image.Image) -> Image.Image:
    out = image.convert("RGBA")
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                continue
            luma = red * 0.32 + green * 0.42 + blue * 0.26
            amberish = (
                red >= 178
                and 55 <= green <= 150
                and blue <= 84
                and red >= green * 1.42
                and red > blue * 2.0
            )
            metal = (
                abs(red - green) <= 44
                and abs(green - blue) <= 54
                and blue >= red * 0.70
                and luma >= 42.0
                and not amberish
            )
            wood = (
                58 <= red <= 150
                and 28 <= green <= 105
                and blue <= 82
                and red >= green * 1.05
                and green >= blue * 1.05
            )
            if metal:
                pixels[x, y] = (*palette_pick(BLADE_PALETTE, min(255.0, luma * 1.08)), alpha)
            elif amberish or wood:
                pixels[x, y] = (*palette_pick(AMBER_PALETTE if luma >= 96.0 else PARCHMENT_PALETTE, luma), alpha)
            elif luma >= 74.0:
                pixels[x, y] = (*palette_pick(PARCHMENT_PALETTE, luma), alpha)
            else:
                pixels[x, y] = (*palette_pick(DARK_TEAL_PALETTE, luma), alpha)
    return clear_transparent_pixels(out)


def fit_pinned_note_source(
    source: Image.Image,
    crop: tuple[int, int, int, int],
    native_size: tuple[int, int],
    label: str,
    fill: bool = True,
) -> Image.Image:
    cropped = crop_explicit_source(source, crop, label)
    keyed = remove_green_key(cropped)
    if fill:
        fitted = ImageOps.fit(
            keyed,
            native_size,
            method=Image.Resampling.LANCZOS,
            centering=(0.5, 0.5),
        ).convert("RGBA")
    else:
        fitted = ImageOps.contain(
            keyed,
            native_size,
            method=Image.Resampling.LANCZOS,
        ).convert("RGBA")
        canvas = Image.new("RGBA", native_size, (0, 0, 0, 0))
        canvas.alpha_composite(fitted, ((native_size[0] - fitted.width) // 2, (native_size[1] - fitted.height) // 2))
        fitted = canvas
    fitted = ImageEnhance.Contrast(fitted).enhance(1.08)
    alpha = fitted.getchannel("A").point(lambda value: 255 if value >= 28 else 0)
    fitted.putalpha(alpha)
    return harmonize_pinned_note_palette(clear_transparent_pixels(fitted))


def fit_ui_source(
    image: Image.Image,
    native_size: tuple[int, int],
    colors: int = 18,
    profile: str = "default",
    fill: bool = False,
    isolate: bool = False,
    horizontal_pad: int = 0,
) -> Image.Image:
    keyed = remove_green_key(image)
    trimmed = trim_to_alpha(keyed)
    if isolate:
        trimmed = dominant_alpha_component(trimmed)
    if fill:
        fitted_size = (max(1, native_size[0] - horizontal_pad * 2), native_size[1])
        fitted = trimmed.resize(fitted_size, Image.Resampling.LANCZOS).convert("RGBA")
    else:
        fitted = ImageOps.contain(trimmed, native_size, method=Image.Resampling.LANCZOS).convert("RGBA")
    canvas = Image.new("RGBA", native_size, (0, 0, 0, 0))
    canvas.alpha_composite(fitted, ((native_size[0] - fitted.width) // 2, (native_size[1] - fitted.height) // 2))
    canvas = ImageEnhance.Contrast(canvas).enhance(1.06)
    alpha = canvas.getchannel("A").point(lambda value: 255 if value >= 30 else 0)
    out = canvas.convert("RGBA")
    out.putalpha(alpha)
    return harmonize_ui_palette(clear_transparent_pixels(out), profile)


def fit_shop_backdrop_source(image: Image.Image) -> Image.Image:
    fitted = ImageOps.fit(
        image.convert("RGBA"),
        SHOP_BACKDROP_NATIVE_SIZE,
        method=Image.Resampling.NEAREST,
        centering=(0.5, 0.5),
    ).convert("RGBA")
    fitted = ImageEnhance.Contrast(fitted).enhance(1.08)
    out = fitted.convert("RGB").quantize(colors=48).convert("RGBA")
    out.putalpha(Image.new("L", SHOP_BACKDROP_NATIVE_SIZE, 255))
    return out


def fit_shop_button_source(sheet: Image.Image, shape: str, state: str) -> Image.Image:
    state_index = {"normal": 0, "hover": 1, "pressed": 2}[state]
    is_wide = shape == "wide"
    index = state_index + (3 if is_wide else 0)
    native_size = SHOP_WIDE_NATIVE_SIZE if is_wide else SHOP_SQUARE_NATIVE_SIZE
    return fit_ui_source(
        crop_sheet_cell(sheet, 3, 2, index),
        native_size,
        colors=18,
        profile="default",
        fill=True,
    )


def extract_shop_stepper_icons(sheet: Image.Image) -> dict[str, Image.Image]:
    keyed = remove_green_key(sheet)
    components = alpha_component_boxes(keyed, 512)
    if len(components) < 2:
        raise ValueError("Shop stepper icon reference must contain decrement and increment symbols")
    largest = sorted(components, key=lambda box: box[4], reverse=True)[:2]
    ordered = sorted(largest, key=lambda box: box[0])
    return {
        "decrement": keyed.crop(ordered[0][:4]).convert("RGBA"),
        "increment": keyed.crop(ordered[1][:4]).convert("RGBA"),
    }


def fit_shop_stepper_icon_source(icons: dict[str, Image.Image], kind: str) -> Image.Image:
    return fit_ui_source(
        icons[kind],
        SHOP_STEPPER_ICON_NATIVE_SIZE,
        colors=12,
        profile="symbol",
        isolate=True,
    )


def fit_shop_panel_source(panel: Image.Image) -> Image.Image:
    return fit_ui_source(
        panel,
        SHOP_PANEL_NATIVE_SIZE,
        colors=28,
        profile="panel",
        fill=True,
    )


def fit_shop_scroll_track_source(panel: Image.Image) -> Image.Image:
    strip_width = max(1, panel.width // 7)
    strip = panel.crop((0, 0, strip_width, panel.height)).convert("RGBA")
    return fit_ui_source(
        strip,
        SCROLL_TRACK_NATIVE_SIZE,
        colors=12,
        profile="scroll",
        fill=True,
    )


def fit_shop_scroll_grabber_source(panel: Image.Image) -> Image.Image:
    corner = panel.crop((0, 0, max(1, panel.width // 7), max(1, panel.height // 3))).convert("RGBA")
    return fit_ui_source(
        corner,
        SCROLL_GRABBER_NATIVE_SIZE,
        colors=12,
        profile="scroll",
        fill=True,
    )


def fit_topbar_source(image: Image.Image) -> Image.Image:
    keyed = remove_green_key(image)
    trimmed = trim_to_alpha(keyed)
    fitted = ImageOps.fit(
        trimmed,
        TOPBAR_NATIVE_SIZE,
        method=Image.Resampling.LANCZOS,
        centering=(0.5, 0.5),
    ).convert("RGBA")
    canvas = Image.new("RGBA", TOPBAR_NATIVE_SIZE, (0, 0, 0, 0))
    canvas.alpha_composite(fitted, (0, 0))
    canvas = ImageEnhance.Contrast(canvas).enhance(1.08)
    alpha = canvas.getchannel("A").point(lambda value: 255 if value >= 28 else 0)
    out = canvas.convert("RGBA")
    out.putalpha(alpha)
    out = harmonize_ui_palette(clear_transparent_pixels(out), "topbar")
    pixels = out.load()
    for x in range(out.width):
        if pixels[x, 0][3] == 0:
            pixels[x, 0] = DARK_INK
    return out


def export_single(name: str, native: Image.Image, runtime_size: tuple[int, int]) -> None:
    runtime = native.resize(runtime_size, Image.Resampling.NEAREST)
    native.save(SOURCE / f"{name}_native.png")
    runtime.save(RUNTIME / f"{name}.png")
    print(f"{name}: {native.size} -> {runtime.size}")


def export_pinned_note_contact_sheet(panel: Image.Image, knife: Image.Image) -> None:
    PINNED_NOTE_CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    panel_runtime = panel.resize(PINNED_NOTE_PANEL_RUNTIME_SIZE, Image.Resampling.NEAREST)
    knife_runtime = knife.resize(PINNED_NOTE_KNIFE_RUNTIME_SIZE, Image.Resampling.NEAREST)
    sheet = Image.new("RGBA", (640, 520), (8, 25, 29, 255))
    sheet.alpha_composite(panel_runtime, (136, 32))
    sheet.alpha_composite(knife_runtime, (44, 76))
    native_preview = panel.resize((184, 192), Image.Resampling.NEAREST)
    knife_preview = knife.resize((72, 72), Image.Resampling.NEAREST)
    sheet.alpha_composite(native_preview, (20, 300))
    sheet.alpha_composite(knife_preview, (236, 360))
    sheet.save(PINNED_NOTE_CONTACT_SHEET)
    print(f"pinned_note_contact_sheet: {sheet.size}")


def write_pinned_note_manifest() -> None:
    if DAYMAP_UI_MANIFEST.exists():
        manifest = json.loads(DAYMAP_UI_MANIFEST.read_text(encoding="utf-8"))
    else:
        manifest = {"assets": {}}
    assets = manifest.setdefault("assets", {})
    assets["pinned_note_panel"] = {
        "id": "pinned_note_panel",
        "source_file": "art_sources/generated_raw/daymap/pinned_note_pierced_source.png",
        "native_file": "assets/source/daymap/ui/pinned_note_panel_native.png",
        "output_file": "assets/textures/daymap/ui/pinned_note_panel.png",
        "size": [368, 384],
        "source_crop": list(PINNED_NOTE_PANEL_CROP),
        "safe_area": [84, 88, 248, 228],
        "intended_godot_use": "DayMap PinnedNotePanel/NoteArt",
    }
    assets["pinned_note_knife"] = {
        "id": "pinned_note_knife",
        "source_file": "art_sources/generated_raw/daymap/pinned_note_pierced_source.png",
        "native_file": "assets/source/daymap/ui/pinned_note_knife_native.png",
        "output_file": "assets/textures/daymap/ui/pinned_note_knife.png",
        "size": [112, 112],
        "source_crop": list(PINNED_NOTE_KNIFE_CROP),
        "safe_area": [18, 0, 74, 112],
        "intended_godot_use": "DayMap PinnedNotePanel optional KnifeArt compatibility layer",
    }
    DAYMAP_UI_MANIFEST.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"daymap_ui_manifest: {DAYMAP_UI_MANIFEST}")


def main() -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)

    primary = load_reference(PRIMARY_BUTTONS_REFERENCE)
    ledger = load_reference(LEDGER_BUTTONS_REFERENCE)
    tabs = load_reference(TAB_BUTTONS_REFERENCE)
    shop = load_reference(SHOP_BUTTONS_REFERENCE)
    shop_atlas = load_reference(SHOP_ATLAS_REFERENCE)
    stepper_icons = extract_shop_stepper_icons(load_reference(SHOP_STEPPER_ICONS_REFERENCE))
    panels = load_reference(PANELS_REFERENCE)
    topbar = load_reference(TOPBAR_REFERENCE)
    panel_detail, panel_result = extract_panel_components(panels)

    for index, state in enumerate(["normal", "hover", "pressed"]):
        export_single(
            f"button_primary_{state}",
            make_primary_button_native(state),
            RUNTIME_SIZE,
        )
        export_single(
            f"button_ledger_{state}",
            make_ledger_button_native(state),
            LEDGER_RUNTIME_SIZE,
        )
        export_single(
            f"button_shop_square_{state}",
            fit_shop_button_source(shop, "square", state),
            SHOP_SQUARE_RUNTIME_SIZE,
        )
        export_single(
            f"button_shop_wide_{state}",
            fit_shop_button_source(shop, "wide", state),
            SHOP_WIDE_RUNTIME_SIZE,
        )
    export_single(
        "icon_shop_stepper_decrement",
        fit_shop_stepper_icon_source(stepper_icons, "decrement"),
        SHOP_STEPPER_ICON_RUNTIME_SIZE,
    )
    export_single(
        "icon_shop_stepper_increment",
        fit_shop_stepper_icon_source(stepper_icons, "increment"),
        SHOP_STEPPER_ICON_RUNTIME_SIZE,
    )

    export_single("button_tab_normal", fit_ui_source(crop_sheet_cell(tabs, 2, 1, 0), TAB_NATIVE_SIZE, colors=12, fill=True, horizontal_pad=1), TAB_RUNTIME_SIZE)
    export_single("button_tab_selected", fit_ui_source(crop_sheet_cell(tabs, 2, 1, 1), TAB_NATIVE_SIZE, colors=12, fill=True, horizontal_pad=1), TAB_RUNTIME_SIZE)
    export_single(
        "panel_detail",
        fit_ui_source(panel_detail, DETAIL_PANEL_NATIVE_SIZE, colors=28, profile="panel", fill=True),
        DETAIL_PANEL_RUNTIME_SIZE,
    )
    export_single(
        "panel_result",
        fit_ui_source(panel_result, RESULT_PANEL_NATIVE_SIZE, colors=28, profile="panel", fill=True),
        RESULT_PANEL_RUNTIME_SIZE,
    )
    export_single("panel_shop", fit_shop_panel_source(panel_result), SHOP_PANEL_RUNTIME_SIZE)
    export_single("shop_backdrop", fit_shop_backdrop_source(shop_atlas), SHOP_BACKDROP_RUNTIME_SIZE)
    export_single("panel_document", make_document_panel_native(), DOCUMENT_PANEL_RUNTIME_SIZE)
    export_single("scroll_track", fit_shop_scroll_track_source(panel_result), SCROLL_TRACK_RUNTIME_SIZE)
    export_single("scroll_grabber", fit_shop_scroll_grabber_source(panel_result), SCROLL_GRABBER_RUNTIME_SIZE)
    export_single("topbar_strip", fit_topbar_source(topbar), TOPBAR_RUNTIME_SIZE)
    pinned_note_source = load_reference(PINNED_NOTE_PIERCED_SOURCE)
    pinned_note_panel = fit_pinned_note_source(
        pinned_note_source,
        PINNED_NOTE_PANEL_CROP,
        PINNED_NOTE_PANEL_NATIVE_SIZE,
        "pinned_note_panel",
    )
    pinned_note_knife = fit_pinned_note_source(
        pinned_note_source,
        PINNED_NOTE_KNIFE_CROP,
        PINNED_NOTE_KNIFE_NATIVE_SIZE,
        "pinned_note_knife",
        fill=False,
    )
    export_single("pinned_note_panel", pinned_note_panel, PINNED_NOTE_PANEL_RUNTIME_SIZE)
    export_single("pinned_note_knife", pinned_note_knife, PINNED_NOTE_KNIFE_RUNTIME_SIZE)
    export_pinned_note_contact_sheet(pinned_note_panel, pinned_note_knife)
    write_pinned_note_manifest()


if __name__ == "__main__":
    main()
