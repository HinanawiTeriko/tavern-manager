# Meme Physics Guests Design

## Goal

Add the first playable framework for authorized meme guest characters whose arrival changes tavern physics for the rest of the night. The first slice ships the framework plus two gravity-law examples:

- `meme_doge`: Doge, low gravity.
- `meme_snack_cat`: 吃零食猫, heavy gravity.

This is a bounded framework slice, not a full content batch. It should make later meme guests data-driven and avoid rewriting existing tavern, economy, save, or narrative systems.

## Scope

This pass adds:

- Data-driven meme guest definitions.
- Data-driven physics law definitions.
- Runtime activation and restoration of a tavern physics law for one night.
- Two example meme guests in normal customer flow.
- Imagegen-based portrait source generation plus deterministic pixel export to runtime character PNGs.
- Focused tests for guest law metadata, law activation, restoration, and asset pipeline outputs.

This pass does not add:

- Wind fields, random motion, collision splitting, or non-gravity laws.
- Important NPC story branches.
- Economy rebalance.
- Scene node renames or UI contract breaks.
- Direct runtime references to imagegen source files.

## Player Experience

When a meme guest appears during tavern service, the tavern enters that guest's physics law for the rest of the night.

Doge applies low gravity: desk items fall slower and thrown items feel floatier.

吃零食猫 applies heavy gravity: desk items fall faster and are harder to toss upward.

The effect persists after the guest leaves and resets when the night ends, the day is restarted, or the Tavern scene exits. A short existing-style stage caption can announce the law change, but the first slice does not need a new UI panel.

## Data Model

Add `data/physics_laws.json`:

```json
{
  "laws": {
    "low_gravity": {
      "display_name": "低重力",
      "summary": "今晚桌面物品变轻，抛掷更飘。",
      "gravity_scale_multiplier": 0.45
    },
    "heavy_gravity": {
      "display_name": "超重力",
      "summary": "今晚桌面物品更快下坠，更难抛高。",
      "gravity_scale_multiplier": 1.75
    }
  }
}
```

Add `data/meme_guests.json`:

```json
{
  "guests": [
    {
      "id": "meme_doge",
      "display_name": "Doge",
      "portrait_key": "meme_doge",
      "physics_law_id": "low_gravity",
      "favorite_orders": ["ale_beer", "bread"],
      "unlock_day": 1,
      "spawn_weight": 0.12,
      "authorization_note": "User-confirmed authorized meme character use."
    },
    {
      "id": "meme_snack_cat",
      "display_name": "吃零食猫",
      "portrait_key": "meme_snack_cat",
      "physics_law_id": "heavy_gravity",
      "favorite_orders": ["bread", "meat_sand"],
      "unlock_day": 1,
      "spawn_weight": 0.12,
      "reference_source": "https://storage.moegirl.org.cn/moegirl/commons/4/45/%E5%90%83%E9%9B%B6%E9%A3%9F%E7%8C%AB.gif",
      "authorization_note": "User-confirmed authorized meme character use."
    }
  ]
}
```

The exact order preferences can change during implementation if a listed product is unavailable on early days. The important contract is stable ids, portrait keys, and `physics_law_id`.

## Systems

Add `scripts/systems/physics_law_system.gd` as a small `PhysicsLawSystem` `RefCounted` helper owned by `GameManager`. It loads `physics_laws.json`, validates ids, and exposes:

- `get_law(law_id: String) -> Dictionary`
- `has_law(law_id: String) -> bool`

Keep mutation out of this helper. It is a data source, not a scene controller.

Extend `GuestSystem` to load `meme_guests.json` and include eligible meme guests in normal guest selection with low spawn weight. When one is selected, create a normal `GuestData` and set metadata:

- `meme_guest_id`
- `physics_law_id`
- `portrait_id`
- `regular_customer_id` is not set, so meme guests do not enter regular-customer memory.

`GameManager._on_guest_arrived()` already centralizes guest arrival and portrait id setup. It should read `physics_law_id` from the guest metadata. If a valid law is present and no nightly law is active yet, it activates the law for the current Tavern scene and records it as the nightly law. If a second meme guest appears later in the same night, the first law remains active for this slice.

## Tavern Physics Application

`BarWorkspace` is the scene-level owner of desk physics. Add methods similar to:

- `apply_physics_law(law: Dictionary) -> void`
- `clear_physics_law() -> void`
- `current_physics_law_id() -> String`

The law applies to:

- Existing `DeskItem` children under `BarWorkspace/World/Items`.
- New `DeskItem` instances created after activation.

The first slice only applies `gravity_scale_multiplier` to `DeskItem.gravity_scale`. Each affected item stores its base gravity scale in metadata before mutation, then restores from that metadata when the law clears.

Do not change `item_physics_profiles.json` values. Do not permanently mutate `DeskItem.PHYSICS_LIMITS` unless implementation proves the existing `0.2..2.0` clamp blocks the chosen multipliers. The proposed `0.45` and `1.75` multipliers stay within the existing practical range for current profiles.

Kitchen containers, spoon, ledger, reward coins, and investigation items are not affected in the first slice. That keeps the change narrow and avoids breaking workspace recovery tests.

## Lifecycle And Recovery

Activation:

1. `GuestSystem` emits a normal guest with `physics_law_id`.
2. `GameManager._on_guest_arrived()` validates the law.
3. `GameManager` calls `TavernView.apply_physics_law(law)`.
4. `TavernView` delegates to `BarWorkspace.apply_physics_law(law)` and can use the existing stage caption path for feedback.
5. `BarWorkspace` updates existing items and marks the law active for future items.

Recovery:

- End night clears the law.
- Restart current day clears the law before restoring the day-start snapshot.
- Tavern scene exit clears the law.
- Re-entering Tavern starts with no active law unless a meme guest appears again.

Invalid law ids are ignored with a warning and no gameplay effect.

## Art Pipeline

Use the built-in `image_gen` workflow for source art. After generation, extract PNGs from Codex session logs with the existing tool:

```powershell
python scripts/tools/extract_codex_imagegen_results.py `
  --out-dir art_sources/generated_raw/characters/meme_guests `
  --after <utc_timestamp> `
  --prefix meme_guest_ `
  --limit <count>
```

Raw imagegen outputs remain under:

- `art_sources/generated_raw/characters/meme_guests/`

Processed native pixel sources go under:

- `assets/source/characters/meme_guests/`

Godot runtime portraits go under:

- `assets/textures/characters/`

Runtime filenames:

- `meme_doge_neutral.png`
- `meme_doge_satisfied.png`
- `meme_doge_dissatisfied.png`
- `meme_snack_cat_neutral.png`
- `meme_snack_cat_satisfied.png`
- `meme_snack_cat_dissatisfied.png`

Image generation constraints:

- No readable text.
- No logos or brand marks.
- Doge keeps Shiba Inu, side-eye, and bewildered meme expression.
- 吃零食猫 keeps the overexposed white cat, dark round eyes, blurred low-resolution feel, and red/blue snack-package color block.
- Generate source art on a removable flat background when practical.
- Final runtime art must be crisp pixel output, not raw generated high-resolution art.

Add a deterministic exporter, for example `scripts/tools/export_meme_guest_portraits.py`, using Pillow. It should crop and scale from explicit manifest entries rather than guessing crop bounds from alpha or connected components.

Add a manifest with one entry per output portrait:

- id
- source file
- output file
- native size
- runtime size
- crop rectangle
- safe area
- intended Godot use

## UI Integration

Reuse `TavernView` portrait loading conventions. The new portrait keys should resolve through existing character texture paths and the existing `_regular_customer_texture_key` or a small adjacent helper without changing `show_customer()`'s public signature.

Use the existing stage caption path for feedback:

- Doge: short line indicating low gravity.
- 吃零食猫: short line indicating heavy gravity.

Do not add a new persistent HUD in the first slice. If a later slice needs a visible law badge, it should be a separate UI surface change.

## Tests

Add focused Godot tests:

- `PhysicsLawSystem` loads both law ids and returns gravity multipliers.
- `GuestSystem` can create or select meme guests with `physics_law_id` metadata.
- `GameManager` activates only one nightly law and clears it when night ends.
- `BarWorkspace` applies law multipliers to existing and newly spawned `DeskItem` nodes.
- `BarWorkspace.clear_physics_law()` restores original `gravity_scale`.

Add asset pipeline tests:

- imagegen extraction script remains covered by the existing extractor test.
- meme portrait exporter creates all six runtime PNGs.
- runtime PNG dimensions match the manifest.
- runtime PNGs are exact nearest-neighbor exports from native pixel sources.
- no runtime scene or data file references `art_sources/generated_raw/`.

Run focused tests first, then run the affected workspace recovery and item physics tests because those are most likely to catch gravity regressions.

## Files Expected In Implementation

Likely new files:

- `data/physics_laws.json`
- `data/meme_guests.json`
- `scripts/systems/physics_law_system.gd`
- `scripts/tools/export_meme_guest_portraits.py`
- `scripts/test/test_physics_law_system.gd`
- `scripts/test/test_meme_guest_physics_laws.gd`
- `scripts/test/test_meme_guest_portrait_pipeline.py`
- `scenes/test/test_physics_law_system.tscn`
- `scenes/test/test_meme_guest_physics_laws.tscn`

Likely edited files:

- `scripts/game_manager.gd`
- `scripts/systems/guest_system.gd`
- `scripts/ui/bar_workspace.gd`
- `scripts/ui/tavern_view.gd`

Implementation must inspect these files again before editing because `GameManager`, `GuestSystem`, and `TavernView` are shared contract-heavy files.

## Acceptance Criteria

- Doge and 吃零食猫 can appear as normal guests.
- Doge activates low gravity for the rest of the night.
- 吃零食猫 activates heavy gravity for the rest of the night.
- Existing desk items and newly spawned desk items are both affected.
- Clearing the law restores every affected item's original gravity scale.
- Ending or restarting the night leaves no active physics law.
- Runtime portraits load through `assets/textures/characters/`.
- Raw imagegen outputs are not referenced by runtime data or scenes.
- Focused tests and affected existing tests pass.
