# Tavern Wood Tabletop Art Design

- Date: 2026-06-12
- Scope: night service scene wooden tabletop art only
- Scene: `scenes/ui/Tavern.tscn`
- Status: approved for spec, awaiting implementation plan approval

## Goal

Replace the current blocky checkerboard-like wooden tabletop in the Tavern night service view with a production pixel-art tabletop asset. The change is limited to the visual table surface. It must not alter cooking, serving, inventory, drag physics, collision walls, customer drop area, economy, or narrative flow.

The tabletop should read as a dark dungeon tavern work surface that supports existing workspace props. It should match the current workspace prop direction: dark wood, chunky pixels, low-density texture, sparse amber edge highlights, and enough visual restraint that dropped items and containers remain readable.

## Non-Goals

- Do not rebuild the whole Tavern background.
- Do not change `BarWorkspace`, `Brewery`, `Grill`, `Pot`, `Spoon`, `SeasoningShaker`, `Ledger`, or item gameplay logic.
- Do not move or resize physics boundaries under `BarWorkspace/World/Walls`.
- Do not rename existing scene nodes, signals, public methods, autoload APIs, or resource paths used by existing code.
- Do not bake text, icons, customer portraits, orders, item state, or interactable markers into the tabletop.
- Do not delete the legacy `Background` node or existing fallback background path.

## Recommended Approach

Use an independent tabletop visual layer in `Tavern.tscn`.

Add a new visual-only node for the table surface, placed between the full-screen background and the interactive workspace props. The node references a generated runtime texture under `assets/textures/tavern/table/`. Existing physics remains in `BarWorkspace/World/Walls`, so the visual change cannot shift collision behavior.

This approach is lower risk than replacing the full background because it isolates the table from customer staging, top UI, and future Tavern background work. It is also simpler than a two-layer front lip pass, which can be added later if visual occlusion is wanted.

## Asset Contract

Add a small tabletop-specific pipeline:

```text
art_sources/generated_raw/tavern_table/
assets/source/tavern/table/
assets/textures/tavern/table/
scripts/tools/export_tavern_table_assets.py
scripts/test/test_tavern_table_asset_pipeline.py
docs/art/tavern_table_contact_sheet.png
```

The primary asset is:

```text
assets/source/tavern/table/tabletop_native.png     320x80
assets/textures/tavern/table/tabletop.png          1280x320
assets/source/tavern/table/tabletop_manifest.json
```

The runtime texture must be an exact 4x nearest-neighbor export from the native source. Retain generated or authored source references under `art_sources/generated_raw/tavern_table/` or `assets/source/tavern/table/reference/`, and record the approved source in `tabletop_manifest.json` with source path, native path, runtime path, size, safe area, scale, and intended Godot use.

## Visual Direction

The tabletop should occupy the current lower work surface area and visually replace the flat checkerboard wood. It should be broad and readable at `320x180` composition scale.

Requirements:

- Dark brown wood base with dark teal shadow bias.
- Chunky plank groups or broad board bands, not a fine checker pattern.
- Sparse amber highlights along a few worn edges and cuts.
- Low-density rough marks that do not compete with item icons or physics props.
- A clean enough central safe area for dropped materials, products, pot, grill, barrel, spoon, shaker, ledger, and stage captions.
- No readable text, symbols, logos, fake labels, UI, numbers, or decorative item silhouettes.

Avoid:

- Bright orange or beige-dominant wood.
- High-frequency wood grain.
- Soft antialiasing, painterly blur, glow, or photographic texture.
- Decorative clutter that looks like interactable items.

## Godot Integration

Modify only `scenes/ui/Tavern.tscn` for the visual hook unless tests reveal a need for a helper.

Planned node:

```text
Tavern
  TabletopArt Sprite2D
```

Suggested properties:

```text
position = Vector2(640, 560)
z_index = -90
centered = true
texture_filter = 1
texture = res://assets/textures/tavern/table/tabletop.png
```

The exact y position can be adjusted to cover the current table surface without hiding the customer stage or shortcut bar. `Background` remains in place as the legacy full-screen fallback. `TabletopArt` is visual-only and has no collision, script, signals, or input handling.

The existing contract nodes remain unchanged:

```text
BarWorkspace/World/Walls/Ground
BarWorkspace/World/Walls/LeftWall
BarWorkspace/World/Walls/RightWall
BarWorkspace/CustomerDropArea
BarWorkspace/World/Brewery
BarWorkspace/World/Grill
BarWorkspace/World/Pot
BarWorkspace/World/Spoon
BarWorkspace/World/SeasoningShaker
BarWorkspace/World/Ledger
```

## Tests

Add a focused Python pipeline test before implementation. It should fail first when the tabletop assets do not exist.

The pipeline test should verify:

- Manifest exists and records fixed paths.
- Native source exists at `320x80`.
- Runtime texture exists at `1280x320`.
- Runtime bytes equal native resized by `Image.Resampling.NEAREST`.
- Native asset is fully opaque, since the tabletop is a rectangular surface.
- The texture has enough dark wood mass and sparse highlight pixels, with no bright flood.
- A contact sheet exists for review.

Add or extend a focused Godot scene contract only if useful:

- `Tavern.tscn` contains `TabletopArt`.
- `TabletopArt.texture.resource_path` is `res://assets/textures/tavern/table/tabletop.png`.
- The existing wall collision segment points are unchanged.
- Existing workspace recovery and prop-art tests still pass.

## Verification

Run the focused verification after implementation:

```powershell
python -m unittest scripts.test.test_tavern_table_asset_pipeline.TavernTableAssetPipelineTest -v
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_workspace_scene_recovery.tscn
& 'C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe' --headless --path . res://scenes/test/test_ryan_slice_assets.tscn
```

If the local Godot path differs, use the installed Godot 4.6 console binary with equivalent arguments.

Also review the generated contact sheet and a Tavern runtime screenshot. The screenshot must show a cohesive wooden tabletop without changing item placement, collisions, order display, or shortcut bar readability.

## Risks

The main risk is visual alignment: the new table could look good alone but make existing props harder to read. Keep the art dark and low-detail, and verify against current barrel, pot, grill, spoon, shaker, ledger, and item icons.

Another risk is hidden contract drift in `Tavern.tscn`. The implementation must add a visual node without moving existing nodes or changing the physics boundary coordinates.

## Completion Criteria

- The checkerboard-like placeholder tabletop is no longer visible in the Tavern night service scene.
- The new tabletop is produced through native source plus exact nearest runtime export.
- A manifest and contact sheet make the art source traceable.
- `Tavern.tscn` references only the runtime texture, not generated raw or source art.
- Existing gameplay and workspace contract tests still pass.
- No existing node paths, signals, public methods, autoload APIs, or gameplay resource paths are renamed or removed.
