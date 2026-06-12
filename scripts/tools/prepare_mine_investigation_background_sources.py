from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = ROOT / "art_sources" / "generated_raw" / "mine_investigation_background"
RAW_BACKGROUND = RAW_DIR / "mine_background_reference_v1.png"
RAW_SHADOW = RAW_DIR / "mine_item_shadow_source_v1.png"
SOURCE = ROOT / "assets" / "source" / "investigation" / "mine_background"
REFERENCE_DIR = SOURCE / "reference"
REFERENCE_BACKGROUND = REFERENCE_DIR / "mine_background_reference_v1.png"
REFERENCE_SHADOW = REFERENCE_DIR / "mine_item_shadow_source_v1.png"
MANIFEST = SOURCE / "mine_background_manifest.json"
BACKGROUND_REFERENCE_SIZE = (1280, 720)
SHADOW_REFERENCE_SIZE = (512, 256)


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def prepare_background(raw: Image.Image) -> Image.Image:
    return ImageOps.fit(raw.convert("RGBA"), BACKGROUND_REFERENCE_SIZE, Image.Resampling.LANCZOS, centering=(0.5, 0.5))


def prepare_shadow(raw: Image.Image) -> Image.Image:
    canvas = Image.new("RGBA", SHADOW_REFERENCE_SIZE, (255, 0, 255, 255))
    fitted = ImageOps.contain(raw.convert("RGBA"), SHADOW_REFERENCE_SIZE, Image.Resampling.LANCZOS)
    x = (canvas.width - fitted.width) // 2
    y = (canvas.height - fitted.height) // 2
    canvas.alpha_composite(fitted, (x, y))
    return canvas


def write_manifest() -> None:
    manifest = {
        "scale": 4,
        "background": {
            "id": "mine_investigation_background",
            "source": rel(RAW_BACKGROUND),
            "reference": rel(REFERENCE_BACKGROUND),
            "native": "assets/source/investigation/mine_background/mine_background_native.png",
            "runtime": "assets/ui/generated/investigation/mine_background/mine_background.png",
            "native_size": [320, 180],
            "runtime_size": [1280, 720],
            "safe_area": [0, 0, 320, 180],
            "intended_godot_use": "MineInvestigation visual-only BackgroundArt Sprite2D layer",
        },
        "shadow": {
            "id": "mine_item_shadow",
            "source": rel(RAW_SHADOW),
            "reference": rel(REFERENCE_SHADOW),
            "native": "assets/source/investigation/mine_background/mine_item_shadow_native.png",
            "runtime": "assets/ui/generated/investigation/mine_background/mine_item_shadow.png",
            "native_size": [40, 14],
            "runtime_size": [160, 56],
            "source_rect": [0, 0, 512, 256],
            "safe_area": [2, 2, 38, 12],
            "intended_godot_use": "MineItem non-rotating contact shadow Sprite2D for mapped production items",
        },
        "review": {
            "contact_sheet": "docs/art/mine_investigation_background_contact_sheet.png",
            "item_overlay_positions_runtime": {
                "broken_arrow": [260, 470],
                "dented_shield": [380, 460],
                "lost_boot": [500, 475],
                "rubble": [980, 455],
                "torn_backpack": [980, 470],
                "coins": [950, 495],
                "warhammer_token": [990, 495],
                "bloodied_paper": [1030, 480],
            },
        },
    }
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    if not RAW_BACKGROUND.exists():
        raise FileNotFoundError(f"missing AI background source: {RAW_BACKGROUND}")
    if not RAW_SHADOW.exists():
        raise FileNotFoundError(f"missing AI shadow source: {RAW_SHADOW}")
    REFERENCE_DIR.mkdir(parents=True, exist_ok=True)
    with Image.open(RAW_BACKGROUND) as raw_background:
        prepare_background(raw_background).save(REFERENCE_BACKGROUND)
    with Image.open(RAW_SHADOW) as raw_shadow:
        prepare_shadow(raw_shadow).save(REFERENCE_SHADOW)
    write_manifest()
    print(f"prepared mine background reference: {rel(REFERENCE_BACKGROUND)}")
    print(f"prepared mine shadow reference: {rel(REFERENCE_SHADOW)}")
    print(f"manifest: {rel(MANIFEST)}")


if __name__ == "__main__":
    main()
