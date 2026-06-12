from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_sources" / "generated_raw" / "mine_investigation" / "mine_item_sheet_v1.png"
REFERENCE = ROOT / "assets" / "source" / "investigation" / "mine_items" / "reference" / "mine_item_sheet_v1_reference.png"
REFERENCE_SIZE = (2048, 1024)


def build_reference(raw: Image.Image) -> Image.Image:
    canvas = Image.new("RGBA", REFERENCE_SIZE, (255, 0, 255, 255))
    fitted = ImageOps.contain(raw.convert("RGBA"), REFERENCE_SIZE, Image.Resampling.LANCZOS)
    x = (REFERENCE_SIZE[0] - fitted.width) // 2
    y = (REFERENCE_SIZE[1] - fitted.height) // 2
    canvas.alpha_composite(fitted, (x, y))
    return canvas


def main() -> None:
    if not RAW.exists():
        raise FileNotFoundError(f"missing raw mine item sheet: {RAW}")
    with Image.open(RAW) as raw:
        reference = build_reference(raw)
    REFERENCE.parent.mkdir(parents=True, exist_ok=True)
    reference.save(REFERENCE)
    print(f"prepared mine item reference: {REFERENCE.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
