from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "intro"
RUNTIME = ROOT / "assets" / "textures" / "intro"
NATIVE_SIZE = (320, 180)
RUNTIME_SIZE = (1280, 720)
VIGNETTE_MIN_VISIBLE_ALPHA = 96
VIGNETTE_INTERMEDIATE_ALPHA_RANGE = range(16, 240)
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
            alpha_range = image.getchannel("A").getextrema()
            if alpha_range != (255, 255):
                raise ValueError(
                    f"{name}: still must be fully opaque, "
                    f"alpha range is {alpha_range}"
                )
        return

    if "A" not in image.getbands():
        raise ValueError(f"{name}: vignette must include an alpha channel")
    alpha = image.getchannel("A")
    minimum_alpha, maximum_alpha = alpha.getextrema()
    if minimum_alpha != 0:
        raise ValueError(
            f"{name}: vignette must contain transparent pixels, "
            f"minimum alpha is {minimum_alpha}"
        )
    if maximum_alpha < VIGNETTE_MIN_VISIBLE_ALPHA:
        raise ValueError(
            f"{name}: vignette maximum alpha must be at least "
            f"{VIGNETTE_MIN_VISIBLE_ALPHA}, got {maximum_alpha}"
        )
    alpha_histogram = alpha.histogram()
    if not any(alpha_histogram[value] for value in VIGNETTE_INTERMEDIATE_ALPHA_RANGE):
        lower = VIGNETTE_INTERMEDIATE_ALPHA_RANGE.start
        upper = VIGNETTE_INTERMEDIATE_ALPHA_RANGE.stop - 1
        raise ValueError(
            f"{name}: vignette must contain intermediate alpha "
            f"in the range {lower}..{upper}"
        )


def build_runtime(name: str, native: Image.Image) -> Image.Image:
    runtime = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
    if runtime.size != RUNTIME_SIZE:
        raise RuntimeError(
            f"{name}: runtime image must be {RUNTIME_SIZE}, got {runtime.size}"
        )
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
