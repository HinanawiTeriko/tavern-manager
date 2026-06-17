from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = ROOT / "art_sources" / "generated_raw" / "clean_table_inference"
RAW_REFERENCE = RAW_DIR / "clean_table_inference_reference_v1.png"
RAW_PROMPT = RAW_DIR / "clean_table_inference_prompt_v1.txt"
SOURCE = ROOT / "assets" / "source" / "ui" / "clean_table_inference"
RUNTIME = ROOT / "assets" / "textures" / "ui" / "clean_table_inference"
REFERENCE = SOURCE / "reference"
MANIFEST = SOURCE / "clean_table_inference_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "clean_table_inference_contact_sheet.png"
SCALE = 4

ASSETS = {
    "clean_table_backdrop": {"native": (320, 180), "runtime": (1280, 720), "safe": [0, 0, 1280, 720], "margins": [0, 0, 0, 0]},
    "clue_tray_panel": {"native": (76, 142), "runtime": (304, 568), "safe": [28, 40, 276, 528], "margins": [36, 36, 36, 36]},
    "inference_book_panel": {"native": (130, 142), "runtime": (520, 568), "safe": [44, 68, 476, 500], "margins": [48, 48, 48, 48]},
    "solved_strip_panel": {"native": (76, 116), "runtime": (304, 464), "safe": [24, 28, 280, 440], "margins": [32, 32, 32, 32]},
    "clue_paper": {"native": (66, 19), "runtime": (264, 76), "safe": [44, 16, 244, 64], "margins": [20, 16, 20, 16]},
    "blank_slot_normal": {"native": (44, 10), "runtime": (176, 40), "safe": [18, 4, 158, 34], "margins": [20, 12, 20, 12]},
    "blank_slot_hover": {"native": (44, 10), "runtime": (176, 40), "safe": [18, 4, 158, 34], "margins": [20, 12, 20, 12]},
    "blank_slot_pressed": {"native": (44, 10), "runtime": (176, 40), "safe": [18, 4, 158, 34], "margins": [20, 12, 20, 12]},
    "continue_button_normal": {"native": (44, 15), "runtime": (176, 60), "safe": [28, 10, 148, 50], "margins": [24, 16, 24, 16]},
    "continue_button_hover": {"native": (44, 15), "runtime": (176, 60), "safe": [28, 10, 148, 50], "margins": [24, 16, 24, 16]},
    "continue_button_pressed": {"native": (44, 15), "runtime": (176, 60), "safe": [28, 10, 148, 50], "margins": [24, 16, 24, 16]},
}

CROPS = {
    "clue_tray_panel": (48, 145, 392, 742),
    "inference_book_panel": (408, 150, 1270, 742),
    "solved_strip_panel": (1326, 150, 1638, 662),
    "clue_paper": (138, 252, 356, 340),
    "blank_slot_normal": (528, 432, 796, 512),
    "continue_button_normal": (1326, 742, 1640, 884),
}


def load_reference() -> Image.Image:
    if not RAW_REFERENCE.exists():
        raise FileNotFoundError(f"missing generated clean-table reference: {RAW_REFERENCE}")
    if not RAW_PROMPT.exists():
        raise FileNotFoundError(f"missing generated clean-table prompt record: {RAW_PROMPT}")
    with Image.open(RAW_REFERENCE) as image:
        return image.convert("RGBA")


def quantize_rgba(image: Image.Image, colors: int = 72) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    rgb = Image.new("RGB", rgba.size, (0, 0, 0))
    rgb.paste(rgba.convert("RGB"), mask=alpha)
    quantized = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    quantized.putalpha(alpha)
    return quantized


def fit_native(reference: Image.Image, asset_id: str, colors: int = 72) -> Image.Image:
    native_size = ASSETS[asset_id]["native"]
    fitted = ImageOps.fit(reference, native_size, method=Image.Resampling.BOX, centering=(0.5, 0.5))
    return quantize_rgba(fitted, colors)


def crop_native(reference: Image.Image, asset_id: str, crop: tuple[int, int, int, int] | None = None, colors: int = 56) -> Image.Image:
    source_rect = crop if crop != None else CROPS[asset_id]
    cropped = reference.crop(source_rect)
    return fit_native(cropped, asset_id, colors)


def make_backdrop(reference: Image.Image) -> Image.Image:
    backdrop = fit_native(reference, "clean_table_backdrop", 96)
    return clean_backdrop_book_pages(backdrop)


def clean_backdrop_book_pages(backdrop: Image.Image) -> Image.Image:
    cleaned = backdrop.copy()
    draw = ImageDraw.Draw(cleaned)
    left_fill = _sample_average(cleaned, (94, 38, 165, 131))
    right_fill = _sample_average(cleaned, (176, 38, 240, 131))
    _paper_fill(draw, (92, 36, 166, 132), left_fill, 31)
    _paper_fill(draw, (176, 36, 241, 132), right_fill, 41)
    binding = _sample_average(cleaned, (166, 34, 176, 134))
    draw.rectangle((166, 34, 176, 134), fill=binding)
    draw.line((170, 36, 170, 132), fill=_darken(binding, 0.50))
    return quantize_rgba(cleaned, 80)


def clean_book_pages(book: Image.Image) -> Image.Image:
    cleaned = book.copy()
    draw = ImageDraw.Draw(cleaned)
    left_fill = _sample_average(cleaned, (25, 24, 55, 122))
    right_fill = _sample_average(cleaned, (76, 24, 111, 122))
    # The generated reference is the art source, but these rectangles remove
    # baked-in placeholder clue boxes so Godot can render the real text/slots.
    _paper_fill(draw, (19, 19, 58, 126), left_fill, 12)
    _paper_fill(draw, (73, 19, 115, 126), right_fill, 21)
    draw.rectangle((61, 8, 68, 134), fill=_sample_average(cleaned, (61, 12, 68, 130)))
    draw.line((64, 12, 64, 131), fill=_darken(_sample_average(cleaned, (61, 12, 68, 130)), 0.55))
    return quantize_rgba(cleaned, 52)


def _paper_fill(draw: ImageDraw.ImageDraw, rect: tuple[int, int, int, int], fill: tuple[int, int, int, int], salt: int) -> None:
    draw.rectangle(rect, fill=fill)
    x0, y0, x1, y1 = rect
    for y in range(y0 + 3, y1 - 3):
        for x in range(x0 + 3, x1 - 3):
            n = ((x * 73 + y * 151 + salt * 193) ^ ((x + y) * 19)) & 255
            if n < 5:
                draw.point((x, y), fill=_darken(fill, 0.82))
            elif n > 251:
                draw.point((x, y), fill=_lighten(fill, 1.10))


def _sample_average(image: Image.Image, rect: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    crop = image.crop(rect).convert("RGBA")
    count = 0
    totals = [0, 0, 0, 0]
    pixel_data = crop.get_flattened_data() if hasattr(crop, "get_flattened_data") else crop.getdata()
    for r, g, b, a in pixel_data:
        if a < 20:
            continue
        totals[0] += r
        totals[1] += g
        totals[2] += b
        totals[3] += a
        count += 1
    if count == 0:
        return (160, 116, 72, 255)
    return tuple(int(channel / count) for channel in totals)  # type: ignore[return-value]


def _darken(color: tuple[int, int, int, int], factor: float) -> tuple[int, int, int, int]:
    return (int(color[0] * factor), int(color[1] * factor), int(color[2] * factor), color[3])


def _lighten(color: tuple[int, int, int, int], factor: float) -> tuple[int, int, int, int]:
    return (min(255, int(color[0] * factor)), min(255, int(color[1] * factor)), min(255, int(color[2] * factor)), color[3])


def make_state_variant(base: Image.Image, state: str) -> Image.Image:
    if state == "normal":
        return base.copy()
    rgba = base.convert("RGBA")
    alpha = rgba.getchannel("A")
    rgb = rgba.convert("RGB")
    if state == "hover":
        overlay = Image.new("RGB", rgb.size, (232, 152, 44))
        rgb = Image.blend(rgb, overlay, 0.22)
    elif state == "pressed":
        overlay = Image.new("RGB", rgb.size, (20, 14, 10))
        rgb = Image.blend(rgb, overlay, 0.34)
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return quantize_rgba(out, 36)


def build_assets(reference: Image.Image) -> dict[str, Image.Image]:
    assets = {
        "clean_table_backdrop": make_backdrop(reference),
        "clue_tray_panel": crop_native(reference, "clue_tray_panel", colors=56),
        "inference_book_panel": clean_book_pages(crop_native(reference, "inference_book_panel", colors=72)),
        "solved_strip_panel": crop_native(reference, "solved_strip_panel", colors=56),
        "clue_paper": crop_native(reference, "clue_paper", colors=36),
    }
    blank_base = crop_native(reference, "blank_slot_normal", colors=36)
    continue_base = crop_native(reference, "continue_button_normal", colors=36)
    for state in ("normal", "hover", "pressed"):
        assets[f"blank_slot_{state}"] = make_state_variant(blank_base, state)
        assets[f"continue_button_{state}"] = make_state_variant(continue_base, state)
    return assets


def save_outputs(assets: dict[str, Image.Image], reference: Image.Image) -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    REFERENCE.mkdir(parents=True, exist_ok=True)
    reference.save(REFERENCE / "clean_table_inference_reference_v1.png")
    compose_scene_preview(assets).save(REFERENCE / "clean_table_inference_runtime_preview.png")
    for asset_id, image in assets.items():
        native_path = SOURCE / f"{asset_id}_native.png"
        runtime_path = RUNTIME / f"{asset_id}.png"
        image.save(native_path)
        image.resize(ASSETS[asset_id]["runtime"], Image.Resampling.NEAREST).save(runtime_path)
        print(f"{asset_id}: {image.size} -> {ASSETS[asset_id]['runtime']}")


def compose_scene_preview(assets: dict[str, Image.Image]) -> Image.Image:
    preview = assets["clean_table_backdrop"].resize((1280, 720), Image.Resampling.NEAREST)
    paper = assets["clue_paper"].resize((264, 76), Image.Resampling.NEAREST)
    for y in (126, 218, 310):
        preview.alpha_composite(paper, (76, y))
    blank = assets["blank_slot_normal"].resize((176, 40), Image.Resampling.NEAREST)
    preview.alpha_composite(blank, (558, 214))
    preview.alpha_composite(blank, (756, 214))
    button = assets["continue_button_normal"].resize((176, 60), Image.Resampling.NEAREST)
    preview.alpha_composite(button, (1010, 592))
    return preview


def write_manifest() -> None:
    manifest_assets = {}
    for asset_id, contract in ASSETS.items():
        manifest_assets[asset_id] = {
            "id": asset_id,
            "source_file": "art_sources/generated_raw/clean_table_inference/clean_table_inference_reference_v1.png",
            "prompt": "art_sources/generated_raw/clean_table_inference/clean_table_inference_prompt_v1.txt",
            "native_file": f"assets/source/ui/clean_table_inference/{asset_id}_native.png",
            "output_file": f"assets/textures/ui/clean_table_inference/{asset_id}.png",
            "native_size": list(contract["native"]),
            "size": list(contract["runtime"]),
            "safe_area": contract["safe"],
            "nine_slice_margins": contract["margins"],
            "intended_godot_use": clean_table_use(asset_id),
        }
        if asset_id in CROPS:
            manifest_assets[asset_id]["source_rect"] = list(CROPS[asset_id])
    manifest = {
        "id": "clean_table_inference_ui",
        "scale": SCALE,
        "source": "art_sources/generated_raw/clean_table_inference/clean_table_inference_reference_v1.png",
        "prompt": "art_sources/generated_raw/clean_table_inference/clean_table_inference_prompt_v1.txt",
        "reference": "assets/source/ui/clean_table_inference/reference/clean_table_inference_reference_v1.png",
        "runtime_preview": "assets/source/ui/clean_table_inference/reference/clean_table_inference_runtime_preview.png",
        "assets": manifest_assets,
    }
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def clean_table_use(asset_id: str) -> str:
    if asset_id == "clean_table_backdrop":
        return "CleanTableInferenceScreen full-screen TextureRect backdrop"
    if asset_id.endswith("_panel"):
        return "CleanTableInferenceScreen panel StyleBoxTexture"
    if asset_id == "clue_paper":
        return "Dynamic clue scrap Panel StyleBoxTexture"
    if asset_id.startswith("blank_slot"):
        return "InferenceBlank Button StyleBoxTexture state"
    if asset_id.startswith("continue_button"):
        return "ExtinguishBtn Button StyleBoxTexture state"
    return "CleanTableInferenceScreen texture"


def make_contact_sheet(assets: dict[str, Image.Image], reference: Image.Image) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (1280, 980), (18, 16, 14, 255))
    raw = ImageOps.contain(reference, (600, 338), Image.Resampling.LANCZOS)
    sheet.alpha_composite(raw, (24, 24))
    preview = compose_scene_preview(assets)
    sheet.alpha_composite(preview.resize((600, 338), Image.Resampling.NEAREST), (656, 24))
    x = 24
    y = 410
    for asset_id in ("clue_tray_panel", "inference_book_panel", "solved_strip_panel", "clue_paper"):
        runtime = assets[asset_id].resize(ASSETS[asset_id]["runtime"], Image.Resampling.NEAREST)
        max_w, max_h = 220, 190
        scale = min(max_w / runtime.width, max_h / runtime.height, 1.0)
        thumb = runtime.resize((int(runtime.width * scale), int(runtime.height * scale)), Image.Resampling.NEAREST)
        sheet.alpha_composite(thumb, (x, y))
        x += max_w + 24
    x = 24
    y = 805
    for asset_id in ("blank_slot_normal", "blank_slot_hover", "blank_slot_pressed", "continue_button_normal", "continue_button_hover", "continue_button_pressed"):
        runtime = assets[asset_id].resize(ASSETS[asset_id]["runtime"], Image.Resampling.NEAREST)
        sheet.alpha_composite(runtime, (x, y))
        x += runtime.width + 18
    sheet.convert("RGB").save(CONTACT_SHEET)


def main() -> None:
    reference = load_reference()
    assets = build_assets(reference)
    save_outputs(assets, reference)
    write_manifest()
    make_contact_sheet(assets, reference)
    print(f"manifest: {MANIFEST}")
    print(f"contact_sheet: {CONTACT_SHEET}")


if __name__ == "__main__":
    main()

