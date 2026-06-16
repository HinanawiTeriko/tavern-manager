from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "endings" / "evelyn"
REFERENCE = SOURCE / "reference"
RUNTIME = ROOT / "assets" / "textures" / "endings" / "evelyn"
MANIFEST = SOURCE / "evelyn_ending_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "evelyn_ending_backgrounds_contact_sheet.png"
NATIVE_SIZE = (320, 140)
RUNTIME_SIZE = (1280, 560)
SCALE = 4
REFERENCE_VERSION = "v1"
ROUTES = [
    "sealed_account",
    "living_witnesses",
    "paper_public",
    "damaged_amendment",
    "cold_amendment",
]


def load_native(route: str) -> Image.Image:
    path = SOURCE / f"evelyn_{route}_native.png"
    if not path.exists():
        raise FileNotFoundError(f"{path}: missing native Evelyn ending source")
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
    sheet = Image.new("RGBA", (NATIVE_SIZE[0] * 3, NATIVE_SIZE[1] * 2), (8, 10, 11, 255))
    positions = {
        "sealed_account": (0, 0),
        "living_witnesses": (NATIVE_SIZE[0], 0),
        "paper_public": (NATIVE_SIZE[0] * 2, 0),
        "damaged_amendment": (0, NATIVE_SIZE[1]),
        "cold_amendment": (NATIVE_SIZE[0], NATIVE_SIZE[1]),
    }
    for route, position in positions.items():
        sheet.alpha_composite(natives[route], position)
    return sheet


def write_manifest() -> None:
    routes = {}
    for route in ROUTES:
        routes[route] = {
            "reference": f"assets/source/endings/evelyn/reference/evelyn_{route}_reference_{REFERENCE_VERSION}.png",
            "native": f"assets/source/endings/evelyn/evelyn_{route}_native.png",
            "runtime": f"assets/textures/endings/evelyn/evelyn_{route}.png",
            "safe_area": [0, 0, NATIVE_SIZE[0], NATIVE_SIZE[1]],
            "intended_godot_use": "Evelyn fate cinematic layer before Day 20 ledger settlement",
        }
    manifest = {
        "id": "evelyn_ending_backgrounds",
        "source_profile": "native_pixel_wide_reference_v1",
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
        reference = REFERENCE / f"evelyn_{route}_reference_{REFERENCE_VERSION}.png"
        if not reference.exists():
            raise FileNotFoundError(f"{reference}: missing approved Evelyn ending reference")
        native = load_native(route)
        runtime = export_runtime(route, native)
        runtime.save(RUNTIME / f"evelyn_{route}.png")
        natives[route] = native
        print(f"{route}: {NATIVE_SIZE} -> {RUNTIME_SIZE} nearest")
    write_manifest()
    make_contact_sheet(natives).save(CONTACT_SHEET)


if __name__ == "__main__":
    main()
