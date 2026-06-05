from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "intro"
REFERENCE = SOURCE / "reference"
RUNTIME = ROOT / "assets" / "textures" / "intro"
TITLE_SOURCE = ROOT / "assets" / "source" / "title"
SCALE = 4
NATIVE_SIZE = (320, 180)
RUNTIME_SIZE = (1280, 720)
SCENES = [
    "arrival_dungeon_overlook",
    "arrival_tavern_exterior",
    "arrival_tavern_door",
]
# Force-clear this native rect on the front layer so the foreground frame never
# covers the narration even if the painted art crept inward. Superset of the label.
TEXT_BAND = (40, 100, 280, 156)
TITLE_PALETTE_COLORS = 36
FULL_REF_SCENES = {"arrival_dungeon_overlook"}
FIRST_VISTA = "arrival_dungeon_overlook"


def open_reference(name: str) -> Image.Image:
    path = REFERENCE / f"{name}.png"
    if not path.exists():
        raise FileNotFoundError(f"missing generated source art: {path}")
    with Image.open(path) as image:
        return image.convert("RGBA")


def optional_reference(name: str) -> Image.Image | None:
    path = REFERENCE / f"{name}.png"
    if not path.exists():
        return None
    with Image.open(path) as image:
        return image.convert("RGBA")


def title_palette() -> Image.Image:
    path = TITLE_SOURCE / "title_pixel_bg_clean_native.png"
    if not path.exists():
        raise FileNotFoundError(f"missing title palette source: {path}")
    with Image.open(path) as image:
        palette = image.convert("RGB").quantize(colors=TITLE_PALETTE_COLORS, method=Image.Quantize.MEDIANCUT)
    out = Image.new("P", (1, 1))
    out.putpalette(palette.getpalette())
    return out


def pixelize(image: Image.Image) -> Image.Image:
    # Clean LANCZOS downscale onto the native grid; runtime 4x NEAREST then gives the
    # title-screen 4px-block density. Never NEAREST-downscale source art (it aliases).
    return ImageOps.fit(image, NATIVE_SIZE, method=Image.Resampling.LANCZOS, centering=(0.5, 0.5))


def title_style(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A") if "A" in image.getbands() else None
    softened = image.convert("RGBA").filter(ImageFilter.GaussianBlur(0.55))
    rgb = ImageEnhance.Contrast(softened.convert("RGB")).enhance(1.22)
    quantized = rgb.quantize(palette=title_palette(), dither=Image.Dither.NONE).convert("RGBA")
    quantized = quantized.filter(ImageFilter.ModeFilter(3))
    quantized = ImageEnhance.Contrast(quantized.convert("RGB")).enhance(1.08).convert("RGBA")
    if alpha is not None:
        quantized.putalpha(alpha)
    return quantized


def first_vista_style(image: Image.Image) -> Image.Image:
    """Source-preserving first-vista conversion from approved reference art."""
    native = ImageEnhance.Contrast(pixelize(image).convert("RGB")).enhance(1.08)
    quantized = native.quantize(colors=42, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGBA")
    return preserve_amber_accents(preserve_teal_tones(quantized))


def preserve_amber_accents(image: Image.Image) -> Image.Image:
    out = image.convert("RGBA")
    pixels = out.load()
    width, height = out.size
    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if alpha >= 200 and red >= 80 and green >= 35 and blue <= 120 and red > green * 1.2:
                pixels[x, y] = (max(red, 122), max(green, 52), min(blue, 96), alpha)
    return out


def preserve_teal_tones(image: Image.Image) -> Image.Image:
    out = image.convert("RGBA")
    pixels = out.load()
    width, height = out.size
    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            cool_stone = green >= 45 and blue >= 45 and blue >= green * 0.75 and red <= green * 1.35
            if alpha >= 200 and cool_stone:
                pixels[x, y] = (min(red, 88), max(green, 66), max(blue, 62), alpha)
    return out


def chroma_key_magenta(image: Image.Image) -> Image.Image:
    """Knock the solid magenta (#FF00FF) key color out to full transparency."""
    out = image.convert("RGBA")
    pixels = out.load()
    width, height = out.size
    for y in range(height):
        for x in range(width):
            red, green, blue, _ = pixels[x, y]
            if red > 110 and green < 120 and blue > 110 and red > green * 1.3 and blue > green * 1.3:
                pixels[x, y] = (0, 0, 0, 0)
    return out


def clear_text_band(image: Image.Image) -> Image.Image:
    out = image.copy()
    draw = ImageDraw.Draw(out, "RGBA")
    draw.rectangle(TEXT_BAND, fill=(0, 0, 0, 0))
    return out


def open_foreground_frame(image: Image.Image) -> Image.Image:
    out = image.copy()
    draw = ImageDraw.Draw(out, "RGBA")
    # Break the "picture frame" silhouette. Keep depth from top/side masses, but
    # leave the subtitle area and most of the bottom open.
    draw.rectangle((44, 132, 276, 180), fill=(0, 0, 0, 0))
    draw.rectangle((92, 0, 228, 18), fill=(0, 0, 0, 0))
    draw.rectangle((150, 0, 210, 44), fill=(0, 0, 0, 0))
    return out


def same_source_front(full_native: Image.Image) -> Image.Image:
    front = full_native.copy()
    alpha = Image.new("L", NATIVE_SIZE, 0)
    draw = ImageDraw.Draw(alpha)
    # Open, non-symmetrical foreground: top rock shelf, left lower anchor, and a
    # small right-side bite. This sells parallax without closing the image.
    draw.polygon(
        [
            (0, 0),
            (320, 0),
            (320, 20),
            (278, 16),
            (252, 30),
            (212, 18),
            (176, 36),
            (130, 18),
            (94, 28),
            (54, 20),
            (0, 38),
        ],
        fill=255,
    )
    draw.polygon([(0, 76), (36, 92), (60, 180), (0, 180)], fill=255)
    draw.polygon([(224, 170), (290, 142), (320, 150), (320, 180), (210, 180)], fill=255)
    draw.rectangle(TEXT_BAND, fill=0)
    front.putalpha(alpha)
    return front


def same_source_back(full_native: Image.Image) -> Image.Image:
    back = full_native.copy()
    draw = ImageDraw.Draw(back, "RGBA")
    # Darken the same-source near edges so the parallax front does not read as a
    # duplicated bright detail. These are broad shadow masses in the title style.
    draw.rectangle((0, 0, 320, 18), fill=(2, 20, 26, 190))
    draw.polygon([(0, 70), (32, 92), (58, 180), (0, 180)], fill=(2, 18, 24, 175))
    draw.polygon([(230, 174), (292, 145), (320, 152), (320, 180), (210, 180)], fill=(2, 18, 24, 160))
    return back


def first_vista_back(full_native: Image.Image) -> Image.Image:
    back = full_native.copy()
    draw = ImageDraw.Draw(back, "RGBA")
    # Subtle edge shading separates the parallax layer without repainting the plate.
    draw.rectangle((0, 0, 320, 14), fill=(2, 18, 24, 80))
    draw.polygon([(0, 72), (28, 92), (48, 180), (0, 180)], fill=(2, 17, 23, 75))
    draw.polygon([(270, 86), (320, 52), (320, 180), (232, 180), (250, 132)], fill=(2, 17, 23, 82))
    return preserve_amber_accents(preserve_teal_tones(back))


def first_vista_front(full_native: Image.Image) -> Image.Image:
    front = full_native.copy()
    alpha = Image.new("L", NATIVE_SIZE, 0)
    draw = ImageDraw.Draw(alpha)
    # Broad asymmetric cave silhouettes: top and sides sell depth; the center stays open.
    draw.polygon(
        [
            (0, 0),
            (320, 0),
            (320, 25),
            (292, 20),
            (274, 42),
            (246, 22),
            (218, 28),
            (196, 18),
            (172, 34),
            (138, 18),
            (110, 28),
            (82, 20),
            (52, 38),
            (24, 28),
            (0, 48),
        ],
        fill=255,
    )
    draw.polygon([(0, 56), (28, 76), (48, 134), (42, 180), (0, 180)], fill=255)
    draw.polygon([(302, 46), (320, 34), (320, 180), (294, 180), (300, 132), (298, 88)], fill=255)
    draw.polygon([(104, 178), (138, 170), (176, 174), (194, 180), (90, 180)], fill=255)
    # Keep the left lantern/post in the front parallax layer.
    draw.rectangle((16, 50, 44, 126), fill=255)
    draw.rectangle((31, 62, 42, 90), fill=255)
    draw.rectangle(TEXT_BAND, fill=0)
    shade = Image.new("RGBA", NATIVE_SIZE, (2, 18, 24, 95))
    front = Image.alpha_composite(front.convert("RGBA"), shade)
    front = preserve_amber_accents(preserve_teal_tones(front))
    front.putalpha(alpha)
    return clear_text_band(front)


def make_back(scene: str) -> Image.Image:
    full_ref = optional_reference(f"{scene}_full_ref") if scene in FULL_REF_SCENES else None
    source = full_ref if full_ref is not None else open_reference(f"{scene}_back_ref")
    styled = first_vista_style(source) if scene == FIRST_VISTA and full_ref is not None else title_style(pixelize(source))
    if scene == FIRST_VISTA and full_ref is not None:
        styled = first_vista_back(styled)
    elif full_ref is not None:
        styled = same_source_back(styled)
    return preserve_amber_accents(preserve_teal_tones(styled))


def make_front(scene: str) -> Image.Image:
    full_ref = optional_reference(f"{scene}_full_ref") if scene in FULL_REF_SCENES else None
    if full_ref is not None:
        if scene == FIRST_VISTA:
            return first_vista_front(first_vista_style(full_ref))
        return clear_text_band(same_source_front(title_style(pixelize(full_ref))))
    keyed = chroma_key_magenta(open_reference(f"{scene}_front_ref"))
    native = chroma_key_magenta(pixelize(keyed))
    native = title_style(native)
    native = chroma_key_magenta(native)
    return clear_text_band(open_foreground_frame(native))


def make_scrim() -> Image.Image:
    """Static full-resolution soft band behind the narration label. Not pixelized
    (a soft gradient reads better than 4px blocks for a text backdrop)."""
    width, height = RUNTIME_SIZE
    scrim = Image.new("RGBA", RUNTIME_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(scrim, "RGBA")
    top, peak, bottom = 430, 520, 620
    for y in range(top, bottom):
        ratio = (y - top) / (peak - top) if y < peak else 1 - (y - peak) / (bottom - peak)
        draw.line([(0, y), (width - 1, y)], fill=(2, 6, 9, int(140 * max(0.0, ratio))))
    return scrim


def export_pair(name: str, native_image: Image.Image) -> None:
    if native_image.size != NATIVE_SIZE:
        raise ValueError(f"{name}: wrong native size {native_image.size}")
    native_path = SOURCE / f"{name}_native.png"
    runtime_path = RUNTIME / f"{name}.png"
    runtime = native_image.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
    native_path.parent.mkdir(parents=True, exist_ok=True)
    runtime_path.parent.mkdir(parents=True, exist_ok=True)
    native_image.save(native_path)
    runtime.save(runtime_path)


def export_runtime_only(name: str, image: Image.Image) -> None:
    path = RUNTIME / f"{name}.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def export_scene(scene: str) -> None:
    back = make_back(scene)
    front = make_front(scene)
    export_pair(f"{scene}_back", back)
    export_pair(f"{scene}_front", front)
    composite = back.copy()
    composite.alpha_composite(front)
    export_pair(scene, composite)  # composite is only the single-sprite `bg` fallback
    print(f"{scene}: back + front + composite")


def main() -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    for scene in SCENES:
        export_scene(scene)
    export_runtime_only("intro_text_scrim", make_scrim())
    print("intro_text_scrim: runtime scrim")


if __name__ == "__main__":
    main()
