# Tavern Reward HUD Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add night-service reward feedback where successful orders burst gold/reputation particles into Tavern HUD milestone progress bars.

**Architecture:** Keep the feature bounded to `Tavern.tscn`, `TavernView`, and the successful-order branch in `GameManager`. Use processed pixel UI textures generated through an explicit manifest and deterministic nearest-neighbor exporter. Preserve existing topbar node paths and add visual-only child nodes that ignore mouse input.

**Tech Stack:** Godot 4.6.3, GDScript, Python Pillow asset pipeline, Python unittest, Godot headless scene tests, built-in image generation for raw source art.

---

## Files

- Create: `art_sources/generated_raw/tavern_reward_hud/tavern_reward_hud_sheet_v1.png` - generated source sheet containing progress bars, ornate states, particles, and spark art.
- Create: `art_sources/generated_raw/tavern_reward_hud/tavern_reward_hud_sheet_v1_prompt.txt` - exact image prompt retained with the raw source.
- Create: `scripts/tools/export_tavern_reward_hud_assets.py` - crops the source sheet from explicit rectangles, normalizes to native pixel assets, exports 4x runtime PNGs, manifest, and contact sheet.
- Create: `scripts/test/test_tavern_reward_hud_asset_pipeline.py` - validates the asset pipeline and nearest-neighbor exports.
- Modify: `scripts/test/test_tavern_patience_ui.gd` - extends the existing Tavern topbar contract with reward HUD node and runtime behavior assertions.
- Modify: `scenes/ui/Tavern.tscn` - adds `RewardFeedbackLayer`, `TopPanel/GoldProgress`, and `TopPanel/ReputationProgress` without renaming existing nodes.
- Modify: `scripts/ui/tavern_view.gd` - loads reward HUD art, updates progress fill clips, spawns reward particles, and flashes ornate milestone states.
- Modify: `scripts/game_manager.gd` - captures previous totals and calls `TavernView.show_order_reward_feedback()` only after successful rewards.

## Task 1: Reward HUD Asset Pipeline

**Files:**
- Create: `scripts/test/test_tavern_reward_hud_asset_pipeline.py`
- Create: `scripts/tools/export_tavern_reward_hud_assets.py`
- Create: `art_sources/generated_raw/tavern_reward_hud/tavern_reward_hud_sheet_v1.png`
- Create: `art_sources/generated_raw/tavern_reward_hud/tavern_reward_hud_sheet_v1_prompt.txt`
- Create: `assets/source/tavern/reward_hud/tavern_reward_hud_manifest.json`
- Create: `assets/source/tavern/reward_hud/*_native.png`
- Create: `assets/textures/ui/reward_hud/*.png`
- Create: `docs/art/tavern_reward_hud_contact_sheet.png`

- [ ] **Step 1: Generate raw source art with built-in imagegen**

Use this prompt:

```text
Use case: stylized-concept
Asset type: pixel-game UI source sheet for a Godot tavern management game
Primary request: Create a clean source sheet on a perfectly flat solid #ff00ff chroma-key background with separate UI reward HUD assets and no readable text.
Subject: two narrow horizontal milestone progress bars, two matching filled bar strips, two ornate completed/level-up rim overlays, a small gold coin particle, a small cool silver-blue reputation sigil particle, and a tiny amber spark.
Style/medium: authored pixel-game UI source art, historical printmaking influence, rough ink silhouettes, dark teal dungeon tavern material, warm amber candlelight for gold, cool stone-blue accent for reputation.
Composition/framing: all assets separated with generous padding, no overlap, arranged in a grid, front-facing orthographic UI sprites, crisp silhouettes.
Color palette: dark teal and near-black wood/stone bodies; muted amber/gold highlights; cool blue-gray reputation highlights; sparse bright pixels only for reward glints.
Materials/textures: chunky low-density pixel clusters, rough ink edges, paper-grain suggestion baked into ornamental frames only, no soft blur.
Constraints: no text, no numbers, no logos, no characters, no UI labels, no gradients that would blur after pixel normalization, no shadows on the chroma-key background, no antialiased soft borders.
Avoid: references to existing games, living artists, readable writing, fake interface text, modern flat vector style, smooth glossy mobile-game icons.
```

Save the generated image as `art_sources/generated_raw/tavern_reward_hud/tavern_reward_hud_sheet_v1.png`.

- [ ] **Step 2: Save the prompt**

Write the exact prompt from Step 1 to `art_sources/generated_raw/tavern_reward_hud/tavern_reward_hud_sheet_v1_prompt.txt`.

- [ ] **Step 3: Write the failing asset test**

Create `scripts/test/test_tavern_reward_hud_asset_pipeline.py` with tests that assert:

```python
ASSETS = {
    "reward_gold_progress_bg": ((48, 12), (192, 48)),
    "reward_gold_progress_fill": ((48, 12), (192, 48)),
    "reward_gold_progress_ornate": ((48, 12), (192, 48)),
    "reward_rep_progress_bg": ((48, 12), (192, 48)),
    "reward_rep_progress_fill": ((48, 12), (192, 48)),
    "reward_rep_progress_ornate": ((48, 12), (192, 48)),
    "reward_coin_particle": ((8, 8), (32, 32)),
    "reward_rep_particle": ((8, 8), (32, 32)),
    "reward_spark": ((6, 6), (24, 24)),
}
```

The test must check raw source and prompt existence, manifest completeness, runtime sizes, exact 4x nearest-neighbor export, visible non-transparent pixels, warm pixels in coin/gold assets, and cool pixels in reputation assets.

- [ ] **Step 4: Run asset test to verify RED**

Run:

```powershell
python -m unittest scripts.test.test_tavern_reward_hud_asset_pipeline.TavernRewardHudAssetPipelineTest -v
```

Expected: FAIL because the exporter, manifest, and runtime assets are not implemented yet.

- [ ] **Step 5: Write exporter**

Create `scripts/tools/export_tavern_reward_hud_assets.py` with explicit `ASSETS` entries for every ID, output native files under `assets/source/tavern/reward_hud/`, output runtime files under `assets/textures/ui/reward_hud/`, write `tavern_reward_hud_manifest.json`, and write `docs/art/tavern_reward_hud_contact_sheet.png`.

Use 4x nearest-neighbor runtime scaling and fixed crop rectangles chosen from the generated sheet after visual inspection.

- [ ] **Step 6: Run exporter**

Run:

```powershell
python scripts/tools/export_tavern_reward_hud_assets.py
```

Expected: prints `exported Tavern reward HUD assets` and writes manifest, runtime assets, native assets, and contact sheet.

- [ ] **Step 7: Run asset test to verify GREEN**

Run:

```powershell
python -m unittest scripts.test.test_tavern_reward_hud_asset_pipeline.TavernRewardHudAssetPipelineTest -v
```

Expected: PASS.

## Task 2: Tavern Reward HUD Contract Test

**Files:**
- Modify: `scripts/test/test_tavern_patience_ui.gd`

- [ ] **Step 1: Write failing Tavern HUD contract assertions**

Extend `_test_tavern_patience_ui_contract()` to assert:

```gdscript
var reward_layer := tavern.get_node_or_null("RewardFeedbackLayer") as CanvasLayer
_ok(reward_layer != null, "Tavern adds a visual-only RewardFeedbackLayer for flying rewards")

var gold_progress := tavern.get_node_or_null("TopPanel/GoldProgress") as Control
var rep_progress := tavern.get_node_or_null("TopPanel/ReputationProgress") as Control
_ok(gold_progress != null, "TopPanel adds GoldProgress without replacing GoldLabel")
_ok(rep_progress != null, "TopPanel adds ReputationProgress without replacing ReputationLabel")
_ok(tavern.has_method("show_order_reward_feedback"), "TavernView exposes reward feedback method")
```

Also assert that the new controls ignore mouse input, that `GoldProgress/FillClip` and `ReputationProgress/FillClip` exist, and that calling:

```gdscript
tavern.update_top_bar(25, 10, 1, 30)
tavern.show_order_reward_feedback(12, 2, 13, 8)
```

spawns at least one child under `RewardFeedbackLayer`.

- [ ] **Step 2: Run Tavern test to verify RED**

Run with the local Godot 4.6.3 console executable:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . --scene res://scenes/test/test_tavern_patience_ui.tscn
```

Expected: FAIL because the nodes and method do not exist yet.

## Task 3: Tavern Scene and View Implementation

**Files:**
- Modify: `scenes/ui/Tavern.tscn`
- Modify: `scripts/ui/tavern_view.gd`

- [ ] **Step 1: Add scene nodes**

Add nodes without renaming existing public nodes:

```text
TopPanel/GoldProgress
TopPanel/GoldProgress/Bg
TopPanel/GoldProgress/FillClip
TopPanel/GoldProgress/FillClip/Fill
TopPanel/GoldProgress/Ornate
TopPanel/ReputationProgress
TopPanel/ReputationProgress/Bg
TopPanel/ReputationProgress/FillClip
TopPanel/ReputationProgress/FillClip/Fill
TopPanel/ReputationProgress/Ornate
RewardFeedbackLayer
RewardFeedbackLayer/Particles
```

Keep all controls `mouse_filter = MOUSE_FILTER_IGNORE`.

- [ ] **Step 2: Add TavernView member variables and constants**

Add variables for progress nodes, fill clips, ornate overlays, and particle root. Add milestone arrays:

```gdscript
const GOLD_PROGRESS_THRESHOLDS := [0, 50, 100, 200, 400]
const REP_PROGRESS_THRESHOLDS := [0, 50, 150]
const REWARD_PARTICLE_TRAVEL_TIME := 0.72
```

- [ ] **Step 3: Load textures and configure reward HUD**

Add `_configure_reward_hud()` called from `_ready()` after `_configure_topbar_layout()`. It should load runtime textures from `res://assets/textures/ui/reward_hud/`, set nearest filtering, hide ornate overlays by default, and call `_refresh_reward_progress()`.

- [ ] **Step 4: Implement progress helpers**

Implement:

```gdscript
func _progress_ratio_for_thresholds(value: int, thresholds: Array) -> float
func _progress_band_for_thresholds(value: int, thresholds: Array) -> int
func _set_reward_fill(progress_root: Control, ratio: float) -> void
func _refresh_reward_progress(gold: int, rep: int) -> void
```

Gold after 400 uses repeating 400-point bands. Reputation after 150 stays full in this first pass.

- [ ] **Step 5: Implement public feedback API**

Implement:

```gdscript
func show_order_reward_feedback(earned_gold: int, earned_rep: int, previous_gold: int, previous_rep: int) -> void
```

It should spawn gold particles when `earned_gold > 0`, reputation particles when `earned_rep > 0`, pulse the matching label, and flash ornate overlays when the previous and current totals cross a milestone band.

- [ ] **Step 6: Run Tavern test to verify GREEN**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . --scene res://scenes/test/test_tavern_patience_ui.tscn
```

Expected: PASS.

## Task 4: GameManager Reward Feedback Routing

**Files:**
- Modify: `scripts/test/test_impact_magic.gd`
- Modify: `scripts/game_manager.gd`

- [ ] **Step 1: Write failing GameManager routing test**

Add a duck-typed Tavern test double in `scripts/test/test_impact_magic.gd` with:

```gdscript
var reward_feedback_calls: Array = []
func show_order_reward_feedback(earned_gold: int, earned_rep: int, previous_gold: int, previous_rep: int) -> void:
    reward_feedback_calls.append({
        "earned_gold": earned_gold,
        "earned_rep": earned_rep,
        "previous_gold": previous_gold,
        "previous_rep": previous_rep,
    })
```

Set up a successful order, call `GameManager.request_serve()`, and assert one call with previous totals. Set up a failed order and assert no new feedback call.

- [ ] **Step 2: Run GameManager test to verify RED**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . --scene res://scenes/test/test_impact_magic.tscn
```

Expected: FAIL because `GameManager` does not call the new reward feedback method.

- [ ] **Step 3: Implement GameManager call**

In the successful branch of `_on_serve_requested()`, capture:

```gdscript
var previous_gold := economy.gold
var previous_rep := economy.reputation
```

before adding rewards, then after `economy.add_gold()` and `economy.add_reputation()`, call:

```gdscript
if _tavern_view != null and is_instance_valid(_tavern_view) and _tavern_view.has_method("show_order_reward_feedback"):
    _tavern_view.show_order_reward_feedback(earned_gold, earned_rep, previous_gold, previous_rep)
```

Do not call it in failed branches.

- [ ] **Step 4: Run GameManager test to verify GREEN**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . --scene res://scenes/test/test_impact_magic.tscn
```

Expected: PASS.

## Task 5: Final Verification

**Files:**
- Verify all modified files from Tasks 1-4.

- [ ] **Step 1: Run focused asset verification**

Run:

```powershell
python -m unittest scripts.test.test_tavern_reward_hud_asset_pipeline.TavernRewardHudAssetPipelineTest -v
```

Expected: PASS.

- [ ] **Step 2: Run focused Tavern UI verification**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . --scene res://scenes/test/test_tavern_patience_ui.tscn
```

Expected: PASS.

- [ ] **Step 3: Run focused GameManager/economy verification**

Run:

```powershell
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . --scene res://scenes/test/test_impact_magic.tscn
```

Expected: PASS.

- [ ] **Step 4: Inspect diff scope**

Run:

```powershell
git diff --stat -- scripts/test/test_tavern_reward_hud_asset_pipeline.py scripts/tools/export_tavern_reward_hud_assets.py scripts/test/test_tavern_patience_ui.gd scripts/test/test_impact_magic.gd scenes/ui/Tavern.tscn scripts/ui/tavern_view.gd scripts/game_manager.gd assets/source/tavern/reward_hud assets/textures/ui/reward_hud art_sources/generated_raw/tavern_reward_hud docs/art/tavern_reward_hud_contact_sheet.png
```

Expected: diff is limited to the reward HUD feature and generated assets.

## Self-Review

- The plan covers every design spec section: scope, behavior, HUD structure, progress rules, runtime API, visual assets, tests, and verification.
- The plan preserves existing Tavern public paths and modifies one UI surface.
- The plan uses generated source art but requires processed runtime assets for Godot.
- The plan starts with failing tests before production code changes.
- The plan contains no ambiguous implementation placeholders.
