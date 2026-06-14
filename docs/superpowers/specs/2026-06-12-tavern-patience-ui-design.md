# Tavern Patience UI Design

## Scope

Update only the Tavern night service UI surface:

- Remove the visible/clickable ledger entrance from the Tavern work surface.
- Preserve the ledger document system, `DocumentOverlay`, `TavernView.open_ledger()`, and `BarWorkspace/World/Ledger` node path for compatibility.
- Replace the placeholder patience bar styling with a small authored pixel UI component.

## Design

The desktop ledger remains in the scene as a hidden compatibility node. It keeps the `ReadableDeskItem` instance path so existing `BarWorkspace` setup code and document tests do not lose their contract, but it is no longer visible or pickable in the Tavern work surface.

The patience UI keeps the existing `CustomerArea/TimerBar` `ProgressBar` path. A new `CustomerArea/PatienceIcon` `TextureRect` sits to the left of it. Runtime text remains Godot-rendered; generated textures contain no readable UI text. The bar uses dark teal slot art, amber fill art, and the existing pixel import path rules under `assets/textures/ui/`.

## Asset Pipeline

Use a generated reference followed by a deterministic native-pixel pipeline:

- Raw generated reference: `art_sources/generated_raw/tavern_patience/patience_meter_reference.png`
- Native sources: `assets/source/ui/patience_bar_*.png`
- Runtime textures: `assets/textures/ui/bar_patience_bg.png`, `assets/textures/ui/bar_patience_fill.png`, `assets/textures/ui/icon_patience.png`
- Export scale: 4x nearest-neighbor
- Tests verify raw source presence, dimensions, generated-art color complexity, and exact nearest-neighbor export.

## UI Contract

The Tavern UI contract must verify:

- `CustomerArea/TimerBar` remains a `ProgressBar`.
- `CustomerArea/PatienceIcon` exists and uses `res://assets/textures/ui/icon_patience.png`.
- `TimerBar` uses the runtime patience background and fill styleboxes.
- `TimerBar` has a stable 300x28 layout and value updates via `TavernView.update_timer()`.
- `BarWorkspace/World/Ledger` still exists for compatibility but is hidden and not pickable.
- Important guests normalize patience against their 90-second maximum so the visual meter starts moving immediately.

## Verification

Run:

```powershell
python -m unittest scripts.test.test_tavern_patience_asset_pipeline.TavernPatienceAssetPipelineTest -v
godot --headless --path . --quit-after 10 --script res://scenes/test/test_tavern_patience_ui.tscn
godot --headless --path . --quit-after 10 --script res://scenes/test/test_tavern_table_scene.tscn
godot --headless --path . --quit-after 10 --script res://scenes/test/test_workspace_scene_recovery.tscn
```
