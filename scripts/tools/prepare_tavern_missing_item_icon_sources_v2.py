from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[2]
OLD_SHEET = ROOT / "assets" / "source" / "tavern" / "missing_item_icons" / "reference" / "missing_item_icons_sheet_v1.png"
AI_SOURCE = ROOT / "art_sources" / "generated_raw" / "tavern_missing_item_icons" / "missing_item_icons_sheet_v3_ai.png"
RAW_OUT = ROOT / "art_sources" / "generated_raw" / "tavern_missing_item_icons" / "missing_item_icons_sheet_v3.png"
REFERENCE_OUT = ROOT / "assets" / "source" / "tavern" / "missing_item_icons" / "reference" / "missing_item_icons_sheet_v3.png"

KEY = (255, 0, 255, 255)
CELL_SIZE = 296
SHEET_SIZE = (1774, 1183)

# Fixed visual crop rectangles in the generated AI source sheet.
# The crop boundaries are authored constants, not alpha/color/component inference.
AI_CELL_RECTS = {
    "ale_beer": (18, 145, 382, 572),
    "bread": (390, 145, 772, 548),
    "meat_cooked": (760, 135, 1145, 572),
    "herb_broth": (1150, 145, 1505, 552),
    "bloodied_contract": (1538, 125, 1815, 575),
    "alternative_contract": (1864, 125, 2165, 575),
}

OUT_CELL_ORIGINS = {
    "ale_beer": (0, 887),
    "bread": (296, 887),
    "meat_cooked": (591, 887),
    "herb_broth": (887, 887),
    "bloodied_contract": (1183, 887),
    "alternative_contract": (1478, 887),
}


def normalize_cell(ai_sheet: Image.Image, rect: tuple[int, int, int, int]) -> Image.Image:
    cell = ai_sheet.crop(rect).convert("RGBA")
    cell = ImageOps.contain(cell, (CELL_SIZE, CELL_SIZE), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), KEY)
    out.alpha_composite(cell, ((CELL_SIZE - cell.width) // 2, (CELL_SIZE - cell.height) // 2))
    return out


def main() -> None:
    old = Image.open(OLD_SHEET).convert("RGBA")
    ai_sheet = Image.open(AI_SOURCE).convert("RGBA")
    if ai_sheet.size != (2172, 724):
        raise ValueError(f"{AI_SOURCE}: expected 2172x724, got {ai_sheet.size}")

    sheet = Image.new("RGBA", SHEET_SIZE, KEY)
    sheet.alpha_composite(old, (0, 0))
    for icon_id, rect in AI_CELL_RECTS.items():
        left, top = OUT_CELL_ORIGINS[icon_id]
        sheet.alpha_composite(normalize_cell(ai_sheet, rect), (left, top))

    RAW_OUT.parent.mkdir(parents=True, exist_ok=True)
    REFERENCE_OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(RAW_OUT)
    sheet.save(REFERENCE_OUT)
    print(f"wrote {RAW_OUT.relative_to(ROOT)}")
    print(f"wrote {REFERENCE_OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
