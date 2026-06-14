from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = ROOT / "art_sources" / "generated_raw" / "mine_investigation_ui"
RAW_BUTTON = RAW_DIR / "mine_leave_button_source_v1.png"
RAW_PROMPT = RAW_DIR / "mine_leave_button_prompt_v1.txt"
SOURCE = ROOT / "assets" / "source" / "investigation" / "mine_ui"
REFERENCE = SOURCE / "reference" / "mine_leave_button_source_v1.png"
MANIFEST = SOURCE / "mine_ui_manifest.json"
RUNTIME = ROOT / "assets" / "ui" / "generated" / "investigation" / "mine_ui"
CONTACT_SHEET = ROOT / "docs" / "art" / "mine_investigation_ui_contact_sheet.png"
SCENE_PREVIEW = ROOT / "docs" / "art" / "mine_investigation_ui_scene_preview.png"
BACKGROUND_RUNTIME = ROOT / "assets" / "ui" / "generated" / "investigation" / "mine_background" / "mine_background.png"
PIXEL_FONT = ROOT / "assets" / "fonts" / "fusion-pixel" / "fusion-pixel-12px-proportional-zh_hans.ttf"

SCALE = 4
SOURCE_RECT = (132, 202, 1400, 500)
NATIVE_SIZE = (70, 25)
RUNTIME_SIZE = (280, 100)
SAFE_AREA = [12, 6, 58, 19]
NINE_SLICE_MARGINS = [28, 28, 18, 18]
STATES = ("normal", "hover", "pressed")


def is_chroma(red: int, green: int, blue: int) -> bool:
    return red >= 170 and blue >= 170 and green <= 105 and abs(red - blue) <= 110


def visible_pixel_count(image: Image.Image) -> int:
    return sum(image.convert("RGBA").getchannel("A").histogram()[1:])


def remove_chroma(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    output = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    src_pixels = rgba.load()
    out_pixels = output.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = src_pixels[x, y]
            if is_chroma(red, green, blue):
                out_pixels[x, y] = (0, 0, 0, 0)
            else:
                out_pixels[x, y] = (red, green, blue, alpha)
    return output


def strip_chroma_fringe(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                pixels[x, y] = (0, 0, 0, 0)
                continue
            if is_chroma(red, green, blue):
                pixels[x, y] = (0, 0, 0, 0)
                continue
            if red >= 120 and blue >= 120 and green <= 90:
                red = min(red, 96)
                blue = min(blue, 102)
                green = min(green, 76)
            if alpha < 28:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (red, green, blue, alpha)
    return rgba


def pixelize_source(raw: Image.Image) -> Image.Image:
    x, y, width, height = SOURCE_RECT
    crop = raw.crop((x, y, x + width, y + height))
    cutout = remove_chroma(crop)
    native = cutout.resize(NATIVE_SIZE, Image.Resampling.LANCZOS)
    native = native.filter(ImageFilter.SHARPEN)
    native = strip_chroma_fringe(native)
    if visible_pixel_count(native) < 900:
        raise ValueError("mine_leave_button: native button silhouette is too sparse")
    return native


def adjust_visible_pixels(image: Image.Image, brightness: float, color: float = 1.0) -> Image.Image:
    alpha = image.convert("RGBA").getchannel("A")
    rgb = image.convert("RGB")
    rgb = ImageEnhance.Brightness(rgb).enhance(brightness)
    rgb = ImageEnhance.Color(rgb).enhance(color)
    adjusted = Image.merge("RGBA", (*rgb.split(), alpha))
    return strip_chroma_fringe(adjusted)


def make_states(normal: Image.Image) -> dict[str, Image.Image]:
    normal = adjust_visible_pixels(normal, 1.26, 1.08)
    hover = adjust_visible_pixels(normal, 1.20, 1.08)
    pressed_dark = adjust_visible_pixels(normal, 0.72, 0.9)
    pressed = Image.new("RGBA", NATIVE_SIZE, (0, 0, 0, 0))
    pressed.alpha_composite(pressed_dark.crop((0, 0, NATIVE_SIZE[0], NATIVE_SIZE[1] - 1)), (0, 1))
    return {
        "normal": normal,
        "hover": hover,
        "pressed": pressed,
    }


def save_contact_sheet(states: dict[str, Image.Image]) -> None:
    sheet = Image.new("RGBA", (960, 360), (24, 20, 18, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((24, 18), "Mine investigation leave button - AI source processed to native/runtime states", fill=(230, 210, 170, 255))
    raw = Image.open(RAW_BUTTON).convert("RGBA")
    x, y, width, height = SOURCE_RECT
    crop_preview = raw.crop((x, y, x + width, y + height)).resize((420, 150), Image.Resampling.LANCZOS)
    sheet.alpha_composite(crop_preview, (24, 54))
    draw.rectangle((24, 54, 443, 203), outline=(110, 92, 68, 255))
    draw.text((24, 214), "fixed source_rect [132, 202, 1400, 500]", fill=(180, 160, 130, 255))
    for index, state in enumerate(STATES):
        runtime = states[state].resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
        px = 500
        py = 48 + index * 96
        sheet.alpha_composite(runtime, (px, py))
        draw.rectangle((px, py, px + RUNTIME_SIZE[0] - 1, py + RUNTIME_SIZE[1] - 1), outline=(110, 92, 68, 255))
        draw.text((px + RUNTIME_SIZE[0] + 16, py + 36), state, fill=(230, 210, 170, 255))
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(CONTACT_SHEET)


def save_scene_preview(states: dict[str, Image.Image]) -> None:
    if not BACKGROUND_RUNTIME.exists() or not PIXEL_FONT.exists():
        return
    preview = Image.open(BACKGROUND_RUNTIME).convert("RGBA")
    button = states["normal"].resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
    button_pos = (1240 - RUNTIME_SIZE[0], 684 - RUNTIME_SIZE[1])
    preview.alpha_composite(button, button_pos)
    draw = ImageDraw.Draw(preview)
    font = ImageFont.truetype(str(PIXEL_FONT), 30)
    text = "\u79bb\u5f00 \u25b8"
    left, top, right, bottom = draw.textbbox((0, 0), text, font=font)
    text_width = right - left
    text_height = bottom - top
    text_pos = (
        button_pos[0] + (RUNTIME_SIZE[0] - text_width) // 2,
        button_pos[1] + (RUNTIME_SIZE[1] - text_height) // 2 - 2,
    )
    for offset in ((-2, 0), (2, 0), (0, -2), (0, 2), (-2, -2), (2, 2)):
        draw.text((text_pos[0] + offset[0], text_pos[1] + offset[1]), text, font=font, fill=(4, 4, 3, 230))
    draw.text(text_pos, text, font=font, fill=(240, 214, 170, 255))
    SCENE_PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    preview.save(SCENE_PREVIEW)


def write_manifest() -> None:
    states = []
    for state in STATES:
        states.append(
            {
                "id": state,
                "source_file": "art_sources/generated_raw/mine_investigation_ui/mine_leave_button_source_v1.png",
                "native": f"assets/source/investigation/mine_ui/mine_leave_button_{state}_native.png",
                "runtime": f"assets/ui/generated/investigation/mine_ui/mine_leave_button_{state}.png",
                "output_file": f"assets/ui/generated/investigation/mine_ui/mine_leave_button_{state}.png",
                "size": list(RUNTIME_SIZE),
                "safe_area": SAFE_AREA,
                "nine_slice_margins": NINE_SLICE_MARGINS,
                "intended_godot_use": f"MineInvestigation LeaveButton {state} StyleBoxTexture",
            }
        )
    manifest = {
        "id": "mine_leave_button",
        "scale": SCALE,
        "source": "art_sources/generated_raw/mine_investigation_ui/mine_leave_button_source_v1.png",
        "prompt": "art_sources/generated_raw/mine_investigation_ui/mine_leave_button_prompt_v1.txt",
        "reference": "assets/source/investigation/mine_ui/reference/mine_leave_button_source_v1.png",
        "source_rect": list(SOURCE_RECT),
        "native_size": list(NATIVE_SIZE),
        "runtime_size": list(RUNTIME_SIZE),
        "safe_area": SAFE_AREA,
        "nine_slice_margins": NINE_SLICE_MARGINS,
        "states": states,
    }
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    if not RAW_BUTTON.exists():
        raise FileNotFoundError(RAW_BUTTON)
    if not RAW_PROMPT.exists():
        raise FileNotFoundError(RAW_PROMPT)
    SOURCE.mkdir(parents=True, exist_ok=True)
    REFERENCE.parent.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    raw = Image.open(RAW_BUTTON).convert("RGBA")
    raw.save(REFERENCE)
    states = make_states(pixelize_source(raw))
    for state, native in states.items():
        native_path = SOURCE / f"mine_leave_button_{state}_native.png"
        runtime_path = RUNTIME / f"mine_leave_button_{state}.png"
        native.save(native_path)
        runtime = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
        runtime.save(runtime_path)
        print(f"mine_leave_button_{state}: {NATIVE_SIZE} -> {RUNTIME_SIZE}")
    save_contact_sheet(states)
    save_scene_preview(states)
    write_manifest()


if __name__ == "__main__":
    main()
