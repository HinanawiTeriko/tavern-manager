import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageOps


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "daymap" / "shop_scene_v2"
REFERENCE = SOURCE / "reference"
MASTER_REFERENCE = REFERENCE / "shop_scene_v2_master_reference.png"
MANIFEST_PATH = REFERENCE / "shop_scene_v2_manifest.json"
NATIVE_SIZE = (320, 180)


def load_manifest() -> dict:
    if not MANIFEST_PATH.exists():
        raise FileNotFoundError(f"Missing shop scene v2 manifest: {MANIFEST_PATH}")
    return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))


def load_master_native() -> Image.Image:
    if not MASTER_REFERENCE.exists():
        raise FileNotFoundError(f"Missing shop scene v2 master reference: {MASTER_REFERENCE}")
    with Image.open(MASTER_REFERENCE) as image:
        native = ImageOps.fit(
            image.convert("RGBA"),
            NATIVE_SIZE,
            method=Image.Resampling.NEAREST,
            centering=(0.5, 0.5),
        )
    native = ImageEnhance.Brightness(native).enhance(0.82)
    native = ImageEnhance.Contrast(native).enhance(1.06)
    native = ImageEnhance.Color(native).enhance(0.92)
    return lift_dark_teal_floor(native)


def lift_dark_teal_floor(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = []
    for red, green, blue, alpha in rgba.getdata():
        if alpha > 0 and red <= 95:
            green = max(green, 26)
            blue = max(blue, 30)
        pixels.append((red, green, blue, alpha))
    lifted = Image.new("RGBA", rgba.size)
    lifted.putdata(pixels)
    return lifted


def crop_layer(native: Image.Image, box: list[int], transparent: bool) -> Image.Image:
    layer = native.crop(tuple(box)).convert("RGBA")
    if transparent:
        layer = rectangular_alpha_from_edges(layer)
    return layer


def rectangular_alpha_from_edges(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    mask = Image.new("L", rgba.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rectangle((1, 1, width - 2, height - 2), fill=255)
    rgba.putalpha(mask)
    return rgba


def tint_visible(image: Image.Image, color: tuple[int, int, int], strength: float) -> Image.Image:
    rgba = image.convert("RGBA")
    overlay = Image.new("RGBA", rgba.size, color + (0,))
    alpha = rgba.getchannel("A").point(lambda value: int(value * strength))
    overlay.putalpha(alpha)
    return Image.alpha_composite(rgba, overlay)


def darken_visible(image: Image.Image, factor: float) -> Image.Image:
    rgba = image.convert("RGBA")
    rgb = ImageEnhance.Brightness(rgba.convert("RGB")).enhance(factor).convert("RGBA")
    rgb.putalpha(rgba.getchannel("A"))
    return rgb


def add_amber_pixels(image: Image.Image, mode: str) -> Image.Image:
    rgba = image.convert("RGBA")
    draw = ImageDraw.Draw(rgba)
    width, height = rgba.size
    if mode == "hover":
        draw.line((3, height - 3, width - 4, height - 3), fill=(209, 132, 35, 220), width=1)
    elif mode == "selected":
        draw.rectangle((2, 2, width - 3, height - 3), outline=(218, 142, 36, 235), width=1)
    elif mode == "pressed":
        draw.rectangle((2, 2, width - 3, height - 3), outline=(162, 85, 28, 240), width=1)
    elif mode == "status":
        draw.rectangle((2, 2, width - 3, height - 3), outline=(232, 153, 43, 235), width=1)
    return rgba


def make_status(size: tuple[int, int], kind: str) -> Image.Image:
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    if kind == "owned":
        draw.rectangle((1, 2, size[0] - 2, size[1] - 3), fill=(20, 55, 58, 210), outline=(218, 142, 36, 235))
        draw.line((3, size[1] // 2, size[0] - 4, size[1] // 2), fill=(236, 170, 62, 240), width=1)
    else:
        draw.polygon(
            [(1, size[1] - 3), (size[0] // 2, 1), (size[0] - 2, size[1] - 3)],
            fill=(31, 72, 71, 220),
            outline=(218, 142, 36, 235),
        )
        draw.line((4, size[1] - 4, size[0] - 5, size[1] - 4), fill=(236, 170, 62, 240), width=1)
    return image


def save_native(name: str, image: Image.Image) -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    path = SOURCE / f"{name}_native.png"
    image.save(path)
    print(path)


def validate_safe_areas(native: Image.Image, manifest: dict) -> None:
    forbidden_boxes = [
        (24, 36, 187, 120),
        (226, 38, 296, 118),
        (43, 149, 278, 167),
    ]
    for box in forbidden_boxes:
        crop = native.crop(box).convert("RGBA")
        bright_pixels = 0
        for red, green, blue, alpha in crop.getdata():
            if alpha >= 220 and max(red, green, blue) >= 185:
                bright_pixels += 1
        if bright_pixels > crop.width * crop.height * 0.18:
            raise ValueError(f"Shop scene v2 safe area is too bright/noisy: {box}")


def main() -> None:
    manifest = load_manifest()
    native = load_master_native()
    validate_safe_areas(native, manifest)

    for name, spec in manifest["full_layers"].items():
        save_native(name, crop_layer(native, spec["box"], bool(spec["transparent"])))

    components: dict[str, Image.Image] = {}
    for name, spec in manifest["component_layers"].items():
        components[name] = crop_layer(native, spec["box"], bool(spec["transparent"]))
        save_native(name, components[name])

    for base in ["materials", "recipes", "abilities"]:
        normal_name = f"shop_scene_tab_{base}_normal"
        selected_name = f"shop_scene_tab_{base}_selected"
        save_native(selected_name, add_amber_pixels(tint_visible(components[normal_name], (38, 84, 82), 0.18), "selected"))

    row = components["shop_scene_row_normal"]
    save_native("shop_scene_row_hover", add_amber_pixels(tint_visible(row, (48, 92, 90), 0.18), "hover"))
    save_native("shop_scene_row_selected", add_amber_pixels(tint_visible(row, (70, 92, 70), 0.26), "selected"))
    save_native("shop_scene_row_disabled", darken_visible(row, 0.55))

    button = components["shop_scene_button_normal"]
    save_native("shop_scene_button_hover", add_amber_pixels(tint_visible(button, (65, 90, 72), 0.18), "hover"))
    save_native("shop_scene_button_pressed", add_amber_pixels(darken_visible(button, 0.70), "pressed"))
    save_native("shop_scene_button_disabled", darken_visible(button, 0.48))

    close = components["shop_scene_close_normal"]
    save_native("shop_scene_close_hover", add_amber_pixels(tint_visible(close, (65, 90, 72), 0.18), "hover"))
    save_native("shop_scene_close_pressed", add_amber_pixels(darken_visible(close, 0.70), "pressed"))

    save_native("shop_scene_status_owned", make_status((14, 12), "owned"))
    save_native("shop_scene_status_discount", make_status((14, 13), "discount"))


if __name__ == "__main__":
    main()
