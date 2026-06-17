from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_sources" / "generated_raw" / "restart_day"
SOURCE_IMAGE = RAW / "restart_day_controls_source_v1.png"
PROMPT = RAW / "restart_day_controls_prompt_v1.txt"
SOURCE = ROOT / "assets" / "source" / "ui" / "restart_day"
RUNTIME = ROOT / "assets" / "textures" / "ui" / "restart_day"
MANIFEST = SOURCE / "restart_day_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "restart_day" / "restart_day_contact_sheet.png"

SOURCE_RECTS = {
    "button_normal": (54, 62, 508, 274),
    "button_hover": (555, 62, 990, 274),
    "button_pressed": (1046, 62, 1470, 274),
    "clock_face": (16, 294, 638, 916),
    "clock_hand": (650, 336, 760, 878),
    "event_panel": (808, 334, 1466, 936),
}
ASSETS = {
    "restart_day_button_normal": {
        "source_key": "button_normal",
        "native_size": (42, 18),
        "runtime_size": (168, 72),
        "safe_area_native": (6, 4, 36, 14),
        "intended_godot_use": "LedgerScreen/UI/RestartDayBtn normal StyleBoxTexture and ClockRewindOverlay/CancelBtn",
    },
    "restart_day_button_hover": {
        "source_key": "button_hover",
        "native_size": (42, 18),
        "runtime_size": (168, 72),
        "safe_area_native": (6, 4, 36, 14),
        "intended_godot_use": "LedgerScreen/UI/RestartDayBtn hover StyleBoxTexture and ClockRewindOverlay/CancelBtn",
    },
    "restart_day_button_pressed": {
        "source_key": "button_pressed",
        "native_size": (42, 18),
        "runtime_size": (168, 72),
        "safe_area_native": (6, 5, 36, 15),
        "intended_godot_use": "LedgerScreen/UI/RestartDayBtn pressed StyleBoxTexture and ClockRewindOverlay/CancelBtn",
    },
    "restart_day_clock_face": {
        "source_key": "clock_face",
        "native_size": (104, 104),
        "runtime_size": (416, 416),
        "safe_area_native": (17, 17, 87, 87),
        "intended_godot_use": "ClockRewindOverlay/ClockRoot/ClockFace",
    },
    "restart_day_clock_hand": {
        "source_key": "clock_hand",
        "native_size": (16, 62),
        "runtime_size": (64, 248),
        "safe_area_native": (5, 4, 11, 57),
        "intended_godot_use": "ClockRewindOverlay/ClockRoot/ClockHand",
    },
    "restart_day_event_panel": {
        "source_key": "event_panel",
        "native_size": (112, 104),
        "runtime_size": (448, 416),
        "safe_area_native": (17, 16, 95, 88),
        "intended_godot_use": "ClockRewindOverlay/EventPanel/EventPanelArt",
    },
}


def load_source() -> Image.Image:
    if not SOURCE_IMAGE.exists():
        raise FileNotFoundError(f"{SOURCE_IMAGE}: missing restart day source")
    with Image.open(SOURCE_IMAGE) as image:
        return image.convert("RGBA")


def remove_chroma_green(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            is_green_key = g >= 150 and r <= 80 and b <= 80
            if a == 0 or is_green_key:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (r, g, b, 255)
    return rgba


def quantize_visible(image: Image.Image, colors: int = 40) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    rgb = Image.new("RGB", rgba.size, (0, 0, 0))
    rgb.paste(rgba.convert("RGB"), mask=alpha)
    quantized = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    quantized.putalpha(alpha)
    return quantized


def build_native(source: Image.Image, source_rect: tuple[int, int, int, int], native_size: tuple[int, int]) -> Image.Image:
    crop = source.crop(source_rect)
    keyed = remove_chroma_green(crop)
    native = keyed.resize(native_size, Image.Resampling.BOX)
    return quantize_visible(native)


def save_pair(name: str, native: Image.Image, runtime_size: tuple[int, int]) -> None:
    native_path = SOURCE / f"{name}_native.png"
    runtime_path = RUNTIME / f"{name}.png"
    native.save(native_path)
    native.resize(runtime_size, Image.Resampling.NEAREST).save(runtime_path)
    print(f"{name}: {native.size} -> {runtime_size}")


def export_assets() -> dict:
    source = load_source()
    manifest_assets: dict = {}
    SOURCE.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    for name, contract in ASSETS.items():
        source_key = contract["source_key"]
        source_rect = SOURCE_RECTS[source_key]
        native_size = contract["native_size"]
        runtime_size = contract["runtime_size"]
        native = build_native(source, source_rect, native_size)
        save_pair(name, native, runtime_size)
        manifest_assets[name] = {
            "id": name,
            "source": "art_sources/generated_raw/restart_day/restart_day_controls_source_v1.png",
            "prompt": "art_sources/generated_raw/restart_day/restart_day_controls_prompt_v1.txt",
            "source_rect": list(source_rect),
            "native": f"assets/source/ui/restart_day/{name}_native.png",
            "runtime": f"assets/textures/ui/restart_day/{name}.png",
            "native_size": list(native_size),
            "runtime_size": list(runtime_size),
            "safe_area_native": list(contract["safe_area_native"]),
            "intended_godot_use": contract["intended_godot_use"],
        }
    return manifest_assets


def write_manifest(assets: dict) -> None:
    manifest = {
        "id": "restart_day_clock_rewind_v1",
        "source": "art_sources/generated_raw/restart_day/restart_day_controls_source_v1.png",
        "prompt": "art_sources/generated_raw/restart_day/restart_day_controls_prompt_v1.txt",
        "assets": assets,
    }
    MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def make_contact_sheet() -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (960, 620), (16, 13, 10, 255))
    placements = [
        ("restart_day_button_normal.png", (24, 24)),
        ("restart_day_button_hover.png", (216, 24)),
        ("restart_day_button_pressed.png", (408, 24)),
        ("restart_day_clock_face.png", (24, 120)),
        ("restart_day_clock_hand.png", (470, 144)),
        ("restart_day_event_panel.png", (576, 120)),
    ]
    for filename, position in placements:
        with Image.open(RUNTIME / filename) as image:
            sheet.alpha_composite(image.convert("RGBA"), position)
    sheet.save(CONTACT_SHEET)


def main() -> None:
    if not PROMPT.exists():
        raise FileNotFoundError(f"{PROMPT}: missing restart day prompt")
    assets = export_assets()
    write_manifest(assets)
    make_contact_sheet()


if __name__ == "__main__":
    main()
