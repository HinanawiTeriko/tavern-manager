from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "workspace"
OUTPUT = ROOT / "assets" / "textures" / "workspace"
NAMES = ["barrel", "pot", "grill", "spoon"]

OUTPUT.mkdir(parents=True, exist_ok=True)
for name in NAMES:
    source = Image.open(SOURCE / f"{name}_native.png").convert("RGBA")
    runtime = source.resize((source.width * 2, source.height * 2), Image.Resampling.NEAREST)
    runtime.save(OUTPUT / f"{name}.png")
    print(f"{name}: {source.size} -> {runtime.size}")
