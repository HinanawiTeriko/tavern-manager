from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "endings" / "ryan"
REFERENCE = SOURCE / "reference"
RUNTIME = ROOT / "assets" / "textures" / "endings" / "ryan"
MANIFEST = SOURCE / "ryan_ending_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "ryan_ending_backgrounds_contact_sheet.png"
NATIVE_SIZE = (320, 140)
RUNTIME_SIZE = (1280, 560)
SCALE = 4
ROUTES = [
    "uninformed_fallen",
    "drugged_survivor",
    "informed_fallen",
    "alternative_survivor",
]


def load_native(route: str) -> Image.Image:
    path = SOURCE / f"ryan_{route}_native.png"
    if not path.exists():
        raise FileNotFoundError(f"{path}: missing native Ryan ending source")
    with Image.open(path) as image:
        native = image.convert("RGBA").copy()
    if native.size != NATIVE_SIZE:
        raise ValueError(f"{route}: native source must be {NATIVE_SIZE}, got {native.size}")
    return native


def export_runtime(route: str, native: Image.Image) -> Image.Image:
    runtime = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
    if runtime.size != RUNTIME_SIZE:
        raise RuntimeError(f"{route}: runtime image must be {RUNTIME_SIZE}, got {runtime.size}")
    return runtime


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


def write_manifest() -> None:
    routes = {}
    for route in ROUTES:
        routes[route] = {
            "reference": f"assets/source/endings/ryan/reference/ryan_{route}_reference_v2.png",
            "native": f"assets/source/endings/ryan/ryan_{route}_native.png",
            "runtime": f"assets/textures/endings/ryan/ryan_{route}.png",
            "safe_area": [0, 0, NATIVE_SIZE[0], NATIVE_SIZE[1]],
            "intended_godot_use": "Future Ryan fate cinematic layer before Day 3 ledger settlement",
        }
    manifest = {
        "id": "ryan_ending_backgrounds",
        "source_profile": "native_pixel_wide_reference_v2",
        "native_size": list(NATIVE_SIZE),
        "runtime_size": list(RUNTIME_SIZE),
        "scale": SCALE,
        "routes": routes,
    }
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    RUNTIME.mkdir(parents=True, exist_ok=True)
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    natives: dict[str, Image.Image] = {}
    for route in ROUTES:
        reference = REFERENCE / f"ryan_{route}_reference_v2.png"
        if not reference.exists():
            raise FileNotFoundError(f"{reference}: missing approved Ryan ending reference")
        native = load_native(route)
        runtime = export_runtime(route, native)
        runtime.save(RUNTIME / f"ryan_{route}.png")
        natives[route] = native
        print(f"{route}: {NATIVE_SIZE} -> {RUNTIME_SIZE} nearest")
    write_manifest()
    make_contact_sheet(natives).save(CONTACT_SHEET)


if __name__ == "__main__":
    main()
