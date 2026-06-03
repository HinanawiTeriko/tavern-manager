from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "ui" / "menu_brush_components_approved.png"
OUTPUT = ROOT / "assets" / "textures" / "ui"
EXPORTS = {
    "menu_brush_panel.png": ((47, 49, 898, 447), (512, 240)),
    "menu_brush_band.png": ((942, 71, 1471, 163), (320, 56)),
    "menu_brush_tab.png": ((47, 678, 332, 768), (176, 56)),
    "menu_brush_slider.png": ((1072, 694, 1456, 741), (256, 32)),
    "menu_brush_divider.png": ((52, 835, 995, 855), (384, 12)),
}
SLIDER_GRABBER_BOX = (99, 0, 127, 32)
SLIDER_TRACK_FILL_BOX = (128, 0, 156, 32)


def export_slider_parts(slider: Image.Image) -> None:
    grabber = slider.crop(SLIDER_GRABBER_BOX)
    grabber.save(OUTPUT / "menu_brush_slider_grabber.png")

    track = slider.copy()
    track.paste(slider.crop(SLIDER_TRACK_FILL_BOX), SLIDER_GRABBER_BOX)
    track.save(OUTPUT / "menu_brush_slider_track.png")

OUTPUT.mkdir(parents=True, exist_ok=True)
source = Image.open(SOURCE).convert("RGBA")
for filename, (crop_box, output_size) in EXPORTS.items():
    source.crop(crop_box).resize(output_size, Image.Resampling.NEAREST).save(OUTPUT / filename)
    print(f"{filename}: {output_size}")

slider = Image.open(OUTPUT / "menu_brush_slider.png").convert("RGBA")
export_slider_parts(slider)
print("menu_brush_slider_track.png: (256, 32)")
print("menu_brush_slider_grabber.png: (28, 32)")
