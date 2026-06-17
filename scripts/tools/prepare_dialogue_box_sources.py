from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_sources" / "generated_raw" / "dialogue_box" / "dialogue_box_sheet_v4.png"
REFERENCE = ROOT / "assets" / "source" / "ui" / "dialogue_box" / "reference" / "dialogue_box_sheet_v4_reference.png"


def build_reference(raw: Image.Image) -> Image.Image:
    return raw.convert("RGBA")


def main() -> None:
    if not RAW.exists():
        raise FileNotFoundError(f"missing raw dialogue box sheet: {RAW}")
    with Image.open(RAW) as raw:
        reference = build_reference(raw)
    REFERENCE.parent.mkdir(parents=True, exist_ok=True)
    reference.save(REFERENCE)
    print(f"prepared dialogue box reference: {REFERENCE.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
