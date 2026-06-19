from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageOps


ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = ROOT / "art_sources" / "generated_raw" / "wind_notice"
RAW_SOURCE = RAW_DIR / "wind_notice_source_v1.png"
PROMPT = RAW_DIR / "wind_notice_prompt_v1.txt"
SOURCE = ROOT / "assets" / "source" / "ui" / "wind_notice"
RUNTIME = ROOT / "assets" / "textures" / "ui" / "wind_notice"
MANIFEST = SOURCE / "wind_notice_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "ui" / "previews" / "wind_notice_contact_sheet.png"
SCALE = 4

SOURCE_RECTS = {
    "wind_notice_panel": (30, 150, 1225, 635),
    "wind_notice_icon": (74, 748, 455, 1128),
    "wind_notice_stamp": (500, 768, 820, 1088),
    "wind_notice_spark": (922, 770, 1172, 1048),
}

ASSETS = {
    "wind_notice_panel": {
        "native_size": (150, 60),
        "runtime_size": (600, 240),
        "safe_area": [126, 70, 424, 94],
        "intended_godot_use": "DayMap WindNotice panel backing",
        "colors": 32,
        "contrast": 1.08,
    },
    "wind_notice_icon": {
        "native_size": (24, 24),
        "runtime_size": (96, 96),
        "safe_area": [10, 10, 76, 76],
        "intended_godot_use": "DayMap WindNotice listening note icon",
        "colors": 24,
        "contrast": 1.18,
    },
    "wind_notice_stamp": {
        "native_size": (32, 32),
        "runtime_size": (128, 128),
        "safe_area": [16, 16, 96, 96],
        "intended_godot_use": "Tavern WindNotice fulfilled rumor stamp",
        "colors": 24,
        "contrast": 1.14,
    },
    "wind_notice_spark": {
        "native_size": (24, 24),
        "runtime_size": (96, 96),
        "safe_area": [8, 8, 80, 80],
        "intended_godot_use": "Tavern WindNotice fulfilled rumor sparkle",
        "colors": 16,
        "contrast": 1.18,
    },
}


def load_source() -> Image.Image:
    if not RAW_SOURCE.exists():
        raise FileNotFoundError(f"missing generated wind notice source: {RAW_SOURCE}")
    if not PROMPT.exists():
        raise FileNotFoundError(f"missing generated wind notice prompt: {PROMPT}")
    return Image.open(RAW_SOURCE).convert("RGBA")


def remove_magenta_key(image: Image.Image) -> Image.Image:
    out = image.convert("RGBA")
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            red, green, blue, alpha = pixels[x, y]
            if red >= 190 and blue >= 190 and green <= 90 and abs(red - blue) <= 80:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (red, green, blue, alpha)
    return out


def clear_transparent_pixels(image: Image.Image) -> Image.Image:
    out = image.convert("RGBA")
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            if pixels[x, y][3] == 0:
                pixels[x, y] = (0, 0, 0, 0)
    return out


def remove_purple_cast(image: Image.Image) -> Image.Image:
    """Despill chroma-key and source wax shadows into the warm tavern palette."""
    out = image.convert("RGBA")
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                continue
            red_purple = (
                red >= 80
                and blue >= 45
                and green <= 65
                and blue >= green * 1.25
                and red >= green * 1.2
                and abs(red - blue) <= 130
            )
            key_magenta = red >= 120 and blue >= 110 and green <= 40
            dark_blue_purple = blue >= 24 and green <= 12 and blue > red * 1.25 and red <= 70
            if key_magenta or red_purple:
                warm_green = max(green + 10, min(68, max(28, red // 4)))
                warm_blue = min(blue, max(8, int(warm_green * 0.64)))
                pixels[x, y] = (red, warm_green, warm_blue, alpha)
            elif dark_blue_purple:
                warm_red = max(red, 22)
                warm_green = max(green + 6, 6)
                warm_blue = min(blue, max(4, int(warm_green * 0.8)))
                pixels[x, y] = (warm_red, warm_green, warm_blue, alpha)
    return out


def normalize_asset(source: Image.Image, asset_id: str) -> Image.Image:
    spec = ASSETS[asset_id]
    rect = SOURCE_RECTS[asset_id]
    crop = source.crop(rect).convert("RGBA")
    keyed = remove_magenta_key(crop)
    fitted = ImageOps.fit(
        keyed,
        spec["native_size"],
        method=Image.Resampling.LANCZOS,
        centering=(0.5, 0.5),
    ).convert("RGBA")
    fitted = ImageEnhance.Contrast(fitted).enhance(float(spec["contrast"]))
    fitted = ImageEnhance.Sharpness(fitted).enhance(1.35)
    quantized = fitted.convert("RGB").quantize(colors=int(spec["colors"]), method=Image.Quantize.MEDIANCUT).convert("RGBA")
    quantized.putalpha(fitted.getchannel("A").point(lambda value: 255 if value >= 28 else 0))
    return clear_transparent_pixels(remove_purple_cast(quantized))


def save_pair(asset_id: str, native: Image.Image) -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    native_path = SOURCE / f"{asset_id}_native.png"
    runtime_path = RUNTIME / f"{asset_id}.png"
    native.save(native_path)
    runtime = native.resize(ASSETS[asset_id]["runtime_size"], Image.Resampling.NEAREST)
    runtime.save(runtime_path)
    print(f"{asset_id}: {native.size} -> {runtime.size}")


def write_manifest() -> None:
    assets = {}
    for asset_id, spec in ASSETS.items():
        assets[asset_id] = {
            "id": asset_id,
            "source_rect": list(SOURCE_RECTS[asset_id]),
            "native_size": list(spec["native_size"]),
            "runtime_size": list(spec["runtime_size"]),
            "native_file": f"assets/source/ui/wind_notice/{asset_id}_native.png",
            "runtime_file": f"assets/textures/ui/wind_notice/{asset_id}.png",
            "safe_area": spec["safe_area"],
            "intended_godot_use": spec["intended_godot_use"],
        }
    manifest = {
        "id": "wind_notice",
        "raw_source": RAW_SOURCE.relative_to(ROOT).as_posix(),
        "prompt": PROMPT.relative_to(ROOT).as_posix(),
        "scale": SCALE,
        "assets": assets,
    }
    SOURCE.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"manifest: {MANIFEST.relative_to(ROOT).as_posix()}")


def make_contact_sheet(outputs: dict[str, Image.Image]) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (900, 640), (8, 25, 29, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((20, 14), "Wind notice UI - extracted imagegen source, fixed manifest crops", fill=(220, 204, 176, 255))
    panel = outputs["wind_notice_panel"].resize(ASSETS["wind_notice_panel"]["runtime_size"], Image.Resampling.NEAREST)
    icon = outputs["wind_notice_icon"].resize(ASSETS["wind_notice_icon"]["runtime_size"], Image.Resampling.NEAREST)
    stamp = outputs["wind_notice_stamp"].resize(ASSETS["wind_notice_stamp"]["runtime_size"], Image.Resampling.NEAREST)
    spark = outputs["wind_notice_spark"].resize(ASSETS["wind_notice_spark"]["runtime_size"], Image.Resampling.NEAREST)
    sheet.alpha_composite(panel, (118, 48))
    sheet.alpha_composite(icon, (140, 96))
    sheet.alpha_composite(stamp, (552, 92))
    sheet.alpha_composite(spark, (672, 92))
    draw.rectangle((250, 120, 540, 174), outline=(207, 117, 18, 255), width=1)
    draw.text((250, 180), "runtime composition preview", fill=(156, 141, 120, 255))

    panel_preview = outputs["wind_notice_panel"].resize((450, 180), Image.Resampling.NEAREST)
    sheet.alpha_composite(panel_preview, (44, 340))
    draw.text((44, 526), "wind_notice_panel", fill=(220, 204, 176, 255))

    x = 540
    for asset_id in ["wind_notice_icon", "wind_notice_stamp", "wind_notice_spark"]:
        preview = outputs[asset_id].resize(
            (outputs[asset_id].width * 4, outputs[asset_id].height * 4),
            Image.Resampling.NEAREST,
        )
        sheet.alpha_composite(preview, (x, 340))
        draw.text((x, 340 + preview.height + 6), asset_id, fill=(220, 204, 176, 255))
        x += 128
    sheet.convert("RGB").save(CONTACT_SHEET)
    print(f"contact sheet: {CONTACT_SHEET.relative_to(ROOT).as_posix()}")


def main() -> None:
    source = load_source()
    outputs: dict[str, Image.Image] = {}
    for asset_id in ASSETS.keys():
        native = normalize_asset(source, asset_id)
        outputs[asset_id] = native
        save_pair(asset_id, native)
    write_manifest()
    make_contact_sheet(outputs)


if __name__ == "__main__":
    main()
