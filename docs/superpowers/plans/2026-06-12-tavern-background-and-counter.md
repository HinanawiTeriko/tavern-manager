# Tavern Background And Counter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an empty but furnished Tavern service background and rebuild the foreground counter from the approved generated reference while preserving physics and UI contracts.

**Architecture:** Keep the runtime scene split into `Background` and `TabletopArt`. A deterministic Pillow exporter converts the approved generated reference into native 320-wide pixel sources, exact 4x runtime textures, manifests, and a contact sheet. Existing Godot tests protect node paths, physics line positions, patience UI, and workspace recovery.

**Tech Stack:** Godot 4.6.3, GDScript scene contracts, Python 3 `unittest`, Pillow asset pipeline, Git.

---

## Files

- Create: `scripts/test/test_tavern_background_asset_pipeline.py`
- Create: `scripts/tools/export_tavern_background_assets.py`
- Create: `assets/source/tavern/background/tavern_background_manifest.json`
- Create: `assets/source/tavern/background/tavern_bg_native.png`
- Create: `assets/textures/tavern/background/tavern_bg.png`
- Create: `docs/art/tavern_background_contact_sheet.png`
- Modify: `scripts/test/test_tavern_table_asset_pipeline.py`
- Modify: `scripts/test/test_tavern_table_scene.gd`
- Modify: `scripts/tools/export_tavern_table_assets.py`
- Modify: `assets/source/tavern/table/tabletop_manifest.json`
- Modify: `assets/source/tavern/table/tabletop_native.png`
- Modify: `assets/textures/tavern/table/tabletop.png`
- Modify: `scenes/ui/Tavern.tscn`
- Modify: `scripts/ui/tavern_view.gd`

## Task 1: Write RED Asset Pipeline Tests

**Files:**
- Create: `scripts/test/test_tavern_background_asset_pipeline.py`
- Modify: `scripts/test/test_tavern_table_asset_pipeline.py`

- [ ] **Step 1: Create the background asset pipeline test**

Write `scripts/test/test_tavern_background_asset_pipeline.py` with these checks:

```python
from __future__ import annotations

import json
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "tavern_background" / "tavern_background_no_people_reference_v1.png"
PROMPT = ROOT / "art_sources" / "generated_raw" / "tavern_background" / "tavern_background_no_people_prompt_v1.txt"
MANIFEST = ROOT / "assets" / "source" / "tavern" / "background" / "tavern_background_manifest.json"
NATIVE = ROOT / "assets" / "source" / "tavern" / "background" / "tavern_bg_native.png"
RUNTIME = ROOT / "assets" / "textures" / "tavern" / "background" / "tavern_bg.png"
CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_background_contact_sheet.png"
NATIVE_SIZE = (320, 180)
RUNTIME_SIZE = (1280, 720)


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def pixels(image: Image.Image) -> list[tuple[int, int, int, int]]:
    return list(image.convert("RGBA").getdata())


class TavernBackgroundAssetPipelineTest(unittest.TestCase):
    def test_generated_reference_and_prompt_are_retained(self) -> None:
        self.assertTrue(RAW_SOURCE.exists(), f"{RAW_SOURCE}: missing generated reference")
        self.assertGreater(RAW_SOURCE.stat().st_size, 1_000_000, "generated reference is unexpectedly small")
        self.assertTrue(PROMPT.exists(), f"{PROMPT}: missing prompt record")
        prompt = PROMPT.read_text(encoding="utf-8").lower()
        for phrase in ("no people", "left", "fireplace", "tables", "chairs"):
            self.assertIn(phrase, prompt)

    def test_manifest_records_background_contract(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["id"], "tavern_no_people_background")
        self.assertEqual(manifest["source"], "art_sources/generated_raw/tavern_background/tavern_background_no_people_reference_v1.png")
        self.assertEqual(manifest["native"], "assets/source/tavern/background/tavern_bg_native.png")
        self.assertEqual(manifest["runtime"], "assets/textures/tavern/background/tavern_bg.png")
        self.assertEqual(manifest["native_size"], list(NATIVE_SIZE))
        self.assertEqual(manifest["runtime_size"], list(RUNTIME_SIZE))
        self.assertEqual(manifest["scale"], 4)
        self.assertEqual(manifest["safe_area"], [0, 0, 320, 180])
        self.assertEqual(manifest["intended_godot_use"], "Tavern service scene visual-only no-people background Sprite2D layer")

    def test_native_runtime_and_contact_sheet_exist(self) -> None:
        for path in (NATIVE, RUNTIME, CONTACT_SHEET):
            self.assertTrue(path.exists(), f"{path}: missing output")
            self.assertGreater(path.stat().st_size, 0, f"{path}: empty output")
        self.assertEqual(load_rgba(NATIVE).size, NATIVE_SIZE)
        self.assertEqual(load_rgba(RUNTIME).size, RUNTIME_SIZE)

    def test_runtime_is_exact_four_x_nearest_export(self) -> None:
        native = load_rgba(NATIVE)
        runtime = load_rgba(RUNTIME)
        expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
        self.assertEqual(runtime.tobytes(), expected.tobytes(), "runtime must be exact 4x nearest export")

    def test_background_palette_and_furniture_density(self) -> None:
        native = load_rgba(NATIVE)
        data = pixels(native)
        dark = sum(1 for r, g, b, a in data if a == 255 and max(r, g, b) <= 58)
        teal = sum(1 for r, g, b, a in data if a == 255 and b >= 30 and g >= 26 and b >= r * 0.9)
        amber = sum(1 for r, g, b, a in data if a == 255 and r >= 92 and g >= 38 and b <= 58 and r >= b * 1.5)
        bright = sum(1 for r, g, b, a in data if a == 255 and max(r, g, b) >= 210)
        self.assertGreaterEqual(dark, 22_000, "background needs enough dark dungeon mass")
        self.assertGreaterEqual(teal, 4_500, "background needs visible teal stone depth")
        self.assertGreaterEqual(amber, 450, "background needs readable amber fireplace/candle accents")
        self.assertLessEqual(amber, 10_000, "background amber accents are flooding the frame")
        self.assertLessEqual(bright, 160, "background should avoid bright noisy pixels")

        midground = native.crop((24, 72, 296, 152)).convert("RGBA")
        mid_pixels = pixels(midground)
        wood_dark = sum(1 for r, g, b, a in mid_pixels if a == 255 and 30 <= r <= 125 and 18 <= g <= 86 and 8 <= b <= 72)
        horizontal_edges = 0
        for y in range(midground.height):
            for x in range(midground.width - 1):
                r1, g1, b1, a1 = midground.getpixel((x, y))
                r2, g2, b2, a2 = midground.getpixel((x + 1, y))
                if a1 == 255 and a2 == 255 and abs((r1 + g1 + b1) - (r2 + g2 + b2)) >= 36:
                    horizontal_edges += 1
        self.assertGreaterEqual(wood_dark, 3_200, "midground needs enough empty table/chair wood mass")
        self.assertGreaterEqual(horizontal_edges, 1_000, "midground needs readable table/chair structure")


if __name__ == "__main__":
    unittest.main(verbosity=2)
```

- [ ] **Step 2: Update the table pipeline contract test**

In `scripts/test/test_tavern_table_asset_pipeline.py`, change the manifest source expectation to:

```python
self.assertEqual(manifest["source"], "art_sources/generated_raw/tavern_background/tavern_background_no_people_reference_v1.png")
```

Keep existing physics alignment expectations:

```python
SPRITE_POSITION_RUNTIME = (640, 600)
SURFACE_TOP_Y_RUNTIME = 455
FRONT_LIP_Y_RUNTIME = 655
GROUND_Y_RUNTIME = 655
```

- [ ] **Step 3: Run RED tests**

Run:

```powershell
python -m unittest scripts.test.test_tavern_background_asset_pipeline.TavernBackgroundAssetPipelineTest -v
python -m unittest scripts.test.test_tavern_table_asset_pipeline.TavernTableAssetPipelineTest -v
```

Expected:
- Background pipeline test fails because `tavern_bg_native.png`, `tavern_bg.png`, and `tavern_background_manifest.json` do not exist.
- Table pipeline test fails because `tabletop_manifest.json` still points to the previous tavern table generated source.

## Task 2: Write RED Godot Scene Contract Tests

**Files:**
- Modify: `scripts/test/test_tavern_table_scene.gd`

- [ ] **Step 1: Add background contract checks**

In `_test_physics_aligned_tabletop_art_layer()`, after instancing Tavern and before checking `TabletopArt`, add:

```gdscript
	var background := tavern.get_node_or_null("Background") as Sprite2D
	_ok(background != null, "Tavern keeps the public Background node")
	if background != null:
		_ok(_texture_path(background.texture) == "res://assets/textures/tavern/background/tavern_bg.png",
			"Background uses Tavern no-people runtime background art")
		_ok(background.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"Background uses nearest texture filter")
		_ok(background.z_index < -90, "Background draws below the foreground counter")
```

The existing `TabletopArt` checks remain and should still assert:

```gdscript
_ok(tabletop.position == Vector2(640, 600), "TabletopArt shifts down so the current ground line lands on the playable work surface")
```

- [ ] **Step 2: Run RED scene test**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_tavern_table_scene.tscn
```

Expected: FAIL because `Background` currently resolves to `res://assets/textures/backgrounds/tavern_bg.png` or a fallback gradient, not `res://assets/textures/tavern/background/tavern_bg.png`.

## Task 3: Implement Deterministic Background And Counter Exporter

**Files:**
- Create: `scripts/tools/export_tavern_background_assets.py`
- Modify: `scripts/tools/export_tavern_table_assets.py`
- Create/Modify: `assets/source/tavern/background/tavern_bg_native.png`
- Create/Modify: `assets/textures/tavern/background/tavern_bg.png`
- Modify: `assets/source/tavern/table/tabletop_native.png`
- Modify: `assets/textures/tavern/table/tabletop.png`
- Create/Modify: manifests and contact sheet

- [ ] **Step 1: Create the exporter**

Create `scripts/tools/export_tavern_background_assets.py` with functions for:

```python
ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE = ROOT / "art_sources" / "generated_raw" / "tavern_background" / "tavern_background_no_people_reference_v1.png"
BACKGROUND_NATIVE = ROOT / "assets" / "source" / "tavern" / "background" / "tavern_bg_native.png"
BACKGROUND_RUNTIME = ROOT / "assets" / "textures" / "tavern" / "background" / "tavern_bg.png"
BACKGROUND_MANIFEST = ROOT / "assets" / "source" / "tavern" / "background" / "tavern_background_manifest.json"
TABLE_NATIVE = ROOT / "assets" / "source" / "tavern" / "table" / "tabletop_native.png"
TABLE_RUNTIME = ROOT / "assets" / "textures" / "tavern" / "table" / "tabletop.png"
TABLE_MANIFEST = ROOT / "assets" / "source" / "tavern" / "table" / "tabletop_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_background_contact_sheet.png"
SCALE = 4
BACKGROUND_NATIVE_SIZE = (320, 180)
TABLE_NATIVE_SIZE = (320, 80)
TABLE_RUNTIME_SIZE = (1280, 320)
SPRITE_POSITION_RUNTIME = (640, 600)
SURFACE_TOP_Y_RUNTIME = 455
FRONT_LIP_Y_RUNTIME = 655
GROUND_Y_RUNTIME = 655
CUTOUT_POLYGON_NATIVE = [(10, 4), (310, 4), (320, 64), (320, 73), (0, 73), (0, 64)]
```

Implementation requirements:
- Use `ImageOps.fit(reference, BACKGROUND_NATIVE_SIZE, Image.Resampling.LANCZOS, centering=(0.5, 0.47))` for the full background plate.
- Enhance contrast and color modestly, then quantize to 48 colors.
- Crop table native from the generated reference so the playable top edge lands near native row 4.
- Apply the transparent cutout polygon so the counter stays visual-only and does not cover the full scene as an opaque rectangle.
- Save runtime images as exact 4x nearest exports.
- Write background and table manifests.
- Write a contact sheet showing raw reference preview, background native 4x preview, table native 4x preview, and runtime overlay preview.

- [ ] **Step 2: Make the old table exporter a compatibility wrapper**

Replace `scripts/tools/export_tavern_table_assets.py` with:

```python
from __future__ import annotations

from scripts.tools.export_tavern_background_assets import main


if __name__ == "__main__":
    main()
```

- [ ] **Step 3: Run exporter**

Run:

```powershell
python scripts\tools\export_tavern_background_assets.py
```

Expected output mentions:

```text
exported Tavern background: assets/textures/tavern/background/tavern_bg.png
exported Tavern counter: assets/textures/tavern/table/tabletop.png
contact sheet: docs/art/tavern_background_contact_sheet.png
```

- [ ] **Step 4: Run GREEN pipeline tests**

Run:

```powershell
python -m unittest scripts.test.test_tavern_background_asset_pipeline.TavernBackgroundAssetPipelineTest -v
python -m unittest scripts.test.test_tavern_table_asset_pipeline.TavernTableAssetPipelineTest -v
```

Expected: both test classes pass.

## Task 4: Integrate Runtime Background Into Tavern Scene

**Files:**
- Modify: `scenes/ui/Tavern.tscn`
- Modify: `scripts/ui/tavern_view.gd`

- [ ] **Step 1: List planned scene edits before editing**

Tell the user:

```text
Planned scene/code edits:
- scenes/ui/Tavern.tscn: add the Tavern background texture resource to Background, keep node name and z-index.
- scripts/ui/tavern_view.gd: load the new Tavern-specific background path first, with the legacy background as fallback.
```

- [ ] **Step 2: Update Tavern scene resource**

In `scenes/ui/Tavern.tscn`:
- Add an `ext_resource` for `res://assets/textures/tavern/background/tavern_bg.png`.
- Increase `load_steps` by 1.
- On node `Background`, set:

```text
texture_filter = 1
texture = ExtResource("tavern_background")
```

Do not rename `Background`, `TabletopArt`, `CustomerArea`, `BarWorkspace`, or any physics nodes.

- [ ] **Step 3: Update TavernView background loading**

In `scripts/ui/tavern_view.gd`, replace the first background load in `_apply_theme()` with:

```gdscript
	var bg_tex = TextureManager.try_load("res://assets/textures/tavern/background/tavern_bg.png")
	if bg_tex == null:
		bg_tex = TextureManager.try_load("res://assets/textures/backgrounds/tavern_bg.png")
```

Keep the existing gradient fallback after that.

- [ ] **Step 4: Run GREEN scene test**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_tavern_table_scene.tscn
```

Expected: table/background scene test passes.

## Task 5: Verification And Commit

**Files:**
- All files touched in Tasks 1-4

- [ ] **Step 1: Run full focused verification**

Run:

```powershell
python -m unittest scripts.test.test_tavern_background_asset_pipeline.TavernBackgroundAssetPipelineTest -v
python -m unittest scripts.test.test_tavern_table_asset_pipeline.TavernTableAssetPipelineTest -v
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_tavern_table_scene.tscn
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_tavern_patience_ui.tscn
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_workspace_scene_recovery.tscn
```

Expected:
- Background pipeline tests pass.
- Table pipeline tests pass.
- Tavern table scene passes with unchanged wall segments and workspace positions.
- Patience UI contract still passes.
- Workspace recovery still passes.

- [ ] **Step 2: Inspect generated contact sheet**

Open:

```text
docs/art/tavern_background_contact_sheet.png
```

Confirm visually:
- No people or human silhouettes in background.
- Left door and right fireplace remain readable.
- Midground contains multiple empty tables/chairs.
- Foreground counter reads as a playable bar surface.

- [ ] **Step 3: Stage only Tavern background/counter files**

Run:

```powershell
git add -- scripts/test/test_tavern_background_asset_pipeline.py scripts/test/test_tavern_table_asset_pipeline.py scripts/test/test_tavern_table_scene.gd scripts/tools/export_tavern_background_assets.py scripts/tools/export_tavern_table_assets.py assets/source/tavern/background/tavern_background_manifest.json assets/source/tavern/background/tavern_bg_native.png assets/textures/tavern/background/tavern_bg.png assets/source/tavern/table/tabletop_manifest.json assets/source/tavern/table/tabletop_native.png assets/textures/tavern/table/tabletop.png docs/art/tavern_background_contact_sheet.png scenes/ui/Tavern.tscn scripts/ui/tavern_view.gd
git add -f -- docs/superpowers/plans/2026-06-12-tavern-background-and-counter.md
git diff --cached --name-only
git diff --cached --check
```

Verify the cached file list does not include DayMap, shop, seasoning, or unrelated workspace files.

- [ ] **Step 4: Commit**

Run:

```powershell
git commit -m "feat: add Tavern background and counter art"
```

Expected: a commit containing only Tavern background/counter art, pipeline, tests, scene, and plan files.
