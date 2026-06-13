from __future__ import annotations

from pathlib import Path
import shutil

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_sources" / "generated_raw" / "ryan_endings"
SOURCE = ROOT / "assets" / "source" / "endings" / "ryan"
REFERENCE = SOURCE / "reference"
NATIVE_SIZE = (320, 140)
ROUTES = [
    "uninformed_fallen",
    "drugged_survivor",
    "informed_fallen",
    "alternative_survivor",
]


def quantize_native(image: Image.Image, colors: int = 64) -> Image.Image:
    rgb = image.convert("RGB")
    return rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGBA")


def build_native(reference: Image.Image) -> Image.Image:
    # V2 references are already pixel-style enlarged previews. Nearest sampling keeps
    # their chunky clusters instead of smoothing them into painterly noise.
    resized = reference.convert("RGBA").resize(NATIVE_SIZE, Image.Resampling.NEAREST)
    return quantize_native(resized)


def make_contact_sheet(natives: dict[str, Image.Image]) -> Image.Image:
    sheet = Image.new("RGBA", (NATIVE_SIZE[0] * 2, NATIVE_SIZE[1] * 2), (8, 10, 11, 255))
    positions = {
        "uninformed_fallen": (0, 0),
        "drugged_survivor": (NATIVE_SIZE[0], 0),
        "informed_fallen": (0, NATIVE_SIZE[1]),
        "alternative_survivor": (NATIVE_SIZE[0], NATIVE_SIZE[1]),
    }
    for route, position in positions.items():
        sheet.alpha_composite(natives[route], position)
    return sheet


def main() -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    REFERENCE.mkdir(parents=True, exist_ok=True)
    natives: dict[str, Image.Image] = {}
    for route in ROUTES:
        raw_path = RAW / f"ryan_{route}_reference_v2.png"
        if not raw_path.exists():
            raise FileNotFoundError(f"{raw_path}: missing V2 Ryan ending reference")
        approved_path = REFERENCE / raw_path.name
        shutil.copy2(raw_path, approved_path)
        with Image.open(approved_path) as reference:
            native = build_native(reference)
        native_path = SOURCE / f"ryan_{route}_native.png"
        native.save(native_path)
        natives[route] = native
        print(f"{route}: {approved_path.name} -> {native_path.relative_to(ROOT)}")

    contact_sheet = make_contact_sheet(natives)
    contact_sheet.save(SOURCE / "ryan_ending_native_contact_sheet.png")


if __name__ == "__main__":
    main()
