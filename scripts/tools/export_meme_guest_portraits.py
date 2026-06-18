import argparse
import json
from pathlib import Path

from PIL import Image


def _resolve_output_path(output_root: Path | None, root: Path, relative_path: str) -> Path:
    base = output_root if output_root is not None else root
    return base / relative_path


def _remove_chroma_green(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = pixels[x, y]
            if green > 170 and red < 120 and blue < 140:
                pixels[x, y] = (red, green, blue, 0)
            else:
                pixels[x, y] = (red, green, blue, alpha)
    return rgba


def _crop_to_safe_square(image: Image.Image, safe_area: list[int]) -> Image.Image:
    x, y, width, height = [int(value) for value in safe_area]
    if width <= 0 or height <= 0:
        raise ValueError(f"Invalid safe area: {safe_area}")
    crop = image.crop((x, y, x + width, y + height))
    square = Image.new("RGBA", (max(width, height), max(width, height)), (0, 0, 0, 0))
    square.alpha_composite(crop, ((square.width - width) // 2, (square.height - height) // 2))
    return square


def _quantize_for_pixel_art(image: Image.Image) -> Image.Image:
    return image.convert("RGBA").quantize(colors=48, method=Image.Quantize.FASTOCTREE).convert("RGBA")


def export_manifest(manifest_path: Path, root: Path, output_root: Path | None = None) -> None:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for asset in manifest["assets"]:
        source = root / asset["source"]
        if not source.exists():
            raise FileNotFoundError(source)
        native_path = _resolve_output_path(output_root, root, asset["native_output"])
        runtime_path = _resolve_output_path(output_root, root, asset["runtime_output"])
        native_path.parent.mkdir(parents=True, exist_ok=True)
        runtime_path.parent.mkdir(parents=True, exist_ok=True)

        source_image = _remove_chroma_green(Image.open(source))
        safe_square = _crop_to_safe_square(source_image, asset["safe_area"])
        native_size = tuple(int(value) for value in asset["native_size"])
        native = safe_square.resize(native_size, Image.Resampling.BOX)
        native = _quantize_for_pixel_art(native)
        native.save(native_path)

        scale = int(asset["runtime_scale"])
        runtime = native.resize((native.width * scale, native.height * scale), Image.Resampling.NEAREST)
        runtime.save(runtime_path)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--manifest",
        default="art_sources/generated_raw/characters/meme_guests/meme_guest_portraits_manifest.json",
    )
    parser.add_argument("--root", default=".")
    args = parser.parse_args()
    export_manifest(Path(args.manifest), Path(args.root).resolve())


if __name__ == "__main__":
    main()
