from pathlib import Path

from PIL import Image, ImageEnhance, ImageOps


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "daymap" / "shop_redesign"
REFERENCE_DIR = SOURCE / "reference"
RUNTIME = ROOT / "assets" / "textures" / "daymap" / "shop_redesign"
SHOP_MASTER_REFERENCE = REFERENCE_DIR / "shop_master_composition_generated.png"
SHOP_CLEAN_REFERENCE = REFERENCE_DIR / "shop_clean_background_reference.png"

SCENE_NATIVE_SIZE = (320, 180)
SCENE_RUNTIME_SIZE = (1280, 720)

DARK_EDGE = (6, 22, 26)
DARK_BODY = (14, 38, 41)
DARK_LIFT = (28, 63, 60)
AMBER_DARK = (119, 69, 28)
AMBER = (178, 103, 38)
AMBER_LIGHT = (222, 143, 46)
PARCHMENT_DIM = (126, 88, 51)
PARCHMENT_LIGHT = (186, 132, 73)
WAX_DARK = (73, 24, 26)
WAX_BODY = (126, 36, 34)
WAX_LIGHT = (171, 55, 38)

CLEAN_LAYER_SPECS = {
    "shop_book": ((38, 45, 286, 149), (992, 416), "book"),
    "bookmark_materials_normal": ((90, 37, 126, 53), (144, 64), "bookmark"),
    "bookmark_materials_selected": ((90, 37, 126, 53), (144, 64), "bookmark"),
    "bookmark_recipes_normal": ((193, 37, 229, 53), (144, 64), "bookmark"),
    "bookmark_recipes_selected": ((193, 37, 229, 53), (144, 64), "bookmark"),
    "bookmark_abilities_normal": ((219, 37, 255, 53), (144, 64), "bookmark"),
    "bookmark_abilities_selected": ((219, 37, 255, 53), (144, 64), "bookmark"),
    "item_row_normal": ((66, 56, 182, 74), (464, 72), "row"),
    "item_row_selected": ((66, 75, 182, 93), (464, 72), "row"),
    "item_row_disabled": ((66, 94, 182, 112), (464, 72), "row"),
    "purchase_seal_normal": ((178, 149, 242, 167), (256, 72), "button"),
    "purchase_seal_pressed": ((178, 149, 242, 167), (256, 72), "button"),
    "purchase_seal_disabled": ((178, 149, 242, 167), (256, 72), "button"),
    "close_tag_normal": ((250, 149, 294, 167), (176, 72), "button"),
    "close_tag_selected": ((250, 149, 294, 167), (176, 72), "button"),
    "quantity_control": ((100, 149, 172, 167), (288, 72), "button"),
    "status_owned": ((169, 130, 209, 144), (160, 56), "status"),
    "status_discount": ((212, 130, 252, 144), (160, 56), "status"),
}


def load_reference(path: Path) -> Image.Image:
    if not path.exists():
        raise FileNotFoundError(f"Missing shop reference art: {path}")
    return Image.open(path).convert("RGBA")


def quantize_rgba(image: Image.Image, colors: int) -> Image.Image:
    alpha = image.getchannel("A")
    quantized = image.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    quantized.putalpha(alpha)
    return quantized


def tint_title_shadows(image: Image.Image) -> Image.Image:
    tinted = image.copy()
    pixels = tinted.load()
    for y in range(tinted.height):
        for x in range(tinted.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha < 220:
                continue
            if red <= 52 and green <= 62 and blue <= 66:
                lift = max(red, green, blue)
                pixels[x, y] = (
                    min(50, max(red, 7 + lift // 5)),
                    min(78, max(green, 24 + lift // 4)),
                    min(85, max(blue, 26 + lift // 4)),
                    alpha,
                )
    return tinted


def mute_parchment(image: Image.Image) -> Image.Image:
    muted = image.copy()
    pixels = muted.load()
    for y in range(muted.height):
        for x in range(muted.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha < 220:
                continue
            if red >= 178 and 118 <= green <= 205 and 55 <= blue <= 145:
                pixels[x, y] = (
                    min(216, red - 14),
                    min(164, green - 14),
                    min(116, blue - 7),
                    alpha,
                )
    return muted


def normalize_reference(reference: Image.Image, resampling: Image.Resampling) -> Image.Image:
    native = ImageOps.fit(
        reference,
        SCENE_NATIVE_SIZE,
        method=resampling,
        centering=(0.5, 0.5),
    ).convert("RGBA")
    native = ImageEnhance.Color(native).enhance(0.84)
    native = ImageEnhance.Contrast(native).enhance(1.10)
    native = ImageEnhance.Brightness(native).enhance(0.94)
    return mute_parchment(tint_title_shadows(quantize_rgba(native, 56)))


def crop_reference(reference: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    return reference.crop(box).convert("RGBA")


def blend(a: tuple[int, int, int], b: tuple[int, int, int], weight: float) -> tuple[int, int, int]:
    return (
        int(a[0] * (1.0 - weight) + b[0] * weight),
        int(a[1] * (1.0 - weight) + b[1] * weight),
        int(a[2] * (1.0 - weight) + b[2] * weight),
    )


def plate_mask(x: int, y: int, width: int, height: int, margin: int = 1, corner: int = 2) -> bool:
    if x < margin or y < margin or x >= width - margin or y >= height - margin:
        return False
    edge_x = min(x - margin, width - margin - 1 - x)
    edge_y = min(y - margin, height - margin - 1 - y)
    return edge_x + edge_y >= corner


def tag_mask(x: int, y: int, width: int, height: int) -> bool:
    if not plate_mask(x, y, width, height, 1, 2):
        return False
    notch_left = width // 2 - 2
    notch_right = width // 2 + 2
    return not (height - 4 <= y < height - 1 and notch_left <= x <= notch_right)


def circle_mask(x: int, y: int, cx: int, cy: int, rx: int, ry: int) -> bool:
    dx = (x - cx) / max(1, rx)
    dy = (y - cy) / max(1, ry)
    return dx * dx + dy * dy <= 1.0


def put_pixel(image: Image.Image, x: int, y: int, color: tuple[int, int, int, int]) -> None:
    if 0 <= x < image.width and 0 <= y < image.height:
        image.putpixel((x, y), color)


def alpha_support(alpha: Image.Image, x: int, y: int) -> int:
    pixels = alpha.load()
    support = 0
    for neighbor_y in range(max(0, y - 1), min(alpha.height, y + 2)):
        for neighbor_x in range(max(0, x - 1), min(alpha.width, x + 2)):
            if neighbor_x == x and neighbor_y == y:
                continue
            if pixels[neighbor_x, neighbor_y] > 0:
                support += 1
    return support


def remove_unsupported_alpha_pixels(image: Image.Image) -> Image.Image:
    cleaned = image.convert("RGBA")
    while True:
        alpha = cleaned.getchannel("A")
        unsupported: list[tuple[int, int]] = []
        for y in range(alpha.height):
            for x in range(alpha.width):
                if alpha.getpixel((x, y)) > 0 and alpha_support(alpha, x, y) <= 1:
                    unsupported.append((x, y))
        if not unsupported:
            return cleaned
        for point in unsupported:
            cleaned.putpixel(point, (0, 0, 0, 0))


def book_edge_layer(master: Image.Image) -> Image.Image:
    layer = Image.new("RGBA", master.size, (0, 0, 0, 0))
    source = master.load()
    pixels = layer.load()
    width, height = master.size
    for y in range(height):
        for x in range(width):
            outer_edge = x < 10 or x >= width - 10 or y < 8 or y >= height - 8
            spine = abs(x - width // 2) <= 5 and y >= 8
            corner_hardware = (x < 18 or x >= width - 18) and (y < 18 or y >= height - 18)
            if not (outer_edge or spine or corner_hardware):
                continue
            red, green, blue, alpha = source[x, y]
            base = (red, green, blue)
            if outer_edge:
                color = blend(base, DARK_EDGE, 0.62)
                out_alpha = 168
            elif corner_hardware:
                color = blend(base, AMBER, 0.46)
                out_alpha = 176
            else:
                color = blend(base, DARK_BODY, 0.52)
                out_alpha = 132
            if (x * 5 + y * 3) % 19 == 0:
                color = blend(color, AMBER_LIGHT, 0.32)
            pixels[x, y] = (color[0], color[1], color[2], out_alpha)
    return quantize_rgba(remove_unsupported_alpha_pixels(layer), 36)


def paint_layer(master: Image.Image, name: str) -> Image.Image:
    layer = Image.new("RGBA", master.size, (0, 0, 0, 0))
    source = master.load()
    pixels = layer.load()
    width, height = master.size
    selected = name.endswith("_selected")
    disabled = name.endswith("_disabled")
    status = name.startswith("status_")
    bookmark = name.startswith("bookmark_")

    for y in range(height):
        for x in range(width):
            if bookmark:
                inside = tag_mask(x, y, width, height)
            else:
                inside = plate_mask(x, y, width, height, 1, 2)
            if not inside:
                continue

            red, green, blue, alpha = source[x, y]
            base = (red, green, blue)
            edge = x < 5 or x >= width - 5 or y < 3 or y >= height - 3
            seam = (x + y * 2) % 17 == 0 and (x < 18 or x > width - 20)
            fleck = (x * 11 + y * 7) % 23 == 0
            if edge:
                if disabled:
                    color = DARK_EDGE if (x + y) % 3 else (37, 48, 45)
                    out_alpha = 174
                elif (x + y) % 4 == 0:
                    color = AMBER
                    out_alpha = 182
                else:
                    color = DARK_EDGE
                    out_alpha = 178
            elif disabled:
                color = blend(base, DARK_EDGE, 0.36)
                out_alpha = 92
            elif selected or status:
                color = blend(base, DARK_LIFT, 0.28)
                out_alpha = 128
            else:
                color = blend(base, DARK_BODY, 0.28)
                out_alpha = 80
            if seam:
                color = blend(color, DARK_EDGE, 0.64)
                out_alpha = max(out_alpha, 148)
            if fleck:
                color = blend(color, AMBER_LIGHT if selected or status else PARCHMENT_DIM, 0.42)
                out_alpha = max(out_alpha, 132)
            pixels[x, y] = (color[0], color[1], color[2], out_alpha)

    if status:
        for x in range(7, width - 7):
            y = height // 2
            put_pixel(layer, x, y, (*AMBER_LIGHT, 168))
            if x % 3 == 0:
                put_pixel(layer, x, max(1, y - 2), (*DARK_EDGE, 148))
    return quantize_rgba(remove_unsupported_alpha_pixels(layer), 40)


def draw_plate(layer: Image.Image, box: tuple[int, int, int, int], colors: tuple[tuple[int, int, int], ...], alpha: int) -> None:
    left, top, right, bottom = box
    width = right - left
    height = bottom - top
    pixels = layer.load()
    for y in range(height):
        for x in range(width):
            if not plate_mask(x, y, width, height, 1, 2):
                continue
            edge = x < 4 or x >= width - 4 or y < 3 or y >= height - 3
            color = colors[0] if edge else colors[1]
            if edge and (x * 3 + y * 5) % 11 == 0:
                color = DARK_LIFT
            elif edge and (x + y) % 7 == 0:
                color = colors[2]
            elif not edge and (x * 13 + y * 5) % 29 == 0:
                color = colors[2]
            elif not edge and (x * 5 + y * 7) % 31 == 0:
                color = AMBER_DARK
            elif not edge and (x * 7 + y * 3) % 37 == 0:
                color = PARCHMENT_LIGHT
            pixels[left + x, top + y] = (color[0], color[1], color[2], alpha if edge else max(72, alpha - 44))


def draw_mark(layer: Image.Image, box: tuple[int, int, int, int], mark: str, color: tuple[int, int, int, int]) -> None:
    left, top, right, bottom = box
    cx = (left + right) // 2
    cy = (top + bottom) // 2
    if mark == "minus":
        for y in range(cy - 1, cy + 2):
            for x in range(cx - 5, cx + 6):
                put_pixel(layer, x, y, color)
    elif mark == "plus":
        for y in range(cy - 5, cy + 6):
            for x in range(cx - 1, cx + 2):
                put_pixel(layer, x, y, color)
        for y in range(cy - 1, cy + 2):
            for x in range(cx - 5, cx + 6):
                put_pixel(layer, x, y, color)


def button_layer(master: Image.Image, name: str) -> Image.Image:
    layer = Image.new("RGBA", master.size, (0, 0, 0, 0))
    pressed = name.endswith("_pressed")
    selected = name.endswith("_selected")
    disabled = name.endswith("_disabled")
    width, height = master.size
    alpha = 218 if selected else 204
    if pressed:
        alpha = 226
    if disabled:
        alpha = 156

    body = DARK_BODY if not disabled else (24, 31, 32)
    lift = DARK_LIFT if not disabled else (45, 49, 48)
    trim = AMBER if not disabled else (87, 77, 61)
    bright = AMBER_LIGHT if not disabled else (113, 98, 70)

    if name == "quantity_control":
        draw_plate(layer, (0, 1, 18, height - 1), (DARK_EDGE, body, trim), alpha)
        draw_plate(layer, (21, 1, 51, height - 1), (DARK_EDGE, (32, 45, 42), PARCHMENT_DIM), alpha - 18)
        draw_plate(layer, (54, 1, width, height - 1), (DARK_EDGE, body, trim), alpha)
        draw_mark(layer, (0, 1, 18, height - 1), "minus", (*bright, 230))
        draw_mark(layer, (54, 1, width, height - 1), "plus", (*bright, 230))
    elif name.startswith("purchase_seal"):
        draw_plate(layer, (0, 1, width, height - 1), (DARK_EDGE, body, trim), alpha)
        seal_cx = width * 5 // 8
        seal_cy = height // 2
        pixels = layer.load()
        for y in range(height):
            for x in range(width):
                if circle_mask(x, y, seal_cx, seal_cy, 10, 7):
                    edge = not circle_mask(x, y, seal_cx, seal_cy, 7, 5)
                    color = WAX_DARK if edge or pressed else WAX_BODY
                    if (x + y) % 7 == 0 and not disabled:
                        color = WAX_LIGHT
                    if disabled:
                        color = blend(color, DARK_EDGE, 0.45)
                    pixels[x, y] = (color[0], color[1], color[2], 232 if edge else 218)
    elif name.startswith("close_tag"):
        draw_plate(layer, (0, 1, width, height - 1), (DARK_EDGE, PARCHMENT_DIM, PARCHMENT_LIGHT if selected else AMBER_DARK), alpha)
        for x in range(5, width - 5):
            if x % 4 != 0:
                put_pixel(layer, x, height // 2, (*DARK_EDGE, 136))
            if x % 6 in {0, 1}:
                put_pixel(layer, x, height // 2 - 3, (*AMBER, 148))
            if x % 7 in {2, 3}:
                put_pixel(layer, x, height // 2 + 4, (*DARK_BODY, 150))
        for y in range(5, height - 5):
            put_pixel(layer, width - 8, y, (*DARK_LIFT, 166))
            if y % 3 == 0:
                put_pixel(layer, width - 11, y, (*PARCHMENT_LIGHT, 152))
        for x in range(width - 16, width - 10):
            for y in range(4, 7):
                put_pixel(layer, x, y, (*WAX_BODY, 168))
    else:
        draw_plate(layer, (0, 1, width, height - 1), (DARK_EDGE, body, trim), alpha)

    return quantize_rgba(remove_unsupported_alpha_pixels(layer), 40)


def adjust_state(name: str, image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    if name.endswith("_selected"):
        image = ImageEnhance.Brightness(image).enhance(1.12)
        image = ImageEnhance.Contrast(image).enhance(1.08)
        image = ImageEnhance.Color(image).enhance(1.08)
    elif name.endswith("_pressed"):
        image = ImageEnhance.Brightness(image).enhance(0.82)
        image = ImageEnhance.Contrast(image).enhance(1.16)
    elif name.endswith("_disabled") or name == "item_row_disabled":
        image = ImageEnhance.Brightness(image).enhance(0.66)
        image = ImageEnhance.Color(image).enhance(0.50)
    image.putalpha(alpha)
    return image


def nearest_export(native: Image.Image, runtime_size: tuple[int, int]) -> Image.Image:
    return native.resize(runtime_size, Image.Resampling.NEAREST)


def save_pair(name: str, native: Image.Image, runtime_size: tuple[int, int]) -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    native.save(SOURCE / f"{name}_native.png")
    nearest_export(native, runtime_size).save(RUNTIME / f"{name}.png")


def main() -> None:
    master_native = normalize_reference(load_reference(SHOP_MASTER_REFERENCE), Image.Resampling.NEAREST)
    clean_native = normalize_reference(load_reference(SHOP_CLEAN_REFERENCE), Image.Resampling.NEAREST)
    save_pair("shop_scene", clean_native, SCENE_RUNTIME_SIZE)

    for name, (box, runtime_size, mode) in CLEAN_LAYER_SPECS.items():
        master_crop = crop_reference(master_native, box)
        if mode == "book":
            native = book_edge_layer(master_crop)
        elif mode in {"row", "bookmark", "status"}:
            native = paint_layer(master_crop, name)
        elif mode == "button":
            native = button_layer(master_crop, name)
        else:
            raise ValueError(f"Unsupported shop layer mode: {mode}")
        native = adjust_state(name, native)
        save_pair(name, native, runtime_size)

    empty_split = Image.new("RGBA", SCENE_NATIVE_SIZE, (0, 0, 0, 0))
    empty_split.save(SOURCE / "shop_clean_split_difference_native.png")


if __name__ == "__main__":
    main()
