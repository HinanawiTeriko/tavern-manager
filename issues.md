# Issues

This file is no longer the primary project tracker. It is kept as a lightweight local note so agents do not read the archived tracker as current truth.

## Current Known Documentation State

- Current documentation entry: `docs/00_文档索引.md`.
- Old tracker archived at `docs/archive/legacy-issues.md`.
- Old numbered docs archived at `docs/archive/legacy-numbered/`.

## Current Engineering Notes

- There is no single all-tests runner; run focused Godot test scenes.
- Some headless Godot tests can print `ObjectDB instances leaked at exit`; treat exit code and explicit test failures as the main signal unless investigating leaks.
- Documentation must be updated when gameplay data flow, public contracts, asset pipelines, or test entry points change.

## Near-Term Product Gaps

- DayMap has immediate rumor feedback, but no persistent in-day rumor review panel yet.
- Documentation has been reset to current truth; remaining historical docs should stay archived unless a specific topic needs extraction.
