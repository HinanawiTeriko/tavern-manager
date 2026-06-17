# Night Settlement Score Redesign

Date: 2026-06-15
Scope: second-pass redesign of `LedgerScreen` only.
Status: design approved in chat; awaiting implementation plan.

## Goal

The night settlement screen should feel like closing the tavern after service, not like reading a static report. After the player closes the tavern, every guest from that night should appear in sequence and join a lineup on the left. Each arrival should also push the business data forward with a punchy score-counter style animation: numbers grow, pop, and settle as if the night's takings are being counted one guest at a time.

The redesign is limited to the settlement surface. It must not change economy, save/load, simulation, order resolution, day flow, or fate logic.

## Confirmed Decisions

- Include all guests who appeared that night, not only important NPCs.
- The persistent right-side "今晚余波" panel should be removed from the visible layout.
- Existing major fate cinematic stills for Ryan, Mira, and future supported NPCs stay intact.
- Existing `FateTitle`, `FateList`, and `FatePanelArt` nodes should not be deleted in this change. Hide or bypass them so existing scene contracts remain available until the replacement is verified.
- The current settlement background needs a replacement because it already contains shadow figures. The new background should be an empty after-hours tavern stage that leaves room for runtime guest silhouettes.
- The exaggerated motion belongs to the stat text and number counters, not to the silhouettes.
- Do not copy the composition, UI layout, symbols, or named style of any reference game. The target is an original pixel dungeon tavern score-counting treatment.

## Current System Boundary

Current settlement flow:

- `TavernView` calls `GameManager.end_night()`.
- `GameManager.end_night()` creates `current_ledger_data`.
- `LedgerData` currently contains day, gold, reputation, guest counts, order counts, `npc_fates`, and `fate_warning_next_day`.
- `LedgerScreen` reads `GameManager.current_ledger_data`, renders the settlement, and its continue button calls `gm.day_cycle.next_phase()`.

This redesign adds presentation-only data, but existing field meanings must not change.

## New Data Contract

Add a presentation-only list to `LedgerData` named `guest_entries`.

Each entry should be a dictionary with stable display data:

- `npc_id`: the guest or NPC id used to find the current runtime portrait texture.
- `display_name`: the visible name at time of service.
- `result`: one of `success`, `failed`, or `left`, matching the final service outcome when available.
- `gold_delta`: gold earned from this guest, defaulting to `0` when not available.
- `rep_delta`: reputation delta from this guest, defaulting to `0` when not available.
- `success_delta`: `1` for successful orders, otherwise `0`.
- `failed_delta`: `1` for failed or abandoned orders, otherwise `0`.

`GuestSystem` should append an entry when a guest appears, then update the final result and deltas when the guest is resolved. This makes the nightly record grow during service, while `LedgerScreen` can still replay from an immutable copy at settlement time.

The implementation must record real per-guest deltas from existing resolution data. Successful service can use the already computed `earned_gold` and `earned_rep` values in `GameManager._on_serve_requested()`. Failed or abandoned guests record zero gold and zero reputation unless existing gameplay already applies a penalty at the resolution point. The counter replay must never invent a different business result from the authoritative settlement data.

## Layout

Target runtime size remains `1280x720`.

- Top: compact day/title line, keeping `第 X 天 · 打烊回声` or an equivalent Godot-rendered label.
- Upper and middle stage: empty tavern background where guest silhouettes enter from the right.
- Left side: final guest lineup. Guests should end up readable as a row or staggered row without covering the counter UI.
- Lower or center-lower counter area: business stats with large readable numbers.
- Right-side aftermath panel: hidden in the new visible layout.
- Continue button: remains available after or during the count-up sequence and keeps calling the existing phase transition.

The layout should reserve stable bounds so text growth, number pops, hover states, and late guest counts do not shift the whole screen.

## Guest Silhouettes

The first implementation should reuse existing character portrait textures and tint them into dark silhouettes at runtime.

Rules:

- Use nearest filtering.
- Do not reference AI source images directly.
- Do not generate final silhouette art procedurally.
- Missing textures should fall back to a generic silhouette or skip the figure without blocking settlement.
- Silhouette entry motion should be restrained: slide in from the right, slight settle, then remain in the lineup.

The silhouettes are background storytelling. They must not intercept input or obscure the stat counter.

## Counter Animation

Stats should replay in guest order.

For each guest:

- The guest silhouette moves into place.
- Service count increments by one.
- Success or failed order count increments based on the guest result.
- Gold and reputation counters increase or decrease by that guest's display delta.
- The changed number gets a short punch animation: scale up, high-contrast color flash, tiny shake or bounce, then settle.

At the end of the sequence:

- Displayed totals must equal authoritative `LedgerData` totals.
- If the player presses continue before the count-up finishes, the first press immediately completes all guest silhouettes and counters to their final values. A later press uses the existing next-phase behavior.

## Fate Presentation

The visible "今晚余波" list is removed for this version.

Major fate presentation remains:

- `_show_fate_cinematic_if_needed()` still uses route-specific runtime stills.
- Fate reveal and preview notice overlays still behave as today unless explicitly changed later.
- Ryan-specific compatibility methods stay as wrappers unless the implementation proves they are unused and covered by tests.

If future design needs a smaller fate summary, it should be added as a new bounded surface after this screen is accepted.

## Background and Asset Pipeline

The background should be regenerated or replaced so it does not contain baked-in human shadows. It should be an empty after-hours tavern stage with dark teal stone, warm candle accents, and enough clean space for runtime silhouettes and counters.

The settlement UI asset pipeline remains:

- Raw generated sources stay under `art_sources/generated_raw/night_settlement/`.
- Native pixel sources stay under `assets/source/ui/night_settlement/`.
- Runtime textures stay under `assets/textures/ui/night_settlement/`.
- Runtime textures must be exact nearest-neighbor exports from native pixel sources.
- Dynamic text and numbers must be Godot labels, never baked into images.
- Background prompts must not mention living artists or named existing game styles.

The exporter and asset pipeline test should be updated when the background or panel assets change. A contact sheet or report should be produced after pipeline changes.

## Files Expected To Change

Implementation should plan changes to these files only unless a test reveals a tighter need:

- `scripts/ledger_data.gd`: add presentation-only guest entry list.
- `scripts/systems/guest_system.gd`: record tonight's visible guest entries and resolution deltas.
- `scripts/game_manager.gd`: copy the guest entries into `current_ledger_data` at settlement.
- `scripts/ui/ledger_screen.gd`: create the guest stage, silhouettes, and animated counters.
- `scenes/ui/LedgerScreen.tscn`: add bounded stage/counter nodes or hide old visible aftermath nodes.
- `scripts/test/test_night_settlement_screen.gd`: contract and behavior tests for the new screen.
- `scripts/test/test_night_settlement_asset_pipeline.py`: updated background/panel asset expectations.
- `scripts/tools/export_night_settlement_assets.py`: export any replacement background or UI art.
- `assets/source/ui/night_settlement/*`, `assets/textures/ui/night_settlement/*`, and `docs/art/night_settlement_contact_sheet.png`: only if the background or UI art is regenerated.

Before modifying the scene, the implementation turn must list the exact files it will touch and why.

## Testing

Behavior tests should cover:

- Existing `LedgerScreen` contract nodes still exist.
- The visible aftermath panel is hidden or absent from the visible layout while its legacy nodes remain available.
- `LedgerData.guest_entries` drives one silhouette per recorded guest.
- Silhouette layer does not block input.
- Counters start from zero or a deliberate initial state, then end at authoritative `LedgerData` totals.
- Per-guest replay increments service, success, failed, gold, and reputation counters consistently.
- Existing major fate cinematic overlays still appear for Ryan and Mira route data.
- Continue still calls the existing next-phase path.

Pipeline tests should cover:

- Replacement runtime background is an exact nearest-neighbor export.
- New background has no baked-in visible character silhouettes if this can be validated by manifest or review artifact.
- Manifest safe areas still reserve space for title, counters, guest lineup, and continue controls.
- Contact sheet exists and is non-empty.

## Non-Goals

- Do not redesign other UI screens.
- Do not delete legacy settlement nodes in the same change.
- Do not migrate the ledger overlay, shop, inventory, day map, tavern HUD, or ending screen.
- Do not change business outcomes to support animation.
- Do not bake dynamic text, readable labels, numbers, or fake UI into generated art.
- Do not introduce a new global UI framework for this single screen.
