from __future__ import annotations

import json
import shutil
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_sources" / "generated_raw" / "evelyn_endings"
RECOVERED = RAW / "recovered_v4"
SOURCE = ROOT / "assets" / "source" / "endings" / "evelyn"
REFERENCE = SOURCE / "reference"
NATIVE_SIZE = (320, 140)
RUNTIME_SIZE = (1280, 560)
REFERENCE_VERSION = "v1"
ROUTES = [
    "sealed_account",
    "living_witnesses",
    "paper_public",
    "damaged_amendment",
    "cold_amendment",
]
RECOVERED_BY_ROUTE = {
    "sealed_account": "evelyn_v4_raw_20260616T113647Z_ig_093eba59c43e9794016a3134f34f8481919fcc18da9e6a26f0.png",
    "living_witnesses": "evelyn_v4_raw_20260616T113908Z_ig_093eba59c43e9794016a313552d3088191b390c796fe2bd302.png",
    "paper_public": "evelyn_v4_raw_20260616T114117Z_ig_093eba59c43e9794016a3135dec43c8191a48d0ef588878cb3.png",
    "damaged_amendment": "evelyn_v4_raw_20260616T114332Z_ig_093eba59c43e9794016a31365fc9c0819191bf467caf392c07.png",
    "cold_amendment": "evelyn_v4_raw_20260616T114544Z_ig_093eba59c43e9794016a3136e687288191aaddc42d1d437df0.png",
}
PROMPTS = {
    "sealed_account": "Evelyn ending still for sealed_account: no Evelyn in frame; a cold guild archive after closing, huge grey ledgers tied shut, thick cords, unbroken wax seals, locked shelves, empty desk, dark teal stone and restrained amber candlelight. Native-pixel concept art source, rough ink lines, paper grain, no readable text, no UI, no logo, no watermark.",
    "living_witnesses": "Evelyn ending still for living_witnesses: Evelyn appears because living witnesses force the account open; she matches the Grey Ledger Lady identity with black hair updo, porcelain-pale face and hands, high-collared tailored black formal dress, cold auditor posture, not elderly. Open grey ledger on desk, witness silhouettes in cold doorway. Native-pixel concept art source, rough ink lines, paper grain, no readable text, no UI, no logo, no watermark.",
    "paper_public": "Evelyn ending still for paper_public: no Evelyn in frame; loose grey account pages, broken wax seals, public doorway, empty chairs, archive shelves, paper evidence exposed outside private control. Native-pixel concept art source, dark teal stone, amber candlelight, rough ink lines, paper grain, no readable text, no UI, no logo, no watermark.",
    "damaged_amendment": "Evelyn ending still for damaged_amendment: Evelyn appears because she reluctantly makes a partial correction; she matches the Grey Ledger Lady identity with black hair updo, porcelain-pale face and hands, high-collared tailored black formal dress, cold auditor posture, not elderly. Open ledger, cut cords, broken wax seals, loose blank page, witness silhouettes in doorway. Native-pixel concept art source, rough ink lines, paper grain, no readable text, no UI, no logo, no watermark.",
    "cold_amendment": "Evelyn ending still for cold_amendment: Evelyn appears because she coldly writes a narrow technical correction alone; she matches the Grey Ledger Lady identity with black hair updo, porcelain-pale face and hands, high-collared tailored black formal dress, cold auditor posture, not elderly. Sealed ledger bundles loom around her, dying candle, no witnesses. Native-pixel concept art source, rough ink lines, paper grain, no readable text, no UI, no logo, no watermark.",
}


def quantize_native(image: Image.Image, colors: int = 64) -> Image.Image:
    rgb = image.convert("RGB")
    return rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGBA")


def build_native(reference: Image.Image) -> Image.Image:
    resized = reference.convert("RGBA").resize(NATIVE_SIZE, Image.Resampling.NEAREST)
    return quantize_native(resized)


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


def write_raw_manifest() -> None:
    entries = []
    for route in ROUTES:
        entries.append(
            {
                "id": f"evelyn_{route}_reference_{REFERENCE_VERSION}",
                "route": route,
                "source_file": f"art_sources/generated_raw/evelyn_endings/recovered_v4/{RECOVERED_BY_ROUTE[route]}",
                "output_file": f"art_sources/generated_raw/evelyn_endings/evelyn_{route}_reference_{REFERENCE_VERSION}.png",
                "prompt_file": f"art_sources/generated_raw/evelyn_endings/evelyn_{route}_reference_{REFERENCE_VERSION}_prompt.txt",
                "size": list(RUNTIME_SIZE),
                "safe_area": [0, 0, RUNTIME_SIZE[0], RUNTIME_SIZE[1]],
                "intended_godot_use": "Evelyn fate cinematic source reference",
            }
        )
    manifest = {
        "id": "evelyn_ending_wide_references_v1",
        "target_native_size": list(NATIVE_SIZE),
        "target_runtime_size": list(RUNTIME_SIZE),
        "entries": entries,
    }
    (RAW / "evelyn_ending_reference_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    RAW.mkdir(parents=True, exist_ok=True)
    SOURCE.mkdir(parents=True, exist_ok=True)
    REFERENCE.mkdir(parents=True, exist_ok=True)
    natives: dict[str, Image.Image] = {}
    for route in ROUTES:
        recovered_path = RECOVERED / RECOVERED_BY_ROUTE[route]
        if not recovered_path.exists():
            raise FileNotFoundError(f"{recovered_path}: missing recovered Evelyn ending reference")
        raw_reference = RAW / f"evelyn_{route}_reference_{REFERENCE_VERSION}.png"
        shutil.copy2(recovered_path, raw_reference)
        prompt_path = RAW / f"evelyn_{route}_reference_{REFERENCE_VERSION}_prompt.txt"
        prompt_path.write_text(PROMPTS[route] + "\n", encoding="utf-8")

        approved_path = REFERENCE / raw_reference.name
        shutil.copy2(raw_reference, approved_path)
        with Image.open(approved_path) as reference:
            native = build_native(reference)
        native_path = SOURCE / f"evelyn_{route}_native.png"
        native.save(native_path)
        natives[route] = native
        print(f"{route}: {approved_path.name} -> {native_path.relative_to(ROOT)}")

    write_raw_manifest()
    make_contact_sheet(natives).save(SOURCE / "evelyn_ending_native_contact_sheet.png")


if __name__ == "__main__":
    main()
