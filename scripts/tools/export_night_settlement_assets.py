from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_sources" / "generated_raw" / "night_settlement"
BACKDROP_SOURCE = RAW / "night_settlement_backdrop_source_v1.png"
BACKDROP_PROMPT = RAW / "night_settlement_backdrop_prompt_v1.txt"
CONTROLS_SOURCE = RAW / "night_settlement_controls_source_v1.png"
CONTROLS_PROMPT = RAW / "night_settlement_controls_prompt_v1.txt"
STATS_PANEL_SOURCE = RAW / "night_settlement_stats_panel_source_v3.png"
STATS_PANEL_PROMPT = RAW / "night_settlement_stats_panel_prompt_v3.txt"
SOURCE = ROOT / "assets" / "source" / "ui" / "night_settlement"
RUNTIME = ROOT / "assets" / "textures" / "ui" / "night_settlement"
MANIFEST = SOURCE / "night_settlement_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "night_settlement_contact_sheet.png"

BACKDROP_NATIVE_SIZE = (320, 180)
BACKDROP_RUNTIME_SIZE = (1280, 720)
PANEL_CONTRACTS = {
    "stats": {
        "source": "stats_panel",
        "source_rect": (120, 70, 1550, 857),
        "native_size": (120, 66),
        "runtime_size": (480, 264),
    },
    "fates": {
        "source": "controls",
        "source_rect": (405, 760, 1198, 1162),
        "native_size": (120, 66),
        "runtime_size": (480, 264),
    },
}
BUTTON_CONTRACTS = {
    "normal": {"source_rect": (96, 72, 390, 378)},
    "hover": {"source_rect": (444, 72, 738, 378)},
    "pressed": {"source_rect": (794, 72, 1088, 378)},
}
ICON_CONTRACTS = {
    "gold": (94, 495, 248, 665),
    "reputation": (276, 495, 430, 665),
    "guests": (456, 495, 610, 665),
    "success": (636, 495, 790, 665),
    "failed": (816, 495, 970, 665),
    "fate": (996, 495, 1150, 665),
}
BUTTON_NATIVE_SIZE = (34, 24)
BUTTON_RUNTIME_SIZE = (136, 96)
ICON_NATIVE_SIZE = (14, 14)
ICON_RUNTIME_SIZE = (56, 56)
TEXT_SAFE_ZONES_NATIVE = {
    "title": (88, 11, 232, 27),
    "stats": (34, 103, 128, 160),
    "fates": (158, 103, 280, 160),
    "continue": (276, 152, 314, 174),
}


def load_required(path: Path) -> Image.Image:
    if not path.exists():
        raise FileNotFoundError(f"missing night settlement source: {path}")
    with Image.open(path) as image:
        return image.convert("RGBA")


def reduce_to_native_palette(image: Image.Image, colors: int) -> Image.Image:
    quantized = image.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
    return quantized.convert("RGBA")


def harden_alpha(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            pixels[x, y] = (r, g, b, 255 if a >= 64 else 0)
    return rgba


def remove_chroma_green(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            is_green_key = g >= 145 and r <= 135 and b <= 145
            if a == 0 or is_green_key:
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


def fit_alpha_content(image: Image.Image, output_size: tuple[int, int], content_size: tuple[int, int] | None = None) -> Image.Image:
    rgba = harden_alpha(image.convert("RGBA"))
    bbox = rgba.getchannel("A").getbbox()
    if bbox is None:
        return Image.new("RGBA", output_size, (0, 0, 0, 0))
    content = rgba.crop(bbox)
    if content_size is None:
        content = ImageOps.contain(content, output_size, Image.Resampling.BOX)
    else:
        content = content.resize(content_size, Image.Resampling.BOX)
    content = harden_alpha(content)
    canvas = Image.new("RGBA", output_size, (0, 0, 0, 0))
    offset = ((output_size[0] - content.width) // 2, (output_size[1] - content.height) // 2)
    canvas.alpha_composite(content, offset)
    return canvas


def save_pair(name: str, native: Image.Image, runtime_size: tuple[int, int]) -> None:
    native_path = SOURCE / f"{name}_native.png"
    runtime_path = RUNTIME / f"{name}.png"
    native.save(native_path)
    native.resize(runtime_size, Image.Resampling.NEAREST).save(runtime_path)
    print(f"{name}: {native.size} -> {runtime_size}")


def make_backdrop_native(reference: Image.Image) -> Image.Image:
    fitted = ImageOps.fit(reference, BACKDROP_NATIVE_SIZE, method=Image.Resampling.BOX, centering=(0.5, 0.5))
    return reduce_to_native_palette(fitted, 72)


def make_cutout_native(
    reference: Image.Image,
    source_rect: tuple[int, int, int, int],
    native_size: tuple[int, int],
    content_size: tuple[int, int] | None = None,
) -> Image.Image:
    crop = reference.crop(source_rect)
    cutout = remove_chroma_green(crop)
    if content_size != native_size:
        native = fit_alpha_content(cutout, native_size, content_size)
    else:
        native = cutout.resize(native_size, Image.Resampling.BOX)
    return harden_alpha(quantize_visible(native))


def export_backdrop(reference: Image.Image) -> None:
    native = make_backdrop_native(reference)
    save_pair("night_settlement_backdrop", native, BACKDROP_RUNTIME_SIZE)


def export_panels(controls_reference: Image.Image, stats_reference: Image.Image) -> dict:
    panels: dict = {}
    for name, contract in PANEL_CONTRACTS.items():
        reference = stats_reference if contract["source"] == "stats_panel" else controls_reference
        source_path = (
            "art_sources/generated_raw/night_settlement/night_settlement_stats_panel_source_v3.png"
            if contract["source"] == "stats_panel"
            else "art_sources/generated_raw/night_settlement/night_settlement_controls_source_v1.png"
        )
        source_rect = contract["source_rect"]
        native_size = contract["native_size"]
        runtime_size = contract["runtime_size"]
        native = make_cutout_native(reference, source_rect, native_size, native_size)
        asset_name = f"night_settlement_panel_{name}"
        save_pair(asset_name, native, runtime_size)
        panels[name] = {
            "source": source_path,
            "source_rect": list(source_rect),
            "native": f"assets/source/ui/night_settlement/{asset_name}_native.png",
            "runtime": f"assets/textures/ui/night_settlement/{asset_name}.png",
            "native_size": list(native_size),
            "runtime_size": list(runtime_size),
            "safe_area_native": [8, 8, native_size[0] - 8, native_size[1] - 8],
            "intended_godot_use": f"LedgerScreen/ArtLayer/{'StatsPanelArt' if name == 'stats' else 'FatePanelArt'}",
        }
    return panels


def export_continue_button(reference: Image.Image) -> dict:
    states: dict = {}
    for state, contract in BUTTON_CONTRACTS.items():
        source_rect = contract["source_rect"]
        native = make_cutout_native(reference, source_rect, BUTTON_NATIVE_SIZE, (28, 22))
        asset_name = f"night_settlement_continue_{state}"
        save_pair(asset_name, native, BUTTON_RUNTIME_SIZE)
        states[state] = {
            "source_rect": list(source_rect),
            "native": f"assets/source/ui/night_settlement/{asset_name}_native.png",
            "runtime": f"assets/textures/ui/night_settlement/{asset_name}.png",
        }
    return {
        "native_size": list(BUTTON_NATIVE_SIZE),
        "runtime_size": list(BUTTON_RUNTIME_SIZE),
        "states": states,
        "intended_godot_use": "LedgerScreen/UI/ContinueBtn StyleBoxTexture",
    }


def export_icons(reference: Image.Image) -> dict:
    icons: dict = {}
    for name, source_rect in ICON_CONTRACTS.items():
        native = make_cutout_native(reference, source_rect, ICON_NATIVE_SIZE, (12, 12))
        asset_name = f"night_settlement_icon_{name}"
        save_pair(asset_name, native, ICON_RUNTIME_SIZE)
        icons[name] = {
            "source": "art_sources/generated_raw/night_settlement/night_settlement_controls_source_v1.png",
            "source_rect": list(source_rect),
            "native": f"assets/source/ui/night_settlement/{asset_name}_native.png",
            "runtime": f"assets/textures/ui/night_settlement/{asset_name}.png",
            "native_size": list(ICON_NATIVE_SIZE),
            "runtime_size": list(ICON_RUNTIME_SIZE),
            "intended_godot_use": f"LedgerScreen stat icon {name}",
        }
    return icons


def write_manifest(panels: dict, continue_button: dict, icons: dict) -> None:
    manifest = {
        "id": "night_settlement_v1",
        "backdrop": {
            "source": "art_sources/generated_raw/night_settlement/night_settlement_backdrop_source_v1.png",
            "prompt": "art_sources/generated_raw/night_settlement/night_settlement_backdrop_prompt_v1.txt",
            "native": "assets/source/ui/night_settlement/night_settlement_backdrop_native.png",
            "runtime": "assets/textures/ui/night_settlement/night_settlement_backdrop.png",
            "native_size": list(BACKDROP_NATIVE_SIZE),
            "runtime_size": list(BACKDROP_RUNTIME_SIZE),
        },
        "text_safe_zones_native": {key: list(value) for key, value in TEXT_SAFE_ZONES_NATIVE.items()},
        "panels": panels,
        "continue_button": continue_button,
        "icons": icons,
        "intended_godot_use": "LedgerScreen post-close settlement art and controls",
    }
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def make_contact_sheet() -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (900, 520), (17, 13, 10, 255))
    with Image.open(RUNTIME / "night_settlement_backdrop.png") as image:
        backdrop = image.convert("RGBA").resize((512, 288), Image.Resampling.NEAREST)
    sheet.alpha_composite(backdrop, (20, 20))
    preview_specs = [
        ("night_settlement_panel_stats.png", (552, 20), (196, 132)),
        ("night_settlement_panel_fates.png", (552, 166), (240, 132)),
        ("night_settlement_continue_normal.png", (552, 324), (68, 48)),
        ("night_settlement_continue_hover.png", (636, 324), (68, 48)),
        ("night_settlement_continue_pressed.png", (720, 324), (68, 48)),
        ("night_settlement_icon_gold.png", (552, 404), (28, 28)),
        ("night_settlement_icon_reputation.png", (604, 404), (28, 28)),
        ("night_settlement_icon_guests.png", (656, 404), (28, 28)),
        ("night_settlement_icon_success.png", (708, 404), (28, 28)),
        ("night_settlement_icon_failed.png", (760, 404), (28, 28)),
        ("night_settlement_icon_fate.png", (812, 404), (28, 28)),
    ]
    for filename, position, size in preview_specs:
        with Image.open(RUNTIME / filename) as image:
            preview = ImageOps.contain(image.convert("RGBA"), size, Image.Resampling.NEAREST)
        sheet.alpha_composite(preview, position)
    sheet.convert("RGB").save(CONTACT_SHEET)


def main() -> None:
    if not BACKDROP_PROMPT.exists():
        raise FileNotFoundError(f"missing night settlement backdrop prompt record: {BACKDROP_PROMPT}")
    if not CONTROLS_PROMPT.exists():
        raise FileNotFoundError(f"missing night settlement controls prompt record: {CONTROLS_PROMPT}")
    if not STATS_PANEL_PROMPT.exists():
        raise FileNotFoundError(f"missing night settlement stats panel prompt record: {STATS_PANEL_PROMPT}")
    SOURCE.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)

    backdrop_reference = load_required(BACKDROP_SOURCE)
    controls_reference = load_required(CONTROLS_SOURCE)
    stats_reference = load_required(STATS_PANEL_SOURCE)
    export_backdrop(backdrop_reference)
    panels = export_panels(controls_reference, stats_reference)
    continue_button = export_continue_button(controls_reference)
    icons = export_icons(controls_reference)
    write_manifest(panels, continue_button, icons)
    make_contact_sheet()


if __name__ == "__main__":
    main()
