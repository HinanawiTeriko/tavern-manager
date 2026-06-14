# Tavern Patience UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the visible Tavern ledger work-surface entrance while adding a production pixel patience bar UI.

**Architecture:** Keep existing Tavern public/node contracts stable by preserving `CustomerArea/TimerBar`, `BarWorkspace/World/Ledger`, `DocumentOverlay`, and `TavernView.open_ledger()`. Add a generated-reference-to-native-pixel 4x nearest-neighbor asset pipeline for the patience UI and bind its runtime textures through `TavernView._apply_theme()`. Normalize important guest patience against its 90-second maximum so the bar moves immediately.

**Tech Stack:** Godot 4.6.3 scene resources and GDScript, Python Pillow asset exporter, Python unittest, headless Godot contract scenes.

---

### Task 1: Asset Pipeline Contract

**Files:**
- Create: `scripts/test/test_tavern_patience_asset_pipeline.py`
- Create: `scripts/tools/export_tavern_patience_ui_assets.py`
- Create: `assets/source/ui/patience_bar_bg_native.png`
- Create: `assets/source/ui/patience_bar_fill_native.png`
- Modify/Create: `assets/source/ui/icon_patience_native.png`
- Modify/Create: `assets/textures/ui/bar_patience_bg.png`
- Modify: `assets/textures/ui/bar_patience_fill.png`
- Modify: `assets/textures/ui/icon_patience.png`
- Create: `art_sources/generated_raw/tavern_patience/patience_meter_reference.png`

- [ ] Write Python unittest assertions for native/runtime dimensions, alpha coverage, exact 4x nearest-neighbor export, and runtime file presence.
- [ ] Run `python -m unittest scripts.test.test_tavern_patience_asset_pipeline.TavernPatienceAssetPipelineTest -v` and confirm RED because the background/native files are missing.
- [ ] Implement `export_tavern_patience_ui_assets.py` using Pillow to crop the generated reference into 75x7, 75x7, and 8x8 native assets and export 300x28, 300x28, and 32x32 runtime textures.
- [ ] Run the exporter, then rerun the Python test and confirm GREEN.

### Task 2: Tavern UI Contract

**Files:**
- Create: `scripts/test/test_tavern_patience_ui.gd`
- Create: `scenes/test/test_tavern_patience_ui.tscn`

- [ ] Write a Godot contract that instantiates `res://scenes/ui/Tavern.tscn`.
- [ ] Assert `CustomerArea/TimerBar` remains a `ProgressBar` with 300x28 size and patience stylebox textures.
- [ ] Assert `CustomerArea/PatienceIcon` exists and uses `res://assets/textures/ui/icon_patience.png`.
- [ ] Assert `BarWorkspace/World/Ledger` exists but is hidden and not input pickable.
- [ ] Assert `tavern.update_timer(0.42)` sets `TimerBar.value` to 42.
- [ ] Run the Godot test scene and confirm RED because scene/script wiring is not updated yet.

### Task 3: Runtime Wiring

**Files:**
- Modify: `scenes/ui/Tavern.tscn`
- Modify: `scripts/ui/tavern_view.gd`
- Modify: `scripts/game_manager.gd`

- [ ] In `Tavern.tscn`, add `CustomerArea/PatienceIcon` as a `TextureRect`.
- [ ] Resize `CustomerArea/TimerBar` to 300x28, position it beside the icon, and keep its node name.
- [ ] Set `BarWorkspace/World/Ledger.visible = false` and `input_pickable = false`.
- [ ] In `TavernView._apply_theme()`, load and assign the patience icon texture and keep stylebox background/fill overrides on `TimerBar`.
- [ ] In `GameManager`, route timer updates through a helper that normalizes normal guests against 60 seconds and important guests against 90 seconds.
- [ ] Run the Godot UI contract and confirm GREEN.

### Task 4: Regression Verification

**Files:**
- Inspect only unless failures prove a scoped fix is needed.

- [ ] Run the Tavern table scene contract.
- [ ] Run the workspace scene recovery contract.
- [ ] Run `git diff --check`.
- [ ] Stage only the scoped files from this plan and commit.
