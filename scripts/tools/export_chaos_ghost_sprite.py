import argparse
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
ASSET_ID = "chaos_phoebe_chupi_ghost"
RAW_SOURCE = Path(
    "art_sources/generated_raw/characters/chaos_ghost/candidates_v2/"
    "phoebe_chupi_candidate_v2_20260618T142704Z_ig_0aa274d60e47d99f016a33ffdcfb908191af513c162f547599.png"
)
SOURCE_DIR = Path("assets/source/characters/chaos_ghost")
RUNTIME_DIR = Path("assets/textures/characters")
DOCS_DIR = Path("docs/art/characters")
MANIFEST_PATH = SOURCE_DIR / "chaos_ghost_manifest.json"
NATIVE_SIZE = (96, 96)
RUNTIME_SCALE = 4
SAFE_AREA = [96, 96, 1062, 1062]
PROMPT_NOTES = (
    "Selected candidate C from imagegen v2. Reference priority: user screenshot #3 for face and low wide hat, "
    "#1 for cute round eyes, #2 for mischievous thief attitude. Single main sprite only; no expression diffs."
)


def _output_path(output_root: Path | None, relative: Path) -> Path:
    return (output_root if output_root is not None else ROOT) / relative


def _remove_chroma_green(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = pixels[x, y]
            if green > 165 and red < 145 and blue < 145:
                pixels[x, y] = (red, green, blue, 0)
            else:
                pixels[x, y] = (red, green, blue, alpha)
    return rgba


def _crop_to_safe_area(image: Image.Image) -> Image.Image:
    x, y, width, height = SAFE_AREA
    return image.crop((x, y, x + width, y + height))


def _quantize_native(image: Image.Image) -> Image.Image:
    return image.convert("RGBA").quantize(colors=64, method=Image.Quantize.FASTOCTREE).convert("RGBA")


def _checker(size: tuple[int, int], cell: int = 8) -> Image.Image:
    image = Image.new("RGBA", size, (30, 33, 42, 255))
    pixels = image.load()
    for y in range(size[1]):
        for x in range(size[0]):
            if (x // cell + y // cell) % 2 == 0:
                pixels[x, y] = (48, 52, 64, 255)
    return image


def _write_manifest(root: Path, source_path: Path, native_path: Path, runtime_path: Path, contact_path: Path) -> None:
    manifest = {
        "assets": [
            {
                "id": ASSET_ID,
                "source": source_path.relative_to(root).as_posix(),
                "native_output": native_path.relative_to(root).as_posix(),
                "runtime_output": runtime_path.relative_to(root).as_posix(),
                "native_size": list(NATIVE_SIZE),
                "runtime_scale": RUNTIME_SCALE,
                "safe_area": SAFE_AREA,
                "contact_sheet": contact_path.relative_to(root).as_posix(),
                "intended_godot_use": "BarWorkspace hidden chaos ghost thief sprite",
                "prompt_notes": PROMPT_NOTES,
            }
        ]
    }
    manifest_path = root / MANIFEST_PATH
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def export_assets(output_root: Path | None = None) -> None:
    root = output_root if output_root is not None else ROOT
    source_path = root / RAW_SOURCE
    if not source_path.exists():
        raise FileNotFoundError(source_path)

    native_path = _output_path(output_root, SOURCE_DIR / f"{ASSET_ID}.png")
    runtime_path = _output_path(output_root, RUNTIME_DIR / f"{ASSET_ID}.png")
    contact_path = _output_path(output_root, DOCS_DIR / f"{ASSET_ID}_contact_sheet.png")
    for path in [native_path.parent, runtime_path.parent, contact_path.parent]:
        path.mkdir(parents=True, exist_ok=True)

    source = _remove_chroma_green(Image.open(source_path))
    crop = _crop_to_safe_area(source)
    native = crop.resize(NATIVE_SIZE, Image.Resampling.BOX)
    native = _quantize_native(native)
    runtime = native.resize(
        (NATIVE_SIZE[0] * RUNTIME_SCALE, NATIVE_SIZE[1] * RUNTIME_SCALE),
        Image.Resampling.NEAREST,
    )
    native.save(native_path)
    runtime.save(runtime_path)

    preview = _checker((runtime.width + 16, runtime.height + 16), 16)
    preview.alpha_composite(runtime, (8, 8))
    contact_path.parent.mkdir(parents=True, exist_ok=True)
    preview.save(contact_path)
    _write_manifest(root, source_path, native_path, runtime_path, contact_path)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-root", type=Path, default=None)
    args = parser.parse_args()
    export_assets(args.output_root)


if __name__ == "__main__":
    main()
