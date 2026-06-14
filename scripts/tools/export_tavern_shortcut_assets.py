from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "tavern_shortcut_bar" / "tavern_shortcut_bar_ui_sheet_v1.png"
SOURCE_DIR = ROOT / "assets" / "source" / "tavern" / "shortcut"
RUNTIME_DIR = ROOT / "assets" / "textures" / "ui"
MANIFEST_PATH = SOURCE_DIR / "tavern_shortcut_bar_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_shortcut_bar_contact_sheet.png"
SCALE = 4

ASSETS = {
    "bar_shortcut_bg": {
        "crop_rect": [50, 188, 1622, 372],
        "native_size": [250, 10],
        "runtime_name": "bar_shortcut_bg",
        "safe_area": [10, 1, 240, 9],
        "intended_godot_use": "Tavern ShortcutBarBg bottom tray StyleBoxTexture",
        "colors": 30,
    },
    "shortcut_slot_empty": {
        "crop_rect": [134, 538, 536, 756],
        "native_size": [24, 10],
        "runtime_name": "shortcut_slot_empty",
        "safe_area": [3, 2, 21, 8],
        "intended_godot_use": "Tavern ShortcutBar empty slot TextureRect",
        "colors": 24,
    },
    "shortcut_slot_filled": {
        "crop_rect": [624, 536, 1032, 756],
        "native_size": [24, 10],
        "runtime_name": "shortcut_slot_filled",
        "safe_area": [3, 2, 21, 8],
        "intended_godot_use": "Tavern ShortcutBar filled slot TextureRect",
        "colors": 24,
    },
    "shortcut_slot_hover": {
        "crop_rect": [1114, 536, 1528, 756],
        "native_size": [24, 10],
        "runtime_name": "shortcut_slot_hover",
        "safe_area": [3, 2, 21, 8],
        "intended_godot_use": "Tavern ShortcutBar hover slot TextureRect",
        "colors": 24,
    },
}


def remove_chroma_key(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, _a = pixels[x, y]
            if g >= 130 and g > r * 1.3 and g > b * 1.3 and g > max(r, b) + 24:
                pixels[x, y] = (0, 0, 0, 0)
    return rgba


def quantize_visible(image: Image.Image, colors: int) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A").point(lambda value: 255 if value >= 96 else 0)
    rgb = Image.new("RGB", rgba.size, (0, 0, 0))
    rgb.paste(rgba.convert("RGB"), mask=alpha)
    quantized = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    quantized.putalpha(alpha)
    pixels = quantized.load()
    for y in range(quantized.height):
        for x in range(quantized.width):
            if pixels[x, y][3] == 0:
                pixels[x, y] = (0, 0, 0, 0)
    return quantized


def normalize_asset(reference: Image.Image, spec: dict[str, object]) -> Image.Image:
    native_size = tuple(spec["native_size"])
    crop = reference.crop(tuple(spec["crop_rect"]))
    keyed = remove_chroma_key(crop)
    resized = keyed.resize(native_size, Image.Resampling.LANCZOS)
    rgb = resized.convert("RGB")
    contrast = ImageEnhance.Contrast(rgb).enhance(1.16)
    color = ImageEnhance.Color(contrast).enhance(1.05)
    sharp = ImageEnhance.Sharpness(color).enhance(1.55).convert("RGBA")
    sharp.putalpha(resized.getchannel("A"))
    return quantize_visible(sharp, int(spec["colors"]))


def save_assets(reference: Image.Image) -> dict[str, Image.Image]:
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    outputs: dict[str, Image.Image] = {}
    for asset_id, spec in ASSETS.items():
        native = normalize_asset(reference, spec)
        native_path = SOURCE_DIR / f"{asset_id}_native.png"
        runtime_path = RUNTIME_DIR / f"{spec['runtime_name']}.png"
        native.save(native_path)
        runtime = native.resize(
            (native.width * SCALE, native.height * SCALE),
            Image.Resampling.NEAREST,
        )
        runtime.save(runtime_path)
        outputs[asset_id] = native
    return outputs


def write_manifest() -> None:
    manifest_assets = {}
    for asset_id, spec in ASSETS.items():
        native_size = list(spec["native_size"])
        runtime_size = [native_size[0] * SCALE, native_size[1] * SCALE]
        manifest_assets[asset_id] = {
            "crop_rect": spec["crop_rect"],
            "native": f"assets/source/tavern/shortcut/{asset_id}_native.png",
            "runtime": f"assets/textures/ui/{spec['runtime_name']}.png",
            "native_size": native_size,
            "runtime_size": runtime_size,
            "safe_area": spec["safe_area"],
            "intended_godot_use": spec["intended_godot_use"],
        }
    manifest = {
        "id": "tavern_shortcut_bar",
        "source": "art_sources/generated_raw/tavern_shortcut_bar/tavern_shortcut_bar_ui_sheet_v1.png",
        "prompt": "art_sources/generated_raw/tavern_shortcut_bar/tavern_shortcut_bar_ui_sheet_v1_prompt.txt",
        "scale": SCALE,
        "assets": manifest_assets,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def make_contact_sheet(reference: Image.Image, natives: dict[str, Image.Image]) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (1000, 620), (18, 14, 11, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((16, 14), "Tavern shortcut bar pipeline - dedicated sheet", fill=(220, 204, 176, 255))
    draw.text((16, 42), "generated source and explicit crop boxes", fill=(220, 204, 176, 255))
    source_preview = reference.resize((960, 540), Image.Resampling.LANCZOS).convert("RGBA")
    sheet.alpha_composite(source_preview, (16, 64))
    for spec in ASSETS.values():
        crop = spec["crop_rect"]
        scale_x = 960 / reference.width
        scale_y = 540 / reference.height
        rect = (
            int(crop[0] * scale_x) + 16,
            int(crop[1] * scale_y) + 64,
            int(crop[2] * scale_x) + 16,
            int(crop[3] * scale_y) + 64,
        )
        draw.rectangle(rect, outline=(255, 188, 92, 255), width=1)

    y = 584
    tray = natives["bar_shortcut_bg"].resize((500, 20), Image.Resampling.NEAREST)
    sheet.alpha_composite(tray, (16, y))
    x = 540
    for asset_id in ["shortcut_slot_empty", "shortcut_slot_filled", "shortcut_slot_hover"]:
        preview = natives[asset_id].resize((96, 40), Image.Resampling.NEAREST)
        sheet.alpha_composite(preview, (x, y - 10))
        x += 108
    sheet.convert("RGB").save(CONTACT_SHEET)


def main() -> None:
    if not RAW_SOURCE.exists():
        raise FileNotFoundError(f"missing Tavern shortcut source: {RAW_SOURCE}")
    reference = Image.open(RAW_SOURCE).convert("RGBA")
    outputs = save_assets(reference)
    write_manifest()
    make_contact_sheet(reference, outputs)
    print("exported Tavern shortcut bar assets")
    print("contact sheet: docs/art/tavern_shortcut_bar_contact_sheet.png")


if __name__ == "__main__":
    main()
