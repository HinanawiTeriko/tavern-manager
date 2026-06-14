# Tavern Reward HUD Feedback Design

## Goal

Make successful night orders feel rewarding by adding visible motion and stage progress to the Tavern HUD. The player should see earned gold and reputation burst out from the customer area, travel into the top HUD, and advance dedicated milestone bars instead of only watching static numbers change.

## Scope

- Target only the night service surface in `res://scenes/ui/Tavern.tscn`.
- Preserve the existing `TopPanel`, `TopPanel/GoldLabel`, `TopPanel/ReputationLabel`, `TopPanel/DayLabel`, `TopPanel/MenuButton`, and `TopPanel/EndNightBtn` paths.
- Preserve `TavernView.update_top_bar()`, `TavernView.reset_today_gold()`, order serving, inventory, economy, save/load, day map, shop, and settlement behavior.
- Do not change economy amounts, reputation level-up rules, or ledger entries.
- Do not modify DayMap or other UI screens in the first pass.

## Player-Facing Behavior

When an order is served correctly:

- Gold particles burst from the customer/order area, spread briefly, then curve into the gold HUD area.
- If the order awards reputation, reputation particles burst beside the gold particles and curve into the reputation HUD area.
- When particles arrive, the matching HUD number gives a small scale pulse and the matching progress bar flashes.
- If the new total crosses a milestone, the matching progress bar enters a short ornate state for about one second, with a brighter rim and a few spark pixels.
- Failed orders do not trigger reward particles or milestone flashes.

The effect is feedback only. It must not delay guest cleanup, dialogue, ledger updates, or the next order.

## HUD Structure

Add visual-only Tavern nodes while keeping existing public paths stable:

- `RewardFeedbackLayer`: a top-level or CanvasLayer-backed visual-only layer for particles and arrival flashes.
- `TopPanel/GoldProgress`: the gold milestone progress surface, placed near `GoldLabel`.
- `TopPanel/ReputationProgress`: the reputation milestone progress surface, placed near `ReputationLabel`.

The exact child structure can use `TextureRect` plus clipped fill controls, but all new controls must ignore mouse input so they do not block table interaction or topbar buttons.

Text remains Godot-rendered through existing labels. Generated images must not contain readable text, numbers, logos, or fake labels.

## Progress Rules

Gold uses display-only milestone targets:

- 0 to 50
- 50 to 100
- 100 to 200
- 200 to 400
- After 400, continue with 400-point bands unless a later economy design replaces the thresholds.

Reputation uses existing tavern level thresholds where possible:

- 0 to 50
- 50 to 150
- After 150, show a filled ornate bar or continue with 150-point display bands. This is display-only and does not add new tavern levels.

Progress is calculated from the current total and the active threshold band. A crossing is detected when the previous total and new total fall in different bands.

## Runtime API

Add a narrow TavernView method:

```gdscript
func show_order_reward_feedback(earned_gold: int, earned_rep: int, previous_gold: int, previous_rep: int) -> void
```

`GameManager._on_serve_requested()` calls this only after successful order rewards have been calculated. It captures previous totals before `economy.add_gold()` and `economy.add_reputation()`, then passes the earned amounts and previous totals to the view.

`TavernView.update_top_bar()` remains the central place that updates label text and refreshes the progress bar fill ratios from current totals.

## Visual Assets

Use the existing native-pixel asset pipeline pattern used by Tavern topbar and patience UI work:

- Raw source sheet: `art_sources/generated_raw/tavern_reward_hud/tavern_reward_hud_sheet_v1.png`
- Prompt/source notes: `art_sources/generated_raw/tavern_reward_hud/tavern_reward_hud_sheet_v1_prompt.txt`
- Native assets: `assets/source/tavern/reward_hud/*_native.png`
- Runtime assets: `assets/textures/ui/reward_hud/*.png`
- Manifest: `assets/source/tavern/reward_hud/tavern_reward_hud_manifest.json`
- Contact sheet: `docs/art/tavern_reward_hud_contact_sheet.png`

Required asset IDs:

- `reward_gold_progress_bg`
- `reward_gold_progress_fill`
- `reward_gold_progress_ornate`
- `reward_rep_progress_bg`
- `reward_rep_progress_fill`
- `reward_rep_progress_ornate`
- `reward_coin_particle`
- `reward_rep_particle`
- `reward_spark`

Every crop must come from explicit manifest rectangles. Runtime exports must be exact nearest-neighbor integer scaling from native sources. Godot runtime scenes must reference only processed runtime textures, not raw generated sources.

## Testing Contract

Before modifying the Tavern scene, add or update a Tavern HUD contract test to verify:

- Existing topbar public paths still exist.
- `GoldProgress`, `ReputationProgress`, and `RewardFeedbackLayer` exist after the scene instantiates.
- New reward controls use nearest texture filtering where applicable.
- New reward controls ignore mouse input.
- `TavernView` exposes `show_order_reward_feedback()`.
- Calling the feedback method with positive gold spawns gold particles under the feedback layer.
- Calling it with positive reputation spawns reputation particles under the feedback layer.
- `update_top_bar()` updates progress fill ratios for gold and reputation totals.
- Crossing a milestone activates a temporary ornate state.

Add or update a GameManager-facing test to verify:

- Successful orders call the Tavern reward feedback method with earned gold, earned reputation, and previous totals.
- Failed orders do not call the reward feedback method.

Add an asset pipeline test to verify:

- The raw source and prompt are retained.
- The manifest lists every reward HUD asset with source, native, runtime, size, safe area, and intended Godot use.
- Runtime textures are exact nearest-neighbor exports from native textures.
- Particle textures are small, crisp, and contain visible warm gold or cold reputation accent pixels.
- Progress bar textures stay restrained: dark teal body, amber gold fill, and cooler reputation fill.

## Verification

Focused verification after implementation:

```powershell
python -m unittest scripts.test.test_tavern_reward_hud_asset_pipeline.TavernRewardHudAssetPipelineTest -v
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . --scene res://scenes/test/test_tavern_patience_ui.tscn
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . --scene res://scenes/test/test_impact_magic.tscn
```

If the local Godot binary path differs, use the installed Godot 4.6.3 console executable.

## Anticipated Implementation Files

- `scripts/test/test_tavern_reward_hud_asset_pipeline.py`
- `scripts/tools/export_tavern_reward_hud_assets.py`
- `scripts/test/test_tavern_patience_ui.gd` or a new focused Tavern reward HUD scene test
- `scenes/test/test_tavern_reward_hud.tscn` if a separate scene test is cleaner
- `scenes/ui/Tavern.tscn`
- `scripts/ui/tavern_view.gd`
- `scripts/game_manager.gd`
- New processed assets and manifest listed above

## Self-Review

- No placeholders or deferred requirements remain.
- The scope is limited to one UI surface: Tavern night service.
- Existing public node paths and public methods are preserved.
- The reward HUD is display-only and does not alter economy, save/load, ledger, guests, or narrative logic.
- The design follows the project asset pipeline rule: generated sources are retained, production UI references processed runtime textures only, and text stays in Godot labels.
