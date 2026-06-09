from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageEnhance, ImageOps


ROOT = Path(__file__).resolve().parents[2]
REFERENCE = ROOT / "assets" / "source" / "ledger" / "reference" / "ledger_overlay_reference_generated.png"
SOURCE = ROOT / "assets" / "source" / "ledger" / "ui"
RUNTIME = ROOT / "assets" / "textures" / "ledger" / "ui"

BACKDROP_NATIVE_SIZE = (320, 180)
BACKDROP_RUNTIME_SIZE = (1280, 720)
NAV_BUTTON_NATIVE_SIZE = (26, 22)
NAV_BUTTON_RUNTIME_SIZE = (104, 88)
CLOSE_BUTTON_NATIVE_SIZE = (128, 22)
CLOSE_BUTTON_RUNTIME_SIZE = (512, 88)

LEFT_NAV_BOX = (61, 156, 87, 178)
RIGHT_NAV_BOX = (233, 156, 259, 178)
CLOSE_BOX = (96, 156, 224, 178)


def load_reference() -> Image.Image:
    if not REFERENCE.exists():
        raise FileNotFoundError(f"Missing generated ledger reference: {REFERENCE}")
    with Image.open(REFERENCE) as image:
        return image.convert("RGBA")


def reduce_to_native_palette(image: Image.Image, colors: int = 56) -> Image.Image:
    quantized = image.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
    return quantized.convert("RGBA")


def make_backdrop_native(reference: Image.Image) -> Image.Image:
    fitted = ImageOps.fit(
        reference,
        BACKDROP_NATIVE_SIZE,
        method=Image.Resampling.BOX,
        centering=(0.5, 0.5),
    )
    return reduce_to_native_palette(fitted, 64)


def button_state(native: Image.Image, state: str) -> Image.Image:
    if state == "hover":
        bright = ImageEnhance.Brightness(native).enhance(1.18)
        return ImageEnhance.Contrast(bright).enhance(1.08).convert("RGBA")
    if state == "pressed":
        dark = ImageEnhance.Brightness(native).enhance(0.78)
        return ImageEnhance.Contrast(dark).enhance(1.04).convert("RGBA")
    return native.convert("RGBA")


def save_pair(name: str, native: Image.Image, runtime_size: tuple[int, int]) -> None:
    native_path = SOURCE / f"{name}_native.png"
    runtime_path = RUNTIME / f"{name}.png"
    native.save(native_path)
    native.resize(runtime_size, Image.Resampling.NEAREST).save(runtime_path)
    print(f"{name}: {native.size} -> {runtime_size}")


def export_button_states(name: str, native: Image.Image, runtime_size: tuple[int, int]) -> None:
    for state in ["normal", "hover", "pressed"]:
        save_pair(f"{name}_{state}", button_state(native, state), runtime_size)


def main() -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)

    reference = load_reference()
    backdrop = make_backdrop_native(reference)
    save_pair("ledger_overlay_backdrop", backdrop, BACKDROP_RUNTIME_SIZE)

    export_button_states(
        "button_nav_left",
        backdrop.crop(LEFT_NAV_BOX).resize(NAV_BUTTON_NATIVE_SIZE, Image.Resampling.BOX),
        NAV_BUTTON_RUNTIME_SIZE,
    )
    export_button_states(
        "button_nav_right",
        backdrop.crop(RIGHT_NAV_BOX).resize(NAV_BUTTON_NATIVE_SIZE, Image.Resampling.BOX),
        NAV_BUTTON_RUNTIME_SIZE,
    )
    export_button_states(
        "button_close",
        backdrop.crop(CLOSE_BOX).resize(CLOSE_BUTTON_NATIVE_SIZE, Image.Resampling.BOX),
        CLOSE_BUTTON_RUNTIME_SIZE,
    )


if __name__ == "__main__":
    main()
