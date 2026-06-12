# DayMap Pinned Note Detail UI Design

Date: 2026-06-12
Status: approved for specification review

## Context

DayMap currently uses a zoomable `MapWorld` with `Camera2D` and a fixed `UILayer` `CanvasLayer`. Location markers live under `MapWorld/Points`, while the existing location detail UI lives at `UILayer/DetailPanel` with the child paths `Name`, `Desc`, `Cost`, `Yield`, and `GoHereBtn`.

The new UI direction is to replace the visible right-side detail panel with a small knife pinning a paper note to the map when a location is selected. The note should follow the selected marker on screen, sit to the marker's right side, and stay the same pixel size while the map is panned or zoomed.

## Goals

- Show selected location details as a pinned note placed to the right of the selected marker.
- Keep the note and knife in screen space so they do not scale with the map camera.
- Preserve existing DayMap behavior: marker selection, visit/shop/home actions, result panel, investigation entry, inventory, document overlay, and camera controls.
- Preserve legacy detail panel node paths and public behavior contracts until the replacement has been verified.
- Use the DayMap native-pixel UI art pipeline for any new production knife or note textures.

## Non-Goals

- Do not change location data semantics, rewards, stamina cost, shop opening, or investigation logic.
- Do not rename `DayMapView`, `MapPointMarker`, existing signals, public methods, or autoload APIs.
- Do not delete `UILayer/DetailPanel` or its existing child nodes.
- Do not migrate shop, inventory, document, result, or topbar UI in this change.
- Do not bake readable UI text into generated image assets.

## Recommended Approach

Add a new screen-space pinned note component under `UILayer`, tentatively named `PinnedNotePanel`. It displays the same data currently written into `DetailPanel`: name, description, cost, yield, and the action button.

The component is positioned by projecting the selected marker's world position into viewport coordinates each frame while a marker is selected. Its visual root stays in `UILayer`, so it follows marker movement caused by camera pan and zoom but keeps a fixed runtime pixel size.

The legacy `DetailPanel` remains in the scene and keeps its node paths. During the replacement, it can be hidden as the visible UI, while code continues to populate compatible data paths or helper methods so existing tests and future rollback remain straightforward.

## Scene Structure

Target structure:

```text
DayMap
+-- MapWorld
|   +-- Background
|   +-- Camera2D
|   +-- Points
|       +-- MapPointMarker instances
+-- UILayer
    +-- TopBar
    +-- MapArea
    +-- DetailPanel              # legacy contract, retained
    +-- PinnedNotePanel          # new visible selected-location detail
    |   +-- KnifeArt             # TextureRect or TextureButton-style art, non-text
    |   +-- NoteArt              # TextureRect / NinePatchRect-style paper
    |   +-- Name
    |   +-- Desc
    |   +-- Cost
    |   +-- Yield
    |   +-- GoHereBtn
    +-- ResultPanel
    +-- DocumentOverlay
    +-- InventoryOverlay
```

The exact node names can change during implementation if tests and scripts define a better local pattern, but no existing node path should be removed or renamed.

## Positioning Behavior

`PinnedNotePanel` uses the selected marker's world position as its anchor.

- Default placement: marker screen position plus a right-side offset.
- Knife placement: between marker and note, visually pinning the paper near the note's left edge.
- Size: fixed runtime dimensions, independent of `Camera2D.zoom`.
- Clamping: keep the note inside the 1280x720 viewport with safe margins. If the marker is too close to the right edge, flip the note to the left side while preserving the "knife pins note to map" read.
- Visibility: hidden when no marker is selected, when a visit result panel is shown, while shop overlay is open, during investigation scenes, or when DayMap is reset for a new day.
- Camera motion: update during `_process` or through a dedicated layout refresh whenever the camera moves or zooms.

If Godot's camera helper APIs are reliable in this project version, use them to convert marker world coordinates to screen coordinates. Otherwise, implement a small, tested DayMap-specific projection helper based on viewport size, camera position, and camera zoom.

## Data Flow

Selection keeps the existing route:

```text
MapPointMarker.clicked -> DayMapView._select_marker(id)
```

After `_selected_id` changes:

- Update marker selected state as today.
- Resolve location data from `GameManager.day_map.get_locations()` or the home sentinel.
- Populate legacy `DetailPanel` fields for contract stability.
- Populate `PinnedNotePanel` fields for the new visible UI.
- Show the pinned note.

Action keeps the existing route:

```text
PinnedNotePanel/GoHereBtn.pressed -> DayMapView._on_go_here_pressed()
```

The action button should reuse the same handler as the legacy detail button. There should not be a second copy of visit, shop, or home-entering logic.

## Art Direction

The note should feel like a tabletop dungeon tavern map object:

- dark teal shadow mass and warm amber accents consistent with DayMap/title UI;
- parchment paper with rough pixel edges and sparse grain;
- a small knife or dagger silhouette used as the pin;
- no readable text, numbers, logos, or labels baked into the image;
- crisp native-pixel silhouettes with no soft antialiasing or subpixel blur.

The visible text remains Godot `Label` text using the DayMap pixel font.

## Asset Pipeline

New production assets should extend the existing DayMap UI pipeline:

```text
assets/source/daymap/ui/
assets/textures/daymap/ui/
scripts/tools/export_daymap_ui_assets.py
scripts/test/test_daymap_ui_asset_pipeline.py
```

Likely new assets:

- `pinned_note_panel_native.png` -> `pinned_note_panel.png`
- `pinned_note_knife_native.png` -> `pinned_note_knife.png`

If multiple visual states are needed later, add them in a separate slice. The first slice only needs normal visible state art. Runtime textures must be exact nearest-neighbor exports from native sources.

## Contract And Test Updates

Before changing visible UI behavior, update the DayMap UI contract tests.

Required assertions:

- Legacy `UILayer/DetailPanel`, `Name`, `Desc`, `Cost`, `Yield`, and `GoHereBtn` still exist.
- New `UILayer/PinnedNotePanel` exists and is not under `MapWorld`.
- Selecting a marker shows exactly one selected marker ring and shows the pinned note.
- The pinned note keeps the same size when camera zoom changes.
- The pinned note's screen position changes when the camera pans or zooms around the selected marker.
- The pinned note hides when selection is cleared, shop opens, a visit result is shown, or investigation takes over.
- The pinned action button routes through the existing `_on_go_here_pressed()` behavior.
- New texture assets, if added, pass exact native-to-runtime export checks.

Existing tests likely affected:

- `scripts/test/test_day_map_scrollbars.gd`
- `scripts/test/test_daymap_selection.gd`
- `scripts/test/test_daymap_visual_hierarchy.gd`
- `scripts/test/test_daymap_ui_asset_pipeline.py`

## Files Planned For Implementation

Expected implementation files:

- `scenes/ui/DayMap.tscn` for adding the new pinned note nodes while keeping legacy nodes.
- `scripts/ui/day_map_view.gd` for positioning, data population, visibility, and action routing.
- `scripts/test/test_day_map_scrollbars.gd` and focused DayMap tests for the updated contract.
- `scripts/tools/export_daymap_ui_assets.py` and `scripts/test/test_daymap_ui_asset_pipeline.py` only if new knife/note textures are added in the first implementation slice.
- `assets/source/daymap/ui/` and `assets/textures/daymap/ui/` only for generated native/runtime UI assets.

Do not touch unrelated gameplay, economy, save/load, input, or simulation logic.

## Verification

Run focused checks after implementation:

```powershell
python -m unittest scripts.test.test_daymap_ui_asset_pipeline -v
godot --headless --path . --quit-after 5 --scene res://scenes/test/test_day_map_scrollbars.tscn
godot --headless --path . --quit-after 5 --scene res://scenes/test/test_daymap_selection.tscn
godot --headless --path . --quit-after 5 --scene res://scenes/test/test_daymap_visual_hierarchy.tscn
```

If the local Godot executable is not on `PATH`, use the repository's normal Godot command equivalent.

## Open Implementation Decision

The implementation plan should decide whether the first slice uses new production textures immediately or a minimal texture-free layout adapter first. If textures are added immediately, the pipeline and contact sheet/report requirement applies in the same change.
