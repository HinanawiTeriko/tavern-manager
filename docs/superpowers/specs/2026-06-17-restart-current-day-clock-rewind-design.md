# Restart Current Day Clock Rewind

Date: 2026-06-17
Scope: `LedgerScreen` restart-day entry, clock rewind confirmation overlay, day-start save snapshot, and the supporting UI art pipeline.
Status: design approved in chat; awaiting implementation plan.

## Goal

Add a "restart current day" flow that returns the player to the current morning DayMap state. The action should feel like rewriting the day's record, not like a generic reload.

The player reaches this from the night settlement screen after seeing the day's results. The existing "熄灯" button keeps accepting the day and advancing to the next day. A new sibling button opens a clock rewind overlay. The player confirms the restart by dragging the clock hand around one full circle while today's recorded events rewind on screen.

## Confirmed Decisions

- Restart semantics are "return to the current day's morning DayMap start".
- The entry point belongs on `LedgerScreen`, not the settings panel.
- `LedgerScreen` should show two end-of-day choices: accept today with "熄灯", or restart today with a new button.
- Restart must require an intentional visual confirmation, not a single accidental click.
- The first visual replay version is event-ledger style, not full scene video replay.
- The UI art work must include authored/generated basics, including three-state button art.
- Built-in `image_gen` should be used for source art. Generated results must be extracted into the repo with `scripts/tools/extract_codex_imagegen_results.py` before processing.
- Runtime UI must use production pixel textures, not raw generated images.

## Current System Boundary

Current night flow:

- `GameManager.end_night()` creates `current_ledger_data`.
- It records the daily summary and resets daily economy/guest counters.
- It changes to `LedgerScreen.tscn` or `CleanTableInferenceScreen.tscn` when inference is pending.
- `LedgerScreen` reads `GameManager.current_ledger_data`.
- `LedgerScreen`'s existing `ContinueBtn` calls `gm.day_cycle.next_phase()`, which advances to the next DayMap unless the game should end.

Current restart method:

- `GameManager.restart_current_day()` already exists.
- It currently calls `continue_game()`, so it restores the latest save, not a true day-start checkpoint.
- Current autosaves can be overwritten by DayMap entry, reveal/camera persistence, inference completion, and other mid-day state writes.

The implementation must preserve existing public methods and scene node contracts unless a later implementation plan explicitly names and verifies a compatible addition.

## User Experience

At settlement:

- The player sees the normal settlement result.
- The right/lower action area contains:
  - Existing `ContinueBtn`: "熄灯", accepts the day.
  - New `RestartDayBtn`: recommended text "重写今日", opens the rewind overlay.
- The restart button is disabled or hidden while the score replay or fate presentation is still active, so it does not interrupt required settlement presentation.
- If no restart checkpoint exists, the restart button is disabled and can show a short unavailable hint through existing label/caption patterns if practical.

On restart click:

- A full-screen `ClockRewindOverlay` appears above the settlement screen.
- The background dims but remains faintly visible.
- A large authored clock face appears near center.
- The player drags the clock hand counterclockwise.
- As drag progress increases from 0 to 1, today's event entries appear in reverse order and fade/strike away as if pulled back into the ledger.
- Releasing before a full circle does not restart. The hand can remain at its partial position or ease back to zero.
- Completing one full circle triggers a short completion beat: clock tick, candle dim, paper/ink pullback, then `GameManager.restart_current_day()`.
- Esc/right click closes the overlay without changing state.

The overlay should make the irreversible nature clear through the drag interaction. It should not add a separate confirmation dialog in the first version.

## Save And Restart Design

Add a day-start checkpoint owned by `GameManager`.

Recommended shape:

```gdscript
var _day_start_snapshot: Dictionary = {}
```

The checkpoint should be captured when the current day reaches a stable morning DayMap state. It must represent the state before player choices for that day:

- current day unchanged
- phase is DAY
- inventory/gold/reputation/craft/narrative/document/inference/day_map/guest state restored to the morning baseline
- current day's event log empty
- no settlement `current_ledger_data`

The normal save file may include this checkpoint, either as a new top-level field such as `day_start_snapshot` or as a separate save slot if implementation finds that cleaner. Old saves without the field must continue loading.

`restart_current_day()` should:

1. Return early or safely fall back if no checkpoint exists.
2. Restore the checkpoint with `_apply_save_state()`.
3. Force `day_cycle.phase = DayCycleSystem.DayPhase.DAY`.
4. Clear transient runtime state that should not survive the restart, including `current_ledger_data`, pending overlay state, and active guest/dialogue flags as needed.
5. Clear the current-day event log.
6. Change to `res://scenes/ui/DayMap.tscn`.

It must not increment the day, reset the whole game, clear global tutorial progress, or mutate route outcomes outside the restored checkpoint.

## Current-Day Event Log

Add a lightweight event log for the visual rewind. This is not authoritative gameplay state. It is a presentation summary.

Recommended event shape:

```gdscript
{
  "type": "location",
  "label": "蘑菇林",
  "detail": "获得 sleep_powder",
  "day": 2,
}
```

First-version event sources:

- `visit_day_location()`: visited location, rewards, documents, and major story result.
- `buy_material()`: material purchase summary.
- `buy_recipe_unlock()`: recipe unlock purchase summary.
- `buy_ability()`: ability purchase summary if used during the day.
- `grant_investigation_document()`: important document or inference clue acquired.
- `request_serve()` / `_on_serve_requested()`: important service result and business delta.
- `end_night()`: final settlement summary if needed to anchor the replay.

The log should be capped to a readable count in the overlay, for example the most recent 8 to 12 entries. If more events exist, aggregate older entries into one line such as "更早的琐事被墨迹吞回账本". Dynamic text must be Godot `Label` text, not baked image text.

The event log should be captured in saves only if it is needed for crash recovery into the settlement screen. It should always reset when a new day-start checkpoint is captured or when the restart completes.

## Clock Rewind Overlay

Create a bounded overlay scene or component. Recommended path:

- `scenes/ui/ClockRewindOverlay.tscn`
- `scripts/ui/clock_rewind_overlay.gd`

Public surface:

- signal `confirmed`
- signal `cancelled`
- method `open(events: Array)`
- method `close()`
- optional method `set_events(events: Array)`

Behavior:

- Owns the input handling for the clock drag.
- Computes angular progress around the clock center.
- Requires one full counterclockwise turn before emitting `confirmed`.
- Emits `confirmed` once only.
- Never calls gameplay mutation directly if it can avoid it. `LedgerScreen` should connect `confirmed` to `GameManager.restart_current_day()` or a small wrapper.
- Does not rename or move existing `LedgerScreen` nodes.

The overlay should be testable without real generated art by checking node existence, signal emission, and progress logic.

## LedgerScreen Integration

Add a new `RestartDayBtn` next to `ContinueBtn`.

Preferred layout:

- Keep `ContinueBtn` in the right-lower action zone.
- Add `RestartDayBtn` to its left with equal or slightly wider bounds.
- Use the same settlement button language so the two choices feel like a pair.
- If there is not enough room with the existing 96px-tall button art, stack the buttons vertically in the lower right rather than shrinking text into illegibility.

Button behavior:

- `ContinueBtn`: unchanged; it can still complete score replay on first press, then advance on later press.
- `RestartDayBtn`: disabled while score replay/fate presentation is active; when enabled, it opens `ClockRewindOverlay`.
- If the score replay is active and the player clicks restart, the first implementation may simply complete the score replay and keep the restart button disabled until the replay is finished. Do not restart mid-animation.

## Art Direction

The target is original pixel dungeon tavern UI:

- dark teal stone shadows
- warm candle/amber highlights
- rough ink-like edges
- paper grain and aged ledger material
- simple tavern clock and clock hand silhouettes
- hand-drawn playing-card-like symbols when useful
- no readable text baked into generated images
- no named existing game style or living artist prompts

The clock should feel like a tavern object and a fate ledger object at once: a worn wood or tarnished metal wall clock, soot-dark rim, amber tick marks, simple heavy hand, subtle paper/ink motifs. It must remain readable at runtime size.

## Required Art Assets

Minimum first-version art:

- Settlement restart button, three states:
  - `restart_day_button_normal`
  - `restart_day_button_hover`
  - `restart_day_button_pressed`
- Clock face.
- Clock hand.
- Rewind event paper/card backing.
- Optional dim/vignette or ink wash overlay if it is not achievable cleanly with existing ColorRect/modulate.

If the existing settlement continue button art cannot support a paired layout cleanly, add a matching second set for the continue button only after documenting why reuse is insufficient. The first attempt should preserve the current `ContinueBtn` art and create only the new restart button art.

Runtime assets should live under:

- `assets/textures/ui/restart_day/`

Native pixel sources should live under:

- `assets/source/ui/restart_day/`

Raw generated sources should live under:

- `art_sources/generated_raw/restart_day/`

Contact sheets or visual reports should live under:

- `docs/art/restart_day/`

## Image Generation And Extraction Workflow

Use built-in `image_gen` for raw source generation.

Expected flow:

1. Write prompts for button state sheet and clock component source art.
2. Generate source art with `image_gen`.
3. Extract generated PNGs from Codex session logs using:

```bash
python scripts/tools/extract_codex_imagegen_results.py --out-dir art_sources/generated_raw/restart_day --after <UTC timestamp> --prefix restart_day_
```

4. Keep the extracted raw source files under `art_sources/generated_raw/restart_day/`.
5. Create or update an explicit manifest with fixed rectangles for each crop. Do not infer crops from alpha, color, or connected components.
6. Export native pixel assets under `assets/source/ui/restart_day/`.
7. Export runtime PNGs under `assets/textures/ui/restart_day/` by exact integer nearest-neighbor scaling.
8. Produce a contact sheet under `docs/art/restart_day/`.
9. Add or update asset pipeline tests to verify dimensions, manifests, and exact nearest-neighbor exports.

The runtime scene may only reference `assets/textures/ui/restart_day/` and existing approved runtime texture folders. It must not reference `art_sources/generated_raw/`.

Prompt constraints:

- no readable words, letters, numbers, UI labels, logos, or watermarks
- no reference to named games or living artists
- flat state-sheet layout with clear cell boundaries or separate individually generated images
- generous padding around each UI element
- crisp silhouettes and limited palette

## Manifest And Exporter

Add a deterministic exporter, recommended:

- `scripts/tools/export_restart_day_assets.py`

Add a manifest, recommended:

- `assets/source/ui/restart_day/restart_day_manifest.json`

Every generated asset entry must include:

- id
- source file
- source rectangle
- native output file
- runtime output file
- native size
- runtime size
- safe area
- optional nine-slice margins
- intended Godot use

Button state entries must share stable dimensions and alpha bounds so hover/pressed states do not shift layout.

## Files Expected To Change

Implementation should plan changes to these areas only unless tests reveal a tighter need:

- `scripts/game_manager.gd`: day-start checkpoint, restart restore, event log capture API.
- `scripts/ledger_data.gd`: only if settlement needs to carry restart-event display data; avoid if `GameManager` can expose it safely.
- `scripts/ui/ledger_screen.gd`: add restart button handling and overlay connection.
- `scenes/ui/LedgerScreen.tscn`: add `RestartDayBtn` and overlay instance or container.
- `scripts/ui/clock_rewind_overlay.gd`: new overlay logic.
- `scenes/ui/ClockRewindOverlay.tscn`: new overlay scene.
- `scripts/tools/export_restart_day_assets.py`: deterministic pixel asset exporter.
- `scripts/test/test_restart_current_day.gd`: snapshot and restart behavior tests.
- `scripts/test/test_clock_rewind_overlay.gd`: drag confirmation behavior.
- `scripts/test/test_night_settlement_screen.gd`: settlement button contract and non-interference tests.
- `scripts/test/test_restart_day_asset_pipeline.py`: art pipeline tests.
- `art_sources/generated_raw/restart_day/*`: extracted image generation sources and prompts.
- `assets/source/ui/restart_day/*`: native pixel sources and manifest.
- `assets/textures/ui/restart_day/*`: runtime textures.
- `docs/art/restart_day/*`: contact sheet/report.

Before modifying scenes or runtime code, the implementation turn must list exact files it plans to touch and why.

## Testing

Behavior tests:

- Capturing a day-start checkpoint preserves the current day and morning DayMap state.
- Restarting after DayMap actions restores inventory, gold, reputation, documents, narrative vars, inference state, DayMap completed state, and guest state from the checkpoint.
- Restarting from `LedgerScreen` after night settlement returns to that same day's DayMap, not the next day.
- Old saves without a day-start checkpoint still load.
- `RestartDayBtn` exists on `LedgerScreen` and does not remove or rename `ContinueBtn`.
- `ContinueBtn` continues to advance by the existing next-phase path.
- `RestartDayBtn` does not trigger restart while score replay/fate presentation is still active.
- `ClockRewindOverlay` emits `confirmed` once after one full counterclockwise drag.
- `ClockRewindOverlay` does not emit `confirmed` when released before a full circle.
- Cancelling the overlay returns to the settlement screen without mutating state.
- Current-day event log is cleared when the day restarts.

Asset pipeline tests:

- Runtime restart-day PNGs are exact nearest-neighbor exports from native pixel sources.
- Manifest includes id, source, output, size, safe area, optional nine-slice, and intended Godot use.
- Restart button normal/hover/pressed states have stable dimensions and alpha bounds.
- Runtime scenes reference production textures, not raw generated source paths.
- Contact sheet/report exists and is non-empty.

Manual verification:

- Run the project and complete a day to reach `LedgerScreen`.
- Confirm both buttons are visible and readable.
- Confirm the restart button opens the clock overlay.
- Dragging less than a full circle cancels safely.
- Dragging a full circle returns to the current day's DayMap morning.
- Confirm text does not overlap on 1280x720.

## Non-Goals

- Do not record or replay real gameplay video.
- Do not replay physics bodies or customer scene state.
- Do not change economy, recipe, guest, route, or simulation outcomes.
- Do not redesign DayMap, Tavern HUD, shop, inventory, settings, or ending screens in this change.
- Do not delete legacy settlement nodes.
- Do not bake text, numbers, labels, or fake UI copy into generated art.
- Do not reference AI source images directly from runtime UI.
- Do not infer asset crops from alpha, color, or connected components.
- Do not use named existing games or living artists in image-generation prompts.

## Notes

The repository instructions mention `docs/pixel-ui/`, but that directory is not present in the current workspace at design time. If those documents are added before implementation, the implementation must read them before editing UI or art assets. Until then, the implementation should follow the existing title, tavern, daymap, and night-settlement asset pipeline conventions already present in this repository.
