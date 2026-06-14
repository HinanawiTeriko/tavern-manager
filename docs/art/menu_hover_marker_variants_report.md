# Menu Hover Marker Variants

## Source

- Base source: `assets/source/ui/menu_brush_hover_marker_base.png`
- Raw generated sources: `art_sources/generated_raw/menu_hover_marker/menu_brush_hover_marker_generated_1.png` to `menu_brush_hover_marker_generated_4.png`
- Runtime legacy fallback: `assets/textures/ui/menu_brush_hover_marker.png`
- Manifest: `assets/source/ui/menu_accent_manifest.json`
- Contact sheet: `docs/art/menu_hover_marker_variants_contact_sheet.png`

## Runtime Variants

- `assets/textures/ui/menu_brush_hover_marker_1.png`
- `assets/textures/ui/menu_brush_hover_marker_2.png`
- `assets/textures/ui/menu_brush_hover_marker_3.png`
- `assets/textures/ui/menu_brush_hover_marker_4.png`

All variants are generated-source marker shapes, then normalized into the current amber brush palette at `243x28` with the same safe area `[16, 6, 211, 16]`.

## Verification

- `python scripts/test/test_menu_accent_asset_pipeline.py`
- `Godot --headless --path . --scene res://scenes/test/test_brush_theme.tscn`
- `Godot --headless --path . --scene res://scenes/test/test_workspace_scene_recovery.tscn`
