from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageOps

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from character_contact_sheet import save_character_contact_sheet
from character_green_matte import despill_green_edges, despill_green_near_alpha, source_level_green_matte


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE_DIR = ROOT / "art_sources" / "generated_raw" / "characters" / "regular_customers"
RAW_SOURCE_V5_A = RAW_SOURCE_DIR / "regular_customer_expression_sheet_v5_a.png"
RAW_SOURCE_V5_B = RAW_SOURCE_DIR / "regular_customer_expression_sheet_v5_b.png"
RAW_SOURCE_V5_C = RAW_SOURCE_DIR / "regular_customer_expression_sheet_v5_c.png"
RAW_SOURCE_V7_A = RAW_SOURCE_DIR / "regular_customer_expansion_sheet_v7_a.png"
RAW_SOURCE_V7_B = RAW_SOURCE_DIR / "regular_customer_expansion_sheet_v7_b.png"
RAW_SOURCE_V7_C = RAW_SOURCE_DIR / "regular_customer_expansion_sheet_v7_c.png"
RAW_SOURCE_V7_D = RAW_SOURCE_DIR / "regular_customer_expansion_sheet_v7_d.png"
RAW_SOURCE_V7_E = RAW_SOURCE_DIR / "regular_customer_expansion_sheet_v7_e.png"
RAW_SOURCE_V8_A = RAW_SOURCE_DIR / "regular_customer_expansion_sheet_v8_a.png"
VERA_REFERENCE = ROOT / "art_sources" / "generated_raw" / "characters" / "vera" / "reference" / "vera_approved_reference_v2.png"
BELTA_STYLE_REFERENCE = RAW_SOURCE_DIR / "regular_belta_style_reference_v1.png"
SOURCE_DIR = ROOT / "assets" / "source" / "tavern" / "regular_customers"
RUNTIME_DIR = ROOT / "assets" / "textures" / "characters"
MANIFEST_PATH = SOURCE_DIR / "regular_customer_portraits_manifest.json"
CONTACT_SHEET_DIR = ROOT / "docs" / "art" / "characters"

NATIVE_SIZE = (128, 160)
RUNTIME_SIZE = (512, 640)
SCALE = 4
STYLE_PROFILE = "approved_vera_belta_runtime_matched_regular_portraits_v5"
UNIFORM_VISIBLE_HEIGHT = 154
UNIFORM_MAX_VISIBLE_WIDTH = 128
UNIFORM_BOTTOM_PADDING = 3
CUSTOMER_GROUPS = [
    {
        "source": RAW_SOURCE_V5_A,
        "prompt": RAW_SOURCE_V5_A.with_name("regular_customer_expression_sheet_v5_a_prompt.txt"),
        "customers": ["regular_belta", "regular_noel", "regular_masha", "regular_coen"],
    },
    {
        "source": RAW_SOURCE_V5_B,
        "prompt": RAW_SOURCE_V5_B.with_name("regular_customer_expression_sheet_v5_b_prompt.txt"),
        "customers": ["regular_dorin", "regular_elira", "regular_marco", "regular_nix"],
    },
    {
        "source": RAW_SOURCE_V5_C,
        "prompt": RAW_SOURCE_V5_C.with_name("regular_customer_expression_sheet_v5_c_prompt.txt"),
        "customers": ["regular_selene", "regular_gareth", "regular_lyra", "regular_oma"],
    },
    {
        "source": RAW_SOURCE_V8_A,
        "prompt": RAW_SOURCE_V8_A.with_name("regular_customer_expansion_sheet_v8_a_prompt.txt"),
        "customers": ["regular_ketta", "regular_bram", "regular_sova", "regular_petra"],
    },
    {
        "source": RAW_SOURCE_V7_B,
        "prompt": RAW_SOURCE_V7_B.with_name("regular_customer_expansion_sheet_v7_b_prompt.txt"),
        "customers": ["regular_jora", "regular_tamsin", "regular_kael", "regular_mirelle"],
    },
    {
        "source": RAW_SOURCE_V7_C,
        "prompt": RAW_SOURCE_V7_C.with_name("regular_customer_expansion_sheet_v7_c_prompt.txt"),
        "customers": ["regular_fenna", "regular_yuval", "regular_nara", "regular_iris"],
    },
    {
        "source": RAW_SOURCE_V7_D,
        "prompt": RAW_SOURCE_V7_D.with_name("regular_customer_expansion_sheet_v7_d_prompt.txt"),
        "customers": ["regular_bastian", "regular_qadir", "regular_rowan", "regular_maeve"],
    },
    {
        "source": RAW_SOURCE_V7_E,
        "prompt": RAW_SOURCE_V7_E.with_name("regular_customer_expansion_sheet_v7_e_prompt.txt"),
        "customers": ["regular_osric", "regular_lio"],
        "column_count": 4,
    },
]
CUSTOMERS = [customer_id for group in CUSTOMER_GROUPS for customer_id in group["customers"]]
STATES = ["neutral", "satisfied", "dissatisfied"]
SOURCE_LEVEL_MATTE_PROFILE = "source_flood_fill_green_screen_v1"
SOURCE_LEVEL_MATTE_CUSTOMERS = list(CUSTOMERS)
PORTRAIT_OVERRIDES = {
    "regular_ketta_satisfied": {
        "fit_mode": "height_locked",
        "fit_reason": "wide_thumb_pose_keeps_character_scale",
    },
}


def contact_sheet_path(customer_id: str) -> Path:
    return CONTACT_SHEET_DIR / f"{customer_id}_contact_sheet.png"


def fixed_grid_crops(
    sheet: Image.Image,
    source_path: Path,
    customers: list[str],
    column_count: int = 0,
    fit_mode: str = "",
) -> dict[str, dict]:
    width, height = sheet.size
    grid_columns = column_count if column_count > 0 else len(customers)
    cell_w = width // grid_columns
    cell_h = height // len(STATES)
    crops: dict[str, dict] = {}
    pad_x = max(8, cell_w // 40)
    pad_y = max(8, cell_h // 48)
    for row, state in enumerate(STATES):
        for col, customer_id in enumerate(customers):
            left = col * cell_w + pad_x
            top = row * cell_h + pad_y
            right = (col + 1) * cell_w - pad_x
            bottom = (row + 1) * cell_h - pad_y
            portrait_id = f"{customer_id}_{state}"
            crops[portrait_id] = {
                "customer_id": customer_id,
                "state": state,
                "source": source_path.relative_to(ROOT).as_posix(),
                "crop_rect": [left, top, right, bottom],
            }
            if fit_mode != "":
                crops[portrait_id]["fit_mode"] = fit_mode
            if portrait_id in PORTRAIT_OVERRIDES:
                crops[portrait_id].update(PORTRAIT_OVERRIDES[portrait_id])
    return crops


def remove_chroma_key(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if g >= 150 and g > r * 1.4 and g > b * 1.4 and g > max(r, b) + 50:
                pixels[x, y] = (0, 0, 0, 0)
            elif g > max(r, b) + 30:
                pixels[x, y] = (r, max(r, b) + 4, b, a)
    return rgba


def trim_visible(image: Image.Image) -> Image.Image:
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        return image
    left, top, right, bottom = bounds
    margin_x = max(4, (right - left) // 12)
    margin_y = max(4, (bottom - top) // 16)
    return image.crop((
        max(0, left - margin_x),
        max(0, top - margin_y),
        min(image.width, right + margin_x),
        min(image.height, bottom + margin_y),
    ))


def visible_crop(image: Image.Image) -> Image.Image:
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        return image
    return image.crop(bounds)


def quantize_visible(image: Image.Image, colors: int = 34, spill_radius: int = 1) -> Image.Image:
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
    if spill_radius <= 1:
        return despill_green_edges(quantized)
    return despill_green_near_alpha(quantized, spill_radius=spill_radius)


def normalize_portrait(
    sheet: Image.Image,
    crop_rect: list[int],
    native_size: tuple[int, int] = NATIVE_SIZE,
    colors: int = 64,
    source_level_matte: bool = False,
    fit_mode: str = "",
) -> Image.Image:
    crop = sheet.crop(tuple(crop_rect))
    keyed = source_level_green_matte(crop) if source_level_matte else remove_chroma_key(crop)
    subject = visible_crop(keyed)
    if fit_mode == "height_locked":
        target_height = min(native_size[1] - UNIFORM_BOTTOM_PADDING, UNIFORM_VISIBLE_HEIGHT)
        fitted_width = max(1, round(subject.width * target_height / max(1, subject.height)))
        fitted = subject.resize((fitted_width, target_height), Image.Resampling.NEAREST)
    else:
        target_box = (
            min(native_size[0], UNIFORM_MAX_VISIBLE_WIDTH),
            min(native_size[1] - UNIFORM_BOTTOM_PADDING, UNIFORM_VISIBLE_HEIGHT),
        )
        fitted = ImageOps.contain(subject, target_box, Image.Resampling.NEAREST)
    native = Image.new("RGBA", native_size, (0, 0, 0, 0))
    if fitted.width > native_size[0]:
        left = (fitted.width - native_size[0]) // 2
        fitted = fitted.crop((left, 0, left + native_size[0], fitted.height))
    x = (native_size[0] - fitted.width) // 2
    bounds = fitted.getchannel("A").getbbox()
    visible_bottom = bounds[3] if bounds is not None else fitted.height
    y = native_size[1] - UNIFORM_BOTTOM_PADDING - visible_bottom
    y = min(max(0, y), max(0, native_size[1] - fitted.height))
    native.alpha_composite(fitted, (x, y))
    spill_radius = 2 if source_level_matte else 1
    return quantize_visible(native, colors=colors, spill_radius=spill_radius)


def save_runtime(
    native: Image.Image,
    portrait_id: str,
    runtime_size: tuple[int, int] = RUNTIME_SIZE,
) -> Image.Image:
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    native_path = SOURCE_DIR / f"{portrait_id}_native.png"
    runtime_path = RUNTIME_DIR / f"{portrait_id}.png"
    native.save(native_path)
    runtime = native.resize(runtime_size, Image.Resampling.NEAREST)
    runtime.save(runtime_path)
    return runtime


def write_manifest(crops: dict[str, dict]) -> None:
    portraits = {}
    for portrait_id, spec in crops.items():
        native_size = spec.get("native_size", NATIVE_SIZE)
        runtime_size = spec.get("runtime_size", RUNTIME_SIZE)
        portraits[portrait_id] = {
            "customer_id": spec["customer_id"],
            "state": spec["state"],
            "source": spec["source"],
            "crop_rect": spec["crop_rect"],
            "native": f"assets/source/tavern/regular_customers/{portrait_id}_native.png",
            "runtime": f"assets/textures/characters/{portrait_id}.png",
            "safe_area": [0, 0, native_size[0], native_size[1]],
            "intended_godot_use": "Tavern CustomerSprite named regular customer bust portrait behind TabletopArt",
        }
        if "prompt" in spec:
            portraits[portrait_id]["prompt"] = spec["prompt"]
        if spec.get("matte"):
            portraits[portrait_id]["matte"] = spec["matte"]
        if spec.get("fit_mode"):
            portraits[portrait_id]["fit_mode"] = spec["fit_mode"]
        if spec.get("fit_reason"):
            portraits[portrait_id]["fit_reason"] = spec["fit_reason"]
        if native_size != NATIVE_SIZE:
            portraits[portrait_id]["native_size"] = list(native_size)
        if runtime_size != RUNTIME_SIZE:
            portraits[portrait_id]["runtime_size"] = list(runtime_size)
    sources = [group["source"].relative_to(ROOT).as_posix() for group in CUSTOMER_GROUPS]
    prompt_sources = [group["prompt"].relative_to(ROOT).as_posix() for group in CUSTOMER_GROUPS]
    manifest = {
        "id": "regular_customer_portraits",
        "style_profile": STYLE_PROFILE,
        "style_references": [
            VERA_REFERENCE.relative_to(ROOT).as_posix(),
            BELTA_STYLE_REFERENCE.relative_to(ROOT).as_posix(),
        ],
        "source": CUSTOMER_GROUPS[0]["source"].relative_to(ROOT).as_posix(),
        "sources": sources,
        "prompt_sources": prompt_sources,
        "native_size": list(NATIVE_SIZE),
        "runtime_size": list(RUNTIME_SIZE),
        "scale": SCALE,
        "uniform_visible_height": UNIFORM_VISIBLE_HEIGHT,
        "uniform_max_visible_width": UNIFORM_MAX_VISIBLE_WIDTH,
        "uniform_bottom_padding": UNIFORM_BOTTOM_PADDING,
        "source_level_matte_profile": SOURCE_LEVEL_MATTE_PROFILE,
        "source_level_matte_customers": SOURCE_LEVEL_MATTE_CUSTOMERS,
        "contact_sheets": {
            customer_id: contact_sheet_path(customer_id).relative_to(ROOT).as_posix()
            for customer_id in CUSTOMERS
        },
        "portraits": portraits,
    }
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def make_contact_sheets(natives: dict[str, Image.Image]) -> None:
    for customer_id in CUSTOMERS:
        entries = [
            (f"{customer_id}_{state}", natives[f"{customer_id}_{state}"])
            for state in STATES
        ]
        save_character_contact_sheet(
            contact_sheet_path(customer_id),
            f"{customer_id} contact sheet",
            "regular customer states, native 128x160 -> runtime 512x640",
            entries,
            row_count=1,
        )


def main() -> None:
    sheets: dict[str, Image.Image] = {}
    crops = {}
    for group in CUSTOMER_GROUPS:
        source_path: Path = group["source"]
        if not source_path.exists():
            raise FileNotFoundError(f"missing regular customer source: {source_path}")
        sheet = Image.open(source_path).convert("RGBA")
        source_key = source_path.relative_to(ROOT).as_posix()
        sheets[source_key] = sheet
        crops.update(fixed_grid_crops(
            sheet,
            source_path,
            group["customers"],
            int(group.get("column_count", 0)),
            str(group.get("fit_mode", "")),
        ))
    natives = {}
    for portrait_id, spec in crops.items():
        sheet = sheets[spec["source"]]
        source_level_matte = spec["customer_id"] in SOURCE_LEVEL_MATTE_CUSTOMERS
        if source_level_matte:
            spec["matte"] = SOURCE_LEVEL_MATTE_PROFILE
        native = normalize_portrait(
            sheet,
            spec["crop_rect"],
            source_level_matte=source_level_matte,
            fit_mode=str(spec.get("fit_mode", "")),
        )
        save_runtime(native, portrait_id)
        natives[portrait_id] = native
    write_manifest(crops)
    make_contact_sheets(natives)
    print("exported regular customer portraits: " + ", ".join(crops.keys()))
    print("contact sheets: docs/art/characters/regular_*_contact_sheet.png")


if __name__ == "__main__":
    main()
