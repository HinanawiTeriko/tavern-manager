from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "tavern_reward_hud" / "tavern_reward_hud_sheet_v1.png"
SOURCE_DIR = ROOT / "assets" / "source" / "tavern" / "reward_hud"
RUNTIME_DIR = ROOT / "assets" / "textures" / "ui" / "reward_hud"
MANIFEST_PATH = SOURCE_DIR / "tavern_reward_hud_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_reward_hud_contact_sheet.png"
SCALE = 4

ASSETS = {
    "reward_gold_progress_bg": {
        "crop_rect": [58, 108, 710, 198],
        "native_size": [48, 12],
        "safe_area": [3, 2, 45, 10],
        "intended_godot_use": "Tavern TopPanel/GoldProgress/Bg understated milestone groove",
        "colors": 24,
    },
    "reward_gold_progress_fill": {
        "crop_rect": [788, 128, 1174, 190],
        "native_size": [48, 12],
        "safe_area": [2, 2, 46, 10],
        "intended_godot_use": "Tavern TopPanel/GoldProgress/Fill low-brightness amber fill",
        "colors": 20,
        "mute_gold": True,
    },
    "reward_gold_progress_ornate": {
        "crop_rect": [92, 518, 1074, 615],
        "native_size": [48, 12],
        "safe_area": [2, 1, 46, 11],
        "intended_godot_use": "Tavern TopPanel/GoldProgress/Ornate milestone-only flash overlay",
        "colors": 26,
    },
    "reward_rep_progress_bg": {
        "crop_rect": [58, 314, 710, 400],
        "native_size": [48, 12],
        "safe_area": [3, 2, 45, 10],
        "intended_godot_use": "Tavern TopPanel/ReputationProgress/Bg understated milestone groove",
        "colors": 24,
    },
    "reward_rep_progress_fill": {
        "crop_rect": [788, 340, 1174, 398],
        "native_size": [48, 12],
        "safe_area": [2, 2, 46, 10],
        "intended_godot_use": "Tavern TopPanel/ReputationProgress/Fill cool low-brightness fill",
        "colors": 20,
        "coolify": True,
    },
    "reward_rep_progress_ornate": {
        "crop_rect": [94, 682, 1076, 782],
        "native_size": [48, 12],
        "safe_area": [2, 1, 46, 11],
        "intended_godot_use": "Tavern TopPanel/ReputationProgress/Ornate milestone-only flash overlay",
        "colors": 26,
        "coolify": True,
    },
    "reward_coin_particle": {
        "crop_rect": [1290, 88, 1426, 224],
        "native_size": [8, 8],
        "safe_area": [1, 1, 7, 7],
        "intended_godot_use": "RewardCoinPhysicsLayer temporary physical coin sprite",
        "colors": 22,
    },
    "reward_rep_particle": {
        "crop_rect": [1290, 310, 1425, 430],
        "native_size": [8, 8],
        "safe_area": [1, 1, 7, 7],
        "intended_godot_use": "RewardFeedbackLayer reputation mark particle",
        "colors": 22,
        "boost_cool": True,
    },
    "reward_spark": {
        "crop_rect": [1312, 548, 1395, 632],
        "native_size": [6, 6],
        "safe_area": [1, 1, 5, 5],
        "intended_godot_use": "RewardFeedbackLayer small milestone spark",
        "colors": 18,
        "boost_warm": True,
    },
}


def remove_chroma_key(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if r >= 190 and b >= 190 and g <= 90 and abs(r - b) <= 70:
                pixels[x, y] = (0, 0, 0, 0)
    return rgba


def coolify_reputation(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            if r >= 85 and g >= 45 and b <= 105:
                luma = int((r * 0.35) + (g * 0.45) + (b * 0.2))
                pixels[x, y] = (
                    max(22, int(luma * 0.38)),
                    max(70, int(luma * 0.82)),
                    min(230, int(luma * 1.22)),
                    a,
                )
    return rgba


def mute_gold_fill(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            if r >= 105 and g >= 55 and b <= 95:
                pixels[x, y] = (
                    max(78, int(r * 0.72)),
                    max(48, int(g * 0.72)),
                    max(18, int(b * 0.85)),
                    a,
                )
    return rgba


def boost_cool_particle(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            if b >= 90 and g >= 50:
                pixels[x, y] = (
                    min(r, 96),
                    max(g, 104),
                    max(b, 148),
                    a,
                )
    return rgba


def boost_warm_spark(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            if r >= 180 and g >= 80:
                pixels[x, y] = (
                    max(r, 220),
                    min(max(g, 104), 188),
                    min(b, 74),
                    a,
                )
    return rgba


def quantize_visible(image: Image.Image, colors: int) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A").point(lambda value: 255 if value >= 72 else 0)
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
    crop = reference.crop(tuple(spec["crop_rect"]))
    keyed = remove_chroma_key(crop)
    native_size = tuple(spec["native_size"])
    resized = keyed.resize(native_size, Image.Resampling.LANCZOS)
    rgb = resized.convert("RGB")
    contrast = ImageEnhance.Contrast(rgb).enhance(1.08)
    color = ImageEnhance.Color(contrast).enhance(0.96)
    sharp = ImageEnhance.Sharpness(color).enhance(1.45).convert("RGBA")
    sharp.putalpha(resized.getchannel("A"))
    if bool(spec.get("mute_gold", False)):
        sharp = mute_gold_fill(sharp)
    if bool(spec.get("coolify", False)):
        sharp = coolify_reputation(sharp)
    if bool(spec.get("boost_cool", False)):
        sharp = boost_cool_particle(sharp)
    if bool(spec.get("boost_warm", False)):
        sharp = boost_warm_spark(sharp)
    return quantize_visible(sharp, int(spec["colors"]))


def save_assets(reference: Image.Image) -> dict[str, Image.Image]:
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    outputs: dict[str, Image.Image] = {}
    for asset_id, spec in ASSETS.items():
        native = normalize_asset(reference, spec)
        native_path = SOURCE_DIR / f"{asset_id}_native.png"
        runtime_path = RUNTIME_DIR / f"{asset_id}.png"
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
            "native": f"assets/source/tavern/reward_hud/{asset_id}_native.png",
            "runtime": f"assets/textures/ui/reward_hud/{asset_id}.png",
            "native_size": native_size,
            "runtime_size": runtime_size,
            "safe_area": spec["safe_area"],
            "intended_godot_use": spec["intended_godot_use"],
        }
    manifest = {
        "id": "tavern_reward_hud",
        "source": "art_sources/generated_raw/tavern_reward_hud/tavern_reward_hud_sheet_v1.png",
        "prompt": "art_sources/generated_raw/tavern_reward_hud/tavern_reward_hud_sheet_v1_prompt.txt",
        "scale": SCALE,
        "assets": manifest_assets,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def make_contact_sheet(reference: Image.Image, natives: dict[str, Image.Image]) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (1280, 700), (18, 14, 12, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((16, 14), "Tavern reward HUD pipeline - understated default, milestone-only ornate", fill=(220, 204, 176, 255))
    draw.text((16, 40), "source with explicit crop boxes", fill=(180, 166, 142, 255))
    source_preview = reference.resize((768, 512), Image.Resampling.LANCZOS).convert("RGBA")
    sheet.alpha_composite(source_preview, (16, 68))
    for spec in ASSETS.values():
        crop = spec["crop_rect"]
        scale_x = 768 / reference.width
        scale_y = 512 / reference.height
        rect = (
            int(crop[0] * scale_x) + 16,
            int(crop[1] * scale_y) + 68,
            int(crop[2] * scale_x) + 16,
            int(crop[3] * scale_y) + 68,
        )
        draw.rectangle(rect, outline=(255, 188, 92, 255), width=1)

    x = 820
    y = 82
    for asset_id, native in natives.items():
        preview = native.resize((native.width * 4, native.height * 4), Image.Resampling.NEAREST)
        sheet.alpha_composite(preview, (x, y))
        draw.text((x, y + preview.height + 4), asset_id.replace("reward_", ""), fill=(210, 195, 170, 255))
        y += preview.height + 38
        if y > 630:
            x += 230
            y = 82
    sheet.convert("RGB").save(CONTACT_SHEET)


def main() -> None:
    if not RAW_SOURCE.exists():
        raise FileNotFoundError(f"missing Tavern reward HUD source: {RAW_SOURCE}")
    reference = Image.open(RAW_SOURCE).convert("RGBA")
    outputs = save_assets(reference)
    write_manifest()
    make_contact_sheet(reference, outputs)
    print("exported Tavern reward HUD assets")
    print("contact sheet: docs/art/tavern_reward_hud_contact_sheet.png")


if __name__ == "__main__":
    main()
