from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = ROOT / "art_sources" / "generated_raw" / "clean_table_inference" / "components"
SOURCE = ROOT / "assets" / "source" / "ui" / "clean_table_inference" / "components"
RUNTIME = ROOT / "assets" / "textures" / "ui" / "clean_table_inference" / "components"
MANIFEST = SOURCE / "clean_table_components_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "clean_table_components_contact_sheet.png"
SCALE = 4

ASSETS = {
    "clue_scrap": {
        "source": "clue_scrap_source_v1.png",
        "source_rect": (245, 235, 1290, 790),
        "native": (66, 19),
        "runtime": (264, 76),
        "margins": (36, 28, 36, 28),
        "safe": (24, 12, 240, 64),
        "use": "Dynamic clue scrap Panel StyleBoxTexture and filled blank paper.",
    },
    "inference_note": {
        "source": "inference_note_source_v1.png",
        "source_rect": (120, 50, 1130, 1200),
        "native": (128, 142),
        "runtime": (512, 568),
        "margins": (48, 48, 48, 48),
        "safe": (42, 54, 470, 520),
        "use": "CleanTableInferenceScreen BookArea inference paper StyleBoxTexture.",
    },
    "ink_ring_slot": {
        "source": "ink_ring_slot_source_v1.png",
        "source_rect": (130, 80, 1120, 1080),
        "native": (12, 12),
        "runtime": (48, 48),
        "margins": (0, 0, 0, 0),
        "safe": (8, 8, 40, 40),
        "use": "Empty InferenceBlank Button StyleBoxTexture drop target.",
    },
    "conclusion_strip": {
        "source": "conclusion_strip_source_v1.png",
        "source_rect": (180, 230, 1995, 500),
        "native": (70, 16),
        "runtime": (280, 64),
        "margins": (40, 24, 40, 24),
        "safe": (24, 12, 256, 52),
        "use": "Solved conclusion paper strip Panel StyleBoxTexture.",
    },
    "keyword_notes_panel": {
        "source": "keyword_notes_panel_source_v1.png",
        "source_rect": (0, 0, 917, 1715),
        "native": (76, 142),
        "runtime": (304, 568),
        "margins": (0, 0, 0, 0),
        "safe": (34, 52, 270, 522),
        "use": "CleanTableInferenceScreen ClueArea keyword notes page TextureRect.",
    },
    "paper_tag_button": {
        "source": "paper_tag_button_states_source_v1.png",
        "source_rect": (190, 90, 1080, 393),
        "native": (44, 15),
        "runtime": (176, 60),
        "margins": (40, 24, 40, 24),
        "safe": (28, 10, 148, 50),
        "use": "Legacy normal ExtinguishBtn paper tag Button StyleBoxTexture alias.",
    },
    "paper_tag_button_normal": {
        "source": "paper_tag_button_states_source_v1.png",
        "source_rect": (190, 90, 1080, 393),
        "native": (44, 15),
        "runtime": (176, 60),
        "margins": (40, 24, 40, 24),
        "safe": (28, 10, 148, 50),
        "use": "ExtinguishBtn normal paper tag Button StyleBoxTexture.",
    },
    "paper_tag_button_hover": {
        "source": "paper_tag_button_states_source_v1.png",
        "source_rect": (190, 480, 1080, 783),
        "native": (44, 15),
        "runtime": (176, 60),
        "margins": (40, 24, 40, 24),
        "safe": (28, 10, 148, 50),
        "use": "ExtinguishBtn hover paper tag Button StyleBoxTexture.",
    },
    "paper_tag_button_pressed": {
        "source": "paper_tag_button_states_source_v1.png",
        "source_rect": (190, 870, 1080, 1173),
        "native": (44, 15),
        "runtime": (176, 60),
        "margins": (40, 24, 40, 24),
        "safe": (28, 10, 148, 50),
        "use": "ExtinguishBtn pressed paper tag Button StyleBoxTexture.",
    },
}


def load_source(asset_id: str) -> Image.Image:
    path = RAW_DIR / ASSETS[asset_id]["source"]
    if not path.exists():
        raise FileNotFoundError(f"{asset_id}: missing raw source {path}")
    with Image.open(path) as image:
        return image.convert("RGBA")


def remove_chroma_key(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                continue
            green_dominance = green - max(red, blue)
            if green > 150 and green_dominance > 60:
                pixels[x, y] = (red, green, blue, 0)
            elif green > 100 and green_dominance > 30:
                fade = max(0, min(255, int((green_dominance - 30) * 8)))
                new_alpha = max(0, alpha - fade)
                pixels[x, y] = (red, max(red, blue), blue, new_alpha)
    return rgba


def snap_alpha(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    snapped = alpha.point(lambda value: 0 if value < 48 else 112 if value < 144 else 192 if value < 224 else 255)
    rgba.putalpha(snapped)
    return rgba


def quantize_rgba(image: Image.Image, colors: int = 32) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    rgb = Image.new("RGB", rgba.size, (0, 0, 0))
    rgb.paste(rgba.convert("RGB"), mask=alpha)
    quantized = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGBA")
    quantized.putalpha(alpha)
    return snap_alpha(quantized)


def make_native(asset_id: str, source: Image.Image) -> Image.Image:
    contract = ASSETS[asset_id]
    cropped = source.crop(contract["source_rect"])
    keyed = remove_chroma_key(cropped)
    resized = keyed.resize(contract["native"], Image.Resampling.BOX)
    return quantize_rgba(resized, 32)


def make_runtime(native: Image.Image, asset_id: str) -> Image.Image:
    return native.resize(ASSETS[asset_id]["runtime"], Image.Resampling.NEAREST)


def validate_asset(asset_id: str, native: Image.Image, runtime: Image.Image) -> None:
    contract = ASSETS[asset_id]
    if native.size != contract["native"]:
        raise ValueError(f"{asset_id}: wrong native size {native.size}")
    if runtime.size != contract["runtime"]:
        raise ValueError(f"{asset_id}: wrong runtime size {runtime.size}")
    alpha_min, alpha_max = native.getchannel("A").getextrema()
    if alpha_min != 0 or alpha_max < 180:
        raise ValueError(f"{asset_id}: alpha range {alpha_min}..{alpha_max} is not usable")
    expected = native.resize(contract["runtime"], Image.Resampling.NEAREST)
    if runtime.mode != expected.mode or runtime.tobytes() != expected.tobytes():
        raise ValueError(f"{asset_id}: runtime is not exact nearest-neighbor export")


def write_manifest() -> None:
    manifest_assets = {}
    for asset_id, contract in ASSETS.items():
        manifest_assets[asset_id] = {
            "id": asset_id,
            "source_file": f"art_sources/generated_raw/clean_table_inference/components/{contract['source']}",
            "prompt": "art_sources/generated_raw/clean_table_inference/components/component_prompts_v1.txt",
            "source_rect": list(contract["source_rect"]),
            "native_file": f"assets/source/ui/clean_table_inference/components/{asset_id}_native.png",
            "output_file": f"assets/textures/ui/clean_table_inference/components/{asset_id}.png",
            "native_size": list(contract["native"]),
            "size": list(contract["runtime"]),
            "safe_area": list(contract["safe"]),
            "nine_slice_margins": list(contract["margins"]),
            "intended_godot_use": contract["use"],
        }
    manifest = {
        "id": "clean_table_component_assets",
        "scale": SCALE,
        "style_reference": "art_sources/generated_raw/clean_table_inference/clean_table_components_style_reference_v1.png",
        "prompt": "art_sources/generated_raw/clean_table_inference/components/component_prompts_v1.txt",
        "assets": manifest_assets,
    }
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def make_contact_sheet(native_assets: dict[str, Image.Image]) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (1280, 980), (18, 18, 18, 255))
    draw = ImageDraw.Draw(sheet)
    x = 40
    y = 40
    for index, asset_id in enumerate(("clue_scrap", "inference_note", "ink_ring_slot", "conclusion_strip", "keyword_notes_panel", "paper_tag_button_normal", "paper_tag_button_hover", "paper_tag_button_pressed")):
        native = native_assets[asset_id]
        preview = native.resize(ASSETS[asset_id]["runtime"], Image.Resampling.NEAREST)
        if asset_id in ("inference_note", "keyword_notes_panel"):
            preview = ImageOps.contain(preview, (360, 400), Image.Resampling.NEAREST)
        elif asset_id == "ink_ring_slot":
            preview = ImageOps.contain(preview, (160, 160), Image.Resampling.NEAREST)
        else:
            preview = ImageOps.contain(preview, (360, 140), Image.Resampling.NEAREST)
        px = x + (index % 2) * 600
        py = y + int(index / 2) * 220
        tile = Image.new("RGBA", (520, 180), (30, 36, 36, 255))
        tile.alpha_composite(preview, ((tile.width - preview.width) // 2, (tile.height - preview.height) // 2))
        sheet.alpha_composite(tile, (px, py))
        draw.text((px, py + 186), asset_id, fill=(230, 220, 200, 255))
    sheet.save(CONTACT_SHEET)


def main() -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    native_assets: dict[str, Image.Image] = {}
    for asset_id in ASSETS:
        native = make_native(asset_id, load_source(asset_id))
        runtime = make_runtime(native, asset_id)
        validate_asset(asset_id, native, runtime)
        native.save(SOURCE / f"{asset_id}_native.png")
        runtime.save(RUNTIME / f"{asset_id}.png")
        native_assets[asset_id] = native
        print(f"{asset_id}: {native.size} -> {runtime.size}")
    write_manifest()
    make_contact_sheet(native_assets)


if __name__ == "__main__":
    main()
