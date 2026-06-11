from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "daymap" / "shop_scene_v2"
RUNTIME = ROOT / "assets" / "textures" / "daymap" / "shop_scene_v2"
SCALE = 4

EXPECTED_ASSETS = {
    "shop_scene_bg": ((320, 180), False),
    "shop_scene_list_panel": ((190, 99), False),
    "shop_scene_detail_panel": ((90, 99), False),
    "shop_scene_checkout": ((260, 32), False),
    "shop_scene_tab_materials_normal": ((48, 16), True),
    "shop_scene_tab_materials_selected": ((48, 16), True),
    "shop_scene_tab_recipes_normal": ((48, 16), True),
    "shop_scene_tab_recipes_selected": ((48, 16), True),
    "shop_scene_tab_abilities_normal": ((48, 16), True),
    "shop_scene_tab_abilities_selected": ((48, 16), True),
    "shop_scene_row_normal": ((145, 16), True),
    "shop_scene_row_hover": ((145, 16), True),
    "shop_scene_row_selected": ((145, 16), True),
    "shop_scene_row_disabled": ((145, 16), True),
    "shop_scene_button_normal": ((64, 18), True),
    "shop_scene_button_hover": ((64, 18), True),
    "shop_scene_button_pressed": ((64, 18), True),
    "shop_scene_button_disabled": ((64, 18), True),
    "shop_scene_quantity_minus": ((18, 18), True),
    "shop_scene_quantity_body": ((44, 18), True),
    "shop_scene_quantity_plus": ((18, 18), True),
    "shop_scene_close_normal": ((18, 18), True),
    "shop_scene_close_hover": ((18, 18), True),
    "shop_scene_close_pressed": ((18, 18), True),
    "shop_scene_status_owned": ((14, 12), True),
    "shop_scene_status_discount": ((14, 13), True),
}


def load_native(name: str) -> Image.Image:
    path = SOURCE / f"{name}_native.png"
    if not path.exists():
        raise FileNotFoundError(f"Missing shop scene v2 native source: {path}")
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def validate_native(name: str, image: Image.Image, size: tuple[int, int], transparent: bool) -> None:
    if image.size != size:
        raise ValueError(f"{name}: expected native size {size}, got {image.size}")
    alpha_min, alpha_max = image.getchannel("A").getextrema()
    if transparent:
        if alpha_min != 0 or alpha_max == 0:
            raise ValueError(f"{name}: transparent asset needs both transparent and visible pixels")
    else:
        if alpha_min != 255 or alpha_max != 255:
            raise ValueError(f"{name}: opaque asset must have full alpha")


def nearest_export(native: Image.Image) -> Image.Image:
    return native.resize((native.width * SCALE, native.height * SCALE), Image.Resampling.NEAREST)


def main() -> None:
    outputs: dict[str, Image.Image] = {}
    for name, (size, transparent) in EXPECTED_ASSETS.items():
        native = load_native(name)
        validate_native(name, native, size, transparent)
        runtime = nearest_export(native)
        expected = native.resize(runtime.size, Image.Resampling.NEAREST)
        if runtime.tobytes() != expected.tobytes():
            raise RuntimeError(f"{name}: runtime is not exact nearest export")
        outputs[name] = runtime

    RUNTIME.mkdir(parents=True, exist_ok=True)
    for name, runtime in outputs.items():
        path = RUNTIME / f"{name}.png"
        runtime.save(path)
        print(f"{name}: {runtime.size}")


if __name__ == "__main__":
    main()
