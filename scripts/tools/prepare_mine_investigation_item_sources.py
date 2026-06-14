from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_sources" / "generated_raw" / "mine_investigation" / "mine_item_sheet_v3_scene_grounded.png"
REFERENCE = ROOT / "assets" / "source" / "investigation" / "mine_items" / "reference" / "mine_item_sheet_v3_scene_grounded_reference.png"
REFERENCE_SIZE = (2048, 1024)


def build_reference(raw: Image.Image) -> Image.Image:
    return raw.convert("RGBA").resize(REFERENCE_SIZE, Image.Resampling.LANCZOS)


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
