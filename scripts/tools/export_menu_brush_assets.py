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

OUTPUT.mkdir(parents=True, exist_ok=True)
source = Image.open(SOURCE).convert("RGBA")
for filename, (crop_box, output_size) in EXPORTS.items():
    source.crop(crop_box).resize(output_size, Image.Resampling.NEAREST).save(OUTPUT / filename)
    print(f"{filename}: {output_size}")
