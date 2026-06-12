from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "tavern_patience" / "patience_meter_reference.png"
SOURCE = ROOT / "assets" / "source" / "ui"
RUNTIME = ROOT / "assets" / "textures" / "ui"
CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_patience_ui_contact_sheet.png"
SCALE = 4

ASSETS = {
    "patience_bar_bg": {
        "source_box": (248, 145, 1522, 330),
        "native_size": (75, 7),
        "runtime_name": "bar_patience_bg",
    },
    "patience_bar_fill": {
        "source_box": (250, 445, 1518, 550),
        "native_size": (75, 7),
        "runtime_name": "bar_patience_fill",
    },
    "icon_patience": {
        "source_box": (806, 588, 973, 760),
        "native_size": (8, 8),
        "runtime_name": "icon_patience",
    },
}


def image_pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    if hasattr(image, "get_flattened_data"):
        return list(image.get_flattened_data())
    return list(image.getdata())


def quantize(image: Image.Image, colors: int) -> Image.Image:
    return image.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")


def normalize_crop(reference: Image.Image, source_box: tuple[int, int, int, int], native_size: tuple[int, int]) -> Image.Image:
    crop = reference.crop(source_box).convert("RGB")
    resized = crop.resize(native_size, Image.Resampling.LANCZOS)
    contrast = ImageEnhance.Contrast(resized).enhance(1.35)
    color = ImageEnhance.Color(contrast).enhance(1.08)
    sharp = ImageEnhance.Sharpness(color).enhance(1.8)
    return quantize(sharp, 28)


def save_pair(native: Image.Image, native_name: str, runtime_name: str) -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    native_path = SOURCE / f"{native_name}_native.png"
    runtime_path = RUNTIME / f"{runtime_name}.png"
    native.save(native_path)
    runtime = native.resize((native.width * SCALE, native.height * SCALE), Image.Resampling.NEAREST)
    runtime.save(runtime_path)
    print(f"{runtime_name}.png: {runtime_path.relative_to(ROOT).as_posix()}")


def make_contact_sheet(reference: Image.Image, assets: dict[str, Image.Image]) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (640, 320), (16, 14, 12, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((16, 12), "Tavern patience UI - generated reference pipeline", fill=(220, 204, 176, 255))

    ref_preview = reference.resize((320, 160), Image.Resampling.LANCZOS).convert("RGBA")
    sheet.alpha_composite(ref_preview, (16, 40))
    draw.text((16, 204), "runtime 4x", fill=(220, 204, 176, 255))

    bg = assets["patience_bar_bg"].resize((300, 28), Image.Resampling.NEAREST)
    fill = assets["patience_bar_fill"].resize((220, 28), Image.Resampling.NEAREST)
    icon = assets["icon_patience"].resize((32, 32), Image.Resampling.NEAREST)
    sheet.alpha_composite(bg, (96, 236))
    sheet.alpha_composite(fill, (96, 236))
    sheet.alpha_composite(icon, (48, 234))

    draw.text((428, 44), "native previews", fill=(220, 204, 176, 255))
    y = 72
    for name in ("patience_bar_bg", "patience_bar_fill", "icon_patience"):
        preview = assets[name].resize((assets[name].width * 4, assets[name].height * 4), Image.Resampling.NEAREST)
        sheet.alpha_composite(preview, (428, y))
        draw.text((428, y + preview.height + 4), name, fill=(156, 141, 120, 255))
        y += preview.height + 30

    sheet.convert("RGB").save(CONTACT_SHEET)


def main() -> None:
    if not RAW_SOURCE.exists():
        raise FileNotFoundError(f"missing generated patience reference: {RAW_SOURCE}")
    reference = Image.open(RAW_SOURCE).convert("RGB")
    outputs: dict[str, Image.Image] = {}
    for native_name, spec in ASSETS.items():
        native = normalize_crop(reference, spec["source_box"], spec["native_size"])
        outputs[native_name] = native
        save_pair(native, native_name, spec["runtime_name"])
    make_contact_sheet(reference, outputs)
    print(f"contact sheet: {CONTACT_SHEET.relative_to(ROOT).as_posix()}")


if __name__ == "__main__":
    main()
