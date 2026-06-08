from pathlib import Path

from PIL import Image, ImageEnhance, ImageOps


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "daymap" / "shop_redesign"
REFERENCE_DIR = SOURCE / "reference"
RUNTIME = ROOT / "assets" / "textures" / "daymap" / "shop_redesign"
SHOP_MASTER_REFERENCE = REFERENCE_DIR / "shop_master_composition_generated.png"

SCENE_NATIVE_SIZE = (320, 180)
SCENE_RUNTIME_SIZE = (1280, 720)

MASTER_ASSET_SPECS = {
    "shop_book": ((48, 30, 296, 134), (992, 416)),
    "bookmark_materials_normal": ((104, 30, 140, 46), (144, 64)),
    "bookmark_materials_selected": ((104, 30, 140, 46), (144, 64)),
    "bookmark_recipes_normal": ((142, 30, 178, 46), (144, 64)),
    "bookmark_recipes_selected": ((142, 30, 178, 46), (144, 64)),
    "bookmark_abilities_normal": ((180, 30, 216, 46), (144, 64)),
    "bookmark_abilities_selected": ((180, 30, 216, 46), (144, 64)),
    "item_row_normal": ((88, 50, 204, 68), (464, 72)),
    "item_row_selected": ((88, 50, 204, 68), (464, 72)),
    "item_row_disabled": ((88, 80, 204, 98), (464, 72)),
    "purchase_seal_normal": ((195, 136, 241, 154), (184, 72)),
    "purchase_seal_pressed": ((195, 136, 241, 154), (184, 72)),
    "purchase_seal_disabled": ((195, 136, 241, 154), (184, 72)),
    "close_tag_normal": ((238, 134, 282, 150), (176, 64)),
    "close_tag_selected": ((238, 134, 282, 150), (176, 64)),
    "quantity_abacus": ((124, 130, 172, 148), (192, 72)),
    "status_owned": ((172, 102, 212, 116), (160, 56)),
    "status_discount": ((194, 106, 234, 120), (160, 56)),
}


def load_master_reference() -> Image.Image:
    if not SHOP_MASTER_REFERENCE.exists():
        raise FileNotFoundError(f"Missing generated shop master composition: {SHOP_MASTER_REFERENCE}")
    return Image.open(SHOP_MASTER_REFERENCE).convert("RGBA")


def normalize_master(reference: Image.Image) -> Image.Image:
    native = ImageOps.fit(
        reference,
        SCENE_NATIVE_SIZE,
        method=Image.Resampling.LANCZOS,
        centering=(0.5, 0.5),
    ).convert("RGBA")
    native = ImageEnhance.Color(native).enhance(0.82)
    native = ImageEnhance.Contrast(native).enhance(1.12)
    alpha = native.getchannel("A")
    native = native.convert("RGB").quantize(colors=48, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    native.putalpha(alpha)
    return native


def crop_reference(reference: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    return reference.crop(box).convert("RGBA")


def adjust_state(name: str, image: Image.Image) -> Image.Image:
    if name.endswith("_selected"):
        image = ImageEnhance.Brightness(image).enhance(1.16)
        image = ImageEnhance.Contrast(image).enhance(1.10)
        image = ImageEnhance.Color(image).enhance(1.08)
    elif name.endswith("_pressed"):
        image = ImageEnhance.Brightness(image).enhance(0.84)
        image = ImageEnhance.Contrast(image).enhance(1.18)
    elif name.endswith("_disabled") or name == "item_row_disabled":
        image = ImageEnhance.Brightness(image).enhance(0.58)
        image = ImageEnhance.Color(image).enhance(0.46)
    return image


def nearest_export(native: Image.Image, runtime_size: tuple[int, int]) -> Image.Image:
    return native.resize(runtime_size, Image.Resampling.NEAREST)


def save_pair(name: str, native: Image.Image, runtime_size: tuple[int, int]) -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    native.save(SOURCE / f"{name}_native.png")
    nearest_export(native, runtime_size).save(RUNTIME / f"{name}.png")


def main() -> None:
    scene_native = normalize_master(load_master_reference())
    save_pair("shop_scene", scene_native, SCENE_RUNTIME_SIZE)
    for name, (box, runtime_size) in MASTER_ASSET_SPECS.items():
        native = crop_reference(scene_native, box)
        native = adjust_state(name, native)
        save_pair(name, native, runtime_size)


if __name__ == "__main__":
    main()
