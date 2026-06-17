# Pixel UI Components

Prefer reusing current components before building new ones.

## Existing Components

| Component | Location | Use |
|---|---|---|
| `GatheringToast` | `scripts/ui/components/gathering_toast.gd` | DayMap top feedback for rewards and rumors |
| `PinnedNotePanel` | `DayMap.tscn` / `day_map_view.gd` | Map-world detail card for locations |
| `ResultPanel` | `DayMap.tscn` | Blocking visit result when top toast is not enough |
| `MenuPrep` controls | `tavern_view.gd` | Nightly menu planning |
| `InferenceReadyNotice` | `Tavern.tscn` / `tavern_view.gd` | Small transient question mark cue |
| `RecipeDiscoveryNotice` | `tavern_view.gd` | Compact recipe discovery feedback |
| Ledger fate notices | `ledger_screen.gd` | Settlement story notices |

## Component Rules

- Use icon or compact text controls for actions; avoid decorative labels as controls.
- Do not create nested cards unless the inner card is a repeated item or modal.
- Preserve legacy UI until replacement is tested and accepted.
- UI feedback that is not a decision point should be transient and non-blocking.
- Blocking panels must have a clear continue/close action and should be used sparingly.
