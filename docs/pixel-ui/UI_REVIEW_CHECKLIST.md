# Pixel UI Review Checklist

Use this before calling UI/art work complete.

## Contracts

- Existing node paths are preserved.
- Public methods/signals used by `GameManager`, tests, or other scenes are preserved.
- Legacy UI remains available unless removal was approved.
- Relevant Godot contract tests pass.

## Visual

- Runtime textures are crisp at 1280x720.
- Text is rendered by Godot controls.
- Text fits inside controls.
- Panels do not nest unnecessarily.
- Feedback elements do not block clicks unless intentionally modal.
- Palette still reads as dark dungeon tavern with amber accents, not a one-color theme.

## Assets

- Runtime scene references use processed assets, not raw generated files.
- Source, manifest, exporter, and test are updated for generated asset sets.
- Contact sheet/report exists for batch visual work.
- No prompt or source asks for a living artist or named existing game style.

## Verification

- Run the smallest relevant Godot UI test.
- Run any changed asset pipeline test.
- Inspect screenshots/contact sheets for crop, scale, and readability problems.
