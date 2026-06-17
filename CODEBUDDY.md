# CODEBUDDY.md

CodeBuddy should use the same current documentation set as other agents.

## Required Reading

1. `AGENTS.md`
2. `README.md`
3. `docs/00_文档索引.md`
4. `docs/01_开发规范.md`
5. `docs/02_项目速查.md`

## Current Truth

The current project is a Godot 4.6.3 dungeon tavern management game with:

- DayMap preparation, gathering, shop, investigations, and rumors.
- Nightly menu preparation based on rumors and customer memory.
- Physics-based tavern service with barrel, grill, pot, seasoning, and drag-to-serve.
- Important NPC routes for Ryan, Mira/Toby, and Evelyn/grey-ledger.
- 30 named regular customers with portraits and appetites.
- Anonymous guest groups affected by rumors.
- Ledger settlement replay and restart-current-day.

Older descriptions of fixed crafting slots, no save system, no tests, 7 subsystems only, or early v0.2 scope are obsolete.

## Do Not Use as Current Requirements

- `docs/archive/legacy-numbered/`
- `docs/archive/branch-overviews/`
- `docs/superpowers/plans/`
- `docs/superpowers/specs/`

These directories explain history only.

## Verification

Run the smallest relevant test first. Use the Godot console binary:

```powershell
& 'D:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'D:\game\tavern-manager' 'res://scenes/test/test_day_map_system.tscn'
```

For content/data work, also consider:

- `test_rumor_appetite_system.tscn`
- `test_regular_customers.tscn`
- `test_restart_current_day.tscn`
- `test_save_roundtrip.tscn`

For UI work, preserve contracts and run the relevant UI scene test before reporting completion.
