# DayMap Art Completion Design

## Background

DayMap already has an unfinished native-pixel pipeline:

- `scripts/tools/export_daymap_assets.py`
- `scripts/test/test_daymap_asset_pipeline.py`
- `assets/source/daymap/`
- `assets/textures/daymap/`

The current gap is runtime integration and art direction. `day_map_view.gd` still replaces the background with a generated gradient, and `MapPointMarker` still draws procedural circles instead of using the exported marker icons.

The title screen works because its process was closed-loop: generate or collect visual reference first, normalize the result onto a native pixel grid, export runtime textures only by integer nearest-neighbor scaling, then protect dimensions, alpha, color density, and readable coverage with tests. DayMap should use the same process.

## Goal

Finish DayMap art so it belongs to the same visual family as the title screen:

- dark teal dungeon palette
- sparse amber light accents
- low-density chunky pixel clusters
- no direct high-resolution generated art in runtime textures
- independent dynamic marker icons instead of baked-in background labels

## Visual Direction

The DayMap background is a **top-down orthographic action map** laid flat on a dark tavern table or bar counter. It is not a perspective illustration of a table.

Layering:

1. Bottom layer: dark wood tabletop/bar surface with dark teal dungeon shadows around the edges.
2. Middle layer: a muted old map sheet, seen from directly above.
3. Runtime layer: independent marker icons, labels, hover rings, selected rings, reveal animation, and click handling.

The background map can contain route lines, broad cave shapes, river strokes, and landmark silhouettes, but it must not contain baked Chinese location names or final marker icons. Home can be suggested by an amber-lit region on the map, but the actual home icon remains a runtime marker asset.

## Reference Generation

Use image generation for concept/reference only. The generated image should help establish top-down composition, palette, light placement, and density. It must not be used directly as a runtime texture.

Correct reference prompt direction:

- top-down orthographic view
- old cave route map laid flat on a dark wooden tavern table/bar counter
- no perspective table scene
- no in-image text, labels, UI, logo, or watermark
- dark teal dungeon shadows around the map
- one sparse amber home/light focus
- route network and symbolic landmark shapes only
- intended to be normalized to `320x180`

Save the selected reference under:

`assets/source/daymap/reference/daymap_reference.png`

Runtime textures still come only from the deterministic Pillow exporter.

## Asset Pipeline

Background:

- Native source: `assets/source/daymap/daymap_bg_native.png`
- Runtime texture: `assets/textures/daymap/daymap_bg.png`
- Native size: `320x180`
- Runtime size: `1280x720`
- Scale: `4x`
- Resampling: `Image.Resampling.NEAREST`

Marker icons:

- Native source: `assets/source/daymap/markers/<location_id>_native.png`
- Runtime texture: `assets/textures/daymap/markers/<location_id>.png`
- Native size: `24x24`
- Runtime size: `96x96`
- Scale: `4x`
- Must have alpha and controlled color count.

Required markers:

- `home`
- `mushroom_forest`
- `dark_river`
- `grape_trellis`
- `mill_farm`
- `mercenary_board`
- `abandoned_mine`
- `guild_counter`

## Runtime Integration

`DayMap.tscn` keeps `MapWorld/Background` as the map background sprite, but its texture should be `res://assets/textures/daymap/daymap_bg.png`. `_setup_background()` should load this texture and set nearest filtering. It must not create a gradient texture over the final art.

`MapPointMarker` should load `res://assets/textures/daymap/markers/<location_id>.png`. The home marker uses `home.png` when `location_id == "__home__"` or `set_home(true)` is called.

If a marker texture is missing, the old procedural circle can remain as a fallback. That fallback protects the gameplay loop from bad assets, but it should not be the normal path.

Location labels remain Godot-rendered text using the project pixel font. Labels are not baked into PNG assets because location names are runtime data and use Chinese text.

## Interaction States

Normal:

- Shows the marker icon.
- Keeps the label readable over the map.

Hover:

- Slight icon brightening toward amber.
- Small scale bump, around `1.08`.
- Weak pixel ring.

Selected:

- Stronger amber ring.
- Scale around `1.12`.
- Label color shifts to `ThemeColors.AMBER_PRIMARY`.

Home:

- Uses the same marker system.
- May look slightly warmer because the background home region has amber light.

## Tests

Python pipeline tests should verify:

- background native/runtime dimensions
- exact nearest-neighbor export
- opaque background alpha
- controlled color count
- enough dark teal and sparse amber pixels
- marker native/runtime dimensions
- marker alpha and readable visible area
- marker exact nearest-neighbor export
- generated reference stays outside runtime textures

Godot tests should verify:

- DayMap background texture path is `res://assets/textures/daymap/daymap_bg.png`
- `MapPointMarker` creates an `Icon` sprite for a normal marker
- normal marker texture path points to `assets/textures/daymap/markers/<id>.png`
- home marker texture path points to `assets/textures/daymap/markers/home.png`
- click signal behavior remains intact

## Non-Goals

- Do not change DayMap gameplay logic.
- Do not change location unlock/shop/narrative data.
- Do not bake location names into the background.
- Do not bake final marker icons into the background.
- Do not use generated high-resolution art directly in runtime textures.
- Do not touch unrelated working-tree changes.

## Done Criteria

DayMap opens with a top-down map that reads as part of the title screen world: dark teal dungeon shadows, amber home light, low-density native pixels, and clean independent marker icons. Runtime no longer shows a generated gradient background or procedural circle markers in the normal path. Re-running the exporter reproduces every runtime PNG from native source exactly, and the Python and Godot tests pass.
