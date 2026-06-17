# Ryan Ending Art Refresh Design

Date: 2026-06-15
Status: Design approved, pending implementation plan
Scope: Refresh the four Ryan fate stills shown by `LedgerScreen`.

## Goal

Ryan's shipped portrait set has changed, so the four fate stills should be rebuilt as one coherent group rather than lightly patched. The new stills must make Ryan's fate readable at a glance, match the current Ryan portrait identity, and keep the existing runtime contracts intact.

The implementation should not touch gameplay, economy, save/load, day flow, narrative branching, node names, signal names, or scene paths.

## Existing Contract

The current runtime contract is:

- `scripts/ui/ledger_screen.gd` maps Ryan route keys to four stable runtime PNG paths.
- Runtime stills remain `1280x560` and are displayed at `Still.position = Vector2(0, 80)`.
- Native stills remain `320x140` and are exported with exact 4x nearest-neighbor scaling.
- Route keys remain:
  - `uninformed_fallen`
  - `drugged_survivor`
  - `informed_fallen`
  - `alternative_survivor`
- Runtime paths remain:
  - `assets/textures/endings/ryan/ryan_uninformed_fallen.png`
  - `assets/textures/endings/ryan/ryan_drugged_survivor.png`
  - `assets/textures/endings/ryan/ryan_informed_fallen.png`
  - `assets/textures/endings/ryan/ryan_alternative_survivor.png`

No scene edits are planned for this art refresh.

## Visual Identity

Ryan should match the current approved portrait manifest:

- ash-lilac messy undercut with a short side braid
- small low red-brown horn nubs
- mostly human face
- patched tan shirt
- charcoal-brown jerkin
- small oath tag
- tiny wax-seal pouch
- plain belt and worn travel trousers

The stills should use the project's native-pixel language: dark teal dungeon shadows, amber candle or lantern accents, rough stone, worn wood, chunky pixel clusters, thick dark silhouettes, restrained palette density, no readable image text, no logos, and no soft high-resolution painting left in runtime assets.

## Four Stills

### `uninformed_fallen`

Ryan is absent, but the evidence must clearly belong to him. The still shows the cold North Mine aftermath: collapsed stone around Ryan's dropped oath tag, tiny wax-seal pouch, torn charcoal-brown jerkin cloth, ash-lilac short-braid tie, and battered patched travel pack. A weak blue mine light recedes into the tunnel. This route should feel like Ryan disappeared into a trap without understanding it.

Avoid showing a body, explicit gore, generic shields, generic helmets, or anonymous adventurer loot.

### `drugged_survivor`

Ryan survives because he missed the muster. The still shows the tavern after closing: Ryan in the new outfit asleep or slumped at a table, his pack and oath token near him, warm candlelight around him, and cold morning or doorway light outside. The mood is not triumphant; it should suggest the cost of someone else making the choice for him.

### `informed_fallen`

Ryan knows the risk and still goes. The still shows him at the threshold of the North Mine, side or back view, hand near the oath tag, lantern light behind him, cold tunnel ahead. He should be visible enough to read as the new Ryan, but the image should emphasize chosen resolve rather than a heroic victory pose.

### `alternative_survivor`

Ryan chooses the slower safer route. The still shows him walking away with the alternative contract, toward a side road, guild side gate, or quieter stone path. Dawn or muted amber-blue light should make this the least bleak image while keeping a grounded, costly tone.

## Asset Pipeline

Implementation should add a V3 source generation pass instead of overwriting the V2 raw references in place:

- Raw generated references: `art_sources/generated_raw/ryan_endings/ryan_<route>_reference_v3.png`
- Raw prompt or manifest update: `art_sources/generated_raw/ryan_endings/ryan_ending_reference_manifest.json`
- Approved references: `assets/source/endings/ryan/reference/ryan_<route>_reference_v3.png`
- Native exports: `assets/source/endings/ryan/ryan_<route>_native.png`
- Runtime exports: `assets/textures/endings/ryan/ryan_<route>.png`
- Native contact sheet: `assets/source/endings/ryan/ryan_ending_native_contact_sheet.png`
- Runtime/contact report: `docs/art/ryan_ending_backgrounds_contact_sheet.png`

The manifest and tests should be updated from `reference_v2` to `reference_v3` so the approved source lineage is explicit.

## Planned Files To Touch

Likely implementation files:

- `scripts/tools/prepare_ryan_ending_sources.py` to consume V3 references.
- `scripts/tools/export_ryan_ending_assets.py` if manifest text needs to point at V3.
- `scripts/test/test_ryan_ending_asset_pipeline.py` to validate V3 references and exact nearest exports.
- `art_sources/generated_raw/ryan_endings/*_reference_v3.png` plus source manifest/prompt records.
- `assets/source/endings/ryan/reference/*_reference_v3.png`.
- `assets/source/endings/ryan/*_native.png`.
- `assets/textures/endings/ryan/*.png`.
- `assets/source/endings/ryan/ryan_ending_manifest.json`.
- `assets/source/endings/ryan/ryan_ending_native_contact_sheet.png`.
- `docs/art/ryan_ending_backgrounds_contact_sheet.png`.

No `*.tscn` edits are expected.

## Validation

Before completion:

- Run `python scripts/tools/prepare_ryan_ending_sources.py`.
- Run `python scripts/tools/export_ryan_ending_assets.py`.
- Run `python -m unittest scripts.test.test_ryan_ending_asset_pipeline`.
- Inspect `docs/art/ryan_ending_backgrounds_contact_sheet.png`.
- If Godot import metadata changes, preserve nearest filtering and existing runtime paths.

Acceptance criteria:

- All four routes have updated Ryan identity or Ryan-specific story evidence.
- Runtime PNGs are exact 4x nearest exports from native PNGs.
- Native images pass palette and edge-density tests.
- No readable text is baked into the images.
- `LedgerScreen` can keep using the same route keys and runtime paths.

## Notes

The user-provided repository instructions mention `docs/pixel-ui/`, but that directory is not present in the current worktree. This refresh will therefore follow the existing Ryan portrait manifest, title/native-pixel pipeline examples, and Ryan ending asset pipeline already present in the repo.
