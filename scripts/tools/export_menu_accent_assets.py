"""Export amber accent assets for the brush UI."""

from pathlib import Path
import json

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
TITLE_MARKER = ROOT / "assets" / "textures" / "title" / "title_pixel_menu_marker.png"
SOURCE = ROOT / "assets" / "source" / "ui"
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "menu_hover_marker"
OUTPUT = ROOT / "assets" / "textures" / "ui"
BASE_HOVER_MARKER = SOURCE / "menu_brush_hover_marker_base.png"
LEGACY_HOVER_MARKER = OUTPUT / "menu_brush_hover_marker.png"
MANIFEST = SOURCE / "menu_accent_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "menu_hover_marker_variants_contact_sheet.png"

SCALE = 4
MARKER_SIZE = (243, 28)
MARKER_SAFE_AREA = [16, 6, 211, 16]
MARKER_SOURCES = [
    {
        "id": "menu_brush_hover_marker_1",
        "raw": RAW_SOURCE / "menu_brush_hover_marker_generated_1.png",
        "crop": [58, 325, 1854, 532],
    },
    {
        "id": "menu_brush_hover_marker_2",
        "raw": RAW_SOURCE / "menu_brush_hover_marker_generated_2.png",
        "crop": [0, 320, 1853, 534],
    },
    {
        "id": "menu_brush_hover_marker_3",
        "raw": RAW_SOURCE / "menu_brush_hover_marker_generated_3.png",
        "crop": [160, 360, 1820, 540],
    },
    {
        "id": "menu_brush_hover_marker_4",
        "raw": RAW_SOURCE / "menu_brush_hover_marker_generated_4.png",
        "crop": [150, 310, 1800, 500],
    },
]
MARKER_PALETTE = [
    (94, 35, 0),
    (139, 52, 0),
    (196, 77, 0),
    (239, 109, 0),
    (255, 161, 0),
    (255, 205, 33),
    (255, 230, 76),
]
GRABBER_BLOCKS = (5, 10)
AMBER_RAMP = [
    (140, 66, 0),
    (180, 96, 4),
    (224, 133, 0),
    (245, 162, 14),
    (255, 190, 40),
]


def _load_marker_base() -> Image.Image:
    for path in (BASE_HOVER_MARKER, LEGACY_HOVER_MARKER, TITLE_MARKER):
        if path.exists():
            return Image.open(path).convert("RGBA").resize(MARKER_SIZE, Image.Resampling.NEAREST)
    raise FileNotFoundError("No hover marker source is available")


def _is_chroma_green(red: int, green: int, blue: int) -> bool:
    return green >= 145 and green > red * 1.45 and green > blue * 1.45


def _normalize_marker_colors(image: Image.Image) -> Image.Image:
    normalized = Image.new("RGBA", image.size, (0, 0, 0, 0))
    src = image.load()
    dst = normalized.load()
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = src[x, y]
            if alpha < 28 or _is_chroma_green(red, green, blue):
                continue
            green = min(green, max(red, blue) + 26)
            warm_value = red * 0.22 + green * 0.78
            thresholds = [72, 102, 132, 162, 192, 222]
            palette_index = 0
            for threshold in thresholds:
                if warm_value >= threshold:
                    palette_index += 1
            palette_index = max(0, min(len(MARKER_PALETTE) - 1, palette_index))
            out_alpha = 255 if alpha > 144 else 176
            dst[x, y] = (*MARKER_PALETTE[palette_index], out_alpha)
    return normalized


def _export_generated_marker(source: dict) -> Image.Image:
    raw_path = source["raw"]
    if not raw_path.exists():
        raise FileNotFoundError(f"{raw_path.relative_to(ROOT)} is missing")
    image = Image.open(raw_path).convert("RGBA")
    marker = image.crop(tuple(source["crop"])).resize(MARKER_SIZE, Image.Resampling.BOX)
    marker = _normalize_marker_colors(marker)
    output_path = OUTPUT / f"{source['id']}.png"
    marker.save(output_path)
    print(f"{output_path.name}: {marker.size}")
    return marker


def export_hover_marker() -> list[Image.Image]:
    SOURCE.mkdir(parents=True, exist_ok=True)
    marker_base = _load_marker_base()
    marker_base.save(BASE_HOVER_MARKER)
    print(f"menu_brush_hover_marker_base.png: {marker_base.size}")
    return [_export_generated_marker(source) for source in MARKER_SOURCES]


def _pick(ramp: list[tuple[int, int, int]], index: int) -> tuple[int, int, int]:
    return ramp[max(0, min(len(ramp) - 1, index))]


def export_slider_grabber() -> None:
    gw, gh = GRABBER_BLOCKS
    small = Image.new("RGBA", GRABBER_BLOCKS, (0, 0, 0, 0))
    px = small.load()
    mask = [
        "01110",
        "11111",
        "11101",
        "11111",
        "11011",
        "11111",
        "01111",
        "11111",
        "11101",
        "01110",
    ]
    for y in range(gh):
        for x in range(gw):
            if mask[y][x] == "0":
                continue
            shade = x + (1 if y % 3 == 1 else 0)
            if x == 0:
                shade = 0
            if x >= gw - 2:
                shade = 4
            if (x + y) % 7 == 0:
                shade = max(0, shade - 1)
            r, g, b = _pick(AMBER_RAMP, shade)
            alpha = 255 if x not in (0, gw - 1) else 210
            px[x, y] = (r, g, b, alpha)

    grabber = small.resize((gw * SCALE, gh * SCALE), Image.Resampling.NEAREST)
    grabber.save(OUTPUT / "menu_brush_slider_grabber.png")
    print(f"menu_brush_slider_grabber.png: {grabber.size}")


def write_manifest() -> None:
    assets = {
        "menu_brush_hover_marker_base": {
            "source_file": "assets/textures/ui/menu_brush_hover_marker.png",
            "output_file": "assets/source/ui/menu_brush_hover_marker_base.png",
            "size": list(MARKER_SIZE),
            "safe_area": MARKER_SAFE_AREA,
            "intended_godot_use": "source base for brush hover marker variants",
        }
    }
    for source in MARKER_SOURCES:
        assets[source["id"]] = {
            "source_file": source["raw"].relative_to(ROOT).as_posix(),
            "output_file": f"assets/textures/ui/{source['id']}.png",
            "size": list(MARKER_SIZE),
            "safe_area": MARKER_SAFE_AREA,
            "source_crop": source["crop"],
            "intended_godot_use": "ThemeColors brush button hover/selected marker variant",
        }
    MANIFEST.write_text(json.dumps({"assets": assets}, indent=2) + "\n", encoding="utf-8")
    print(f"{MANIFEST.relative_to(ROOT)}")


def write_contact_sheet(markers: list[Image.Image]) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    scale = 4
    cell = (MARKER_SIZE[0] * scale, MARKER_SIZE[1] * scale)
    sheet = Image.new("RGBA", (cell[0], cell[1] * len(markers)), (10, 24, 27, 255))
    for index, marker in enumerate(markers):
        preview = marker.resize(cell, Image.Resampling.NEAREST)
        sheet.alpha_composite(preview, (0, index * cell[1]))
    sheet.save(CONTACT_SHEET)
    print(f"{CONTACT_SHEET.relative_to(ROOT)}")


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    markers = export_hover_marker()
    export_slider_grabber()
    write_manifest()
    write_contact_sheet(markers)
