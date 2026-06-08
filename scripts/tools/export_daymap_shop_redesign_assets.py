from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "daymap" / "shop_redesign"
RUNTIME = ROOT / "assets" / "textures" / "daymap" / "shop_redesign"
BASE_SHOP_BACKDROP = ROOT / "assets" / "source" / "daymap" / "ui" / "shop_backdrop_native.png"

COLORS = {
    "transparent": (0, 0, 0, 0),
    "teal_deep": (10, 24, 28, 255),
    "teal_mid": (18, 45, 48, 255),
    "stone": (24, 48, 50, 255),
    "wood_dark": (53, 30, 20, 255),
    "wood": (93, 56, 31, 255),
    "wood_light": (133, 85, 45, 255),
    "amber": (194, 123, 47, 255),
    "amber_bright": (235, 171, 80, 255),
    "parchment": (170, 125, 73, 255),
    "parchment_light": (203, 154, 88, 255),
    "ink": (67, 43, 30, 255),
    "disabled": (72, 61, 53, 215),
}


def nearest_export(native: Image.Image, runtime_size: tuple[int, int]) -> Image.Image:
    return native.resize(runtime_size, Image.Resampling.NEAREST)


def save_pair(name: str, image: Image.Image, runtime_size: tuple[int, int]) -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    image.save(SOURCE / f"{name}_native.png")
    nearest_export(image, runtime_size).save(RUNTIME / f"{name}.png")


def rect(draw: ImageDraw.ImageDraw, xy, fill: str) -> None:
    draw.rectangle(xy, fill=COLORS[fill])


def make_scene() -> Image.Image:
    if BASE_SHOP_BACKDROP.exists():
        return Image.open(BASE_SHOP_BACKDROP).convert("RGBA")

    image = Image.new("RGBA", (320, 180), COLORS["teal_deep"])
    draw = ImageDraw.Draw(image)

    for y in range(0, 116, 18):
        rect(draw, (0, y, 319, y + 12), "teal_mid" if y % 36 == 0 else "stone")
        for x in range((y * 3) % 22, 320, 36):
            rect(draw, (x, y + 2, x + 18, y + 9), "teal_deep")

    rect(draw, (0, 82, 319, 122), "wood_dark")
    rect(draw, (0, 90, 319, 96), "wood")
    rect(draw, (0, 121, 319, 178), "wood_dark")
    rect(draw, (0, 126, 319, 140), "wood")
    rect(draw, (0, 159, 319, 166), "wood")

    for x in [18, 38, 244, 268, 292]:
        rect(draw, (x, 36, x + 26, 41), "wood")
        rect(draw, (x + 2, 42, x + 22, 57), "wood_dark")

    for x, y in [(42, 65), (246, 62), (272, 68), (24, 70)]:
        rect(draw, (x, y, x + 8, y + 14), "wood_light")
        rect(draw, (x + 2, y + 2, x + 6, y + 12), "wood_dark")

    for x, y in [(55, 78), (258, 76), (300, 118)]:
        rect(draw, (x, y, x + 3, y + 13), "amber_bright")
        rect(draw, (x - 4, y + 8, x + 7, y + 18), "amber")
        rect(draw, (x - 8, y + 18, x + 11, y + 20), "wood_light")

    # Sparse counter clutter that stays behind dynamic UI text.
    for x, y in [(12, 132), (34, 147), (284, 132), (302, 146), (238, 150)]:
        rect(draw, (x, y, x + 11, y + 5), "wood_light")
        rect(draw, (x + 2, y + 6, x + 9, y + 12), "wood")

    return image


def make_book() -> Image.Image:
    if BASE_SHOP_BACKDROP.exists():
        backdrop = Image.open(BASE_SHOP_BACKDROP).convert("RGBA")
        crop = backdrop.crop((42, 78, 278, 170))
        crop = crop.resize((232, 90), Image.Resampling.NEAREST)
        image = Image.new("RGBA", (240, 104), COLORS["transparent"])
        image.alpha_composite(crop, (4, 6))
        return image

    image = Image.new("RGBA", (240, 104), COLORS["transparent"])
    draw = ImageDraw.Draw(image)
    rect(draw, (6, 8, 236, 98), "ink")
    rect(draw, (12, 6, 118, 94), "parchment")
    rect(draw, (122, 6, 230, 94), "parchment")
    rect(draw, (116, 8, 124, 98), "ink")
    rect(draw, (16, 10, 114, 21), "parchment_light")
    rect(draw, (126, 10, 224, 21), "parchment_light")
    for y in range(30, 88, 12):
        rect(draw, (20, y, 108, y + 1), "ink")
        rect(draw, (130, y, 220, y + 1), "ink")
    for x, y in [(18, 88), (104, 92), (132, 88), (214, 92)]:
        rect(draw, (x, y, x + 12, y + 2), "ink")
    return image


def make_tab(selected: bool) -> Image.Image:
    image = Image.new("RGBA", (42, 14), COLORS["transparent"])
    draw = ImageDraw.Draw(image)
    base = "amber" if selected else "wood"
    rect(draw, (2, 2, 39, 12), "ink")
    rect(draw, (4, 1, 37, 10), base)
    if selected:
        rect(draw, (8, 10, 33, 12), "amber_bright")
    return image


def make_card(state: str) -> Image.Image:
    image = Image.new("RGBA", (58, 28), COLORS["transparent"])
    draw = ImageDraw.Draw(image)
    fill = "disabled" if state == "disabled" else "parchment"
    edge = "amber" if state == "selected" else "ink"
    rect(draw, (1, 1, 56, 26), edge)
    rect(draw, (3, 3, 54, 24), fill)
    rect(draw, (6, 6, 21, 21), "wood_dark")
    rect(draw, (9, 9, 18, 18), "wood_light")
    rect(draw, (26, 8, 50, 9), "ink")
    rect(draw, (26, 16, 43, 17), "ink")
    if state == "selected":
        rect(draw, (4, 24, 53, 25), "amber_bright")
    return image


def make_button(disabled: bool) -> Image.Image:
    image = Image.new("RGBA", (44, 14), COLORS["transparent"])
    draw = ImageDraw.Draw(image)
    fill = "disabled" if disabled else "amber"
    rect(draw, (1, 2, 42, 12), "ink")
    rect(draw, (3, 1, 40, 10), fill)
    if not disabled:
        rect(draw, (9, 10, 35, 11), "amber_bright")
    return image


def main() -> None:
    save_pair("shop_scene", make_scene(), (1280, 720))
    save_pair("shop_book", make_book(), (960, 416))
    save_pair("shop_tab_normal", make_tab(False), (168, 56))
    save_pair("shop_tab_selected", make_tab(True), (168, 56))
    save_pair("shop_item_card_normal", make_card("normal"), (232, 112))
    save_pair("shop_item_card_selected", make_card("selected"), (232, 112))
    save_pair("shop_item_card_disabled", make_card("disabled"), (232, 112))
    save_pair("shop_purchase_button_normal", make_button(False), (176, 56))
    save_pair("shop_purchase_button_disabled", make_button(True), (176, 56))


if __name__ == "__main__":
    main()
