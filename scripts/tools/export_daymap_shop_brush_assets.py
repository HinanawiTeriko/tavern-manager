from pathlib import Path
import shutil

from PIL import Image, ImageEnhance, ImageOps


ROOT = Path(__file__).resolve().parents[2]
MENU_SOURCE = ROOT / "assets" / "source" / "ui" / "menu_brush_components_approved.png"
REFERENCE = ROOT / "assets" / "source" / "daymap" / "shop_brush" / "reference"
SOURCE = ROOT / "assets" / "source" / "daymap" / "shop_brush"
RUNTIME = ROOT / "assets" / "textures" / "daymap" / "shop_brush"
SHOP_UI_CHROMA_REFERENCE = REFERENCE / "shop_ui_chroma_reference_v3.png"
SHOP_BACKDROP_REFERENCE = REFERENCE / "shop_clean_background_reference_v2.png"
SCALE = 4

COMPONENT_BOXES = {
    "panel_list": (76, 75, 957, 415),
    "panel_detail": (1022, 77, 1371, 411),
    "category_normal": (1424, 141, 1594, 215),
    "category_selected": (1424, 287, 1594, 370),
    "row_normal": (76, 465, 471, 529),
    "checkout_strip": (562, 492, 1590, 655),
    "row_hover": (76, 550, 472, 615),
    "row_selected": (76, 636, 473, 701),
    "row_disabled": (77, 722, 472, 788),
    "button_normal": (557, 722, 724, 791),
    "button_hover": (740, 722, 900, 791),
    "button_pressed": (918, 722, 1078, 791),
    "button_disabled": (1097, 722, 1256, 791),
    "close_normal": (1309, 724, 1386, 794),
    "close_hover": (1417, 724, 1494, 794),
    "close_pressed": (1523, 724, 1600, 794),
    "gold_area": (81, 826, 189, 876),
    "quantity_body": (312, 821, 458, 882),
    "quantity_minus": (229, 824, 282, 880),
    "quantity_plus": (487, 824, 543, 881),
    "status_owned": (639, 841, 685, 877),
    "status_discount": (762, 841, 797, 879),
    "divider": (893, 864, 1585, 872),
}

EXPORTS = {
    "shop_brush_panel_list": ("panel_list", (190, 99)),
    "shop_brush_panel_detail": ("panel_detail", (90, 99)),
    "shop_brush_category_normal": ("category_normal", (48, 16)),
    "shop_brush_category_selected": ("category_selected", (48, 16)),
    "shop_brush_row_normal": ("row_normal", (145, 16)),
    "shop_brush_row_hover": ("row_hover", (145, 16)),
    "shop_brush_row_selected": ("row_selected", (145, 16)),
    "shop_brush_row_disabled": ("row_disabled", (145, 16)),
    "shop_brush_checkout_strip": ("checkout_strip", (260, 32)),
    "shop_brush_button_normal": ("button_normal", (64, 18)),
    "shop_brush_button_hover": ("button_hover", (64, 18)),
    "shop_brush_button_pressed": ("button_pressed", (64, 18)),
    "shop_brush_button_disabled": ("button_disabled", (64, 18)),
    "shop_brush_close_normal": ("close_normal", (18, 18)),
    "shop_brush_close_hover": ("close_hover", (18, 18)),
    "shop_brush_close_pressed": ("close_pressed", (18, 18)),
    "shop_brush_gold_area": ("gold_area", (36, 14)),
    "shop_brush_quantity_minus": ("quantity_minus", (18, 18)),
    "shop_brush_quantity_body": ("quantity_body", (44, 18)),
    "shop_brush_quantity_plus": ("quantity_plus", (18, 18)),
    "shop_brush_status_owned": ("status_owned", (14, 12)),
    "shop_brush_status_discount": ("status_discount", (14, 13)),
    "shop_brush_divider": ("divider", (180, 4)),
}


def load_rgba(path: Path) -> Image.Image:
    if not path.exists():
        raise FileNotFoundError(path)
    return Image.open(path).convert("RGBA")


def is_chroma_or_magenta_fringe(red: int, green: int, blue: int) -> bool:
    pure_chroma = red >= 210 and green <= 110 and blue >= 210
    magenta_fringe = (
        red >= 50
        and blue >= 50
        and green <= 120
        and red >= green + 20
        and blue >= green + 20
    )
    return pure_chroma or magenta_fringe


def remove_chroma_background(image: Image.Image) -> Image.Image:
    out = image.copy()
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                continue
            if is_chroma_or_magenta_fringe(red, green, blue):
                pixels[x, y] = (0, 0, 0, 0)
    return out


def crop_resize(source: Image.Image, box: tuple[int, int, int, int], size: tuple[int, int]) -> Image.Image:
    crop = source.crop(box).convert("RGBA")
    crop = remove_chroma_background(crop)
    resized = crop.resize(size, Image.Resampling.NEAREST).convert("RGBA")
    return remove_chroma_background(resized)


def build_backdrop(source: Image.Image) -> Image.Image:
    native = ImageOps.fit(
        source,
        (320, 180),
        method=Image.Resampling.NEAREST,
        centering=(0.5, 0.5),
    ).convert("RGBA")
    native = ImageEnhance.Brightness(native).enhance(0.82)
    native = ImageEnhance.Contrast(native).enhance(1.04)
    native = ImageEnhance.Color(native).enhance(0.90)
    return native


def nearest_export(native: Image.Image, runtime_size: tuple[int, int]) -> Image.Image:
    return native.resize(runtime_size, Image.Resampling.NEAREST)


def save_pair(name: str, native: Image.Image, runtime_size: tuple[int, int]) -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    native.save(SOURCE / f"{name}_native.png")
    nearest_export(native, runtime_size).save(RUNTIME / f"{name}.png")


def retain_reference_sources() -> None:
    REFERENCE.mkdir(parents=True, exist_ok=True)
    retained_menu = REFERENCE / "menu_brush_components_approved.png"
    if MENU_SOURCE.exists() and not retained_menu.exists():
        shutil.copy2(MENU_SOURCE, retained_menu)


def main() -> None:
    retain_reference_sources()
    components = load_rgba(SHOP_UI_CHROMA_REFERENCE)
    backdrop = load_rgba(SHOP_BACKDROP_REFERENCE)
    save_pair("shop_brush_backdrop", build_backdrop(backdrop), (1280, 720))
    for name, (component_key, native_size) in EXPORTS.items():
        save_pair(name, crop_resize(components, COMPONENT_BOXES[component_key], native_size), (native_size[0] * SCALE, native_size[1] * SCALE))


if __name__ == "__main__":
    main()
