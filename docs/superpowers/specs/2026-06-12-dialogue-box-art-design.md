# Dialogue Box Art Design

## Scope

Rebuild the runtime story dialogue box art without changing dialogue content or Dialogue Manager APIs.

The work targets the story dialogue balloon shown by `GameManager` for important NPC pre/post dialogue. It does not replace ordinary customer reaction bubbles, dialogue files, narrative variables, save/load, or Dialogue Manager internals.

## Approach

Use a project-owned dialogue balloon scene instead of editing the plugin example scene.

- Add `scenes/ui/DialogueBalloon.tscn` with the same required balloon node contract as Dialogue Manager's example balloon.
- Add `scripts/ui/dialogue_balloon.gd` extending the plugin example balloon script, keeping `start()`, input handling, response flow, and public fields compatible.
- Change `GameManager` to call `DialogueManager.show_dialogue_balloon_scene()` with the project balloon scene.
- Preserve `%Balloon`, `%CharacterLabel`, `%DialogueLabel`, `%ResponsesMenu`, and `%Progress` so inherited runtime behavior keeps working.

## Art Direction

The dialogue box should match the current dark teal dungeon tavern UI language:

- rough ink and woodcut edges;
- dark teal/charcoal panel mass;
- warm amber candlelit trim;
- paper-grain or worn wood texture in low-density pixel clusters;
- no generated readable text, logos, numbers, or fake labels.

Godot renders all dialogue text, names, responses, and dynamic state.

## Asset Pipeline

Use AI generation only as source/reference art, then deterministic native-pixel processing:

- Raw AI source: `art_sources/generated_raw/dialogue_box/dialogue_box_sheet_v1.png`
- Prompt record: `art_sources/generated_raw/dialogue_box/dialogue_box_prompt_v1.txt`
- Native assets: `assets/source/ui/dialogue_box/`
- Runtime assets: `assets/textures/ui/dialogue_box/`
- Review contact sheet: `docs/art/dialogue_box_contact_sheet.png`
- Runtime preview: `docs/art/dialogue_box_scene_preview.png`

Runtime PNGs must be exact nearest-neighbor exports from native sources. New runtime UI references may only point at `assets/textures/ui/dialogue_box/`.

## Components

The first pass ships:

- `dialogue_panel`: bottom dialogue frame, used as the main panel stylebox.
- `dialogue_nameplate`: small speaker-name strip.
- `dialogue_response_normal`, `dialogue_response_hover`, `dialogue_response_pressed`: response button states.
- `dialogue_progress_arrow`: small authored continue indicator, with the legacy `%Progress` polygon kept as a hidden compatibility node.

## UI Contract

Tests should verify:

- the project dialogue balloon scene exists and keeps required Dialogue Manager node names;
- `GameManager` uses the project balloon scene;
- text and responses use the project pixel font and runtime textures;
- generated/runtime art never references raw AI source files;
- native/runtime assets are present, non-empty, and exact nearest-neighbor exports;
- the legacy plugin example scene is not modified for project styling.

## Verification

Run:

```powershell
python scripts/test/test_dialogue_box_asset_pipeline.py
godot --headless --path . --import
godot --headless --path . scenes/test/test_dialogue_balloon_contract.tscn
```
