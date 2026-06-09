from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "daymap"
SOURCE_MARKERS = SOURCE / "markers"
RUNTIME = ROOT / "assets" / "textures" / "daymap"
RUNTIME_MARKERS = RUNTIME / "markers"
SCALE = 4
BG_SIZE = (320, 180)
FULL_MAP_SIZE = (640, 360)
MARKER_SIZE = (24, 24)
MARKER_STATE_SIZE = (32, 32)
RUNTIME_BG_SIZE = (1280, 720)
RUNTIME_FULL_MAP_SIZE = (2560, 1440)
RUNTIME_MARKER_SIZE = (96, 96)
RUNTIME_MARKER_STATE_SIZE = (128, 128)
MAX_MARKER_COLORS = 10

MARKERS = [
    "home",
    "mushroom_forest",
    "dark_river",
    "grape_trellis",
    "mill_farm",
    "mercenary_board",
    "abandoned_mine",
    "guild_counter",
]
MARKER_STATES = [
    "marker_base",
    "marker_hover_ring",
    "marker_selected_ring",
    "marker_reveal_burst",
]


def visible_pixel_count(image: Image.Image) -> int:
    alpha = image.convert("RGBA").getchannel("A")
    return sum(alpha.histogram()[1:])


def color_count(image: Image.Image) -> int:
    colors = image.convert("RGBA").getcolors(maxcolors=65536)
    return len(colors) if colors is not None else 65536


def source_path(name: str) -> Path:
    if name == "daymap_bg":
        return SOURCE / "daymap_bg_native.png"
    if name == "daymap_full":
        return SOURCE / "daymap_full_native.png"
    return SOURCE_MARKERS / f"{name}_native.png"


def runtime_path(name: str) -> Path:
    if name == "daymap_bg":
        return RUNTIME / "daymap_bg.png"
    if name == "daymap_full":
        return RUNTIME / "daymap_full.png"
    return RUNTIME_MARKERS / f"{name}.png"


def expected_source_size(name: str) -> tuple[int, int]:
    if name == "daymap_bg":
        return BG_SIZE
    if name == "daymap_full":
        return FULL_MAP_SIZE
    if name in MARKER_STATES:
        return MARKER_STATE_SIZE
    return MARKER_SIZE


def expected_runtime_size(name: str) -> tuple[int, int]:
    if name == "daymap_bg":
        return RUNTIME_BG_SIZE
    if name == "daymap_full":
        return RUNTIME_FULL_MAP_SIZE
    if name in MARKER_STATES:
        return RUNTIME_MARKER_STATE_SIZE
    return RUNTIME_MARKER_SIZE


def load_source(name: str) -> Image.Image:
    path = source_path(name)
    if not path.exists():
        raise FileNotFoundError(f"Missing native DayMap source: {path}. Run scripts/tools/prepare_daymap_sources.py first.")
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def validate_source(name: str, image: Image.Image) -> None:
    expected_size = expected_source_size(name)
    if image.size != expected_size:
        raise ValueError(f"{name}: expected {expected_size}, got {image.size}")
    alpha_extrema = image.getchannel("A").getextrema()
    if name == "daymap_bg" or name == "daymap_full":
        if alpha_extrema[0] < 250:
            raise ValueError(f"{name}: expected opaque native background")
        return
    if alpha_extrema[0] != 0 or alpha_extrema[1] == 0:
        raise ValueError(f"{name}: expected transparent and visible pixels")
    if visible_pixel_count(image) < 20:
        raise ValueError(f"{name}: too few visible pixels")
    if name in MARKERS and color_count(image) > MAX_MARKER_COLORS:
        raise ValueError(f"{name}: too many native colors")


def export_runtime(name: str, source: Image.Image) -> Image.Image:
    target_size = expected_runtime_size(name)
    runtime = source.resize(target_size, Image.Resampling.NEAREST)
    expected = source.resize(target_size, Image.Resampling.NEAREST)
    if runtime.size != target_size:
        raise ValueError(f"{name}: wrong runtime size {runtime.size}")
    if runtime.mode != expected.mode or runtime.tobytes() != expected.tobytes():
        raise ValueError(f"{name}: runtime is not an exact nearest-neighbor export")
    return runtime


def main() -> None:
    names = ["daymap_bg", "daymap_full", *MARKERS, *MARKER_STATES]
    RUNTIME.mkdir(parents=True, exist_ok=True)
    RUNTIME_MARKERS.mkdir(parents=True, exist_ok=True)
    for name in names:
        source = load_source(name)
        validate_source(name, source)
        runtime = export_runtime(name, source)
        runtime.save(runtime_path(name))
        print(f"{name}: {source.size} -> {runtime.size}")


if __name__ == "__main__":
    main()
