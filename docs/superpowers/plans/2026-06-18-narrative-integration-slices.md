# Narrative Integration Slices Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the next six narrative-management integration slices from `docs/narrative/day1_day20_route_matrix.md`.

**Architecture:** Keep the existing Godot systems intact. Put route guidance in existing data and `GameManager` fate-track notes, keep inference source taxonomy in `InferenceSystem`, and verify through existing script tests instead of scene migrations.

**Tech Stack:** Godot 4.6.3, GDScript, JSON data files, existing `scripts/test/*.gd` runner scripts.

---

## Files

- Modify: `data/inference_puzzles.json`
  - Correct Toby heart clue source names.
- Modify: `scripts/game_manager.gd`
  - Add contextual fate-track hints for Mira old-road pursuit, Mira trust, grey clearing-table follow-up, Day18-Day19 public-account gaps, and Ryan drugged-survivor pressure.
- Modify: `scripts/systems/narrative_manager.gd`
  - Keep Ryan drugged survivor as living pressure, with wording covered through `GameManager` track output.
- Modify: `scripts/test/test_inference_system.gd`
  - Verify Toby heart clue source copy.
- Modify: `scripts/test/test_day_map_system.gd`
  - Verify Day7-Day11 Mira guidance and Day14-Day17 clearing-table hints.
- Modify: `scripts/test/test_evelyn_grey_ledger_line.gd`
  - Verify Day18-Day19 public-account gap hints and Ryan drugged witness wording.

## Tasks

### Task 1: Toby Heart Clue Source Copy

- [ ] Write a failing test in `scripts/test/test_inference_system.gd` asserting `back_alley_boy.source == "托比夜谈"` and `one_person_walk.source == "托比夜谈"`.
- [ ] Run `godot --headless --path . --script res://scripts/test/test_inference_system.gd` and confirm it fails on the new assertion.
- [ ] Update `data/inference_puzzles.json`.
- [ ] Re-run the test and commit.

### Task 2: Mira Old-Road Menu Guidance

- [ ] Write a failing test in `scripts/test/test_day_map_system.gd` that starts Day7 after Toby route activation, opens the ledger, and expects a Mira fate note naming old-road/trade guests and menu prep.
- [ ] Add `GameManager` helper logic that writes this note once per day while missing old-road gossip clues.
- [ ] Re-run `test_day_map_system` and commit.

### Task 3: Mira Trust Warning

- [ ] Write a failing test in `scripts/test/test_day_map_system.gd` that gives Mira `toby_contract` below trust threshold and expects a fate note saying she heard it but may not turn back.
- [ ] Add the note in the existing Mira story-item handling path without exposing raw numbers.
- [ ] Re-run `test_day_map_system` and commit.

### Task 4: Grey Clearing-Table Follow-Up

- [ ] Write failing tests in `scripts/test/test_day_map_system.gd` for Day14 payout office, Day16 blacktooth ledger, and Day17 Mira supply copy result text, each expecting an explicit return-to-clearing-table instruction.
- [ ] Update location result handling or data text with precise follow-up wording.
- [ ] Re-run `test_day_map_system` and `test_evelyn_grey_ledger_line`, then commit.

### Task 5: Day18-Day19 Public-Account Gap Hints

- [ ] Write a failing test in `scripts/test/test_evelyn_grey_ledger_line.gd` that starts Day18 with missing public-account requirements and expects the Evelyn fate track to include `get_evelyn_public_account_gap_summary()`.
- [ ] Add a once-per-day fate note on Day18-Day19.
- [ ] Re-run `test_evelyn_grey_ledger_line` and commit.

### Task 6: Ryan Drugged Survivor Pressure

- [ ] Write a failing test in `scripts/test/test_evelyn_grey_ledger_line.gd` expecting the Evelyn pressure summary or track result to describe drugged Ryan as a forced survivor witness.
- [ ] Add wording in the Ryan/Evelyn pressure path without changing route priority.
- [ ] Re-run `test_evelyn_grey_ledger_line`, `test_ryan_actions`, and `test_ryan_delivery`, then commit.

### Task 7: Final Verification

- [ ] Run the touched suites:
  - `godot --headless --path . --script res://scripts/test/test_inference_system.gd`
  - `godot --headless --path . --script res://scripts/test/test_day_map_system.gd`
  - `godot --headless --path . --script res://scripts/test/test_evelyn_grey_ledger_line.gd`
  - `godot --headless --path . --script res://scripts/test/test_ryan_actions.gd`
  - `godot --headless --path . --script res://scripts/test/test_ryan_delivery.gd`
- [ ] Run `git status --short`.
- [ ] Report commits and any residual risks.
