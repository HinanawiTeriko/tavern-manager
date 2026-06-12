from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "ui"
RUNTIME = ROOT / "assets" / "textures" / "ui"
CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_patience_ui_contact_sheet.png"
SCALE = 4


def put(image: Image.Image, x: int, y: int, color: tuple[int, int, int, int]) -> None:
    image.putpixel((x, y), color)


def create_bar_bg() -> Image.Image:
    transparent = (0, 0, 0, 0)
    ink = (8, 12, 15, 255)
    edge = (25, 60, 62, 255)
    edge_dark = (14, 36, 42, 255)
    inner = (13, 25, 31, 255)
    high = (38, 86, 84, 255)
    image = Image.new("RGBA", (75, 7), transparent)
    draw = ImageDraw.Draw(image)
    draw.rectangle((1, 0, 73, 6), fill=ink)
    draw.rectangle((0, 1, 74, 5), fill=ink)
    draw.rectangle((2, 1, 72, 5), fill=edge_dark)
    draw.rectangle((3, 2, 71, 4), fill=inner)
    draw.line((4, 1, 70, 1), fill=edge)
    draw.line((4, 5, 70, 5), fill=(10, 23, 28, 255))
    for x in range(6, 69, 7):
        put(image, x, 2, high)
    for x in range(9, 72, 11):
        put(image, x, 4, (8, 18, 22, 255))
    return image


def create_bar_fill() -> Image.Image:
    transparent = (0, 0, 0, 0)
    image = Image.new("RGBA", (75, 7), transparent)
    draw = ImageDraw.Draw(image)
    shadow = (94, 45, 28, 255)
    amber = (205, 124, 50, 255)
    bright = (236, 171, 74, 255)
    ember = (166, 76, 34, 255)
    draw.rectangle((1, 1, 73, 5), fill=shadow)
    draw.rectangle((2, 2, 72, 4), fill=amber)
    draw.line((4, 1, 69, 1), fill=bright)
    draw.line((5, 5, 70, 5), fill=ember)
    for x in range(6, 70, 8):
        put(image, x, 2, bright)
    for x in range(12, 72, 13):
        put(image, x, 4, (126, 58, 32, 255))
    return image


def create_patience_icon() -> Image.Image:
    transparent = (0, 0, 0, 0)
    outline = (10, 16, 18, 255)
    teal = (35, 82, 80, 255)
    amber = (224, 154, 62, 255)
    image = Image.new("RGBA", (6, 6), transparent)
    pixels = [
        ".####.",
        ".#..#.",
        "..##..",
        "..##..",
        ".#..#.",
        ".####.",
    ]
    for y, row in enumerate(pixels):
        for x, value in enumerate(row):
            if value != "#":
                continue
            border = y in (0, 5) or x in (1, 4)
            put(image, x, y, outline if border else amber)
    put(image, 2, 2, amber)
    put(image, 3, 3, amber)
    put(image, 2, 3, teal)
    put(image, 3, 2, teal)
    return image


def save_pair(native: Image.Image, native_name: str, runtime_name: str) -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    native_path = SOURCE / f"{native_name}_native.png"
    runtime_path = RUNTIME / f"{runtime_name}.png"
    native.save(native_path)
    native.resize((native.width * SCALE, native.height * SCALE), Image.Resampling.NEAREST).save(runtime_path)
    print(f"{runtime_name}.png: {runtime_path.relative_to(ROOT).as_posix()}")


def make_contact_sheet(bg: Image.Image, fill: Image.Image, icon: Image.Image) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (420, 180), (16, 14, 12, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((12, 10), "Tavern patience UI", fill=(220, 204, 176, 255))
    draw.text((12, 34), "native", fill=(220, 204, 176, 255))
    draw.text((12, 96), "runtime 4x", fill=(220, 204, 176, 255))
    native_preview = Image.new("RGBA", (90, 28), (0, 0, 0, 0))
    native_preview.alpha_composite(bg, (0, 0))
    native_preview.alpha_composite(fill, (0, 10))
    native_preview.alpha_composite(icon, (78, 1))
    runtime_preview = Image.new("RGBA", (360, 44), (0, 0, 0, 0))
    runtime_preview.alpha_composite(bg.resize((300, 28), Image.Resampling.NEAREST), (32, 8))
    runtime_preview.alpha_composite(fill.resize((220, 28), Image.Resampling.NEAREST), (32, 8))
    runtime_preview.alpha_composite(icon.resize((24, 24), Image.Resampling.NEAREST), (0, 10))
    sheet.alpha_composite(native_preview.resize((180, 56), Image.Resampling.NEAREST), (88, 30))
    sheet.alpha_composite(runtime_preview, (40, 112))
    sheet.convert("RGB").save(CONTACT_SHEET)


def main() -> None:
    bg = create_bar_bg()
    fill = create_bar_fill()
    icon = create_patience_icon()
    save_pair(bg, "patience_bar_bg", "bar_patience_bg")
    save_pair(fill, "patience_bar_fill", "bar_patience_fill")
    save_pair(icon, "icon_patience", "icon_patience")
    make_contact_sheet(bg, fill, icon)
    print(f"contact sheet: {CONTACT_SHEET.relative_to(ROOT).as_posix()}")


if __name__ == "__main__":
    main()
