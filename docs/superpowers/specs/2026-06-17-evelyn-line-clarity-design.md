# Evelyn Line Clarity Design

Date: 2026-06-17
Status: Approved direction, pending implementation plan

## Goal

Make the Evelyn grey-ledger route read as a complete character line, not a chain of cryptic clues.

The player should understand:

- Who Evelyn is.
- Why she speaks in ledger terms.
- Why she lets the player find the grey-ledger trail.
- How Ryan, Toby, and Mira connect to her route.
- What evidence changes Day20 from sealed account, to amended account, to public account.

The route should stay morally cold and investigative. It should not become a direct confession, quest marker tutorial, or simple villain monologue.

## Current Problem

The existing route has the needed mechanics and evidence chain:

- Day5, Day8, Day13, and Day20 Evelyn visits.
- Grey-ledger DayMap locations.
- Clearing-table investigation.
- Inference questions for same batch, payout method, Mira link, and public account.
- Ending branches for sealed, amended, and public account.

The weakness is readability. Evelyn's current dialogue leans too hard on poetic ledger language before the player knows her role, beliefs, or relationship to the case. As a result, the player receives clues but not a stable character image.

## Character Design

Evelyn is a polite, elegant, professional guild clearer. She is not a random mystery speaker. She is someone whose job is to make damage administratively survivable.

Her core belief:

> A clean account cannot save the dead, but it can keep the living from drowning in unfinished loss.

Her moral failure:

> She knows the grey ledger hurts people, but she translates names into columns, batches, payouts, and seals so she can keep doing the work.

Her contradiction:

> She believes sealing accounts is mercy, but she also knows some accounts are only "clean" because the truth was removed.

Her relationship to the player:

> The player has already caused fate records to deviate. Evelyn treats the tavern keeper as an outside audit: if the player cannot assemble proof, the account remains sealed; if the player can assemble proof, she no longer has a professional excuse to close it.

## Why Evelyn Lets the Player Know

Evelyn is not confessing. She is running a controlled audit and testing whether the player can turn scattered abnormalities into public evidence.

Surface motive:

- The player has touched Ryan, Toby, and Mira's cases.
- Evelyn needs to know whether those deviations are isolated mistakes or a pattern that threatens the guild's grey ledger.
- She points the player at audit paths because a real challenge must be documented, not guessed.

Deep motive:

- Evelyn cannot betray the guild by directly handing over the conclusion.
- She can, however, name locations, rules, and ordering problems.
- If the player fails, she can truthfully say the evidence did not rise above suspicion.
- If the player succeeds, she can truthfully say the account can no longer be sealed.

This keeps her agency intact without turning her into a careless expositor.

## Route Shape

### Day5: First Impression

Purpose: establish Evelyn as a guild clearer with a believable worldview.

Player takeaway:

- Evelyn works around payouts and accident records.
- She believes fast settlement can be a kind of mercy.
- The strange phrase "payout before obituary" is not just atmosphere; it is the first visible crack.

Writing target:

- Pair one elegant line with one concrete idea.
- Avoid explaining the whole grey ledger this early.
- Make her unsettling because she is reasonable, not because she is obscure.

### Day8: First Pattern

Purpose: connect Evelyn to Toby's Blacktooth commission without fully revealing the route.

Player takeaway:

- Evelyn knows Blacktooth is not a fresh isolated job.
- Batch numbers and renamed work matter.
- Toby's case is being fit into an older administrative pattern.

Writing target:

- Let Evelyn sound like she is warning the player and measuring them at the same time.
- Keep her motive ambiguous, but make the clue's concrete meaning clear.

### Day13: Audit Starts

Purpose: formally open the grey-ledger investigation.

Player takeaway:

- Evelyn has recognized the player as someone who can audit the pattern.
- The first stop is the payout office.
- The method is to check order: when payout, closure, missing names, and seals appear.
- The player must prove the columns are wrong.

Writing target:

- Make "go to payout office" and "look at order" explicit.
- Name Ryan, Toby, and Mira as the three relevant lines.
- Show Evelyn's professional pride: she will not accept feeling, only proof.

### Day14-17: Investigation Spine

Purpose: make each investigation result reinforce the same case.

Player takeaway:

- Payout office: Ryan's case shows payout and closure order.
- Clearing table: the player physically produces the grey contract traces.
- Blacktooth ledger: Toby's commission was renamed and batched.
- Mira supply copy: Mira's agreement links the supply guarantee to the same grey contract mechanism.

Writing target:

- Strengthen location descriptions, result text, document pages, and fate notes so every clue says what it proves.
- Do not add new UI.
- Do not change scene node names, public methods, or signal contracts.

### Inference Sequence

Purpose: make the deduction chain feel like building a case file.

Player takeaway:

1. Ryan and Toby share the same grey batch.
2. The batch works by paying first, then closing.
3. Mira's supply agreement links the personal story to the same sealing method.
4. Publicly joining all three lines prevents Evelyn from closing the account as a private guild matter.

Writing target:

- Keep fill-in puzzle answers unchanged unless needed for clarity.
- Improve titles, hints, and conclusions.
- Avoid wording that makes a clue sound like it performs the action when it merely proves the action.

### Day20: Settlement

Purpose: make Day20 feel like a confrontation with Evelyn, not a surprise branch result.

Player takeaway:

- Sealed account: the player did not build enough proof, so Evelyn can close the ledger.
- Amended account: the player proved errors, so Evelyn must correct part of the account, but the guild keeps control.
- Public account: the player joined Ryan, Toby, and Mira into evidence that can leave the guild, so Evelyn cannot seal it.
- Living witnesses versus paper-only pressure depends on prior line outcomes.

Writing target:

- In pre-dialogue, let Evelyn state the three possible outcomes in character.
- In post-dialogue, make her response reveal what the player proved and what she is forced to do.
- Preserve the existing branch variables: `evelyn_ending` and `evelyn_pressure`.

## Content Changes

Expected runtime content files:

- `dialogue/evelyn_day5.pre.dialogue`
- `dialogue/evelyn_day5.post.dialogue`
- `dialogue/evelyn_day8.pre.dialogue`
- `dialogue/evelyn_day8.post.dialogue`
- `dialogue/evelyn_day13.pre.dialogue`
- `dialogue/evelyn_day13.post.dialogue`
- `dialogue/evelyn_day20.pre.dialogue`
- `dialogue/evelyn_day20.post.dialogue`
- `data/documents.json`
- `data/inference_puzzles.json`
- `data/locations.json`
- `data/npcs.json`
- `scripts/game_manager.gd`

Expected tests:

- `scripts/test/test_evelyn_grey_ledger_line.gd`
- `scripts/test/test_inference_system.gd`
- Optional, if route text affects location contracts: `scripts/test/test_day_map_system.gd`

## Non-Goals

- Do not build a new quest tracker UI.
- Do not rebuild the inference screen.
- Do not change the clearing-table scene contract.
- Do not alter economy, save/load, serving, or simulation logic.
- Do not rename existing nodes, signals, public methods, resource paths, or autoload APIs.
- Do not generate new art.

## Acceptance Criteria

After implementation:

- A player can summarize Evelyn after Day5 as a guild clearer who believes settlement can be mercy.
- A player can explain after Day13 why Evelyn points them to the payout office without reading external notes.
- Each grey-ledger document states both what it is and what it proves.
- Each grey inference conclusion advances the case in clear order.
- Day20 dialogue explains why the player's evidence produced sealed, amended, or public account.
- Existing Evelyn route tests pass.
- Relevant inference tests pass.

## Verification Plan

Run focused text/data and route tests first:

- `res://scenes/test/test_evelyn_grey_ledger_line.tscn`
- `res://scenes/test/test_inference_system.tscn`
- `res://scenes/test/test_day_map_system.tscn` if `data/locations.json` assertions change.

If the implementation touches only text and data, no art pipeline validation is required.
