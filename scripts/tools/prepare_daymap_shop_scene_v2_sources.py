import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageOps


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


def rgba_pixels(image: Image.Image) -> tuple[tuple[int, int, int, int], ...]:
    return image.convert("RGBA").get_flattened_data()


def lift_dark_teal_floor(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = []
    for red, green, blue, alpha in rgba_pixels(rgba):
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


def state_overlay(
    image: Image.Image,
    color: tuple[int, int, int],
    strength: float,
    brightness: float = 1.0,
) -> Image.Image:
    rgba = image.convert("RGBA")
    rgb = ImageEnhance.Brightness(rgba.convert("RGB")).enhance(brightness).convert("RGBA")
    rgb.putalpha(rgba.getchannel("A"))
    overlay = Image.new("RGBA", rgba.size, color + (0,))
    alpha = rgba.getchannel("A").point(lambda value: int(value * strength))
    overlay.putalpha(alpha)
    return Image.alpha_composite(rgb, overlay)


def derive_asset(image: Image.Image, operation: str) -> Image.Image:
    operations = {
        "row_hover_state": lambda source: state_overlay(source, (40, 100, 92), 0.34, 1.08),
        "row_selected_state": lambda source: state_overlay(source, (126, 94, 42), 0.38, 1.10),
        "row_disabled_state": lambda source: state_overlay(source, (18, 28, 30), 0.40, 0.62),
        "tab_hover_state": lambda source: state_overlay(source, (42, 104, 96), 0.36, 1.10),
        "tab_selected_state": lambda source: state_overlay(source, (126, 96, 48), 0.40, 1.12),
        "button_hover_state": lambda source: state_overlay(source, (150, 96, 42), 0.30, 1.12),
        "button_pressed_state": lambda source: state_overlay(source, (68, 42, 28), 0.32, 0.72),
        "button_disabled_state": lambda source: state_overlay(source, (18, 26, 28), 0.44, 0.58),
        "close_hover_state": lambda source: state_overlay(source, (160, 86, 44), 0.32, 1.12),
        "close_pressed_state": lambda source: state_overlay(source, (62, 34, 28), 0.34, 0.72),
        "quantity_hover_state": lambda source: state_overlay(source, (150, 96, 42), 0.32, 1.12),
        "quantity_pressed_state": lambda source: state_overlay(source, (62, 42, 28), 0.34, 0.72),
        "quantity_disabled_state": lambda source: state_overlay(source, (18, 28, 30), 0.42, 0.58),
        "status_emphasis_state": lambda source: state_overlay(source, (155, 98, 42), 0.24, 1.05),
    }
    if operation in operations:
        return operations[operation](image)
    raise ValueError(f"Unknown shop scene v2 derivation operation: {operation}")


def build_asset(name: str, native: Image.Image, manifest: dict, cache: dict[str, Image.Image]) -> Image.Image:
    if name in cache:
        return cache[name]
    assets: dict = manifest["assets"]
    spec: dict = assets[name]
    if "source_box" in spec:
        image = crop_layer(native, spec["source_box"], bool(spec["transparent"]))
    elif "derived_from" in spec:
        source = build_asset(str(spec["derived_from"]), native, manifest, cache)
        image = derive_asset(source, str(spec["operation"]))
    else:
        raise ValueError(f"{name}: manifest entry needs source_box or derived_from")
    expected_size = tuple(spec["native_size"])
    if image.size != expected_size:
        raise ValueError(f"{name}: expected native size {expected_size}, got {image.size}")
    cache[name] = image
    return image


def save_native(name: str, image: Image.Image) -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    path = SOURCE / f"{name}_native.png"
    image.save(path)
    print(path)


def validate_safe_areas(native: Image.Image, manifest: dict) -> None:
    full_canvas = (0, 0, NATIVE_SIZE[0], NATIVE_SIZE[1])
    text_safe_areas = [
        tuple(spec["safe_area"])
        for spec in manifest["full_layers"].values()
        if "safe_area" in spec and tuple(spec["safe_area"]) != full_canvas
    ]
    for box in text_safe_areas:
        crop = native.crop(box).convert("RGBA")
        bright_pixels = 0
        for red, green, blue, alpha in rgba_pixels(crop):
            if alpha >= 220 and max(red, green, blue) >= 185:
                bright_pixels += 1
        if bright_pixels > crop.width * crop.height * 0.18:
            raise ValueError(f"Shop scene v2 safe area is too bright/noisy: {box}")


def main() -> None:
    manifest = load_manifest()
    native = load_master_native()
    validate_safe_areas(native, manifest)

    cache: dict[str, Image.Image] = {}
    for name in manifest["assets"]:
        save_native(name, build_asset(name, native, manifest, cache))


if __name__ == "__main__":
    main()
