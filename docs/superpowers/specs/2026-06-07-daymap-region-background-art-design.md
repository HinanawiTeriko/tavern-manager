# DayMap Region Background Art Design

Date: 2026-06-07
Branch: feat/blacksouls-intro
Status: design approved, ready for implementation planning

## Context

DayMap already has the core runtime shape for a larger map:

- `data/locations.json` defines a `2x2` region grid: `market`, `wilds`, `north_road`, and `fog`.
- `DayMapSystem` converts each location from region-local coordinates into world coordinates.
- `DayMapCamera` can pan and zoom inside the union of all regions.
- `DayMapView` tries to load `res://assets/textures/daymap/regions/<id>.png` for each region and falls back to flat tint textures when those files are missing.
- The existing native-pixel DayMap pipeline covers the single `daymap_bg` background and marker icons, but it does not yet produce four region background tiles.

The current work is specifically about the four background tiles. UI polish, shop redesign, and gameplay changes are out of scope for this slice.

## Goal

Create a complete, usable four-region DayMap background set that matches the current title and main UI visual language:

- dark teal dungeon atmosphere
- sparse amber light accents
- low-density chunky pixel clusters
- native source under `assets/source/daymap/regions/`
- runtime textures under `assets/textures/daymap/regions/`
- exact integer nearest-neighbor scaling from native to runtime

The result should make the zoomed-out DayMap read as one coherent map, not four unrelated screens.

## Chosen Approach

Use one large composition first, then split it into four tiles.

Production composition:

- Full native composition: `640x360`
- Runtime assembled map: `2560x1440`
- Region native tile: `320x180`
- Region runtime tile: `1280x720`
- Scale: `4x`

Layout:

```text
market      wilds
north_road  fog
```

This approach keeps roads, rivers, paper texture, shadows, and lighting continuous across region edges. It is preferred over painting four independent images because the player can zoom out and see the entire `2x2` map at once.

## Visual Model

The DayMap is an underground route map laid on a dark tavern table. It is not a clean fantasy overworld map and not a modern UI panel.

Layering:

1. Dark wood tabletop or bar surface, using deep teal and near-black shadow.
2. A worn parchment or cave-route map surface.
3. Low-contrast landmark drawings that tell the player what each marker sits on.
4. Runtime markers, labels, hover rings, selected rings, and reveal effects.

The background must not contain final map pins, labels, task icons, hover rings, selected rings, UI text, buttons, or readable location names. Those are runtime layers.

## Region Art Direction

### Market

`market` is the player's daylight hub and keeps the warmest tone of the four tiles.

It should include:

- the tavern/home landmark
- a small market road network
- a mercenary or Toby posting board
- Mira's traveling stall
- Toby's lodging in a back lane
- a fixer den or dark alley

Amber light can appear near the tavern and stall, but it should stay sparse. The marker layer must remain the strongest read.

### Wilds

`wilds` is the main gathering region.

It should include:

- damp mushroom forest silhouettes
- a dark underground river
- grape trellis shapes
- a mill or farm patch
- cave moss, wet stone, and teal shadow

This tile can be greener and cooler than `market`, but it should still belong to the same parchment/table map. The river or road should help connect visually to neighboring tiles.

### North Road

`north_road` is the investigation and risk region.

It should include:

- a stronger abandoned mine entrance
- a mercenary route or posting board
- a guild counter or field office landmark
- broken road, mine timber, stone debris, and colder shadows

The mine entrance should be the strongest landmark in this tile, but not a finished marker icon.

### Fog

`fog` is a non-interactive unknown region.

It should include:

- fog banks
- broken routes
- distant cave walls, dark slopes, or submerged map detail
- no interactable landmark that looks clickable

This tile exists to complete the `2x2` rectangle, prevent exposed empty background during camera movement, and imply future expansion.

## Marker Landing Coordinates

Coordinates below are native region-local positions. Runtime positions are the current `data/locations.json` values divided by `4`.

```text
market:
home tavern                  (86, 125)
mercenary/Toby posting board (75, 60)
Mira stall                   (245, 75)
Toby lodging                 (63, 155)
fixer den                    (250, 150)

wilds:
mushroom forest              (139, 139)
dark river                   (165, 144)
grape trellis                (239, 118)
mill farm                    (219, 130)

north_road:
mercenary board              (126, 90)
abandoned mine               (233, 56)
guild counter                (196, 84)

fog:
no markers
```

Each marker landing area needs at least a `20x20` native readable zone. The zone should contain a low-contrast supporting landmark or ground shape, but avoid strong outlines, bright highlights, readable text, or dense details directly under the marker.

Runtime marker icons are `24x24` native sources exported to `96x96`. Marker state textures are larger, so the background must leave visual room for base, hover, selected, and reveal overlays.

## Seam Rules

All four regions are one map split into tiles. The seams need planned continuity:

- `market` to `wilds`: roads or a river route should continue across the vertical seam. Do not cut a large building on the seam.
- `market` to `north_road`: the main route and parchment/table shadow should continue down across the horizontal seam.
- `wilds` to `fog`: terrain should fade into fog, ink wash, or cave shadow toward the lower-right direction.
- `north_road` to `fog`: a mine road, broken bridge, or path should enter fog and lose detail.
- All tiles share one parchment texture and one tabletop lighting model. Do not give each tile its own complete paper border.

The assembled `640x360` native image should be inspected before export. If the seams look like separate pasted maps, the art is not accepted.

## Pipeline Design

Add region support to the existing DayMap pipeline rather than introducing a parallel process.

Expected source files:

```text
assets/source/daymap/regions/market_native.png
assets/source/daymap/regions/wilds_native.png
assets/source/daymap/regions/north_road_native.png
assets/source/daymap/regions/fog_native.png
```

Expected runtime files:

```text
assets/textures/daymap/regions/market.png
assets/textures/daymap/regions/wilds.png
assets/textures/daymap/regions/north_road.png
assets/textures/daymap/regions/fog.png
```

If high-resolution reference art is used, keep it under:

```text
assets/source/daymap/regions/reference/
```

The production exporter must:

- validate each region native tile is `320x180`
- validate each runtime tile is `1280x720`
- validate background alpha is opaque
- export runtime by exact `Image.Resampling.NEAREST`
- reject empty or low-complexity placeholder tiles
- keep the current marker pipeline intact

## Runtime Integration

`DayMapView._region_texture()` already checks:

```text
res://assets/textures/daymap/regions/<region_id>.png
```

The implementation should produce those files so the fallback tint path is no longer used in normal play.

No gameplay logic changes are required for this art slice. Location data, camera bounds, and marker placement already provide the needed structure.

## Tests

Python pipeline tests should expand `scripts/test/test_daymap_asset_pipeline.py` to cover region backgrounds:

- each native region file exists
- each native region is `320x180`
- each runtime region file exists
- each runtime region is `1280x720`
- each runtime region is byte-identical to native resized `4x` with nearest-neighbor
- each region background is effectively opaque
- region outputs are not empty flat-color placeholders

Existing marker tests should continue to pass.

Godot regression tests should confirm DayMap still creates four `RegionTile_<id>` sprites with textures. Existing `test_day_map_scrollbars.gd` already checks this structure and should remain green after real assets are added.

## Visual Acceptance

The final DayMap art passes when:

- zoomed out, the `2x2` map reads as one coherent image
- no seam looks like a hard accidental cut
- each marker sits on a recognizable but subdued landmark
- `fog` looks intentionally unknown, not unfinished
- title-screen palette continuity is visible: deep teal shadows, amber accents, chunky pixel clusters
- no text or final marker symbols are baked into the background
- the normal runtime path uses region PNGs, not tint fallback textures

## Non-Goals

- Do not redesign the DayMap UI in this slice.
- Do not change shop behavior or layout in this slice.
- Do not change location unlock logic.
- Do not bake Chinese labels into background art.
- Do not place generated high-resolution art directly in `assets/textures/`.
- Do not treat image-generation "pixel art" output as final runtime art without the native-pixel pipeline.

## Risks

The main risk is producing four attractive tiles that do not assemble into one map. This is why the source composition should be reviewed as a full `640x360` native canvas before splitting.

The second risk is over-detailed landmarks under markers. Landmarks should support recognition; runtime marker art should own interaction readability.

## Done Criteria

The slice is done when four region native files and four region runtime files exist, the exporter can reproduce runtime output deterministically, pipeline tests pass, DayMap loads the region PNGs in normal play, and a visual inspection of the assembled map confirms coherent seams and readable marker landing zones.

## Self-Review Notes

- Placeholder scan: no unresolved `TBD`, `TODO`, or `FIXME` entries. The word `placeholder` appears only in rejection criteria for flat temporary art.
- Consistency check: region layout, source/runtime dimensions, marker coordinates, and existing `DayMapView._region_texture()` path convention all match the current codebase.
- Scope check: this spec is limited to four region background tiles and their pipeline/test contracts. DayMap UI redesign and gameplay changes are explicitly excluded.
- Ambiguity check: the selected production approach is one full `640x360` native composition split into four `320x180` tiles, not four independent paintings.
