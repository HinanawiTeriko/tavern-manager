# Dungeon Tavern

Godot 4.6.3 pixel-art dungeon tavern management game. The current build is no longer a simple crafting prototype: it combines DayMap preparation, rumor-driven menu planning, physics-based tavern service, regular customer memory, important NPC story routes, and nightly settlement replay.

## Current Loop

```text
TitleScreen
  -> DayMap: visit locations, gather resources, hear rumors, shop, investigate
  -> Tavern: choose the daily menu, serve guests on the physics bar
  -> LedgerScreen: replay results, story/fate notices, restart-current-day option
  -> next DayMap or EndingScreen
```

The authoritative runtime coordinator is `GameManager` (`res://scripts/game_manager.gd`). It owns the system instances, scene handoffs, save/load, day restart snapshots, rumor/menu preparation, guest spawning, service resolution, story item delivery, and settlement data.

## Key Systems

| Area | Main Files |
|---|---|
| Day/night flow | `scripts/game_manager.gd`, `scripts/systems/day_cycle_system.gd` |
| DayMap | `scenes/ui/DayMap.tscn`, `scripts/ui/day_map_view.gd`, `scripts/systems/day_map_system.gd`, `data/locations.json` |
| Rumors and menu planning | `scripts/systems/rumor_system.gd`, `scripts/systems/appetite_system.gd`, `data/rumors.json`, `data/guest_appetites.json`, `data/guest_group_profiles.json` |
| Guests | `scripts/systems/guest_system.gd`, `data/regular_customers.json`, `data/guest_reactions.json` |
| Tavern physics | `scenes/ui/Tavern.tscn`, `scripts/ui/bar_workspace.gd`, `scripts/test/desk_item.gd`, `scripts/ui/kitchen_container.gd` |
| Recipes and inventory | `scripts/systems/craft_system.gd`, `scripts/systems/inventory_system.gd`, `data/items.json`, `data/recipes.json` |
| Story and inference | `scripts/systems/narrative_manager.gd`, `scripts/systems/inference_system.gd`, `data/npcs.json`, `data/inference_puzzles.json`, `dialogue/` |
| Settlement | `scenes/ui/LedgerScreen.tscn`, `scripts/ui/ledger_screen.gd`, `scripts/ledger_data.gd` |
| Save/restart | `scripts/systems/save_system.gd`, `GameManager.capture_day_start_snapshot()`, `GameManager.restart_current_day()` |

## Playable Content Snapshot

- 21-day current campaign boundary, with Ryan, Mira, Toby, and Evelyn/grey-ledger routes resolving by Day 20 and a final Day 21 epilogue management day.
- 30 named regular customers with neutral/satisfied/dissatisfied portraits.
- Anonymous guest groups driven by DayMap rumors, each with reusable regular-customer portrait pools.
- Menu preparation before service, using current-day rumors and previous-night echoes.
- Food appetite tags and customer memory affect feedback and word-of-mouth.
- Tavern service uses physical dragging, barrel/grill/pot processing, seasoning, quality, and customer drop-off.
- Ledger settlement shows guest entries, rumor summary, score impact, fate notices, and restart-current-day flow.

## Run

Open the repository in Godot 4.6.3 standard and run the main scene:

```text
res://scenes/ui/TitleScreen.tscn
```

The project is GDScript-only for gameplay. The Godot MCP/editor environment may print `.NET` noise; treat that as environmental unless the standard editor reproduces it.

## Targeted Verification

Use the Godot console binary in this workspace:

```powershell
& 'D:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'D:\game\tavern-manager' 'res://scenes/test/test_rumor_appetite_system.tscn'
```

High-value smoke tests:

| Purpose | Scene |
|---|---|
| Baseline systems | `res://scenes/test/test_baseline_systems.tscn` |
| DayMap logic | `res://scenes/test/test_day_map_system.tscn` |
| DayMap UI contracts | `res://scenes/test/test_day_map_scrollbars.tscn` |
| Rumors/appetite/menu prep | `res://scenes/test/test_rumor_appetite_system.tscn` |
| Regular customers | `res://scenes/test/test_regular_customers.tscn` |
| Tavern UI contracts | `res://scenes/test/test_tavern_patience_ui.tscn` |
| Settlement | `res://scenes/test/test_night_settlement_screen.tscn` |
| Restart current day | `res://scenes/test/test_restart_current_day.tscn` |
| Save roundtrip | `res://scenes/test/test_save_roundtrip.tscn` |

Some headless tests can emit `ObjectDB instances leaked at exit`; use the process exit code and test failure count as the primary signal unless the leak is the subject of the change.

## Documentation

Start with [docs/00_文档索引.md](docs/00_文档索引.md). The old numbered planning documents were moved under `docs/archive/legacy-numbered/` and are historical reference only.
