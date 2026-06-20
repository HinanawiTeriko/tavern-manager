"""Export the DayMap Today Intel paper tab through the native pixel UI pipeline."""

from __future__ import annotations

from pathlib import Path
import json
import math

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = ROOT / "art_sources" / "generated_raw" / "today_intel_tab"
RAW_SOURCE = RAW_DIR / "today_intel_tab_source_v1.png"
PROMPT = RAW_DIR / "today_intel_tab_prompt_v1.txt"
SOURCE_DIR = ROOT / "assets" / "source" / "ui" / "today_intel_tab"
RUNTIME_DIR = ROOT / "assets" / "textures" / "ui"
MANIFEST = SOURCE_DIR / "today_intel_tab_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "today_intel_tab_contact_sheet.png"

SCALE = 4
NATIVE_SIZE = (56, 24)
RUNTIME_SIZE = (NATIVE_SIZE[0] * SCALE, NATIVE_SIZE[1] * SCALE)
SAFE_AREA = [82, 18, 120, 60]
NINE_SLICE_MARGINS = [34, 28, 34, 28]

STATE_RECTS = {
    "normal": [68, 178, 688, 438],
    "hover": [768, 178, 1388, 438],
    "pressed": [68, 622, 688, 882],
    "unread": [768, 622, 1388, 882],
}

PIXEL_PALETTE = [
    (44, 25, 15),
    (71, 39, 22),
    (103, 64, 35),
    (136, 91, 50),
    (166, 117, 65),
    (195, 148, 87),
    (222, 180, 111),
    (242, 209, 142),
    (114, 52, 0),
    (169, 81, 0),
    (222, 126, 12),
    (255, 184, 38),
]


def _is_chroma_green(red: int, green: int, blue: int) -> bool:
    return green >= 150 and green > red * 1.35 and green > blue * 1.35


def _remove_chroma(image: Image.Image) -> Image.Image:
    cleaned = Image.new("RGBA", image.size, (0, 0, 0, 0))
    src = image.convert("RGBA").load()
    dst = cleaned.load()
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = src[x, y]
            if alpha < 18 or _is_chroma_green(red, green, blue):
                continue
            dst[x, y] = (red, green, blue, alpha)
    return cleaned


def _resize_premultiplied(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    src = image.convert("RGBA")
    premultiplied = Image.new("RGBA", src.size, (0, 0, 0, 0))
    src_px = src.load()
    dst_px = premultiplied.load()
    for y in range(src.height):
        for x in range(src.width):
            red, green, blue, alpha = src_px[x, y]
            factor = alpha / 255.0
            dst_px[x, y] = (
                int(red * factor),
                int(green * factor),
                int(blue * factor),
                alpha,
            )
    resized = premultiplied.resize(size, Image.Resampling.BOX)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    resized_px = resized.load()
    out_px = out.load()
    for y in range(size[1]):
        for x in range(size[0]):
            red, green, blue, alpha = resized_px[x, y]
            if alpha <= 0:
                continue
            factor = 255.0 / alpha
            out_px[x, y] = (
                min(255, int(red * factor)),
                min(255, int(green * factor)),
                min(255, int(blue * factor)),
                alpha,
            )
    return out


def _nearest_palette_color(color: tuple[int, int, int]) -> tuple[int, int, int]:
    red, green, blue = color
    return min(
        PIXEL_PALETTE,
        key=lambda option: (
            math.pow(red - option[0], 2)
            + math.pow(green - option[1], 2)
            + math.pow(blue - option[2], 2)
        ),
    )


def _pixel_normalize(image: Image.Image) -> Image.Image:
    native = _resize_premultiplied(image, NATIVE_SIZE)
    normalized = Image.new("RGBA", NATIVE_SIZE, (0, 0, 0, 0))
    src = native.load()
    dst = normalized.load()
    for y in range(NATIVE_SIZE[1]):
        for x in range(NATIVE_SIZE[0]):
            red, green, blue, alpha = src[x, y]
            if alpha < 36:
                continue
            dst[x, y] = (*_nearest_palette_color((red, green, blue)), 255)
    return normalized


def _export_state(raw: Image.Image, state: str, rect: list[int]) -> Image.Image:
    crop = raw.crop(tuple(rect))
    crop = _remove_chroma(crop)
    native = _pixel_normalize(crop)
    native_path = SOURCE_DIR / f"today_intel_tab_{state}_native.png"
    runtime_path = RUNTIME_DIR / f"today_intel_tab_{state}.png"
    native.save(native_path)
    native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST).save(runtime_path)
    print(f"{native_path.relative_to(ROOT).as_posix()} -> {runtime_path.relative_to(ROOT).as_posix()}")
    return native


def _write_manifest() -> None:
    states = {}
    for state, rect in STATE_RECTS.items():
        states[state] = {
            "source_file": RAW_SOURCE.relative_to(ROOT).as_posix(),
            "source_rect": rect,
            "native_file": f"assets/source/ui/today_intel_tab/today_intel_tab_{state}_native.png",
            "runtime_file": f"assets/textures/ui/today_intel_tab_{state}.png",
            "size": list(RUNTIME_SIZE),
            "safe_area": SAFE_AREA,
            "nine_slice_margins": NINE_SLICE_MARGINS,
            "intended_godot_use": "DayMap TodayIntelBtn paper tab state",
        }
    manifest = {
        "id": "today_intel_tab",
        "raw_source": RAW_SOURCE.relative_to(ROOT).as_posix(),
        "prompt": PROMPT.relative_to(ROOT).as_posix(),
        "scale": SCALE,
        "native_size": list(NATIVE_SIZE),
        "runtime_size": list(RUNTIME_SIZE),
        "contact_sheet": CONTACT_SHEET.relative_to(ROOT).as_posix(),
        "states": states,
    }
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(MANIFEST.relative_to(ROOT).as_posix())


def _write_contact_sheet(native_states: dict[str, Image.Image]) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    cell_w, cell_h = RUNTIME_SIZE
    sheet = Image.new("RGBA", (cell_w * len(native_states), cell_h), (10, 24, 27, 255))
    for index, state in enumerate(["normal", "hover", "pressed", "unread"]):
        preview = native_states[state].resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
        sheet.alpha_composite(preview, (index * cell_w, 0))
    sheet.save(CONTACT_SHEET)
    print(CONTACT_SHEET.relative_to(ROOT).as_posix())


def main() -> int:
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    raw = Image.open(RAW_SOURCE).convert("RGBA")
    native_states = {
        state: _export_state(raw, state, rect)
        for state, rect in STATE_RECTS.items()
    }
    _write_manifest()
    _write_contact_sheet(native_states)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
