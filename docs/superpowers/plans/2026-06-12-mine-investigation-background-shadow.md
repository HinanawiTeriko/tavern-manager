# Mine Investigation Background Shadow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an AI-sourced native-pixel abandoned mine background and AI-sourced unified contact shadow so the existing mine investigation item art reads as grounded inside the cave.

**Architecture:** Keep raw AI art under `art_sources/generated_raw/`, normalize approved references into native sources under `assets/source/investigation/mine_background/`, and export Godot runtime textures under `assets/ui/generated/investigation/mine_background/` by exact `4x` nearest-neighbor scaling. Preserve `MineInvestigation` gameplay and node contracts by adding a visual-only `BackgroundArt` node while keeping `Background` and `BloodTrail`, and extend `MineItem` with a top-level `ShadowVisual` only for mapped production items.

**Tech Stack:** Godot 4.6.3, GDScript, scene `.tscn` resources, Python 3, Pillow, `unittest`, built-in AI image generation, exact nearest-neighbor PNG export.

---

## Scope Check

The approved spec covers one bounded visual surface: `scenes/ui/MineInvestigation.tscn` background art plus `MineItem` contact shadows. It does not include observation UI, leave button styling, DayMap, DocumentOverlay, location data, investigation logic, save/load, economy, or simulation behavior. This is one testable project because the background, shadow asset, scene hookup, and visual contracts all support the same mine investigation surface.

## File Structure

Create:

- `art_sources/generated_raw/mine_investigation_background/mine_background_reference_v1.png`  
  Raw AI-generated mine background source. Runtime Godot files must never reference this file.
- `art_sources/generated_raw/mine_investigation_background/mine_background_prompt_v1.txt`  
  Exact prompt used to generate the background reference.
- `art_sources/generated_raw/mine_investigation_background/mine_item_shadow_source_v1.png`  
  Raw AI-generated contact shadow source on a removable chroma background.
- `art_sources/generated_raw/mine_investigation_background/mine_item_shadow_prompt_v1.txt`  
  Exact prompt used to generate the shadow source.
- `assets/source/investigation/mine_background/reference/mine_background_reference_v1.png`  
  Stable background reference normalized from raw AI output.
- `assets/source/investigation/mine_background/reference/mine_item_shadow_source_v1.png`  
  Stable shadow reference normalized from raw AI output.
- `assets/source/investigation/mine_background/mine_background_manifest.json`  
  Manifest for the background and shadow source/runtime contract.
- `assets/source/investigation/mine_background/mine_background_native.png`  
  `320x180` native-pixel background source.
- `assets/source/investigation/mine_background/mine_item_shadow_native.png`  
  `40x14` native-pixel shadow source.
- `assets/ui/generated/investigation/mine_background/mine_background.png`  
  `1280x720` runtime background texture exported from native by exact `4x` nearest.
- `assets/ui/generated/investigation/mine_background/mine_item_shadow.png`  
  `160x56` runtime shadow texture exported from native by exact `4x` nearest.
- `docs/art/mine_investigation_background_contact_sheet.png`  
  Review sheet showing raw reference, native/runtime previews, shadow, and item overlay preview.
- `scripts/tools/prepare_mine_investigation_background_sources.py`  
  Copies approved raw AI outputs into stable references and writes the manifest.
- `scripts/tools/export_mine_investigation_background_assets.py`  
  Builds native/runtime textures and contact sheet from the manifest.
- `scripts/test/test_mine_investigation_background_pipeline.py`  
  Python asset pipeline tests.
- `scripts/test/test_mine_background_scene_contract.gd`  
  Godot scene contract test for background hookup.
- `scenes/test/test_mine_background_scene_contract.tscn`  
  Test scene for the background scene contract.

Modify:

- `scripts/test/test_mine_item_visual_contract.gd`  
  Add assertions for `ShadowVisual` on production items and no forced shadow on fallback items.
- `scripts/ui/components/mine_item.gd`  
  Add `mine_item_shadow` loading, `ShadowVisual` creation, and non-rotating shadow transform updates. Preserve `setup()` signature, `Shape`, `Visual`, `Label`, collision sizing, and legacy fallback behavior.
- `scenes/ui/MineInvestigation.tscn`  
  Add a `BackgroundArt` Sprite2D using the runtime background, keep `Background`, hide `BloodTrail`, and leave `World`, `DragCtrl`, and `UI` paths unchanged.

Do not modify:

- `scripts/ui/mine_investigation.gd`
- `scripts/ui/day_map_view.gd`
- `scripts/game_manager.gd`
- `data/locations.json`
- `scripts/ui/document_overlay.gd`
- `ObservationLabel`, `HintLabel`, or `LeaveButton` behavior and styling

Project note:

- `docs/pixel-ui/` exists in this checkout but contains no readable files. Use `docs/art_pipeline.md`, the title pipeline, and the existing mine item pipeline as the active local art pipeline references.

---

### Task 1: Add the Failing Background Pipeline Test

**Files:**
- Create: `scripts/test/test_mine_investigation_background_pipeline.py`

- [ ] **Step 1: Create the Python asset pipeline test**

Create `scripts/test/test_mine_investigation_background_pipeline.py` with this content:

```python
from __future__ import annotations

import json
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = ROOT / "art_sources" / "generated_raw" / "mine_investigation_background"
RAW_BACKGROUND = RAW_DIR / "mine_background_reference_v1.png"
RAW_BACKGROUND_PROMPT = RAW_DIR / "mine_background_prompt_v1.txt"
RAW_SHADOW = RAW_DIR / "mine_item_shadow_source_v1.png"
RAW_SHADOW_PROMPT = RAW_DIR / "mine_item_shadow_prompt_v1.txt"
SOURCE = ROOT / "assets" / "source" / "investigation" / "mine_background"
REFERENCE_BACKGROUND = SOURCE / "reference" / "mine_background_reference_v1.png"
REFERENCE_SHADOW = SOURCE / "reference" / "mine_item_shadow_source_v1.png"
MANIFEST = SOURCE / "mine_background_manifest.json"
BACKGROUND_NATIVE = SOURCE / "mine_background_native.png"
SHADOW_NATIVE = SOURCE / "mine_item_shadow_native.png"
RUNTIME = ROOT / "assets" / "ui" / "generated" / "investigation" / "mine_background"
BACKGROUND_RUNTIME = RUNTIME / "mine_background.png"
SHADOW_RUNTIME = RUNTIME / "mine_item_shadow.png"
CONTACT_SHEET = ROOT / "docs" / "art" / "mine_investigation_background_contact_sheet.png"
SCALE = 4
BACKGROUND_NATIVE_SIZE = (320, 180)
BACKGROUND_RUNTIME_SIZE = (1280, 720)
SHADOW_NATIVE_SIZE = (40, 14)
SHADOW_RUNTIME_SIZE = (160, 56)


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    rgba = image.convert("RGBA")
    if hasattr(rgba, "get_flattened_data"):
        return list(rgba.get_flattened_data())
    return list(rgba.getdata())


def color_count(image: Image.Image) -> int:
    colors = image.convert("RGBA").getcolors(maxcolors=65536)
    return len(colors) if colors is not None else 65536


def visible_pixel_count(image: Image.Image) -> int:
    alpha = image.convert("RGBA").getchannel("A")
    return sum(alpha.histogram()[1:])


def chroma_fringe_pixels(image: Image.Image) -> int:
    count = 0
    for red, green, blue, alpha in pixels(image):
        if alpha == 0:
            continue
        if red >= 10 and blue >= 10 and blue >= red * 0.70 and red >= blue * 0.50 and green <= min(red, blue) * 0.45:
            count += 1
    return count


class MineInvestigationBackgroundPipelineTest(unittest.TestCase):
    def test_ai_sources_and_prompts_are_retained(self) -> None:
        self.assertTrue(RAW_BACKGROUND.exists(), f"{RAW_BACKGROUND}: missing AI background source")
        self.assertTrue(RAW_SHADOW.exists(), f"{RAW_SHADOW}: missing AI shadow source")
        self.assertGreater(RAW_BACKGROUND.stat().st_size, 100_000, "AI background source is unexpectedly small")
        self.assertGreater(RAW_SHADOW.stat().st_size, 10_000, "AI shadow source is unexpectedly small")
        for prompt_path, phrases in {
            RAW_BACKGROUND_PROMPT: ("abandoned mine", "landing zones", "no text", "no labels", "no complete interactive props"),
            RAW_SHADOW_PROMPT: ("contact shadow", "pure magenta", "no text", "no object"),
        }.items():
            self.assertTrue(prompt_path.exists(), f"{prompt_path}: missing prompt record")
            prompt = prompt_path.read_text(encoding="utf-8").lower()
            for phrase in phrases:
                self.assertIn(phrase, prompt)

    def test_manifest_records_background_and_shadow_contracts(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["scale"], SCALE)
        background = manifest["background"]
        shadow = manifest["shadow"]
        self.assertEqual(background["id"], "mine_investigation_background")
        self.assertEqual(background["source"], "art_sources/generated_raw/mine_investigation_background/mine_background_reference_v1.png")
        self.assertEqual(background["reference"], "assets/source/investigation/mine_background/reference/mine_background_reference_v1.png")
        self.assertEqual(background["native"], "assets/source/investigation/mine_background/mine_background_native.png")
        self.assertEqual(background["runtime"], "assets/ui/generated/investigation/mine_background/mine_background.png")
        self.assertEqual(background["native_size"], list(BACKGROUND_NATIVE_SIZE))
        self.assertEqual(background["runtime_size"], list(BACKGROUND_RUNTIME_SIZE))
        self.assertEqual(background["safe_area"], [0, 0, 320, 180])
        self.assertEqual(shadow["id"], "mine_item_shadow")
        self.assertEqual(shadow["source"], "art_sources/generated_raw/mine_investigation_background/mine_item_shadow_source_v1.png")
        self.assertEqual(shadow["reference"], "assets/source/investigation/mine_background/reference/mine_item_shadow_source_v1.png")
        self.assertEqual(shadow["native"], "assets/source/investigation/mine_background/mine_item_shadow_native.png")
        self.assertEqual(shadow["runtime"], "assets/ui/generated/investigation/mine_background/mine_item_shadow.png")
        self.assertEqual(shadow["native_size"], list(SHADOW_NATIVE_SIZE))
        self.assertEqual(shadow["runtime_size"], list(SHADOW_RUNTIME_SIZE))
        self.assertEqual(shadow["source_rect"], [0, 0, 512, 256])
        self.assertEqual(shadow["safe_area"], [2, 2, 38, 12])

    def test_references_native_runtime_and_contact_sheet_exist(self) -> None:
        for path in (REFERENCE_BACKGROUND, REFERENCE_SHADOW, BACKGROUND_NATIVE, SHADOW_NATIVE, BACKGROUND_RUNTIME, SHADOW_RUNTIME, CONTACT_SHEET):
            self.assertTrue(path.exists(), f"{path}: missing output")
            self.assertGreater(path.stat().st_size, 0, f"{path}: empty output")
        self.assertEqual(load_rgba(REFERENCE_BACKGROUND).size, BACKGROUND_RUNTIME_SIZE)
        self.assertGreaterEqual(load_rgba(REFERENCE_SHADOW).width, 256)
        self.assertEqual(load_rgba(BACKGROUND_NATIVE).size, BACKGROUND_NATIVE_SIZE)
        self.assertEqual(load_rgba(BACKGROUND_RUNTIME).size, BACKGROUND_RUNTIME_SIZE)
        self.assertEqual(load_rgba(SHADOW_NATIVE).size, SHADOW_NATIVE_SIZE)
        self.assertEqual(load_rgba(SHADOW_RUNTIME).size, SHADOW_RUNTIME_SIZE)
        contact = load_rgba(CONTACT_SHEET)
        self.assertGreaterEqual(contact.width, 900, "contact sheet is too narrow for review")
        self.assertGreaterEqual(contact.height, 700, "contact sheet is too short for review")

    def test_runtime_outputs_are_exact_four_x_nearest_exports(self) -> None:
        for native_path, runtime_path, runtime_size in (
            (BACKGROUND_NATIVE, BACKGROUND_RUNTIME, BACKGROUND_RUNTIME_SIZE),
            (SHADOW_NATIVE, SHADOW_RUNTIME, SHADOW_RUNTIME_SIZE),
        ):
            native = load_rgba(native_path)
            runtime = load_rgba(runtime_path)
            expected = native.resize(runtime_size, Image.Resampling.NEAREST)
            self.assertEqual(runtime.tobytes(), expected.tobytes(), f"{runtime_path.name}: not exact 4x nearest export")

    def test_background_palette_is_dark_cold_and_not_flat(self) -> None:
        native = load_rgba(BACKGROUND_NATIVE)
        data = pixels(native)
        dark = sum(1 for red, green, blue, alpha in data if alpha == 255 and max(red, green, blue) <= 70)
        cool = sum(1 for red, green, blue, alpha in data if alpha == 255 and green >= 18 and blue >= 20 and blue >= red * 0.62)
        blood = sum(1 for red, green, blue, alpha in data if alpha == 255 and red >= 50 and green <= 48 and blue <= 50 and red >= green * 1.25)
        amber = sum(1 for red, green, blue, alpha in data if alpha == 255 and red >= 82 and green >= 38 and blue <= 62 and red >= blue * 1.45)
        bright = sum(1 for red, green, blue, alpha in data if alpha == 255 and max(red, green, blue) >= 215)
        histogram = native.convert("RGBA").getcolors(maxcolors=65536)
        self.assertIsNotNone(histogram, "background color count should stay bounded")
        assert histogram is not None
        self.assertGreaterEqual(dark, 18_000, "background needs enough dark cave mass")
        self.assertGreaterEqual(cool, 5_000, "background needs visible cold stone color")
        self.assertGreaterEqual(blood, 35, "background needs a small dark red blood trail")
        self.assertLessEqual(amber, 3_800, "amber accents should not flood the mine background")
        self.assertLessEqual(bright, 120, "background should avoid bright noisy pixels")
        self.assertGreaterEqual(color_count(native), 36, "background should preserve authored color nuance")
        self.assertLessEqual(max(count for count, _pixel in histogram), 22_000, "background should not collapse into one flat color")

    def test_shadow_alpha_and_chroma_contract(self) -> None:
        native = load_rgba(SHADOW_NATIVE)
        alpha = native.getchannel("A")
        alpha_min, alpha_max = alpha.getextrema()
        self.assertEqual(alpha_min, 0, "shadow needs transparent boundary pixels")
        self.assertGreater(alpha_max, 0, "shadow needs visible pixels")
        self.assertGreaterEqual(visible_pixel_count(native), 80, "shadow has too few visible pixels")
        self.assertLessEqual(visible_pixel_count(native), 360, "shadow covers too much of its native canvas")
        self.assertIsNotNone(alpha.getbbox(), "shadow alpha bbox is empty")
        self.assertEqual(chroma_fringe_pixels(native), 0, "shadow contains visible magenta chroma-key fringe")

    def test_ui_scene_files_do_not_reference_raw_or_reference_art(self) -> None:
        forbidden = [
            "art_sources/generated_raw/mine_investigation_background",
            "assets/source/investigation/mine_background/reference",
            "mine_background_reference_v1.png",
            "mine_item_shadow_source_v1.png",
        ]
        for root in (ROOT / "scripts" / "ui", ROOT / "scenes" / "ui"):
            for path in root.rglob("*"):
                if path.suffix not in {".gd", ".tscn", ".tres"}:
                    continue
                text = path.read_text(encoding="utf-8", errors="ignore").replace("\\", "/")
                for marker in forbidden:
                    self.assertNotIn(marker, text, f"{path.relative_to(ROOT)} references raw/reference art")


if __name__ == "__main__":
    unittest.main(verbosity=2)
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```powershell
python scripts/test/test_mine_investigation_background_pipeline.py
```

Expected: FAIL because the AI source files, manifest, native textures, runtime textures, and contact sheet have not been created.

- [ ] **Step 3: Commit the failing pipeline test**

Run:

```powershell
git add scripts/test/test_mine_investigation_background_pipeline.py
git commit -m "test: cover mine investigation background pipeline"
```

Expected: the commit contains only `scripts/test/test_mine_investigation_background_pipeline.py`.

---

### Task 2: Generate and Retain AI Source Images

**Files:**
- Create: `art_sources/generated_raw/mine_investigation_background/mine_background_reference_v1.png`
- Create: `art_sources/generated_raw/mine_investigation_background/mine_background_prompt_v1.txt`
- Create: `art_sources/generated_raw/mine_investigation_background/mine_item_shadow_source_v1.png`
- Create: `art_sources/generated_raw/mine_investigation_background/mine_item_shadow_prompt_v1.txt`

- [ ] **Step 1: Generate the AI background reference**

Use the built-in AI image generation tool with this exact prompt:

```text
Abandoned mine investigation background for a Godot pixel-art dungeon tavern management game, 16:9 full-screen scene, no UI. A cold dark cave cross-section with rough stone walls, timber supports, dusty floor, left-side shallow investigation area, right-side collapsed rubble area, and a subtle dark red blood trail leading from the left lower floor toward the right collapse. Build low-contrast landing zones for props without drawing complete interactive props. No broken arrow, no shield, no boot, no backpack, no coins, no token, no paper as complete readable objects. No text, no labels, no numbers, no logos, no characters, no hands, no buttons. Visual language: dark teal dungeon palette, cold stone blues and greens, sparse amber edge highlights, rough ink-like silhouettes, chunky low-density pixel-game composition, readable after normalization to a 320x180 native pixel grid. Keep far wall detail lower contrast than foreground props.
```

Save the exact prompt text to `art_sources/generated_raw/mine_investigation_background/mine_background_prompt_v1.txt`.

- [ ] **Step 2: Save the approved background PNG**

Save the generated PNG as:

```text
art_sources/generated_raw/mine_investigation_background/mine_background_reference_v1.png
```

Reject and regenerate if it contains readable text, UI, characters, hands, complete item silhouettes that duplicate interactive props, or if the blood trail and right-side collapse are missing.

- [ ] **Step 3: Generate the AI contact shadow source**

Use the built-in AI image generation tool with this exact prompt:

```text
Single contact shadow sprite source for grounding small pixel-art investigation props. One horizontal cold black soft oval shadow centered on a pure magenta background (#ff00ff), broad middle and feathered edge, no object, no prop, no text, no labels, no numbers, no logo, no UI, no glow, no colored outline. It should be easy to chroma-key and normalize into a 40x14 native pixel sprite for a dark stone cave floor.
```

Save the exact prompt text to `art_sources/generated_raw/mine_investigation_background/mine_item_shadow_prompt_v1.txt`.

- [ ] **Step 4: Save the approved shadow PNG**

Save the generated PNG as:

```text
art_sources/generated_raw/mine_investigation_background/mine_item_shadow_source_v1.png
```

Reject and regenerate if it contains any prop, text, frame, logo, non-magenta background, or bright colored fringe.

- [ ] **Step 5: Run the pipeline test and verify the remaining failures**

Run:

```powershell
python scripts/test/test_mine_investigation_background_pipeline.py
```

Expected: FAIL because the manifest, stable references, native textures, runtime textures, and contact sheet have not been created. The AI source and prompt assertions should pass.

- [ ] **Step 6: Commit the raw AI source images and prompt records**

Run:

```powershell
git add art_sources/generated_raw/mine_investigation_background/mine_background_reference_v1.png art_sources/generated_raw/mine_investigation_background/mine_background_prompt_v1.txt art_sources/generated_raw/mine_investigation_background/mine_item_shadow_source_v1.png art_sources/generated_raw/mine_investigation_background/mine_item_shadow_prompt_v1.txt
git commit -m "art: add mine background ai sources"
```

Expected: the commit contains only the raw AI PNGs and prompt text files.

---

### Task 3: Prepare Stable References and Manifest

**Files:**
- Create: `scripts/tools/prepare_mine_investigation_background_sources.py`
- Create: `assets/source/investigation/mine_background/reference/mine_background_reference_v1.png`
- Create: `assets/source/investigation/mine_background/reference/mine_item_shadow_source_v1.png`
- Create: `assets/source/investigation/mine_background/mine_background_manifest.json`

- [ ] **Step 1: Add the prepare script**

Create `scripts/tools/prepare_mine_investigation_background_sources.py` with this content:

```python
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
                "bloodied_paper": [1030, 480]
            }
        }
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
```

- [ ] **Step 2: Run the prepare script**

Run:

```powershell
python scripts/tools/prepare_mine_investigation_background_sources.py
```

Expected: prints the stable background reference path, stable shadow reference path, and manifest path.

- [ ] **Step 3: Run the pipeline test and verify the remaining failures**

Run:

```powershell
python scripts/test/test_mine_investigation_background_pipeline.py
```

Expected: FAIL because native textures, runtime textures, and contact sheet have not been created. Manifest and stable reference assertions should pass.

- [ ] **Step 4: Commit prepare script, stable references, and manifest**

Run:

```powershell
git add scripts/tools/prepare_mine_investigation_background_sources.py assets/source/investigation/mine_background/reference/mine_background_reference_v1.png assets/source/investigation/mine_background/reference/mine_item_shadow_source_v1.png assets/source/investigation/mine_background/mine_background_manifest.json
git commit -m "build: prepare mine background references"
```

Expected: the commit contains only the prepare script, two stable reference PNGs, and manifest.

---

### Task 4: Export Native and Runtime Background Assets

**Files:**
- Create: `scripts/tools/export_mine_investigation_background_assets.py`
- Create: `assets/source/investigation/mine_background/mine_background_native.png`
- Create: `assets/source/investigation/mine_background/mine_item_shadow_native.png`
- Create: `assets/ui/generated/investigation/mine_background/mine_background.png`
- Create: `assets/ui/generated/investigation/mine_background/mine_item_shadow.png`
- Create: `docs/art/mine_investigation_background_contact_sheet.png`

- [ ] **Step 1: Add the exporter**

Create `scripts/tools/export_mine_investigation_background_assets.py` with this content:

```python
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "source" / "investigation" / "mine_background"
MANIFEST = SOURCE / "mine_background_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "mine_investigation_background_contact_sheet.png"
ITEM_RUNTIME = ROOT / "assets" / "ui" / "generated" / "investigation" / "mine_items"


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def load_manifest() -> dict[str, Any]:
    if not MANIFEST.exists():
        raise FileNotFoundError(f"missing manifest: {MANIFEST}")
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def quantize_rgba(image: Image.Image, colors: int) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    rgb = Image.new("RGB", rgba.size, (0, 0, 0))
    rgb.paste(rgba.convert("RGB"), mask=alpha)
    quantized = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    quantized.putalpha(alpha)
    return quantized


def normalize_background(reference: Image.Image, native_size: tuple[int, int]) -> Image.Image:
    fitted = ImageOps.fit(reference.convert("RGB"), native_size, Image.Resampling.LANCZOS, centering=(0.5, 0.52))
    sharpened = fitted.filter(ImageFilter.UnsharpMask(radius=1, percent=160, threshold=2))
    contrast = ImageEnhance.Contrast(sharpened).enhance(1.18)
    color = ImageEnhance.Color(contrast).enhance(0.86)
    balanced = ImageEnhance.Brightness(color).enhance(0.82)
    native = quantize_rgba(balanced, 72)
    pixels = native.load()
    for y in range(native.height):
        for x in range(native.width):
            red, green, blue, alpha = pixels[x, y]
            if y < 34:
                red = int(red * 0.70)
                green = int(green * 0.74)
                blue = int(blue * 0.84)
            if y > 156:
                red = int(red * 0.74)
                green = int(green * 0.76)
                blue = int(blue * 0.82)
            if 36 <= y <= 146 and 16 <= x <= 304:
                blue = min(130, max(blue, int(green * 0.78)))
            if red >= 118 and green >= 58 and blue <= 64:
                red = min(160, red)
                green = min(96, green)
                blue = min(62, blue)
            elif red > 145 and green > 145 and blue > 145:
                red = min(red, 112)
                green = min(green, 118)
                blue = min(blue, 128)
            pixels[x, y] = (max(5, red), max(6, green), max(8, blue), alpha)
    return native


def is_chroma_key(red: int, green: int, blue: int) -> bool:
    if red >= 210 and blue >= 210 and green <= 80:
        return True
    return red >= 120 and blue >= 120 and green <= min(red, blue) * 0.45


def shadow_alpha_from_pixel(red: int, green: int, blue: int) -> int:
    luminance = (red * 30 + green * 59 + blue * 11) // 100
    return max(0, min(210, 230 - luminance * 2))


def normalize_shadow(reference: Image.Image, native_size: tuple[int, int], source_rect: list[int]) -> Image.Image:
    x, y, width, height = source_rect
    rgba = reference.crop((x, y, x + width, y + height)).convert("RGBA")
    cleaned = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    source_pixels = rgba.load()
    target_pixels = cleaned.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = source_pixels[x, y]
            if alpha == 0 or is_chroma_key(red, green, blue):
                continue
            shadow_alpha = shadow_alpha_from_pixel(red, green, blue)
            if shadow_alpha >= 12:
                target_pixels[x, y] = (5, 8, 11, shadow_alpha)
    fitted = ImageOps.fit(cleaned, (native_size[0] - 4, native_size[1] - 4), Image.Resampling.LANCZOS, centering=(0.5, 0.5))
    native = Image.new("RGBA", native_size, (0, 0, 0, 0))
    x = (native.width - fitted.width) // 2
    y = (native.height - fitted.height) // 2
    native.alpha_composite(fitted, (x, y))
    alpha = native.getchannel("A").point(lambda value: 0 if value < 18 else min(210, value))
    native.putalpha(alpha)
    pixels = native.load()
    for y in range(native.height):
        for x in range(native.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (5, 8, 11, alpha)
    if native.getchannel("A").getbbox() is None:
        raise ValueError("shadow source has no visible pixels after chroma cleanup")
    return native


def save_nearest(native: Image.Image, native_path: Path, runtime_path: Path, runtime_size: tuple[int, int]) -> Image.Image:
    native_path.parent.mkdir(parents=True, exist_ok=True)
    runtime_path.parent.mkdir(parents=True, exist_ok=True)
    native.save(native_path)
    runtime = native.resize(runtime_size, Image.Resampling.NEAREST)
    expected = native.resize(runtime_size, Image.Resampling.NEAREST)
    if runtime.tobytes() != expected.tobytes():
        raise ValueError(f"{runtime_path.name}: runtime is not exact nearest output")
    runtime.save(runtime_path)
    return runtime


def paste_item_overlay(sheet: Image.Image, background_preview: Image.Image, shadow_runtime: Image.Image, positions: dict[str, list[int]], origin: tuple[int, int]) -> None:
    preview = background_preview.copy()
    for item_id, position in positions.items():
        item_path = ITEM_RUNTIME / f"{item_id}.png"
        if not item_path.exists():
            continue
        item = Image.open(item_path).convert("RGBA")
        x = int(position[0] * 0.5)
        y = int(position[1] * 0.5)
        shadow_preview = shadow_runtime.resize((80, 28), Image.Resampling.NEAREST)
        preview.alpha_composite(shadow_preview, (x - shadow_preview.width // 2, y - 4))
        item_preview = ImageOps.contain(item, (max(12, item.width // 2), max(12, item.height // 2)), Image.Resampling.NEAREST)
        preview.alpha_composite(item_preview, (x - item_preview.width // 2, y - item_preview.height // 2))
    sheet.alpha_composite(preview, origin)


def make_contact_sheet(reference: Image.Image, background_native: Image.Image, background_runtime: Image.Image, shadow_native: Image.Image, shadow_runtime: Image.Image, manifest: dict[str, Any]) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (980, 780), (16, 14, 12, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((20, 16), "Mine investigation background and contact shadow pipeline", fill=(226, 210, 178, 255))
    draw.text((20, 48), "AI reference", fill=(226, 210, 178, 255))
    reference_preview = ImageOps.contain(reference.convert("RGBA"), (440, 248), Image.Resampling.LANCZOS)
    sheet.alpha_composite(reference_preview, (20, 72))
    draw.text((510, 48), "native 2x preview", fill=(226, 210, 178, 255))
    native_preview = background_native.resize((640, 360), Image.Resampling.NEAREST)
    native_preview = ImageOps.contain(native_preview, (440, 248), Image.Resampling.NEAREST)
    sheet.alpha_composite(native_preview, (510, 72))
    draw.text((20, 348), "runtime item overlay preview", fill=(226, 210, 178, 255))
    overlay_bg = ImageOps.contain(background_runtime.convert("RGBA"), (640, 360), Image.Resampling.NEAREST)
    paste_item_overlay(sheet, overlay_bg, shadow_runtime, manifest["review"]["item_overlay_positions_runtime"], (20, 374))
    draw.text((700, 348), "shadow native 4x", fill=(226, 210, 178, 255))
    shadow_preview = shadow_native.resize((shadow_native.width * 4, shadow_native.height * 4), Image.Resampling.NEAREST)
    sheet.alpha_composite(shadow_preview, (700, 384))
    draw.text((700, 470), "shadow runtime", fill=(226, 210, 178, 255))
    sheet.alpha_composite(shadow_runtime, (700, 506))
    sheet.convert("RGB").save(CONTACT_SHEET)


def main() -> None:
    manifest = load_manifest()
    background_entry = manifest["background"]
    shadow_entry = manifest["shadow"]
    background_reference_path = ROOT / background_entry["reference"]
    shadow_reference_path = ROOT / shadow_entry["reference"]
    if not background_reference_path.exists():
        raise FileNotFoundError(f"missing background reference: {background_reference_path}")
    if not shadow_reference_path.exists():
        raise FileNotFoundError(f"missing shadow reference: {shadow_reference_path}")
    background_reference = Image.open(background_reference_path).convert("RGBA")
    shadow_reference = Image.open(shadow_reference_path).convert("RGBA")
    background_native_size = tuple(background_entry["native_size"])
    background_runtime_size = tuple(background_entry["runtime_size"])
    shadow_native_size = tuple(shadow_entry["native_size"])
    shadow_runtime_size = tuple(shadow_entry["runtime_size"])
    background_native = normalize_background(background_reference, background_native_size)
    shadow_native = normalize_shadow(shadow_reference, shadow_native_size, shadow_entry["source_rect"])
    background_runtime = save_nearest(background_native, ROOT / background_entry["native"], ROOT / background_entry["runtime"], background_runtime_size)
    shadow_runtime = save_nearest(shadow_native, ROOT / shadow_entry["native"], ROOT / shadow_entry["runtime"], shadow_runtime_size)
    make_contact_sheet(background_reference, background_native, background_runtime, shadow_native, shadow_runtime, manifest)
    print(f"exported mine background: {background_entry['native']} -> {background_entry['runtime']}")
    print(f"exported mine item shadow: {shadow_entry['native']} -> {shadow_entry['runtime']}")
    print(f"contact sheet: {rel(CONTACT_SHEET)}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run the exporter**

Run:

```powershell
python scripts/tools/export_mine_investigation_background_assets.py
```

Expected: prints exported background path, exported shadow path, and contact sheet path.

- [ ] **Step 3: Run the pipeline test**

Run:

```powershell
python scripts/test/test_mine_investigation_background_pipeline.py
```

Expected: PASS. If the palette assertions fail, regenerate the AI source or adjust only the deterministic normalization parameters, then rerun the exporter and this test.

- [ ] **Step 4: Inspect the contact sheet**

Open `docs/art/mine_investigation_background_contact_sheet.png` and verify:

- background reads as abandoned mine, not a pure color field;
- left shallow area, right collapse, and blood trail are visible;
- item overlay preview shows items grounded by the shadow;
- background does not contain complete copies of the interactive props;
- no text, labels, numbers, logos, UI, purple fringe, or high-resolution blur are visible.

- [ ] **Step 5: Commit exporter and generated production assets**

Run:

```powershell
git add scripts/tools/export_mine_investigation_background_assets.py assets/source/investigation/mine_background/mine_background_native.png assets/source/investigation/mine_background/mine_item_shadow_native.png assets/ui/generated/investigation/mine_background/mine_background.png assets/ui/generated/investigation/mine_background/mine_item_shadow.png docs/art/mine_investigation_background_contact_sheet.png
git commit -m "art: export mine background textures"
```

Expected: the commit contains only the exporter, native/runtime textures, and contact sheet.

---

### Task 5: Add Godot Visual Contract Tests

**Files:**
- Modify: `scripts/test/test_mine_item_visual_contract.gd`
- Create: `scripts/test/test_mine_background_scene_contract.gd`
- Create: `scenes/test/test_mine_background_scene_contract.tscn`

- [ ] **Step 1: Extend the MineItem visual contract test**

Replace `scripts/test/test_mine_item_visual_contract.gd` with this content:

```gdscript
extends Node

const MINE_ITEM_SCENE := preload("res://scenes/ui/components/MineItem.tscn")
const SHADOW_PATH := "res://assets/ui/generated/investigation/mine_background/mine_item_shadow.png"

var _checks := 0
var _failures := 0


func _ready() -> void:
	await _test_production_item_hides_debug_visuals_and_shows_shadow()
	_test_unknown_item_keeps_legacy_visuals_without_shadow()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-MINE-ITEM-VISUAL] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-MINE-ITEM-VISUAL] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-MINE-ITEM-VISUAL] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _spawn_item() -> MineItem:
	var item: MineItem = MINE_ITEM_SCENE.instantiate()
	add_child(item)
	return item


func _test_production_item_hides_debug_visuals_and_shows_shadow() -> void:
	var item := _spawn_item()
	item.setup("broken_arrow", "observation", Vector2(48, 16), Color.RED, "debug label", "observation")
	item.rotation = 1.35
	await get_tree().physics_frame
	_ok(item.get_node_or_null("Shape") is CollisionShape2D, "Shape node is preserved")
	_ok(item.get_node_or_null("Visual") is Polygon2D, "Visual node is preserved")
	_ok(item.get_node_or_null("Label") is Label, "Label node is preserved")
	_ok(item.get_node_or_null("TextureVisual") is Sprite2D, "production item creates TextureVisual")
	_ok(item.get_node_or_null("ShadowVisual") is Sprite2D, "production item creates ShadowVisual")
	_ok(not item.get_node("Visual").visible, "production item hides polygon debug visual")
	_ok(not item.get_node("Label").visible, "production item hides always-on debug label")
	var sprite := item.get_node_or_null("TextureVisual") as Sprite2D
	if sprite != null:
		_ok(sprite.visible, "production sprite is visible")
		_ok(sprite.texture != null, "production sprite has texture")
		_ok(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "production sprite uses nearest texture filtering")
	var shadow := item.get_node_or_null("ShadowVisual") as Sprite2D
	if shadow != null:
		_ok(shadow.visible, "production shadow is visible")
		_ok(shadow.texture != null, "production shadow has texture")
		if shadow.texture != null:
			_ok(shadow.texture.resource_path == SHADOW_PATH, "production shadow uses mine_item_shadow runtime texture")
		_ok(shadow.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "production shadow uses nearest texture filtering")
		_ok(shadow.top_level, "production shadow is top-level so it does not inherit item rotation")
		_ok(absf(wrapf(shadow.global_rotation, -PI, PI)) < 0.01, "production shadow remains horizontally aligned")
		if sprite != null:
			_ok(shadow.z_index < sprite.z_index, "production shadow renders below item texture")
	_ok(item.item_tag == "broken_arrow", "item_tag contract remains set by setup")
	_ok(item.kind == "observation", "kind contract remains set by setup")
	item.queue_free()


func _test_unknown_item_keeps_legacy_visuals_without_shadow() -> void:
	var item := _spawn_item()
	item.setup("unmapped_debug_item", "plain", Vector2(32, 32), Color.GREEN, "debug label", "")
	_ok(item.get_node("Visual").visible, "unmapped item keeps polygon visual")
	_ok(item.get_node("Label").visible, "unmapped item keeps debug label")
	_ok(item.get_node_or_null("TextureVisual") == null or not item.get_node("TextureVisual").visible, "unmapped item does not show production sprite")
	_ok(item.get_node_or_null("ShadowVisual") == null or not item.get_node("ShadowVisual").visible, "unmapped item does not force a production shadow")
	item.queue_free()
```

- [ ] **Step 2: Add the MineInvestigation background scene test**

Create `scripts/test/test_mine_background_scene_contract.gd` with this content:

```gdscript
extends Node

const MINE_SCENE := preload("res://scenes/ui/MineInvestigation.tscn")
const BACKGROUND_PATH := "res://assets/ui/generated/investigation/mine_background/mine_background.png"

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_scene_background_contract()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-MINE-BACKGROUND] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-MINE-BACKGROUND] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-MINE-BACKGROUND] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_scene_background_contract() -> void:
	var scene := MINE_SCENE.instantiate()
	var background := scene.get_node_or_null("Background")
	var background_art := scene.get_node_or_null("BackgroundArt")
	var blood_trail := scene.get_node_or_null("BloodTrail")
	_ok(background is ColorRect, "legacy Background node remains a ColorRect fallback")
	_ok(background_art is Sprite2D, "BackgroundArt Sprite2D exists")
	_ok(blood_trail is ColorRect, "legacy BloodTrail node remains present")
	if background != null and background_art != null:
		_ok(background.z_index < background_art.z_index, "Background fallback renders below BackgroundArt")
	if background_art != null:
		var sprite := background_art as Sprite2D
		_ok(sprite.position == Vector2(640, 360), "BackgroundArt is centered on the 1280x720 scene")
		_ok(sprite.texture != null, "BackgroundArt has a texture")
		if sprite.texture != null:
			_ok(sprite.texture.resource_path == BACKGROUND_PATH, "BackgroundArt uses the runtime background texture")
		_ok(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "BackgroundArt uses nearest texture filtering")
	if blood_trail != null:
		_ok(not blood_trail.visible, "legacy BloodTrail is hidden rather than deleted")
	_ok(scene.get_node_or_null("World") is Node2D, "World node path is preserved")
	_ok(scene.get_node_or_null("World/Ground") is StaticBody2D, "World/Ground path is preserved")
	_ok(scene.get_node_or_null("DragCtrl") is Node, "DragCtrl path is preserved")
	_ok(scene.get_node_or_null("UI/ObservationLabel") is Label, "ObservationLabel path is preserved")
	_ok(scene.get_node_or_null("UI/HintLabel") is Label, "HintLabel path is preserved")
	_ok(scene.get_node_or_null("UI/LeaveButton") is Button, "LeaveButton path is preserved")
	scene.free()
```

- [ ] **Step 3: Add the scene contract test scene**

Create `scenes/test/test_mine_background_scene_contract.tscn` with this content:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/test/test_mine_background_scene_contract.gd" id="1"]

[node name="TestMineBackgroundSceneContract" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 4: Run the Godot tests and verify they fail for the intended reasons**

Run:

```powershell
$Godot = 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe'
& $Godot --headless --path . scenes/test/test_mine_item_visual_contract.tscn
& $Godot --headless --path . scenes/test/test_mine_background_scene_contract.tscn
```

Expected: the item visual test FAILS because `MineItem` does not create `ShadowVisual`; the background scene test FAILS because `MineInvestigation.tscn` does not have `BackgroundArt` and still shows `BloodTrail`.

- [ ] **Step 5: Commit the failing contract tests**

Run:

```powershell
git add scripts/test/test_mine_item_visual_contract.gd scripts/test/test_mine_background_scene_contract.gd scenes/test/test_mine_background_scene_contract.tscn
git commit -m "test: cover mine background visual contracts"
```

Expected: the commit contains only the updated item test and new background scene test files.

---

### Task 6: Add Non-Rotating Contact Shadow to MineItem

**Files:**
- Modify: `scripts/ui/components/mine_item.gd`

- [ ] **Step 1: Add the shadow texture constant and state**

In `scripts/ui/components/mine_item.gd`, add this constant after `ITEM_TEXTURES`:

```gdscript
const SHADOW_TEXTURE := "res://assets/ui/generated/investigation/mine_background/mine_item_shadow.png"
```

Add these variables after `_texture_visual`:

```gdscript
var _shadow_visual: Sprite2D = null
var _shadow_offset_y: float = 0.0
var _uses_production_texture: bool = false
```

- [ ] **Step 2: Replace `_apply_texture_visual()`**

Replace the existing `_apply_texture_visual()` function with:

```gdscript
func _apply_texture_visual(p_tag: String, p_size: Vector2) -> void:
	var path: String = String(ITEM_TEXTURES.get(p_tag, ""))
	if path == "":
		_show_legacy_visual()
		return
	var texture := load(path) as Texture2D
	if texture == null:
		push_warning("MineItem texture missing or invalid for %s: %s" % [p_tag, path])
		_show_legacy_visual()
		return
	_ensure_texture_visual()
	_texture_visual.texture = texture
	_texture_visual.visible = true
	_texture_visual.z_index = _visual.z_index + 2
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x > 0.0 and texture_size.y > 0.0:
		_texture_visual.scale = Vector2(p_size.x / texture_size.x, p_size.y / texture_size.y)
	else:
		_texture_visual.scale = Vector2.ONE
	_visual.visible = false
	_label.visible = false
	_uses_production_texture = true
	_apply_shadow_visual(p_size)
```

- [ ] **Step 3: Add the shadow helper functions and physics transform update**

Add these functions below `_ensure_texture_visual()`:

```gdscript
func _physics_process(_delta: float) -> void:
	_update_shadow_visual()


func _apply_shadow_visual(p_size: Vector2) -> void:
	var texture := load(SHADOW_TEXTURE) as Texture2D
	if texture == null:
		push_warning("MineItem shadow texture missing or invalid: %s" % SHADOW_TEXTURE)
		if _shadow_visual != null:
			_shadow_visual.visible = false
		return
	_ensure_shadow_visual()
	_shadow_visual.texture = texture
	_shadow_visual.visible = true
	_shadow_visual.z_index = _visual.z_index + 1
	_shadow_offset_y = p_size.y * 0.38
	var texture_size := texture.get_size()
	if texture_size.x > 0.0 and texture_size.y > 0.0:
		var target_width := maxf(24.0, p_size.x * 1.05)
		var target_height := clampf(p_size.y * 0.18, 8.0, 18.0)
		_shadow_visual.scale = Vector2(target_width / texture_size.x, target_height / texture_size.y)
	else:
		_shadow_visual.scale = Vector2.ONE
	_update_shadow_visual()


func _ensure_shadow_visual() -> void:
	if _shadow_visual != null:
		return
	_shadow_visual = Sprite2D.new()
	_shadow_visual.name = "ShadowVisual"
	_shadow_visual.centered = true
	_shadow_visual.top_level = true
	_shadow_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_shadow_visual)


func _update_shadow_visual() -> void:
	if _shadow_visual == null:
		return
	_shadow_visual.visible = visible and _uses_production_texture
	if not _shadow_visual.visible:
		return
	_shadow_visual.global_position = global_position + Vector2(0.0, _shadow_offset_y)
	_shadow_visual.global_rotation = 0.0
```

- [ ] **Step 4: Replace `_show_legacy_visual()`**

Replace the existing `_show_legacy_visual()` function with:

```gdscript
func _show_legacy_visual() -> void:
	_uses_production_texture = false
	_visual.visible = true
	_label.visible = true
	if _texture_visual != null:
		_texture_visual.visible = false
	if _shadow_visual != null:
		_shadow_visual.visible = false
```

- [ ] **Step 5: Run the MineItem visual contract test**

Run:

```powershell
$Godot = 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe'
& $Godot --headless --path . scenes/test/test_mine_item_visual_contract.tscn
```

Expected: PASS.

- [ ] **Step 6: Run shared investigation tests**

Run:

```powershell
$Godot = 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe'
& $Godot --headless --path . scenes/test/test_mine_investigation.tscn
& $Godot --headless --path . scenes/test/test_toby_lodging_investigation.tscn
```

Expected: both PASS. Toby fallback items should keep legacy visuals and should not force `ShadowVisual`.

- [ ] **Step 7: Commit the MineItem shadow implementation**

Run:

```powershell
git add scripts/ui/components/mine_item.gd
git commit -m "feat: add mine item contact shadows"
```

Expected: the commit contains only `scripts/ui/components/mine_item.gd`.

---

### Task 7: Hook the Runtime Background into MineInvestigation

**Files:**
- Modify: `scenes/ui/MineInvestigation.tscn`

- [ ] **Step 1: Update the scene header and resources**

In `scenes/ui/MineInvestigation.tscn`, change the scene header to:

```ini
[gd_scene load_steps=6 format=3]
```

Add this resource after the existing script resources:

```ini
[ext_resource type="Texture2D" path="res://assets/ui/generated/investigation/mine_background/mine_background.png" id="3"]
```

- [ ] **Step 2: Preserve `Background` and add `BackgroundArt`**

Update the `Background` node so it keeps the same name and type but renders below the art:

```ini
[node name="Background" type="ColorRect" parent="."]
z_index = -120
offset_right = 1280.0
offset_bottom = 720.0
color = Color(0.08, 0.07, 0.09, 1)
```

Insert this node immediately after `Background`:

```ini
[node name="BackgroundArt" type="Sprite2D" parent="."]
position = Vector2(640, 360)
z_index = -110
texture_filter = 1
texture = ExtResource("3")
centered = true
```

- [ ] **Step 3: Hide the legacy `BloodTrail` node without deleting it**

Update `BloodTrail` so it remains present but hidden:

```ini
[node name="BloodTrail" type="ColorRect" parent="."]
visible = false
z_index = -100
offset_left = 180.0
offset_top = 505.0
offset_right = 900.0
offset_bottom = 520.0
color = Color(0.45, 0.08, 0.08, 0.5)
```

- [ ] **Step 4: Run the background scene contract test**

Run:

```powershell
$Godot = 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe'
& $Godot --headless --path . scenes/test/test_mine_background_scene_contract.tscn
```

Expected: PASS.

- [ ] **Step 5: Run the mine investigation behavior test**

Run:

```powershell
$Godot = 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe'
& $Godot --headless --path . scenes/test/test_mine_investigation.tscn
```

Expected: PASS. The scene should still spawn investigation items and preserve the original node paths.

- [ ] **Step 6: Commit the scene hookup**

Run:

```powershell
git add scenes/ui/MineInvestigation.tscn
git commit -m "feat: add mine investigation background art"
```

Expected: the commit contains only `scenes/ui/MineInvestigation.tscn`.

---

### Task 8: Full Verification and Visual Review

**Files:**
- Read: `docs/art/mine_investigation_background_contact_sheet.png`
- Read: Godot headless output
- Read: `git status --short`

- [ ] **Step 1: Run the complete focused verification set**

Run:

```powershell
python scripts/test/test_mine_investigation_background_pipeline.py
$Godot = 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe'
& $Godot --headless --path . scenes/test/test_mine_background_scene_contract.tscn
& $Godot --headless --path . scenes/test/test_mine_item_visual_contract.tscn
& $Godot --headless --path . scenes/test/test_mine_investigation.tscn
& $Godot --headless --path . scenes/test/test_toby_lodging_investigation.tscn
```

Expected: all commands PASS.

- [ ] **Step 2: Inspect the final contact sheet**

Open:

```text
docs/art/mine_investigation_background_contact_sheet.png
```

Confirm:

- the item overlay preview shows items grounded rather than floating;
- the background leaves low-contrast landing zones below the shallow items and deep-layer objects;
- `bloodied_paper` remains readable against the right-side ground;
- the blood trail leads toward the right-side collapse;
- the background does not contain readable text, UI labels, or full duplicate interactive props.

- [ ] **Step 3: Runtime smoke test the scene**

Run the scene through Godot:

```powershell
$Godot = 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe'
& $Godot --path . scenes/ui/MineInvestigation.tscn
```

Manually verify:

- background fills the `1280x720` scene;
- `Background`, `BackgroundArt`, `BloodTrail`, `World`, `DragCtrl`, and `UI` all exist;
- `BloodTrail` is hidden;
- production items show no always-on debug labels;
- contact shadows sit under production items and stay horizontal while items rotate;
- observation pickup, rubble reveal, backpack spill, and bloodied paper pickup still behave normally.

- [ ] **Step 4: Check working tree scope**

Run:

```powershell
git status --short
```

Expected: no uncommitted files from this feature. Existing unrelated dirty files may still appear; do not edit or revert them.

- [ ] **Step 5: Record final evidence**

In the handoff, report:

- commit hashes created during this implementation;
- each verification command and whether it passed;
- the contact sheet path;
- any Godot warnings that are pre-existing and unrelated.

No commit is required in this task unless Task 8 finds a feature-specific issue and the fix changes files. If a visual tuning fix is needed, rerun the exporter, rerun all focused tests, and commit only the changed background/shadow assets plus contact sheet with:

```powershell
git add assets/source/investigation/mine_background assets/ui/generated/investigation/mine_background docs/art/mine_investigation_background_contact_sheet.png
git commit -m "art: tune mine background readability"
```

Expected: final feature files are committed, and unrelated working tree changes remain untouched.

---

## Self-Review

Spec coverage:

- AI-generated background source is covered by Task 2 and retained under `art_sources/generated_raw/mine_investigation_background/`.
- AI-generated shadow source is covered by Task 2, satisfying the user's requirement that both background and contact shadow originate from AI generation.
- Native/runtime background and shadow pipeline is covered by Tasks 3 and 4 with exact `4x` nearest export tests.
- Manifest entries include id, source, reference, native output, runtime output, size, safe area, and intended Godot use.
- Contact sheet and item overlay review are covered by Task 4 and Task 8.
- `MineInvestigation.tscn` keeps `Background` and `BloodTrail`, adds `BackgroundArt`, hides `BloodTrail`, and preserves `World`, `DragCtrl`, `UI`, `ObservationLabel`, `HintLabel`, and `LeaveButton`.
- `MineItem` keeps `setup()` and legacy fallback behavior while adding `ShadowVisual` only for mapped production items.
- Existing mine and Toby tests are included in Tasks 6, 7, and 8.

Type consistency:

- `mine_item_shadow` runtime path is consistent across the manifest, pipeline test, `MineItem.SHADOW_TEXTURE`, and GDScript visual contract test.
- `BackgroundArt` is consistently planned as a `Sprite2D`, not a `TextureRect`.
- Godot texture filtering uses `CanvasItem.TEXTURE_FILTER_NEAREST` in scripts and `texture_filter = 1` in scene resources.
- The background runtime texture path is consistently `res://assets/ui/generated/investigation/mine_background/mine_background.png`.

Execution order:

- Pipeline tests are written before source assets and exporters.
- AI raw sources are retained before stable references and native/runtime outputs are generated.
- Godot contract tests are written before `MineItem` and scene implementation.
- Runtime scene hookup happens after production textures exist.
- Full verification happens after all focused commits.
