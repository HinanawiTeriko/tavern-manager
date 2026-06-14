from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

from export_daymap_marker_assets import (
    build_contact_sheet,
    crop_source,
    export_runtime,
    fit_icon_to_native,
    repo_path,
    validate_native,
)


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "assets" / "source" / "daymap" / "markers" / "daymap_market_shop_marker_manifest.json"
SOURCE_IMAGE = ROOT / "art_sources" / "generated_raw" / "daymap_markers" / "market_shop_marker_source_v1.png"
CONTACT_SHEET = ROOT / "docs" / "art" / "daymap_market_shop_marker_contact_sheet.png"


def load_manifest() -> dict:
    with MANIFEST_PATH.open("r", encoding="utf-8") as file:
        return json.load(file)


def load_source_image(manifest: dict) -> Image.Image:
    source_path = repo_path(str(manifest.get("source_image", SOURCE_IMAGE.relative_to(ROOT).as_posix())))
    if not source_path.exists():
        raise FileNotFoundError(f"Missing retained market shop marker source: {source_path}")
    with Image.open(source_path) as image:
        return image.convert("RGBA")


def main() -> None:
    manifest = load_manifest()
    source = load_source_image(manifest)
    previews: list[tuple[Image.Image, Image.Image]] = []
    for marker_id, entry in manifest["assets"].items():
        source_crop = entry["source_crop"]
        source_part = crop_source(source, source_crop)
        native = fit_icon_to_native(source_part)
        validate_native(marker_id, native)

        native_path = repo_path(entry["native_file"])
        runtime_path = repo_path(entry["output_file"])
        runtime = export_runtime(native, tuple(entry["size"]))

        native_path.parent.mkdir(parents=True, exist_ok=True)
        runtime_path.parent.mkdir(parents=True, exist_ok=True)
        native.save(native_path)
        runtime.save(runtime_path)
        previews.append((source_part, runtime))
        print(f"{marker_id}: {source_crop} -> {native.size} -> {runtime.size}")

    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    build_contact_sheet(previews).save(CONTACT_SHEET)
    print(f"Contact sheet: {CONTACT_SHEET.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
