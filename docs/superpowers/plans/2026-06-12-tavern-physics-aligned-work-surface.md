# Tavern Physics-Aligned Work Surface Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the rejected Tavern table/bar-counter art with a readable 3/4 wooden bar work surface that visually aligns with the existing physics play area.

**Architecture:** Keep the active `TabletopArt` Sprite2D and `assets/textures/tavern/table/tabletop.png` runtime path so scene contracts stay stable. Rebuild only the deterministic source-to-native-to-runtime art pipeline and its tests; keep `BarWorkspace/World/Walls/Ground` and all RigidBody2D coordinates unchanged.

**Tech Stack:** Godot 4.6.3 scene resources, Python Pillow pixel export pipeline, built-in image generation for raw source art, GDScript scene contract tests.

---

### Task 1: Retarget Asset Contract To A Physics-Aligned Work Surface

**Files:**
- Modify: `scripts/test/test_tavern_table_asset_pipeline.py`

- [ ] **Step 1: Write the failing test**

Assert the manifest uses `tavern_bar_work_surface`, `tabletop_reference_v2.png`, `tabletop_native.png`, and `tabletop.png`; assert native size is `320x80`, runtime size is `1280x320`, and manifest records `surface_top_y_runtime = 455`, `front_lip_y_runtime = 655`, and `ground_y_runtime = 655`.

- [ ] **Step 2: Add pixel readability assertions**

Map the runtime alignment back to native rows for the centered Sprite2D at `Vector2(640, 560)`: back edge row around `14`, front lip row around `64`. Assert both rows have enough horizontal contrast and that the playable surface rows `14..64` have wood mass and visible texture.

- [ ] **Step 3: Run the focused asset test**

Run: `python -m unittest scripts.test.test_tavern_table_asset_pipeline.TavernTableAssetPipelineTest -v`

Expected: FAIL because the current manifest and generated image still describe the rejected bar counter/tabletop contract.

### Task 2: Rebuild The Exporter

**Files:**
- Modify: `scripts/tools/export_tavern_table_assets.py`

- [ ] **Step 1: Point the exporter at the v2 raw source**

Use `art_sources/generated_raw/tavern_table/tabletop_reference_v2.png` as the source and keep the runtime output at `assets/textures/tavern/table/tabletop.png`.

- [ ] **Step 2: Use full-frame deterministic normalization**

Resize the full generated frame to `320x80` with the fixed centering needed for the work-surface composition. Do not infer crop bounds from alpha, colors, or connected components.

- [ ] **Step 3: Keep the asset native-pixel safe**

Quantize to a restrained dark wood/teal/amber palette and export the runtime texture by exact 4x nearest-neighbor scaling.

- [ ] **Step 4: Write the manifest**

Record id, source, native, runtime, sizes, scale, safe area, and the physics visual alignment fields used by the tests.

### Task 3: Generate And Process The Work-Surface Art

**Files:**
- Create: `art_sources/generated_raw/tavern_table/tabletop_reference_v2.png`
- Modify: `assets/source/tavern/table/tabletop_manifest.json`
- Modify: `assets/source/tavern/table/tabletop_native.png`
- Modify: `assets/textures/tavern/table/tabletop.png`
- Modify: `docs/art/tavern_table_contact_sheet.png`

- [ ] **Step 1: Generate the raw image**

Use the built-in image generation tool. Prompt for a 3/4 top-down wooden tavern bar work surface with a visible back edge near the upper third, a broad playable wooden plane, and a thick front lip aligned with the bottom physics ground. Avoid text, props, people, logos, and a straight-on cabinet front.

- [ ] **Step 2: Copy the chosen raw output into the workspace**

Copy the generated PNG into `art_sources/generated_raw/tavern_table/tabletop_reference_v2.png`, leaving the original generated image in place.

- [ ] **Step 3: Run exporter and asset test**

Run: `python scripts/tools/export_tavern_table_assets.py`

Run: `python -m unittest scripts.test.test_tavern_table_asset_pipeline.TavernTableAssetPipelineTest -v`

Expected: PASS with exact nearest-neighbor runtime export and visible row-level table structure.

### Task 4: Keep The Tavern Scene Contract Stable

**Files:**
- Modify: `scripts/test/test_tavern_table_scene.gd`
- Inspect only unless needed: `scenes/ui/Tavern.tscn`

- [ ] **Step 1: Update the scene test first**

Assert `TabletopArt` remains present, uses `res://assets/textures/tavern/table/tabletop.png`, is centered at `Vector2(640, 560)`, draws behind gameplay props, and leaves the existing ground, left wall, right wall, customer drop area, and RigidBody2D positions unchanged.

- [ ] **Step 2: Run scene test for RED or PASS**

Run: `& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_tavern_table_scene.tscn`

Expected: PASS if the current scene contract already matches; FAIL only if the previous rejected `BarCounterArt` test is still active.

- [ ] **Step 3: Edit scene only if the updated contract fails**

If needed, change only the texture resource path or `TabletopArt` placement. Do not edit physics walls or gameplay nodes.

### Task 5: Final Verification And Commit

**Files:**
- Stage only Tavern work-surface files and this plan.

- [ ] **Step 1: Run focused verification**

Run:

```powershell
python scripts/tools/export_tavern_table_assets.py
python -m unittest scripts.test.test_tavern_table_asset_pipeline.TavernTableAssetPipelineTest -v
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_tavern_table_scene.tscn
```

- [ ] **Step 2: Run relevant regression checks**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_workspace_scene_recovery.tscn
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_ryan_slice_assets.tscn
```

- [ ] **Step 3: Review image output**

Open `docs/art/tavern_table_contact_sheet.png` and `assets/textures/tavern/table/tabletop.png` to inspect the work-surface alignment before final response.

- [ ] **Step 4: Commit scoped changes**

Commit only the new plan, updated tests, exporter, raw v2 source, processed Tavern table assets, and contact sheet.
