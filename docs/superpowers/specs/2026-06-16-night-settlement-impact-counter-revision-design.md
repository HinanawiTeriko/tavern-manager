# Night Settlement Impact Counter Revision

Date: 2026-06-16
Scope: revision of the night settlement `LedgerScreen` presentation only.
Status: design approved in chat; awaiting user review of this written spec.

## Goal

The settlement screen should clearly sell the idea that every guest from tonight is being counted one by one. The black guest silhouettes should arrive from the right and join a left-side queue. Each arrival should trigger the business counter to grow with the main exaggerated motion. The silhouette motion is readable and restrained; the counter board is theatrical.

This revision keeps the work bounded to the settlement surface. It must not change economy math, guest resolution, save/load, day flow, fate resolution, or any tavern gameplay behavior.

## Current Context

The current implementation already contains:

- `LedgerData.guest_entries`, copied into settlement data.
- `LedgerScreen` score replay fields and `_complete_score_replay()` for deterministic completion.
- `ArtLayer/GuestSilhouetteLayer` in `scenes/ui/LedgerScreen.tscn`.
- A hidden legacy aftermath panel using `FateTitle`, `FateList`, and `FatePanelArt`.
- A night settlement asset pipeline in `scripts/tools/export_night_settlement_assets.py`.

The current visual problem is that the silhouettes are too small and the existing background is not tuned for pure black silhouettes. The current animation problem is that silhouettes are effectively placed into their final positions without a strong right-to-left arrival, and the counter board does not yet carry the requested impact.

The repository instructions reference `docs/pixel-ui/`, but that directory is not present in this working tree. The implementation should therefore use the existing title-screen/main UI assets, settlement manifest, exporter, and tests as the local visual and contract references.

## Confirmed Direction

- Keep silhouettes pure black or near-black because they are convenient and readable when the background is designed for them.
- Do not squash, stretch, or rebound the silhouettes themselves.
- Silhouettes may overlap slightly in the final lineup so they read like a queue.
- Put the exaggerated motion on the counter board and stat values.
- Replace or revise the settlement background so the black silhouettes have a lighter cold-blue stone or mist-lit stage behind them.

## Visual Design

The screen remains a closed dungeon tavern at night. The background should be empty of baked-in people and should reserve a clear mid-screen stage for runtime silhouettes.

The silhouette path should run across a readable band:

- Right edge: guests enter from beyond the screen.
- Center: guest crosses the lighter stone-wall or cool haze area.
- Left side: guest joins a compact queue with slight overlap.

The background should support black silhouettes without making the whole screen flat:

- Use dark teal stone and wood as the overall palette.
- Keep a lighter, colder wall/haze band behind the guest route.
- Keep amber candlelight as sparse accents, not as the main shape behind the silhouettes.
- Avoid baked text, numbers, logos, fake UI, or baked character shadows.

The final silhouette queue should sit behind or beside the counter board without obscuring the stat labels. It can feel like the night's customers are lining up in memory while the tavern totals are counted.

## Counter Board Animation

The counter board is the main performance object. For each guest entry:

1. A black silhouette slides in from the right and reaches the next queue slot on the left.
2. On arrival, the relevant business values increment using that guest entry's deltas.
3. The changed stat rows perform the impact animation.

The impact animation should include:

- A short board shake or bump.
- A stat-value scale pop.
- A brief amber flash on changed numbers.
- Optional small pixel burst marks around the changed row.
- A quick return to stable readable text.

The effect should feel exaggerated and playful, but it must not make the final values hard to read. The counter board should settle within a fraction of a second after each guest.

## Data Rules

The replay must use the existing presentation-only guest data. It must not invent business results.

Per guest:

- `gold_delta` changes the gold counter.
- `rep_delta` changes the reputation counter.
- `served_delta` changes served guests.
- `success_delta` changes successful orders.
- `failed_delta` changes failed orders.

At the end of the sequence, displayed totals must be forced to the authoritative `LedgerData` values:

- `gold_today`
- `rep_today`
- `guests_served`
- `orders_success`
- `orders_failed`

If guest entries are missing or incomplete, the screen should still be able to complete to authoritative totals without blocking the player.

## Layout Contract

Target runtime remains `1280x720`.

Preserve these existing scene contracts:

- `UI/TitleLabel`
- `UI/StatsList`
- `UI/FateTitle`
- `UI/FateList`
- `UI/ContinueBtn`
- `ArtLayer/SettlementBackdrop`
- `ArtLayer/StatsPanelArt`
- `ArtLayer/FatePanelArt`
- `ArtLayer/GuestSilhouetteLayer`

Legacy fate summary nodes should remain hidden but available. Major fate cinematic overlays for Ryan, Mira, and future supported NPCs should keep using the existing cinematic path.

The continue button behavior remains:

- If replay is active, the first press completes the replay immediately.
- If replay is complete, pressing continue advances through the existing day-cycle path.

## Asset Pipeline

If the background changes, the implementation must update the existing night settlement pipeline rather than dropping a runtime image directly into the game.

Expected paths:

- Raw generated source: `art_sources/generated_raw/night_settlement/`
- Native pixel source: `assets/source/ui/night_settlement/`
- Runtime texture: `assets/textures/ui/night_settlement/`
- Contact sheet: `docs/art/night_settlement_contact_sheet.png`
- Exporter: `scripts/tools/export_night_settlement_assets.py`
- Pipeline test: `scripts/test/test_night_settlement_asset_pipeline.py`

The runtime background must remain an exact nearest-neighbor export from the native source. Dynamic text and values must be Godot labels.

## Expected Implementation Surface

The likely implementation files are:

- `scripts/ui/ledger_screen.gd`: make silhouettes larger, animate right-to-left arrival, trigger counter-board impact, and keep deterministic completion.
- `scenes/ui/LedgerScreen.tscn`: adjust bounds only if needed for stage, queue, and counter safe areas.
- `scripts/test/test_night_settlement_screen.gd`: add contract tests for silhouette size, queue overlap metadata or positions, right-side start positions, arrival completion, and counter impact nodes/state.
- `scripts/tools/export_night_settlement_assets.py`: update background source references or safe zones if the background is regenerated.
- `scripts/test/test_night_settlement_asset_pipeline.py`: validate the replacement background and updated safe zones.
- `assets/source/ui/night_settlement/*`, `assets/textures/ui/night_settlement/*`, and `docs/art/night_settlement_contact_sheet.png`: only if the background or counter art is exported.

Before modifying any scene, the implementation step must list the exact files it will touch and why.

## Testing

Behavior tests should cover:

- Existing `LedgerScreen` contract nodes still exist.
- The silhouette layer does not block input.
- One silhouette is created for each recorded guest entry.
- Silhouettes start offscreen to the right before replay.
- Completing the replay places silhouettes into a slightly overlapping left-side queue.
- The silhouette size is larger than the current too-small implementation.
- Counter values complete to authoritative `LedgerData` totals.
- Continuing during replay completes the replay instead of advancing the day.
- Continuing after replay uses the existing next-phase behavior.
- Ryan and Mira fate cinematics still appear and dismiss as before.

Pipeline tests should cover:

- The background runtime PNG is an exact nearest-neighbor export from native.
- The manifest reserves safe zones for title, guest route/queue, score counter, and continue control.
- The contact sheet exists and shows the updated background and controls.
- The background source/prompt record exists and does not rely on named game styles, living artists, readable generated text, or baked character silhouettes.

Manual visual review should check:

- Black silhouettes read clearly against the background.
- The queue can tolerate several guests with mild overlap.
- The counter board feels like the primary impact moment.
- Final values are readable within seconds.
- The screen still feels like the existing dark teal dungeon tavern UI.

## Non-Goals

- Do not redesign any other screen.
- Do not delete legacy settlement UI nodes in this change.
- Do not change economy, reputation, guest, save, or day-cycle semantics.
- Do not bake dynamic text, readable labels, numbers, or fake UI into generated art.
- Do not animate silhouettes with squash/stretch or rebound.
- Do not introduce a new UI framework for this single screen.
