# Pixel UI Screen Recipes

## DayMap

- Primary map lives in world space.
- Location detail is a pinned note near the selected marker.
- Fast positive feedback uses `GatheringToast`.
- Full result panel is for blocking or longer text.
- Camera movement and pinned note placement must not make controls inaccessible.

Relevant tests:

- `test_day_map_system.tscn`
- `test_day_map_scrollbars.tscn`
- `test_daymap_camera.tscn`

## Tavern

- Preserve `CustomerArea/CustomerSprite`, `BarWorkspace`, `CustomerDropArea`, top bars, shortcut bar, and overlay contracts.
- Menu preparation happens before service and should be dense but readable.
- Guest reactions should not obscure physics interactions.
- Reward feedback can animate but must not block table clicks.

Relevant tests:

- `test_tavern_patience_ui.tscn`
- `test_workspace_scene_recovery.tscn`
- `test_regular_customers.tscn`

## Ledger

- Settlement should read as after-hours accounting, not a shop/menu screen.
- Fate notices can block score replay briefly, but replay must continue deterministically.
- Restart-current-day button and clock overlay must preserve their contracts.

Relevant tests:

- `test_night_settlement_screen.tscn`
- `test_ledger_restart_day_entry.tscn`
- `test_clock_rewind_overlay.tscn`
