"""Export amber accent assets for the brush UI.

This script intentionally does not write the slider track. The track already
matches the dark teal brush language; only the grabber needs richer amber
texture.
"""
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
TITLE_MARKER = ROOT / "assets" / "textures" / "title" / "title_pixel_menu_marker.png"
OUTPUT = ROOT / "assets" / "textures" / "ui"

SCALE = 4
GRABBER_BLOCKS = (5, 10)
AMBER_RAMP = [
    (140, 66, 0),
    (180, 96, 4),
    (224, 133, 0),
    (245, 162, 14),
    (255, 190, 40),
]


def export_hover_marker() -> None:
    marker = Image.open(TITLE_MARKER).convert("RGBA")
    marker.save(OUTPUT / "menu_brush_hover_marker.png")
    print(f"menu_brush_hover_marker.png: {marker.size}")


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

    grabber = small.resize((gw * SCALE, gh * SCALE), Image.NEAREST)
    grabber.save(OUTPUT / "menu_brush_slider_grabber.png")
    print(f"menu_brush_slider_grabber.png: {grabber.size}")


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    export_hover_marker()
    export_slider_grabber()
