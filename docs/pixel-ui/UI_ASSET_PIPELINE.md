# Pixel UI Asset Pipeline

## Required Flow

1. Generate or author source art.
2. Store raw/generated source under `art_sources/generated_raw/` when AI-generated.
3. Normalize production source under `assets/source/`.
4. Export runtime textures under `assets/textures/`.
5. Use deterministic scripts in `scripts/tools/`.
6. Add or update tests in `scripts/test/`.
7. Produce a contact sheet/report when visual review is needed.

## Runtime Rules

- Godot runtime UI should reference `assets/textures/` or approved theme/font assets.
- Do not reference raw AI source images from scenes.
- Do not bake readable text into UI art.
- Do not guess crop boundaries from alpha or connected components.
- Every generated UI asset should have an explicit manifest entry when part of a reusable set.

## Existing References

- Title exporter: `scripts/tools/export_title_screen_assets.py`
- Intro exporter: `scripts/tools/export_intro_assets.py`
- DayMap exporter: `scripts/tools/export_daymap_assets.py`
- Regular customer portraits: `scripts/tools/export_regular_customer_portraits.py`

## Verification

Run the relevant Python pipeline test and the affected Godot UI contract test. For example:

```powershell
python -m unittest scripts.test.test_regular_customer_portrait_pipeline
& 'D:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'D:\game\tavern-manager' 'res://scenes/test/test_tavern_patience_ui.tscn'
```
