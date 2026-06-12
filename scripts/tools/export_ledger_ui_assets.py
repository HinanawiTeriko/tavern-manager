from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[2]
BACKDROP_REFERENCE = ROOT / "art_sources" / "generated_raw" / "ledger_ui" / "ledger_overlay_background_reference_v2.png"
BACKDROP_PROMPT = ROOT / "art_sources" / "generated_raw" / "ledger_ui" / "ledger_overlay_background_prompt_v2.txt"
CONTROL_REFERENCE = ROOT / "art_sources" / "generated_raw" / "ledger_ui" / "ledger_controls_reference_v2.png"
CONTROL_PROMPT = ROOT / "art_sources" / "generated_raw" / "ledger_ui" / "ledger_controls_prompt_v2.txt"
SOURCE = ROOT / "assets" / "source" / "ledger" / "ui"
RUNTIME = ROOT / "assets" / "textures" / "ledger" / "ui"
MANIFEST = SOURCE / "ledger_ui_v2_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "ledger_ui_v2_contact_sheet.png"
LEGACY_CONTACT_SHEET = ROOT / "docs" / "art" / "ledger_button_states_contact_sheet.png"

BACKDROP_NATIVE_SIZE = (320, 180)
BACKDROP_RUNTIME_SIZE = (1280, 720)
NAV_BUTTON_NATIVE_SIZE = (28, 30)
NAV_BUTTON_RUNTIME_SIZE = (112, 120)
CLOSE_BUTTON_NATIVE_SIZE = (24, 24)
CLOSE_BUTTON_RUNTIME_SIZE = (96, 96)

STATES = ("normal", "hover", "pressed")
TEXT_SAFE_ZONES_NATIVE = {
    "left": (70, 30, 134, 122),
    "right": (186, 30, 250, 122),
}
BUTTON_CONTRACTS = {
    "button_nav_left": {
        "native_size": NAV_BUTTON_NATIVE_SIZE,
        "runtime_size": NAV_BUTTON_RUNTIME_SIZE,
        "states": {
            "normal": (105, 105, 365, 390),
            "hover": (105, 475, 365, 760),
            "pressed": (105, 850, 365, 1135),
        },
    },
    "button_nav_right": {
        "native_size": NAV_BUTTON_NATIVE_SIZE,
        "runtime_size": NAV_BUTTON_RUNTIME_SIZE,
        "states": {
            "normal": (500, 105, 760, 390),
            "hover": (500, 475, 760, 760),
            "pressed": (500, 850, 760, 1135),
        },
    },
    "button_close": {
        "native_size": CLOSE_BUTTON_NATIVE_SIZE,
        "runtime_size": CLOSE_BUTTON_RUNTIME_SIZE,
        "states": {
            "normal": (880, 95, 1175, 390),
            "hover": (880, 465, 1175, 760),
            "pressed": (880, 835, 1175, 1130),
        },
    },
}


def load_required(path: Path) -> Image.Image:
    if not path.exists():
        raise FileNotFoundError(f"missing ledger UI source: {path}")
    with Image.open(path) as image:
        return image.convert("RGBA")


def reduce_to_native_palette(image: Image.Image, colors: int) -> Image.Image:
    quantized = image.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
    return quantized.convert("RGBA")


def make_backdrop_native(reference: Image.Image) -> Image.Image:
    fitted = ImageOps.fit(
        reference,
        BACKDROP_NATIVE_SIZE,
        method=Image.Resampling.BOX,
        centering=(0.5, 0.5),
    )
    return reduce_to_native_palette(fitted, 72)


def remove_chroma(image: Image.Image, threshold: int = 178) -> Image.Image:
    rgba = image.convert("RGBA")
    key = (255, 0, 255)
    max_distance_sq = threshold * threshold
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            dr = r - key[0]
            dg = g - key[1]
            db = b - key[2]
            is_magenta_edge = r >= 150 and g <= 120 and b >= 145
            if a == 0 or is_magenta_edge or dr * dr + dg * dg + db * db <= max_distance_sq:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (r, g, b, 255)
    return rgba


def quantize_visible(image: Image.Image, colors: int = 36) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    rgb = Image.new("RGB", rgba.size, (0, 0, 0))
    rgb.paste(rgba.convert("RGB"), mask=alpha)
    quantized = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    quantized.putalpha(alpha)
    return quantized


def harden_alpha(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if a < 64:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (r, g, b, 255)
    return rgba


def make_control_native(reference: Image.Image, source_rect: tuple[int, int, int, int], native_size: tuple[int, int]) -> Image.Image:
    crop = reference.crop(source_rect)
    cutout = remove_chroma(crop)
    native = cutout.resize(native_size, Image.Resampling.BOX)
    return harden_alpha(quantize_visible(native))


def save_pair(name: str, native: Image.Image, runtime_size: tuple[int, int]) -> None:
    native_path = SOURCE / f"{name}_native.png"
    runtime_path = RUNTIME / f"{name}.png"
    native.save(native_path)
    native.resize(runtime_size, Image.Resampling.NEAREST).save(runtime_path)
    print(f"{name}: {native.size} -> {runtime_size}")


def export_controls(reference: Image.Image) -> dict:
    assets: dict = {}
    for name, contract in BUTTON_CONTRACTS.items():
        native_size = contract["native_size"]
        runtime_size = contract["runtime_size"]
        assets[name] = {
            "native_size": list(native_size),
            "runtime_size": list(runtime_size),
            "states": {},
        }
        for state in STATES:
            source_rect = contract["states"][state]
            native = make_control_native(reference, source_rect, native_size)
            save_pair(f"{name}_{state}", native, runtime_size)
            assets[name]["states"][state] = {
                "source_rect": list(source_rect),
                "native": f"assets/source/ledger/ui/{name}_{state}_native.png",
                "runtime": f"assets/textures/ledger/ui/{name}_{state}.png",
            }
    return assets


def write_manifest(control_assets: dict) -> None:
    manifest = {
        "id": "ledger_ui_v2",
        "backdrop": {
            "source": "art_sources/generated_raw/ledger_ui/ledger_overlay_background_reference_v2.png",
            "prompt": "art_sources/generated_raw/ledger_ui/ledger_overlay_background_prompt_v2.txt",
            "native": "assets/source/ledger/ui/ledger_overlay_backdrop_native.png",
            "runtime": "assets/textures/ledger/ui/ledger_overlay_backdrop.png",
            "native_size": list(BACKDROP_NATIVE_SIZE),
            "runtime_size": list(BACKDROP_RUNTIME_SIZE),
            "text_safe_zones_native": {key: list(value) for key, value in TEXT_SAFE_ZONES_NATIVE.items()},
        },
        "controls": {
            "source": "art_sources/generated_raw/ledger_ui/ledger_controls_reference_v2.png",
            "prompt": "art_sources/generated_raw/ledger_ui/ledger_controls_prompt_v2.txt",
            "assets": control_assets,
        },
        "intended_godot_use": "DocumentOverlay full-screen ledger v2 art with separate normal/hover/pressed controls",
    }
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def make_contact_sheet() -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (900, 360), (18, 14, 11, 255))
    with Image.open(RUNTIME / "ledger_overlay_backdrop.png") as image:
        backdrop = image.convert("RGBA").resize((512, 288), Image.Resampling.NEAREST)
    sheet.alpha_composite(backdrop, (20, 36))
    x_positions = {"button_nav_left": 570, "button_nav_right": 700, "button_close": 830}
    y_positions = {"normal": 20, "hover": 130, "pressed": 240}
    for name in BUTTON_CONTRACTS:
        for state in STATES:
            with Image.open(RUNTIME / f"{name}_{state}.png") as image:
                preview = image.convert("RGBA")
            max_size = (112, 120) if name != "button_close" else (96, 96)
            preview = ImageOps.contain(preview, max_size, Image.Resampling.NEAREST)
            sheet.alpha_composite(preview, (x_positions[name], y_positions[state]))
    sheet.convert("RGB").save(CONTACT_SHEET)
    sheet.convert("RGB").save(LEGACY_CONTACT_SHEET)


def main() -> None:
    if not BACKDROP_PROMPT.exists():
        raise FileNotFoundError(f"missing ledger backdrop prompt record: {BACKDROP_PROMPT}")
    if not CONTROL_PROMPT.exists():
        raise FileNotFoundError(f"missing ledger controls prompt record: {CONTROL_PROMPT}")
    SOURCE.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)

    backdrop_reference = load_required(BACKDROP_REFERENCE)
    backdrop = make_backdrop_native(backdrop_reference)
    save_pair("ledger_overlay_backdrop", backdrop, BACKDROP_RUNTIME_SIZE)

    control_reference = load_required(CONTROL_REFERENCE)
    control_assets = export_controls(control_reference)
    write_manifest(control_assets)
    make_contact_sheet()


if __name__ == "__main__":
    main()
