# Tavern Background And Counter Design

- Date: 2026-06-12
- Scope: `scenes/ui/Tavern.tscn` night service background and foreground counter art
- Status: design approved by user, awaiting implementation plan
- Generated reference: `art_sources/generated_raw/tavern_background/tavern_background_no_people_reference_v1.png`
- Prompt record: `art_sources/generated_raw/tavern_background/tavern_background_no_people_prompt_v1.txt`

## Goal

Replace the current empty Tavern background with a production art background that reads as an underground tavern from the bartender's side of the counter.

The background must use the approved no-people direction: a left-side door, right-side stone fireplace, dark teal stone walls, wooden beams, shelves, and many empty tables/chairs in the middle ground. It should feel furnished and busy in layout, but there must be no people, no patron silhouettes, no faces, and no character-like bodies in the background.

The foreground counter should be rebuilt from the same approved visual direction because the generated counter reads better than the current work surface. The counter remains a separate `TabletopArt` runtime layer so the physics system stays aligned to the existing work surface.

## Non-Goals

- Do not add people or crowd silhouettes to the background.
- Do not change cooking, serving, drag physics, inventory, economy, save/load, dialogue, or guest logic.
- Do not move or resize `BarWorkspace/World/Walls/Ground`, `LeftWall`, or `RightWall`.
- Do not rename existing nodes, signals, public methods, autoload APIs, or gameplay resource paths.
- Do not bake UI text, orders, item icons, customer portraits, labels, numbers, or interactable markers into background art.
- Do not reference generated raw images directly from Godot runtime scenes.

## Visual Direction

The camera is behind the bar looking into the tavern room.

Required composition:

- Left side: heavy dark entrance door or doorway with stone frame.
- Right side: stone fireplace/hearth as the primary warm amber focal point.
- Middle ground: several empty plank tables, stools, benches, and chairs, distributed like the intro second beat's fuller tavern layout.
- Back wall: sparse shelves and broad bottle silhouettes, not dense bottle clutter.
- Ceiling: heavy rough wooden beams.
- Palette: mostly dark teal, blue-green black, soot brown, muted stone gray, and restrained amber highlights.
- Lighting: fireplace and a few table candles may provide warm accents, but the frame must not become orange-dominant.
- Foreground: strong horizontal wooden counter that can be cropped into a standalone `TabletopArt` layer.

The second intro beat remains the spatial-density reference for tables and furniture, but not for people. The service scene must stay empty until gameplay spawns customers through existing scene nodes.

## Asset Contract

Use a Tavern-specific native pixel pipeline:

```text
art_sources/generated_raw/tavern_background/
assets/source/tavern/background/
assets/source/tavern/table/
assets/textures/tavern/background/
assets/textures/tavern/table/
scripts/tools/export_tavern_background_assets.py
scripts/test/test_tavern_background_asset_pipeline.py
docs/art/tavern_background_contact_sheet.png
```

Runtime targets:

```text
assets/source/tavern/background/tavern_bg_native.png     320x180
assets/textures/tavern/background/tavern_bg.png          1280x720
assets/source/tavern/table/tabletop_native.png           320x80
assets/textures/tavern/table/tabletop.png                1280x320
```

The runtime files must be exact 4x nearest-neighbor exports from native source images. The generated reference is retained under `art_sources/generated_raw/`; runtime scenes may only reference `assets/textures/tavern/background/` and `assets/textures/tavern/table/`.

Add or update manifests to record source file, native file, runtime file, size, scale, safe area, crop boxes, and intended Godot use.

## Godot Integration

Keep integration local to `scenes/ui/Tavern.tscn` and `scripts/ui/tavern_view.gd` unless tests prove a helper is needed.

Expected scene behavior:

- `Background` remains the public background node.
- `Background.texture` should resolve to `res://assets/textures/tavern/background/tavern_bg.png`.
- `Background.z_index` remains below the counter and gameplay props.
- `TabletopArt` remains the visual-only foreground counter node.
- `TabletopArt.texture` remains `res://assets/textures/tavern/table/tabletop.png`.
- `TabletopArt.position` remains `Vector2(640, 600)` unless a test-backed visual alignment adjustment is explicitly approved.
- The existing ground collision stays at `Vector2(150, 655)` to `Vector2(1130, 655)`.

If `tavern_view.gd` still needs the legacy background path for older tests, keep `res://assets/textures/backgrounds/tavern_bg.png` as a compatibility copy or fallback, but prefer the new Tavern-specific path for the service scene.

## Tests

Write failing tests before implementation.

Pipeline tests should verify:

- Generated reference and prompt record exist.
- Background native and runtime assets exist at `320x180` and `1280x720`.
- Counter native and runtime assets exist at `320x80` and `1280x320`.
- Runtime images are exact nearest-neighbor 4x exports.
- Background palette has enough dark teal mass and sparse amber accents.
- The native background contains enough table/chair-like furniture silhouettes without character-like portrait regions.
- A contact sheet exists for review.

Godot scene tests should verify:

- `Tavern/Background` uses the new Tavern runtime background texture.
- `Tavern/TabletopArt` still uses the runtime counter texture.
- `Background.z_index < TabletopArt.z_index < 0`.
- `TabletopArt` stays behind gameplay props.
- Existing wall collision segment points remain unchanged.
- Existing patience UI and ledger compatibility nodes remain unchanged.

## Verification

Run at minimum:

```powershell
python -m unittest scripts.test.test_tavern_background_asset_pipeline.TavernBackgroundAssetPipelineTest -v
python -m unittest scripts.test.test_tavern_table_asset_pipeline.TavernTableAssetPipelineTest -v
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_tavern_table_scene.tscn
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_tavern_patience_ui.tscn
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_workspace_scene_recovery.tscn
```

Also inspect the contact sheet and a runtime Tavern screenshot. The screenshot must show an empty but furnished tavern room, a readable left door, right fireplace, and a foreground counter that matches the physics-aligned work surface.

## Risks

The main risk is that the background tables compete with gameplay props or customer UI. Keep the midground darker and lower contrast than the foreground counter and active objects.

Another risk is accidentally treating the generated high-resolution image as final. The implementation must normalize it to a native pixel grid and export runtime textures only by integer nearest-neighbor scaling.

## Completion Criteria

- Tavern no longer shows the old flat placeholder background.
- The room has left door, right fireplace, and enough empty tables/chairs to feel like a tavern.
- There are no people or human silhouettes baked into the background.
- The foreground counter is rebuilt from the approved visual direction and remains physics-aligned.
- Godot scenes reference runtime textures only, never raw generated art.
- Pipeline tests, scene contract tests, and runtime visual review pass.
