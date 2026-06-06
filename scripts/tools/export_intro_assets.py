from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "intro"
RUNTIME = ROOT / "assets" / "textures" / "intro"
NATIVE_SIZE = (320, 180)
RUNTIME_SIZE = (1280, 720)
NAMES = [
    "intro_descent",
    "intro_hearth_memory",
    "intro_tavern_dark",
    "intro_rusted_key",
    "intro_threshold",
    "intro_vignette",
]
STILLS = set(NAMES[:-1])


def load_source(name: str) -> Image.Image:
    path = SOURCE / f"{name}_native.png"
    if not path.exists():
        raise FileNotFoundError(f"{path}: missing native intro source")
    with Image.open(path) as image:
        return image.copy()


def validate_source(name: str, image: Image.Image) -> None:
    if image.size != NATIVE_SIZE:
        raise ValueError(
            f"{name}: native source must be {NATIVE_SIZE}, got {image.size}"
        )

    if name in STILLS:
        if "A" in image.getbands():
            minimum_alpha, _ = image.getchannel("A").getextrema()
            if minimum_alpha < 250:
                raise ValueError(
                    f"{name}: still must be effectively opaque, "
                    f"minimum alpha is {minimum_alpha}"
                )
        return

    if "A" not in image.getbands():
        raise ValueError(f"{name}: vignette must include an alpha channel")
    minimum_alpha, maximum_alpha = image.getchannel("A").getextrema()
    if minimum_alpha != 0 or maximum_alpha == 0:
        raise ValueError(
            f"{name}: vignette must contain transparent and visible pixels, "
            f"alpha range is {(minimum_alpha, maximum_alpha)}"
        )


def build_runtime(name: str, native: Image.Image) -> Image.Image:
    runtime = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
    expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
    if (
        runtime.size != RUNTIME_SIZE
        or runtime.mode != expected.mode
        or runtime.tobytes() != expected.tobytes()
    ):
        raise RuntimeError(f"{name}: runtime image is not an exact nearest export")
    return runtime


def main() -> None:
    sources = {name: load_source(name) for name in NAMES}
    for name, image in sources.items():
        validate_source(name, image)

    outputs = {
        name: build_runtime(name, image)
        for name, image in sources.items()
    }

    RUNTIME.mkdir(parents=True, exist_ok=True)
    for name, image in outputs.items():
        path = RUNTIME / f"{name}.png"
        image.save(path)
        print(f"{name}: {NATIVE_SIZE} -> {RUNTIME_SIZE} nearest")


if __name__ == "__main__":
    main()
