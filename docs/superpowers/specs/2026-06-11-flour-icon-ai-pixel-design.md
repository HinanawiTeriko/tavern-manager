# Flour Icon AI Pixel Pipeline Design

Date: 2026-06-11
Scope: first item texture, `flour`
Status: ready for user review

## Goal

Create the first production item texture using an AI reference image followed by clean local pixel normalization and cutting. The output must fit the Tavern item icon pipeline without replacing legacy `assets/textures/icons/...` files.

This pass only covers `flour`. It establishes the workflow that later item icons can repeat one by one.

## Visual Target

The icon is a small flour sack for a dungeon tavern inventory:

- squat burlap bag with a tied neck
- open top showing pale flour
- a small spill of flour near the base
- warm candlelit brown cloth, dark outline, sparse pale flour accents
- no readable text, logo, numbers, or label
- transparent final background

The final icon must read clearly at the native `24x24` grid and at the runtime `96x96` nearest-neighbor export.

## Asset Flow

AI reference:

- Save raw generated reference under `assets/source/tavern/reference/flour_icon_reference.png`.
- Generate on a perfectly flat chroma-key background, with generous padding and no cast shadow.
- The AI image is reference/input only. Godot must not load it directly.

Native source:

- Save cleaned native pixels at `assets/source/tavern/icons/flour_native.png`.
- Native size is exactly `24x24`.
- Background is alpha.
- Visible pixels must stay inside the canvas with at least one transparent pixel of breathing room where possible.

Runtime texture:

- Save runtime export at `assets/textures/tavern/icons/flour.png`.
- Runtime size is exactly `96x96`.
- Runtime must be an exact 4x nearest-neighbor export from the native source.

## Processing Rules

Use the AI reference as a shape/color source, then normalize locally:

1. Remove the flat chroma-key background.
2. Crop from an explicit bounding box around the flour sack, not by guessing a connected component as the final crop rule.
3. Fit the subject into a `24x24` native canvas with stable padding.
4. Pixel-normalize with a limited palette and hard alpha edges.
5. Clean stray pixels and chroma remnants.
6. Export runtime only with nearest-neighbor 4x scaling.

No text is baked into the image. Dynamic names and counts remain Godot labels.

## Integration

This first asset should be additive:

- Do not modify legacy `assets/textures/icons/materials/wheat.png`.
- Do not remove old icon paths.
- When implementation reaches runtime hookup, `GameManager.try_load_material_icon(key)` may prefer `res://assets/textures/tavern/icons/<key>.png` and fall back to the legacy map.

If only the asset pipeline is implemented in the first slice, runtime hookup can wait for the next step, but the output paths must match the planned lookup.

## Tests And Review

Add or update focused validation so `flour` is checked before use:

- native file exists and is `24x24`
- runtime file exists and is `96x96`
- runtime bytes equal `flour_native.png` resized 4x with nearest-neighbor
- native has alpha, transparent corners, and enough visible pixels to read as an item
- reference file is retained but not used by Godot runtime

Also produce a small contact sheet or preview showing:

- AI reference
- cleaned native icon enlarged with nearest-neighbor
- runtime icon

## Files Planned For Implementation

Likely new files:

- `assets/source/tavern/reference/flour_icon_reference.png`
- `assets/source/tavern/icons/flour_native.png`
- `assets/textures/tavern/icons/flour.png`
- `docs/art/flour_icon_contact_sheet.png`

Likely code/test files:

- `scripts/tools/export_tavern_item_icons.py` or an equivalent focused exporter
- `scripts/test/test_tavern_item_icon_pipeline.py`

Potential later runtime hookup:

- `scripts/game_manager.gd`

No scene files are required for the first icon asset slice.

## Open Decision

The approved production method is: AI reference image first, then local pixel normalization and clean cutting into native/runtime PNGs.
