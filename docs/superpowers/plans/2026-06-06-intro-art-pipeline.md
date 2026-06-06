# Intro Art Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the six approved intro references into five production-ready `320x180` native stills, a deterministic vignette, exact `4x` runtime textures, and a verified Godot intro sequence.

**Architecture:** `prepare_intro_sources.py` owns all reference-to-native transformations and writes outputs only after validating every image in memory. `export_intro_assets.py` only validates native files and performs exact nearest-neighbor `4x` exports. The Python pipeline test verifies file contracts, visual guardrails, JSON runtime references, and atomic failure behavior; existing Godot tests verify the playback scene.

**Tech Stack:** Python 3, Pillow, `unittest`, Godot 4, GDScript, PowerShell.

**Spec:** `docs/superpowers/specs/2026-06-06-intro-art-pipeline-design.md`

---

## File Structure

| Path | Responsibility | Action |
|---|---|---|
| `assets/source/intro/reference/*.png` | Approved high-resolution inputs and continuity master | Keep/add |
| `assets/source/intro/*_native.png` | Five `320x180` production stills and vignette | Generate |
| `assets/source/intro/intro_contact_sheet.png` | Visual review sheet | Generate |
| `assets/textures/intro/*.png` | Five `1280x720` stills and vignette | Generate |
| `scripts/tools/prepare_intro_sources.py` | Reference normalization, grading, quantization, validation, contact sheet | Create |
| `scripts/tools/export_intro_assets.py` | Native validation and exact nearest export | Rewrite |
| `scripts/test/test_intro_asset_pipeline.py` | End-to-end asset contract tests | Rewrite |
| `data/intro.json` | Runtime manifest | Verify only |
| `scripts/test/test_intro_sequence.gd` | Existing playback contract | Verify only |

Do not modify `scripts/ui/intro_sequence.gd`, `scenes/ui/IntroSequence.tscn`, or DayMap handoff code unless runtime verification exposes a concrete defect.

---

### Task 1: Replace The Obsolete Parallax Pipeline Contract

**Files:**
- Modify: `scripts/test/test_intro_asset_pipeline.py`

- [ ] **Step 1: Write the new failing manifest and file-contract tests**

Replace the old `arrival_*` test file with constants and helpers for the five current stills:

```python
from __future__ import annotations

import json
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "intro"
REFERENCE = SOURCE / "reference"
RUNTIME = ROOT / "assets" / "textures" / "intro"
INTRO_DATA = ROOT / "data" / "intro.json"
NATIVE_SIZE = (320, 180)
RUNTIME_SIZE = (1280, 720)
SCALE = 4
STILLS = [
    "intro_descent",
    "intro_hearth_memory",
    "intro_tavern_dark",
    "intro_rusted_key",
    "intro_threshold",
]
REFERENCE_FILES = [*STILLS, "tavern_continuity_master"]


def load_image(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.copy()


class IntroAssetPipelineTest(unittest.TestCase):
    def test_approved_references_exist(self) -> None:
        for name in REFERENCE_FILES:
            path = REFERENCE / f"{name}.png"
            self.assertTrue(path.exists(), f"{path}: missing approved reference")
            image = load_image(path)
            self.assertGreaterEqual(image.width, 1280, f"{name}: reference is too narrow")
            self.assertGreaterEqual(image.height, 720, f"{name}: reference is too short")

    def test_native_and_runtime_files_exist_at_expected_sizes(self) -> None:
        for name in STILLS:
            native = load_image(SOURCE / f"{name}_native.png")
            runtime = load_image(RUNTIME / f"{name}.png")
            self.assertEqual(native.size, NATIVE_SIZE, f"{name}: wrong native size")
            self.assertEqual(runtime.size, RUNTIME_SIZE, f"{name}: wrong runtime size")

    def test_runtime_manifest_uses_the_five_pipeline_textures_in_order(self) -> None:
        data = json.loads(INTRO_DATA.read_text(encoding="utf-8"))
        actual = [beat["image"] for beat in data["beats"]]
        expected = [f"res://assets/textures/intro/{name}.png" for name in STILLS]
        self.assertEqual(actual, expected)
```

- [ ] **Step 2: Run the focused test and confirm RED**

Run:

```powershell
python -m unittest scripts.test.test_intro_asset_pipeline -v
```

Expected: reference test passes; native/runtime tests fail because the new production outputs do not exist.

- [ ] **Step 3: Commit the red test**

```powershell
git add scripts/test/test_intro_asset_pipeline.py
git commit -m "test(intro): define five-still art pipeline contract"
```

---

### Task 2: Implement Deterministic Reference-To-Native Preparation

**Files:**
- Create: `scripts/tools/prepare_intro_sources.py`
- Modify: `scripts/test/test_intro_asset_pipeline.py`

- [ ] **Step 1: Add visual guardrail tests**

Add helpers and tests:

```python
MIN_DARK_PIXELS = 18_000
MIN_COOL_PIXELS = 4_000
MIN_WARM_PIXELS = {
    "intro_descent": 20,
    "intro_hearth_memory": 200,
    "intro_tavern_dark": 0,
    "intro_rusted_key": 10,
    "intro_threshold": 0,
}
MAX_NATIVE_COLORS = 64


def rgba_pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    return list(image.convert("RGBA").getdata())


def color_count(image: Image.Image) -> int:
    colors = image.convert("RGB").getcolors(maxcolors=65536)
    return len(colors) if colors is not None else 65536


def edge_change_ratio(image: Image.Image) -> float:
    rgb = image.convert("RGB")
    pixels = rgb.load()
    changes = 0
    total = 0
    for y in range(rgb.height):
        for x in range(rgb.width - 1):
            total += 1
            changes += pixels[x, y] != pixels[x + 1, y]
    for y in range(rgb.height - 1):
        for x in range(rgb.width):
            total += 1
            changes += pixels[x, y] != pixels[x, y + 1]
    return changes / total


def test_native_stills_match_visual_guardrails(self) -> None:
    for name in STILLS:
        image = load_image(SOURCE / f"{name}_native.png").convert("RGBA")
        pixels = rgba_pixels(image)
        dark = sum(1 for r, g, b, a in pixels if a >= 250 and max(r, g, b) <= 58)
        cool = sum(
            1 for r, g, b, a in pixels
            if a >= 250 and b >= 38 and g >= 36 and b >= r * 1.05 and g >= r * 0.85
        )
        warm = sum(
            1 for r, g, b, a in pixels
            if a >= 250 and r >= 95 and g >= 42 and r >= b * 1.6 and g >= b * 1.1
        )
        self.assertGreaterEqual(dark, MIN_DARK_PIXELS, f"{name}: insufficient dark mass")
        self.assertGreaterEqual(cool, MIN_COOL_PIXELS, f"{name}: insufficient teal depth")
        self.assertGreaterEqual(warm, MIN_WARM_PIXELS[name], f"{name}: missing warm focal accents")
        self.assertLessEqual(color_count(image), MAX_NATIVE_COLORS, f"{name}: too many colors")
        self.assertGreaterEqual(edge_change_ratio(image), 0.08, f"{name}: likely over-smoothed")
```

Add vignette and contact-sheet tests:

```python
def test_vignette_is_native_alpha_art(self) -> None:
    vignette = load_image(SOURCE / "intro_vignette_native.png").convert("RGBA")
    self.assertEqual(vignette.size, NATIVE_SIZE)
    alpha = vignette.getchannel("A")
    self.assertEqual(alpha.getextrema()[0], 0)
    self.assertGreater(alpha.getextrema()[1], 0)
    self.assertLess(alpha.getpixel((160, 90)), 40)
    self.assertGreater(alpha.getpixel((0, 0)), 80)


def test_contact_sheet_contains_all_five_native_stills(self) -> None:
    sheet = load_image(SOURCE / "intro_contact_sheet.png")
    self.assertEqual(sheet.size, (960, 360))
```

- [ ] **Step 2: Run tests and confirm the new tests fail**

Run:

```powershell
python -m unittest scripts.test.test_intro_asset_pipeline -v
```

Expected: missing native stills, vignette, and contact sheet.

- [ ] **Step 3: Create `prepare_intro_sources.py`**

Implement these exact boundaries:

```python
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "intro"
REFERENCE = SOURCE / "reference"
NATIVE_SIZE = (320, 180)
STILLS = [
    "intro_descent",
    "intro_hearth_memory",
    "intro_tavern_dark",
    "intro_rusted_key",
    "intro_threshold",
]
MAX_COLORS = 56


def load_reference(name: str) -> Image.Image:
    path = REFERENCE / f"{name}.png"
    if not path.exists():
        raise FileNotFoundError(f"Missing approved intro reference: {path}")
    with Image.open(path) as image:
        return image.convert("RGB")


def normalize_reference(image: Image.Image) -> Image.Image:
    intermediate = ImageOps.fit(
        image,
        (640, 360),
        method=Image.Resampling.LANCZOS,
        centering=(0.5, 0.5),
    )
    intermediate = intermediate.filter(ImageFilter.GaussianBlur(0.35))
    return intermediate.resize(NATIVE_SIZE, Image.Resampling.LANCZOS)


def grade_native(image: Image.Image, name: str) -> Image.Image:
    rgb = ImageEnhance.Contrast(image).enhance(1.14)
    rgb = ImageEnhance.Color(rgb).enhance(0.88)
    if name in {"intro_tavern_dark", "intro_threshold"}:
        rgb = ImageEnhance.Brightness(rgb).enhance(1.12)
    elif name == "intro_rusted_key":
        rgb = ImageEnhance.Brightness(rgb).enhance(1.06)
    pixels = rgb.load()
    for y in range(rgb.height):
        for x in range(rgb.width):
            red, green, blue = pixels[x, y]
            cool = blue >= red * 1.05 and green >= red * 0.82
            warm = red >= blue * 1.45 and green >= blue * 1.05
            if cool:
                pixels[x, y] = (min(red, 82), min(150, int(green * 1.04)), min(168, int(blue * 1.06)))
            elif warm:
                pixels[x, y] = (min(210, int(red * 1.04)), min(145, int(green * 1.02)), min(blue, 92))
    return rgb


def quantize_native(image: Image.Image) -> Image.Image:
    return image.quantize(
        colors=MAX_COLORS,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGBA")


def build_native(name: str) -> Image.Image:
    return quantize_native(grade_native(normalize_reference(load_reference(name)), name))


def build_vignette() -> Image.Image:
    alpha = Image.new("L", NATIVE_SIZE, 0)
    pixels = alpha.load()
    center_x = (NATIVE_SIZE[0] - 1) / 2
    center_y = (NATIVE_SIZE[1] - 1) / 2
    for y in range(NATIVE_SIZE[1]):
        for x in range(NATIVE_SIZE[0]):
            dx = abs(x - center_x) / center_x
            dy = abs(y - center_y) / center_y
            distance = min(1.0, (dx * dx * 0.58 + dy * dy * 0.42) ** 0.5)
            pixels[x, y] = round(max(0.0, (distance - 0.42) / 0.58) ** 1.7 * 150)
    vignette = Image.new("RGBA", NATIVE_SIZE, (0, 8, 12, 0))
    vignette.putalpha(alpha)
    return vignette


def build_contact_sheet(stills: dict[str, Image.Image]) -> Image.Image:
    sheet = Image.new("RGB", (960, 360), (2, 12, 16))
    positions = [(0, 0), (320, 0), (640, 0), (160, 180), (480, 180)]
    for name, position in zip(STILLS, positions):
        sheet.paste(stills[name].convert("RGB"), position)
    return sheet
```

Add validation before disk writes:

```python
def validate_still(name: str, image: Image.Image) -> None:
    if image.size != NATIVE_SIZE:
        raise ValueError(f"{name}: expected {NATIVE_SIZE}, got {image.size}")
    colors = image.convert("RGB").getcolors(maxcolors=65536)
    if colors is None or not 24 <= len(colors) <= 64:
        raise ValueError(f"{name}: invalid native color count")


def prepare_outputs() -> dict[Path, Image.Image]:
    stills = {name: build_native(name) for name in STILLS}
    for name, image in stills.items():
        validate_still(name, image)
    vignette = build_vignette()
    return {
        **{SOURCE / f"{name}_native.png": image for name, image in stills.items()},
        SOURCE / "intro_vignette_native.png": vignette,
        SOURCE / "intro_contact_sheet.png": build_contact_sheet(stills),
    }


def main() -> None:
    outputs = prepare_outputs()
    SOURCE.mkdir(parents=True, exist_ok=True)
    for path, image in outputs.items():
        image.save(path)
        print(f"prepared {path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run preparation**

Run:

```powershell
python scripts/tools/prepare_intro_sources.py
```

Expected: five native stills, one vignette, and one contact sheet are written.

- [ ] **Step 5: Run focused tests**

Run:

```powershell
python -m unittest scripts.test.test_intro_asset_pipeline -v
```

Expected: preparation and visual tests pass; runtime export tests still fail.

- [ ] **Step 6: Visually inspect native outputs**

Open:

```text
assets/source/intro/intro_contact_sheet.png
assets/source/intro/intro_descent_native.png
assets/source/intro/intro_hearth_memory_native.png
assets/source/intro/intro_tavern_dark_native.png
assets/source/intro/intro_rusted_key_native.png
assets/source/intro/intro_threshold_native.png
```

Reject and adjust only named grading constants if silhouettes collapse, teal becomes cyan, amber floods the frame, or dark scenes lose their architecture.

- [ ] **Step 7: Commit preparation pipeline and native outputs**

```powershell
git add scripts/tools/prepare_intro_sources.py scripts/test/test_intro_asset_pipeline.py assets/source/intro
git commit -m "feat(intro): prepare native cinematic stills"
```

---

### Task 3: Rewrite Runtime Export As Exact Nearest Scaling

**Files:**
- Modify: `scripts/tools/export_intro_assets.py`
- Modify: `scripts/test/test_intro_asset_pipeline.py`

- [ ] **Step 1: Add exact export tests**

Add:

```python
def test_runtime_stills_are_exact_nearest_exports(self) -> None:
    for name in [*STILLS, "intro_vignette"]:
        native = load_image(SOURCE / f"{name}_native.png")
        runtime = load_image(RUNTIME / f"{name}.png")
        expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
        self.assertEqual(runtime.size, RUNTIME_SIZE)
        self.assertEqual(runtime.mode, expected.mode)
        self.assertEqual(runtime.tobytes(), expected.tobytes(), f"{name}: not exact nearest")
```

- [ ] **Step 2: Run test and confirm RED**

Run:

```powershell
python -m unittest scripts.test.test_intro_asset_pipeline -v
```

Expected: runtime files are missing.

- [ ] **Step 3: Replace `export_intro_assets.py`**

```python
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


def load_source(name: str) -> Image.Image:
    path = SOURCE / f"{name}_native.png"
    if not path.exists():
        raise FileNotFoundError(f"Missing native intro source: {path}")
    with Image.open(path) as image:
        return image.copy()


def build_runtime(name: str, source: Image.Image) -> Image.Image:
    if source.size != NATIVE_SIZE:
        raise ValueError(f"{name}: expected {NATIVE_SIZE}, got {source.size}")
    runtime = source.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
    expected = source.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
    if runtime.mode != expected.mode or runtime.tobytes() != expected.tobytes():
        raise ValueError(f"{name}: runtime is not an exact nearest-neighbor export")
    return runtime


def main() -> None:
    outputs = {name: build_runtime(name, load_source(name)) for name in NAMES}
    RUNTIME.mkdir(parents=True, exist_ok=True)
    for name, image in outputs.items():
        path = RUNTIME / f"{name}.png"
        image.save(path)
        print(f"{name}: {NATIVE_SIZE} -> {RUNTIME_SIZE}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run export and tests**

Run:

```powershell
python scripts/tools/export_intro_assets.py
python -m unittest scripts.test.test_intro_asset_pipeline -v
```

Expected: all Python tests pass.

- [ ] **Step 5: Commit runtime export**

```powershell
git add scripts/tools/export_intro_assets.py scripts/test/test_intro_asset_pipeline.py assets/textures/intro
git commit -m "feat(intro): export exact-nearest runtime stills"
```

---

### Task 4: Add Atomic Failure Regression Coverage

**Files:**
- Modify: `scripts/tools/prepare_intro_sources.py`
- Modify: `scripts/tools/export_intro_assets.py`
- Modify: `scripts/test/test_intro_asset_pipeline.py`

- [ ] **Step 1: Add late-validation failure tests**

Add these imports:

```python
from hashlib import sha256
import shutil
import subprocess
import sys
import tempfile
```

Add constants and helpers:

```python
TOOLS = ROOT / "scripts" / "tools"
NATIVE_NAMES = [*STILLS, "intro_vignette"]


def file_hash(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


def seed_destinations(paths: list[Path]) -> dict[Path, str]:
    hashes: dict[Path, str] = {}
    for index, path in enumerate(paths):
        path.parent.mkdir(parents=True, exist_ok=True)
        Image.new("RGBA", (4, 4), (index + 1, 2, 3, 255)).save(path)
        hashes[path] = file_hash(path)
    return hashes


def assert_destinations_unchanged(
    test_case: unittest.TestCase,
    hashes: dict[Path, str],
) -> None:
    for path, expected_hash in hashes.items():
        test_case.assertEqual(
            file_hash(path),
            expected_hash,
            f"{path.name}: replaced before all validation completed",
        )
```

Add the complete tests inside `IntroAssetPipelineTest`:

```python
    def test_prepare_does_not_replace_outputs_when_validation_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            tool = root / "scripts" / "tools" / "prepare_intro_sources.py"
            tool.parent.mkdir(parents=True)
            shutil.copy2(TOOLS / tool.name, tool)

            reference = root / "assets" / "source" / "intro" / "reference"
            reference.mkdir(parents=True)
            for name in REFERENCE_FILES:
                shutil.copy2(REFERENCE / f"{name}.png", reference)
            Image.new("RGB", (1672, 941), (0, 0, 0)).save(
                reference / "intro_threshold.png"
            )

            source = root / "assets" / "source" / "intro"
            destinations = [
                *[source / f"{name}_native.png" for name in NATIVE_NAMES],
                source / "intro_contact_sheet.png",
            ]
            hashes = seed_destinations(destinations)

            result = subprocess.run(
                [sys.executable, str(tool)],
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(
                result.returncode,
                0,
                "prepare accepted a blank approved reference",
            )
            assert_destinations_unchanged(self, hashes)

    def test_export_does_not_replace_outputs_when_validation_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            tool = root / "scripts" / "tools" / "export_intro_assets.py"
            tool.parent.mkdir(parents=True)
            shutil.copy2(TOOLS / tool.name, tool)

            source = root / "assets" / "source" / "intro"
            source.mkdir(parents=True)
            for name in NATIVE_NAMES:
                shutil.copy2(SOURCE / f"{name}_native.png", source)
            Image.new("RGBA", (3, 3), (0, 0, 0, 255)).save(
                source / "intro_threshold_native.png"
            )

            runtime = root / "assets" / "textures" / "intro"
            destinations = [runtime / f"{name}.png" for name in NATIVE_NAMES]
            hashes = seed_destinations(destinations)

            result = subprocess.run(
                [sys.executable, str(tool)],
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(
                result.returncode,
                0,
                "export accepted a malformed native source",
            )
            assert_destinations_unchanged(self, hashes)
```

- [ ] **Step 2: Run tests and confirm RED if scripts write incrementally**

Run:

```powershell
python -m unittest scripts.test.test_intro_asset_pipeline -v
```

- [ ] **Step 3: Keep all generated images in dictionaries until every validation passes**

`prepare_outputs()` and the export output dictionary must complete before either script creates directories or calls `save`.

- [ ] **Step 4: Run tests until GREEN**

Run:

```powershell
python -m unittest scripts.test.test_intro_asset_pipeline -v
```

Expected: all tests pass, including both non-replacement tests.

- [ ] **Step 5: Commit atomicity coverage**

```powershell
git add scripts/tools/prepare_intro_sources.py scripts/tools/export_intro_assets.py scripts/test/test_intro_asset_pipeline.py
git commit -m "test(intro): protect approved asset outputs on failure"
```

---

### Task 5: Import And Runtime Verification

**Files:**
- Verify: `data/intro.json`
- Verify: `scripts/ui/intro_sequence.gd`
- Verify: `scenes/ui/IntroSequence.tscn`
- Verify: `scripts/test/test_intro_sequence.gd`

- [ ] **Step 1: Refresh Godot imports**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path 'D:\game\tavern-manager' --editor --quit
```

Expected: no `SCRIPT ERROR`, no missing texture import errors.

- [ ] **Step 2: Run intro and DayMap regression scenes**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path 'D:\game\tavern-manager' 'res://scenes/test/test_intro_sequence.tscn'
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path 'D:\game\tavern-manager' 'res://scenes/test/test_day_map_system.tscn'
```

Expected: intro prints `[TEST-INTRO] ALL PASS`; inspect DayMap output for `FAIL`, `SCRIPT ERROR`, or new errors rather than relying only on exit code.

- [ ] **Step 3: Run the complete Python asset pipeline again**

Run:

```powershell
python scripts/tools/prepare_intro_sources.py
python scripts/tools/export_intro_assets.py
python -m unittest scripts.test.test_intro_asset_pipeline -v
```

Expected: deterministic regeneration and all tests pass.

- [ ] **Step 4: Perform GUI visual review**

Run TitleScreen → New Game and verify:

- all five stills appear in manifest order;
- letterbox and narration remain readable;
- no Ken Burns movement exposes an image edge;
- `intro_hearth_memory` reads warm but not orange-washed;
- `intro_tavern_dark` and `intro_threshold` retain midtone structure;
- the key remains readable;
- transitions pass through black cleanly;
- skip and DayMap match-cut still work.

- [ ] **Step 5: Commit any import metadata required by the repository**

```powershell
git add assets/source/intro assets/textures/intro
git commit -m "chore(intro): finalize cinematic art imports"
```

Skip the commit if Godot creates no tracked metadata changes.

---

### Task 6: Final Verification And Cleanup

**Files:**
- Review: all files changed by Tasks 1-5

- [ ] **Step 1: Confirm obsolete parallax names are absent**

Run:

```powershell
rg -n "arrival_dungeon_overlook|arrival_tavern_exterior|arrival_tavern_door|_back_ref|_front_ref" scripts/tools/export_intro_assets.py scripts/test/test_intro_asset_pipeline.py assets/source/intro assets/textures/intro
```

Expected: no matches.

- [ ] **Step 2: Confirm the intended references and outputs**

Run:

```powershell
Get-ChildItem assets/source/intro/reference -File | Sort-Object Name
Get-ChildItem assets/source/intro -File | Sort-Object Name
Get-ChildItem assets/textures/intro -File | Sort-Object Name
```

Expected: six references, five native stills plus vignette/contact sheet, and five runtime stills plus vignette.

- [ ] **Step 3: Inspect repository diff**

Run:

```powershell
git status --short
git diff --check
git log -6 --oneline
```

Expected: only intentional intro pipeline changes plus the user's pre-existing `assets/image1.png` and `assets/image2.png` if they remain untracked.

- [ ] **Step 4: Record final verification evidence**

Report the exact Python test count, Godot intro result, DayMap result, generated asset paths, and any remaining GUI-only visual risk.
