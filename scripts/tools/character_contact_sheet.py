from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


CONTACT_SHEET_WIDTH = 1180
CONTACT_SHEET_HEADER_HEIGHT = 100
CONTACT_SHEET_ROW_HEIGHT = 360
CONTACT_SHEET_SIZE = (CONTACT_SHEET_WIDTH, CONTACT_SHEET_HEADER_HEIGHT + CONTACT_SHEET_ROW_HEIGHT * 2)
NATIVE_SIZE = (128, 160)
NATIVE_PREVIEW_SCALE = 2
GRID_LEFT = 44
GRID_TOP = 92
GRID_X_STEP = 418
GRID_Y_STEP = 360
NATIVE_PREVIEW_SIZE = (
    NATIVE_SIZE[0] * NATIVE_PREVIEW_SCALE,
    NATIVE_SIZE[1] * NATIVE_PREVIEW_SCALE,
)
GRID_POSITIONS = [
    (44, 92),
    (462, 92),
    (880, 92),
    (44, 452),
    (462, 452),
    (880, 452),
]
SHEET_BG = (18, 14, 11, 255)
PANEL_BG = (24, 20, 16, 255)
TITLE_COLOR = (222, 204, 176, 255)
TEXT_COLOR = (180, 168, 144, 255)


def backed_native_preview(native: Image.Image) -> Image.Image:
    preview_size = (
        native.width * NATIVE_PREVIEW_SCALE,
        native.height * NATIVE_PREVIEW_SCALE,
    )
    preview = native.convert("RGBA").resize(preview_size, Image.Resampling.NEAREST)
    out = Image.new("RGBA", preview_size, PANEL_BG)
    out.alpha_composite(preview, (0, 0))
    return out


def _grid_positions(row_count: int, column_count: int) -> list[tuple[int, int]]:
    return [
        (GRID_LEFT + column * GRID_X_STEP, GRID_TOP + row * GRID_Y_STEP)
        for row in range(row_count)
        for column in range(column_count)
    ]


def _sheet_width(column_count: int) -> int:
    if column_count == 3:
        return CONTACT_SHEET_WIDTH
    if column_count == 4:
        return 1600
    return GRID_LEFT + (column_count - 1) * GRID_X_STEP + NATIVE_PREVIEW_SIZE[0] + GRID_LEFT


def make_character_contact_sheet(
    title: str,
    subtitle: str,
    entries: list[tuple[str, Image.Image]],
    row_count: int = 2,
    column_count: int = 3,
) -> Image.Image:
    if row_count < 1 or row_count > 4:
        raise ValueError(f"character contact sheet supports 1 to 4 rows, got {row_count}")
    if column_count < 1 or column_count > 4:
        raise ValueError(f"character contact sheet supports 1 to 4 columns, got {column_count}")
    positions = _grid_positions(row_count, column_count)
    if len(entries) > len(positions):
        raise ValueError(f"character contact sheet supports {len(positions)} entries, got {len(entries)}")

    out = Image.new(
        "RGBA",
        (_sheet_width(column_count), CONTACT_SHEET_HEADER_HEIGHT + CONTACT_SHEET_ROW_HEIGHT * row_count),
        SHEET_BG,
    )
    draw = ImageDraw.Draw(out)
    draw.text((20, 18), title, fill=TITLE_COLOR)
    draw.text((20, 44), subtitle, fill=TEXT_COLOR)

    for position in positions:
        out.alpha_composite(Image.new("RGBA", NATIVE_PREVIEW_SIZE, PANEL_BG), position)

    for index, (label, native) in enumerate(entries):
        x, y = positions[index]
        out.alpha_composite(backed_native_preview(native), (x, y))
        label_y = y + native.height * NATIVE_PREVIEW_SCALE + 6
        draw.text((x, label_y), label, fill=TEXT_COLOR)

    return out


def save_character_contact_sheet(
    path: Path,
    title: str,
    subtitle: str,
    entries: list[tuple[str, Image.Image]],
    row_count: int = 2,
    column_count: int = 3,
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    make_character_contact_sheet(
        title,
        subtitle,
        entries,
        row_count=row_count,
        column_count=column_count,
    ).convert("RGB").save(path)
