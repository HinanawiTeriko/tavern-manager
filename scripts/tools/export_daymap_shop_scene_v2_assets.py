from pathlib import Path
import json

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "daymap" / "shop_scene_v2"
MANIFEST_PATH = SOURCE / "reference" / "shop_scene_v2_manifest.json"
RUNTIME = ROOT / "assets" / "textures" / "daymap" / "shop_scene_v2"
SCALE = 4


def load_manifest_assets() -> dict:
    if not MANIFEST_PATH.exists():
        raise FileNotFoundError(f"Missing shop scene v2 manifest: {MANIFEST_PATH}")
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    return manifest["assets"]


def load_native(name: str) -> Image.Image:
    path = SOURCE / f"{name}_native.png"
    if not path.exists():
        raise FileNotFoundError(f"Missing shop scene v2 native source: {path}")
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def validate_native(name: str, image: Image.Image, size: tuple[int, int], transparent: bool) -> None:
    if image.size != size:
        raise ValueError(f"{name}: expected native size {size}, got {image.size}")
    alpha_min, alpha_max = image.getchannel("A").getextrema()
    if transparent:
        if alpha_min != 0 or alpha_max == 0:
            raise ValueError(f"{name}: transparent asset needs both transparent and visible pixels")
    else:
        if alpha_min != 255 or alpha_max != 255:
            raise ValueError(f"{name}: opaque asset must have full alpha")


def nearest_export(native: Image.Image) -> Image.Image:
    return native.resize((native.width * SCALE, native.height * SCALE), Image.Resampling.NEAREST)


def main() -> None:
    outputs: dict[str, Image.Image] = {}
    for name, spec in load_manifest_assets().items():
        size = tuple(spec["native_size"])
        transparent = bool(spec["transparent"])
        native = load_native(name)
        validate_native(name, native, size, transparent)
        runtime = nearest_export(native)
        expected = native.resize(runtime.size, Image.Resampling.NEAREST)
        if runtime.tobytes() != expected.tobytes():
            raise RuntimeError(f"{name}: runtime is not exact nearest export")
        outputs[name] = runtime

    RUNTIME.mkdir(parents=True, exist_ok=True)
    for name, runtime in outputs.items():
        path = RUNTIME / f"{name}.png"
        runtime.save(path)
        print(f"{name}: {runtime.size}")


if __name__ == "__main__":
    main()
