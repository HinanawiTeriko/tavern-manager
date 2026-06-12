# Tavern Wood Tabletop Art Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a production pixel-art wooden tabletop layer to the Tavern night service scene without changing gameplay or physics contracts.

**Architecture:** Use a small tabletop-specific asset pipeline that keeps generated reference art, native source, runtime texture, manifest, and contact sheet separate. Add one visual-only `TabletopArt` node to `scenes/ui/Tavern.tscn`, leaving `Background`, `BarWorkspace/World/Walls`, customer drop area, and all workspace props untouched.

**Tech Stack:** Godot 4.6.3 scene resources, GDScript-free scene hookup, Python `unittest`, Pillow, built-in `image_gen`, nearest-neighbor pixel export.

---

## File Structure

| Path | Action | Responsibility |
| --- | --- | --- |
| `art_sources/generated_raw/tavern_table/tabletop_reference_v1.png` | Create | Retained AI-generated source/reference image. |
| `assets/source/tavern/table/tabletop_manifest.json` | Create | Fixed source/native/runtime contract for the tabletop asset. |
| `assets/source/tavern/table/tabletop_native.png` | Create | `320x80` native production tabletop source. |
| `assets/textures/tavern/table/tabletop.png` | Create | `1280x320` runtime texture exported exactly 4x nearest. |
| `docs/art/tavern_table_contact_sheet.png` | Create | Review sheet showing reference, native 4x preview, and runtime. |
| `scripts/test/test_tavern_table_asset_pipeline.py` | Create | Python pipeline contract test. |
| `scripts/tools/export_tavern_table_assets.py` | Create | Deterministic Pillow exporter from reference to native/runtime/contact sheet. |
| `scripts/test/test_tavern_table_scene.gd` | Create | Headless Godot scene contract for `TabletopArt` and wall invariants. |
| `scenes/test/test_tavern_table_scene.tscn` | Create | Test scene entry point. |
| `scenes/ui/Tavern.tscn` | Modify | Add `TabletopArt` Sprite2D with the runtime texture. |

Use explicit path-based staging. Do not run `git add .`.

## Task 1: Write the Pipeline Contract Test

**Files:**
- Create: `scripts/test/test_tavern_table_asset_pipeline.py`
- Test: `scripts/test/test_tavern_table_asset_pipeline.py`

- [ ] **Step 1: Write the failing test**

Create `scripts/test/test_tavern_table_asset_pipeline.py`:

```python
from __future__ import annotations

import json
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "source" / "tavern" / "table" / "tabletop_manifest.json"
CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_table_contact_sheet.png"
NATIVE_SIZE = (320, 80)
RUNTIME_SIZE = (1280, 320)


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


class TavernTableAssetPipelineTest(unittest.TestCase):
    def test_manifest_records_fixed_tabletop_contract(self) -> None:
        self.assertTrue(MANIFEST.exists(), f"{MANIFEST}: missing manifest")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["id"], "tavern_tabletop")
        self.assertEqual(manifest["source"], "art_sources/generated_raw/tavern_table/tabletop_reference_v1.png")
        self.assertEqual(manifest["native"], "assets/source/tavern/table/tabletop_native.png")
        self.assertEqual(manifest["runtime"], "assets/textures/tavern/table/tabletop.png")
        self.assertEqual(manifest["native_size"], list(NATIVE_SIZE))
        self.assertEqual(manifest["runtime_size"], list(RUNTIME_SIZE))
        self.assertEqual(manifest["scale"], 4)
        self.assertEqual(manifest["safe_area"], [0, 0, 320, 80])
        self.assertEqual(manifest["intended_godot_use"], "visual-only Tavern tabletop Sprite2D layer")

    def test_source_native_runtime_and_contact_sheet_exist(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        for key in ("source", "native", "runtime"):
            path = ROOT / manifest[key]
            self.assertTrue(path.exists(), f"{path}: missing {key} image")
            self.assertGreater(path.stat().st_size, 0, f"{path}: empty {key} image")
        self.assertTrue(CONTACT_SHEET.exists(), f"{CONTACT_SHEET}: missing contact sheet")
        self.assertGreater(CONTACT_SHEET.stat().st_size, 0, "contact sheet is empty")

    def test_runtime_is_exact_nearest_export(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        native = load_rgba(ROOT / manifest["native"])
        runtime = load_rgba(ROOT / manifest["runtime"])
        self.assertEqual(native.size, NATIVE_SIZE)
        self.assertEqual(runtime.size, RUNTIME_SIZE)
        expected = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
        self.assertEqual(runtime.tobytes(), expected.tobytes(), "runtime must be exact 4x nearest export")

    def test_native_tabletop_is_opaque_and_visually_restrained(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        native = load_rgba(ROOT / manifest["native"])
        alpha_min, alpha_max = native.getchannel("A").getextrema()
        self.assertEqual((alpha_min, alpha_max), (255, 255), "tabletop is a rectangular opaque surface")
        pixels = list(native.getdata())
        dark_wood = sum(1 for r, g, b, a in pixels if a == 255 and 20 <= r <= 95 and 14 <= g <= 70 and 8 <= b <= 60)
        teal_shadow = sum(1 for r, g, b, a in pixels if a == 255 and b >= 18 and g >= 16 and b >= r * 0.55)
        amber = sum(1 for r, g, b, a in pixels if a == 255 and r >= 90 and g >= 45 and b <= 45 and r >= b * 2.0)
        bright = sum(1 for r, g, b, a in pixels if a == 255 and max(r, g, b) >= 185)
        self.assertGreaterEqual(dark_wood, 14000, "tabletop needs enough dark wood mass")
        self.assertGreaterEqual(teal_shadow, 3500, "tabletop needs dark teal shadow bias")
        self.assertGreaterEqual(amber, 160, "tabletop needs sparse amber edge highlights")
        self.assertLessEqual(amber, 5200, "amber accents are flooding the tabletop")
        self.assertLessEqual(bright, 120, "tabletop should not contain bright noisy pixels")


if __name__ == "__main__":
    unittest.main(verbosity=2)
```

- [ ] **Step 2: Verify RED**

Run:

```powershell
python -m unittest scripts.test.test_tavern_table_asset_pipeline.TavernTableAssetPipelineTest -v
```

Expected: fail because `assets/source/tavern/table/tabletop_manifest.json` does not exist.

- [ ] **Step 3: Commit the failing test**

Run:

```powershell
git add scripts/test/test_tavern_table_asset_pipeline.py
git commit -m "test: add Tavern tabletop asset contract"
```

## Task 2: Generate the Tabletop Reference Image

**Files:**
- Create: `art_sources/generated_raw/tavern_table/tabletop_reference_v1.png`

- [ ] **Step 1: Generate with built-in imagegen**

Use built-in `image_gen` with this prompt:

```text
Use case: stylized-concept
Asset type: pixel-game tabletop source reference for a Godot tavern management scene
Primary request: Create a wide wooden tabletop texture for the lower playable work surface of a dark dungeon tavern.
Scene/backdrop: no scene, only a flat rectangular tabletop surface viewed straight-on with slight top-down game UI perspective.
Subject: old tavern worktable planks, broad dark wooden boards, worn edges, a few rough cuts and dents.
Style/medium: authored game art reference that will be normalized to chunky low-resolution pixel art; crisp silhouettes, broad blocky clusters, hard-edged shadow groups, low-density detail.
Composition/framing: 16:4 wide horizontal rectangle, table surface fills the frame edge to edge, no objects on top, no border frame, no text. Keep the center readable for draggable items and cookware.
Lighting/mood: dark underground tavern, cold teal shadows, sparse warm amber candle edge highlights.
Color palette: dark brown wood, coal black, dark teal shadows, muted amber highlights only.
Materials/textures: rough planks, low-detail grain, chunky pixel-friendly scratches, no fine noise.
Constraints: no readable text, no symbols, no logos, no items, no UI, no characters, no labels, no checkerboard pattern, no high-frequency wood grain, no soft antialiasing, no blur, no watermark.
Avoid: bright orange wood, beige tabletop, modern polished table, photorealistic texture, clutter, cast shadows, decorative objects.
```

After generation, copy or move the selected output into:

```text
art_sources/generated_raw/tavern_table/tabletop_reference_v1.png
```

- [ ] **Step 2: Inspect the reference**

Use `view_image` on `art_sources/generated_raw/tavern_table/tabletop_reference_v1.png`.

Accept only if:

- It has no text or objects.
- It is not checkerboard-like.
- It is dark enough for current workspace props.
- It has broad plank shapes and restrained texture.

If it fails, run one targeted `image_gen` iteration and replace only the reference image.

## Task 3: Implement the Deterministic Exporter

**Files:**
- Create: `scripts/tools/export_tavern_table_assets.py`
- Create: `assets/source/tavern/table/tabletop_manifest.json`
- Create: `assets/source/tavern/table/tabletop_native.png`
- Create: `assets/textures/tavern/table/tabletop.png`
- Create: `docs/art/tavern_table_contact_sheet.png`
- Test: `scripts/test/test_tavern_table_asset_pipeline.py`

- [ ] **Step 1: Add the exporter**

Create `scripts/tools/export_tavern_table_assets.py`:

```python
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageOps


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art_sources" / "generated_raw" / "tavern_table" / "tabletop_reference_v1.png"
MANIFEST = ROOT / "assets" / "source" / "tavern" / "table" / "tabletop_manifest.json"
NATIVE = ROOT / "assets" / "source" / "tavern" / "table" / "tabletop_native.png"
RUNTIME = ROOT / "assets" / "textures" / "tavern" / "table" / "tabletop.png"
CONTACT_SHEET = ROOT / "docs" / "art" / "tavern_table_contact_sheet.png"
NATIVE_SIZE = (320, 80)
RUNTIME_SIZE = (1280, 320)
SCALE = 4


def quantize_image(image: Image.Image, colors: int = 18) -> Image.Image:
    rgb = image.convert("RGB")
    return rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")


def normalize_tabletop(source: Image.Image) -> Image.Image:
    cropped = ImageOps.fit(source.convert("RGB"), NATIVE_SIZE, method=Image.Resampling.LANCZOS, centering=(0.5, 0.56))
    contrast = ImageEnhance.Contrast(cropped).enhance(1.18)
    color = ImageEnhance.Color(contrast).enhance(0.82)
    darkened = ImageEnhance.Brightness(color).enhance(0.58)
    native = quantize_image(darkened, 18)
    pixels = native.load()
    for y in range(native.height):
        for x in range(native.width):
            r, g, b, a = pixels[x, y]
            r = min(130, max(18, r))
            g = min(92, max(14, g))
            b = min(70, max(10, b))
            if (x + y * 3) % 19 == 0 and r > 45:
                r = min(135, r + 10)
                g = min(88, g + 5)
            if y < 4 or y > native.height - 6:
                r = max(16, int(r * 0.78))
                g = max(12, int(g * 0.78))
                b = max(10, int(b * 0.86))
            pixels[x, y] = (r, g, b, 255)
    return native


def save_manifest() -> None:
    manifest = {
        "id": "tavern_tabletop",
        "source": "art_sources/generated_raw/tavern_table/tabletop_reference_v1.png",
        "native": "assets/source/tavern/table/tabletop_native.png",
        "runtime": "assets/textures/tavern/table/tabletop.png",
        "native_size": list(NATIVE_SIZE),
        "runtime_size": list(RUNTIME_SIZE),
        "scale": SCALE,
        "safe_area": [0, 0, 320, 80],
        "intended_godot_use": "visual-only Tavern tabletop Sprite2D layer",
    }
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def make_contact_sheet(reference: Image.Image, native: Image.Image, runtime: Image.Image) -> None:
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (720, 380), (18, 14, 11, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((20, 16), "Tavern tabletop art pipeline", fill=(220, 204, 176, 255))
    draw.text((20, 52), "reference", fill=(220, 204, 176, 255))
    draw.text((20, 178), "native 4x preview", fill=(220, 204, 176, 255))
    draw.text((20, 304), "runtime preview", fill=(220, 204, 176, 255))
    ref_preview = ImageOps.contain(reference.convert("RGBA"), (640, 96), Image.Resampling.LANCZOS)
    native_preview = native.resize((native.width * 4, native.height * 4), Image.Resampling.NEAREST)
    native_preview = ImageOps.contain(native_preview, (640, 96), Image.Resampling.NEAREST)
    runtime_preview = ImageOps.contain(runtime.convert("RGBA"), (640, 48), Image.Resampling.NEAREST)
    sheet.alpha_composite(ref_preview, (60, 76))
    sheet.alpha_composite(native_preview, (60, 202))
    sheet.alpha_composite(runtime_preview, (60, 328))
    sheet.convert("RGB").save(CONTACT_SHEET)


def main() -> None:
    if not SOURCE.exists():
        raise FileNotFoundError(f"missing tabletop reference: {SOURCE}")
    reference = Image.open(SOURCE).convert("RGBA")
    native = normalize_tabletop(reference)
    runtime = native.resize(RUNTIME_SIZE, Image.Resampling.NEAREST)
    NATIVE.parent.mkdir(parents=True, exist_ok=True)
    RUNTIME.parent.mkdir(parents=True, exist_ok=True)
    native.save(NATIVE)
    runtime.save(RUNTIME)
    save_manifest()
    make_contact_sheet(reference, native, runtime)
    print("exported tavern tabletop: assets/textures/tavern/table/tabletop.png")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run exporter**

Run:

```powershell
python scripts/tools/export_tavern_table_assets.py
```

Expected: prints `exported tavern tabletop: assets/textures/tavern/table/tabletop.png`.

- [ ] **Step 3: Verify GREEN for pipeline**

Run:

```powershell
python -m unittest scripts.test.test_tavern_table_asset_pipeline.TavernTableAssetPipelineTest -v
```

Expected: pass.

- [ ] **Step 4: Inspect contact sheet**

Use `view_image` on:

```text
docs/art/tavern_table_contact_sheet.png
```

If the tabletop is too bright or too noisy, adjust only constants in `normalize_tabletop()`, rerun the exporter, and rerun the pipeline test.

- [ ] **Step 5: Commit the pipeline**

Run:

```powershell
git add scripts/tools/export_tavern_table_assets.py scripts/test/test_tavern_table_asset_pipeline.py assets/source/tavern/table/tabletop_manifest.json assets/source/tavern/table/tabletop_native.png assets/textures/tavern/table/tabletop.png docs/art/tavern_table_contact_sheet.png art_sources/generated_raw/tavern_table/tabletop_reference_v1.png
git commit -m "feat: add Tavern tabletop art pipeline"
```

## Task 4: Write the Tavern Scene Contract Test

**Files:**
- Create: `scripts/test/test_tavern_table_scene.gd`
- Create: `scenes/test/test_tavern_table_scene.tscn`
- Test: `scenes/test/test_tavern_table_scene.tscn`

- [ ] **Step 1: Add the failing Godot test**

Create `scripts/test/test_tavern_table_scene.gd`:

```gdscript
extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	await _test_tabletop_art_layer()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-TAVERN-TABLE] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-TAVERN-TABLE] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-TAVERN-TABLE] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _texture_path(texture: Texture2D) -> String:
	if texture == null:
		return ""
	return texture.resource_path


func _segment_points(shape: Shape2D) -> Array:
	var segment := shape as SegmentShape2D
	if segment == null:
		return []
	return [segment.a, segment.b]


func _test_tabletop_art_layer() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var table := tavern.get_node_or_null("TabletopArt") as Sprite2D
	_ok(table != null, "Tavern has visual-only TabletopArt node")
	if table != null:
		_ok(_texture_path(table.texture) == "res://assets/textures/tavern/table/tabletop.png", "TabletopArt uses runtime tabletop texture")
		_ok(table.z_index > tavern.get_node("Background").z_index, "TabletopArt draws over full-screen background")
		_ok(table.z_index < 0, "TabletopArt stays behind gameplay props")
		_ok(table.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "TabletopArt uses nearest texture filter")

	var ground := tavern.get_node("BarWorkspace/World/Walls/Ground") as CollisionShape2D
	var left_wall := tavern.get_node("BarWorkspace/World/Walls/LeftWall") as CollisionShape2D
	var right_wall := tavern.get_node("BarWorkspace/World/Walls/RightWall") as CollisionShape2D
	_ok(_segment_points(ground.shape) == [Vector2(150, 655), Vector2(1130, 655)], "ground segment contract is unchanged")
	_ok(_segment_points(left_wall.shape) == [Vector2(150, 410), Vector2(150, 655)], "left wall segment contract is unchanged")
	_ok(_segment_points(right_wall.shape) == [Vector2(1130, 410), Vector2(1130, 655)], "right wall segment contract is unchanged")

	var customer_drop := tavern.get_node_or_null("BarWorkspace/CustomerDropArea/Shape") as CollisionShape2D
	_ok(customer_drop != null and customer_drop.shape is RectangleShape2D, "customer drop area shape remains present")

	tavern.queue_free()
```

Create `scenes/test/test_tavern_table_scene.tscn`:

```text
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/test/test_tavern_table_scene.gd" id="1"]

[node name="TestTavernTableScene" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: Verify RED**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_tavern_table_scene.tscn
```

Expected: fail because `TabletopArt` does not exist.

- [ ] **Step 3: Commit the failing test**

Run:

```powershell
git add scripts/test/test_tavern_table_scene.gd scenes/test/test_tavern_table_scene.tscn
git commit -m "test: add Tavern tabletop scene contract"
```

## Task 5: Wire the Tabletop Art Node

**Files:**
- Modify: `scenes/ui/Tavern.tscn`
- Test: `scenes/test/test_tavern_table_scene.tscn`

- [ ] **Step 1: Add the texture ext_resource**

In `scenes/ui/Tavern.tscn`, increment `load_steps` by one and add:

```text
[ext_resource type="Texture2D" path="res://assets/textures/tavern/table/tabletop.png" id="tavern_tabletop"]
```

- [ ] **Step 2: Add a visual-only table node**

Add this node after `Background` and before `CustomerArea`:

```text
[node name="TabletopArt" type="Sprite2D" parent="."]
position = Vector2(640, 560)
z_index = -90
texture_filter = 1
texture = ExtResource("tavern_tabletop")
centered = true
```

Do not move or edit existing `BarWorkspace/World/Walls` collision shapes.

- [ ] **Step 3: Verify GREEN for scene contract**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_tavern_table_scene.tscn
```

Expected: pass.

- [ ] **Step 4: Commit scene hookup**

Run:

```powershell
git add scenes/ui/Tavern.tscn
git commit -m "feat: wire Tavern tabletop art layer"
```

## Task 6: Final Verification

**Files:**
- No source edits unless verification finds a defect.

- [ ] **Step 1: Run focused pipeline verification**

Run:

```powershell
python -m unittest scripts.test.test_tavern_table_asset_pipeline.TavernTableAssetPipelineTest -v
```

Expected: pass.

- [ ] **Step 2: Run focused Godot scene verification**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_tavern_table_scene.tscn
```

Expected: pass.

- [ ] **Step 3: Run workspace regressions**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_workspace_scene_recovery.tscn
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_ryan_slice_assets.tscn
```

Expected: pass.

- [ ] **Step 4: Inspect review images**

Use `view_image` on:

```text
docs/art/tavern_table_contact_sheet.png
assets/textures/tavern/table/tabletop.png
```

Check that the tabletop is dark, broad, non-checkerboard, and does not contain baked items or text.

- [ ] **Step 5: Inspect git status**

Run:

```powershell
git status --short
```

Expected: only pre-existing unrelated worktree changes remain, plus any intentionally uncommitted tabletop task changes if a commit step was skipped because of verification failure.

## Self-Review

- Spec coverage: Tasks 1 and 3 cover manifest, native/runtime assets, exact nearest export, and contact sheet. Task 2 covers required AI-generated source art. Tasks 4 and 5 cover visual-only scene integration and physics invariants. Task 6 covers focused verification and visual review.
- Placeholder scan: This plan contains no TBD/TODO/fill-in steps. Every code-creating step includes complete content or exact scene snippets.
- Type consistency: The manifest key names match the Python test and exporter. The scene test expects `TabletopArt`, `res://assets/textures/tavern/table/tabletop.png`, and the existing collision segment coordinates from `Tavern.tscn`.
