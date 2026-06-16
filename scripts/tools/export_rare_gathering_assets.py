from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance


ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = ROOT / "art_sources" / "generated_raw" / "rare_gathering"
MATERIAL_SOURCE = RAW_DIR / "rare_material_icons_sheet_v1.png"
PRODUCT_SOURCE = RAW_DIR / "rare_upgrade_items_sheet_v1.png"
PROMPT_SOURCE = RAW_DIR / "rare_gathering_icon_sheets_prompt_v1.txt"
SOURCE_DIR = ROOT / "assets" / "source" / "rare_gathering"
MANIFEST_PATH = SOURCE_DIR / "rare_gathering_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "rare_gathering_contact_sheet.png"
SCALE = 4
NATIVE_SIZE = (24, 24)

ASSETS = {
    "cave_mushroom": {
        "source": MATERIAL_SOURCE,
        "source_rel": "art_sources/generated_raw/rare_gathering/rare_material_icons_sheet_v1.png",
        "crop_rect": [36, 70, 520, 633],
        "runtime": "assets/textures/tavern/icons/cave_mushroom.png",
        "safe_area": [2, 1, 22, 23],
        "intended_godot_use": "Tavern material icon for cave_mushroom",
        "colors": 28,
    },
    "rock_lizard_meat": {
        "source": MATERIAL_SOURCE,
        "source_rel": "art_sources/generated_raw/rare_gathering/rare_material_icons_sheet_v1.png",
        "crop_rect": [620, 134, 1072, 618],
        "runtime": "assets/textures/tavern/icons/rock_lizard_meat.png",
        "safe_area": [2, 2, 22, 22],
        "intended_godot_use": "Tavern material icon for rock_lizard_meat",
        "colors": 26,
    },
    "north_sour_grape": {
        "source": MATERIAL_SOURCE,
        "source_rel": "art_sources/generated_raw/rare_gathering/rare_material_icons_sheet_v1.png",
        "crop_rect": [1142, 70, 1542, 648],
        "runtime": "assets/textures/tavern/icons/north_sour_grape.png",
        "safe_area": [2, 1, 22, 23],
        "intended_godot_use": "Tavern material icon for north_sour_grape",
        "colors": 28,
    },
    "black_malt": {
        "source": MATERIAL_SOURCE,
        "source_rel": "art_sources/generated_raw/rare_gathering/rare_material_icons_sheet_v1.png",
        "crop_rect": [1684, 74, 2142, 650],
        "runtime": "assets/textures/tavern/icons/black_malt.png",
        "safe_area": [2, 1, 22, 23],
        "intended_godot_use": "Tavern material icon for black_malt",
        "colors": 28,
    },
    "cave_mushroom_stew": {
        "source": PRODUCT_SOURCE,
        "source_rel": "art_sources/generated_raw/rare_gathering/rare_upgrade_items_sheet_v1.png",
        "crop_rect": [38, 320, 474, 674],
        "runtime": "assets/textures/tavern/items/cave_mushroom_stew.png",
        "safe_area": [1, 4, 23, 21],
        "intended_godot_use": "Tavern product icon for cave_mushroom_stew",
        "colors": 28,
    },
    "rock_lizard_steak": {
        "source": PRODUCT_SOURCE,
        "source_rel": "art_sources/generated_raw/rare_gathering/rare_upgrade_items_sheet_v1.png",
        "crop_rect": [520, 338, 940, 692],
        "runtime": "assets/textures/tavern/items/rock_lizard_steak.png",
        "safe_area": [1, 4, 23, 21],
        "intended_godot_use": "Tavern product icon for rock_lizard_steak",
        "colors": 26,
    },
    "old_road_wine": {
        "source": PRODUCT_SOURCE,
        "source_rel": "art_sources/generated_raw/rare_gathering/rare_upgrade_items_sheet_v1.png",
        "crop_rect": [1076, 120, 1300, 704],
        "runtime": "assets/textures/tavern/items/old_road_wine.png",
        "safe_area": [6, 1, 18, 23],
        "intended_godot_use": "Tavern product icon for old_road_wine",
        "colors": 26,
    },
    "miner_dark_ale": {
        "source": PRODUCT_SOURCE,
        "source_rel": "art_sources/generated_raw/rare_gathering/rare_upgrade_items_sheet_v1.png",
        "crop_rect": [1350, 286, 1718, 706],
        "runtime": "assets/textures/tavern/items/miner_dark_ale.png",
        "safe_area": [2, 3, 22, 22],
        "intended_godot_use": "Tavern product icon for miner_dark_ale",
        "colors": 28,
    },
}


def remove_chroma_key(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, _a = pixels[x, y]
            if g >= 120 and g > r * 1.25 and g > b * 1.25 and g > max(r, b) + 24:
                pixels[x, y] = (0, 0, 0, 0)
    return rgba


def quantize_visible(image: Image.Image, colors: int) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A").point(lambda value: 255 if value >= 104 else 0)
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


def normalize_icon(source: Image.Image, crop_rect: list[int], colors: int) -> Image.Image:
    crop = remove_chroma_key(source.crop(tuple(crop_rect)))
    crop.thumbnail((22, 22), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", NATIVE_SIZE, (0, 0, 0, 0))
    offset = ((NATIVE_SIZE[0] - crop.width) // 2, (NATIVE_SIZE[1] - crop.height) // 2)
    canvas.alpha_composite(crop, offset)

    rgb = canvas.convert("RGB")
    contrast = ImageEnhance.Contrast(rgb).enhance(1.18)
    color = ImageEnhance.Color(contrast).enhance(0.92)
    sharp = ImageEnhance.Sharpness(color).enhance(1.35).convert("RGBA")
    sharp.putalpha(canvas.getchannel("A"))
    return quantize_visible(sharp, colors)


def export_assets() -> dict[str, Image.Image]:
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    (ROOT / "assets" / "textures" / "tavern" / "icons").mkdir(parents=True, exist_ok=True)
    (ROOT / "assets" / "textures" / "tavern" / "items").mkdir(parents=True, exist_ok=True)

    loaded_sources: dict[Path, Image.Image] = {}
    outputs: dict[str, Image.Image] = {}
    for item_id, spec in ASSETS.items():
        source_path = Path(spec["source"])
        if source_path not in loaded_sources:
            loaded_sources[source_path] = Image.open(source_path).convert("RGBA")
        native = normalize_icon(loaded_sources[source_path], list(spec["crop_rect"]), int(spec["colors"]))
        native.save(SOURCE_DIR / f"{item_id}.png")

        runtime_path = ROOT / str(spec["runtime"])
        runtime = native.resize((NATIVE_SIZE[0] * SCALE, NATIVE_SIZE[1] * SCALE), Image.Resampling.NEAREST)
        runtime.save(runtime_path)
        outputs[item_id] = native
    return outputs


def write_manifest() -> None:
    manifest_assets = {}
    for item_id, spec in ASSETS.items():
        manifest_assets[item_id] = {
            "source": spec["source_rel"],
            "prompt": "art_sources/generated_raw/rare_gathering/rare_gathering_icon_sheets_prompt_v1.txt",
            "crop_rect": spec["crop_rect"],
            "native": f"assets/source/rare_gathering/{item_id}.png",
            "runtime": spec["runtime"],
            "native_size": list(NATIVE_SIZE),
            "runtime_size": [NATIVE_SIZE[0] * SCALE, NATIVE_SIZE[1] * SCALE],
            "safe_area": spec["safe_area"],
            "intended_godot_use": spec["intended_godot_use"],
        }

    manifest = {
        "id": "rare_gathering_icons",
        "source_files": [
            "art_sources/generated_raw/rare_gathering/rare_material_icons_sheet_v1.png",
            "art_sources/generated_raw/rare_gathering/rare_upgrade_items_sheet_v1.png",
        ],
        "prompt": "art_sources/generated_raw/rare_gathering/rare_gathering_icon_sheets_prompt_v1.txt",
        "scale": SCALE,
        "assets": manifest_assets,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def draw_source_preview(sheet: Image.Image, source: Image.Image, box: tuple[int, int, int, int]) -> tuple[int, int, float, float]:
    width = box[2] - box[0]
    height = box[3] - box[1]
    preview = source.copy()
    preview.thumbnail((width, height), Image.Resampling.LANCZOS)
    x = box[0] + (width - preview.width) // 2
    y = box[1] + (height - preview.height) // 2
    sheet.alpha_composite(preview.convert("RGBA"), (x, y))
    return x, y, preview.width / source.width, preview.height / source.height


def make_contact_sheet(outputs: dict[str, Image.Image]) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    material_source = Image.open(MATERIAL_SOURCE).convert("RGBA")
    product_source = Image.open(PRODUCT_SOURCE).convert("RGBA")

    sheet = Image.new("RGBA", (1280, 900), (18, 15, 12, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((24, 18), "Rare gathering icon pipeline", fill=(224, 206, 174, 255))
    draw.text((24, 44), "fixed crop boxes, 24x24 native, 96x96 runtime", fill=(185, 164, 132, 255))

    mat_box = (24, 78, 1256, 488)
    prod_box = (24, 508, 1256, 820)
    mat_x, mat_y, mat_scale_x, mat_scale_y = draw_source_preview(sheet, material_source, mat_box)
    prod_x, prod_y, prod_scale_x, prod_scale_y = draw_source_preview(sheet, product_source, prod_box)

    for spec in ASSETS.values():
        crop = list(spec["crop_rect"])
        if spec["source"] == MATERIAL_SOURCE:
            origin_x, origin_y = mat_x, mat_y
            scale_x, scale_y = mat_scale_x, mat_scale_y
        else:
            origin_x, origin_y = prod_x, prod_y
            scale_x, scale_y = prod_scale_x, prod_scale_y
        rect = (
            int(origin_x + crop[0] * scale_x),
            int(origin_y + crop[1] * scale_y),
            int(origin_x + crop[2] * scale_x),
            int(origin_y + crop[3] * scale_y),
        )
        draw.rectangle(rect, outline=(255, 188, 86, 255), width=2)

    x = 24
    y = 840
    for item_id in ASSETS.keys():
        preview = outputs[item_id].resize((48, 48), Image.Resampling.NEAREST)
        sheet.alpha_composite(preview, (x, y))
        draw.text((x + 54, y + 16), item_id, fill=(224, 206, 174, 255))
        x += 156

    sheet.convert("RGB").save(CONTACT_SHEET)


def main() -> None:
    for path in [MATERIAL_SOURCE, PRODUCT_SOURCE, PROMPT_SOURCE]:
        if not path.exists():
            raise FileNotFoundError(f"missing rare gathering source: {path}")
    outputs = export_assets()
    write_manifest()
    make_contact_sheet(outputs)
    print("exported rare gathering icons")
    print("contact sheet: docs/art/rare_gathering_contact_sheet.png")


if __name__ == "__main__":
    main()
