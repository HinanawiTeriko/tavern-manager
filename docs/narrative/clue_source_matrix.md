# Clue Source Matrix

Date: 2026-06-18

## Goal

This file is the working contract for integrating narrative clues with tavern management.
It keeps clue sources from collapsing into one vague "rumor" bucket.

## Source Rules

| Source kind | Meaning | Primary gameplay surface | Must not do |
|---|---|---|---|
| Wind | Public noise, likely guests, menu pressure, route hints | Normal customers, DayMap rumors, menu prep | Prove core facts |
| Heart | Motive, fear, denial, trust, pressure | Important NPC dialogue and service reactions | Replace investigation or inference |
| Evidence | Physical or written proof | Investigation scenes, documents, ledger pages | Come only from casual customer talk |
| Fact | Player-confirmed conclusion | Inference puzzles and unlock flags | Appear as a one-line rumor |
| Cost | What the player spends or risks | Menu, service quality, gold, trust, seasoning/story items | Stay hidden as only a variable flip |
| Consequence | What the choice changes later | Ledger, next-day map state, endings, customer pressure | Exist only in dialogue branches |

Short form:

- Normal customers = Wind
- Important NPCs = Heart
- Physical investigation = Evidence
- Inference puzzles = Fact
- Tavern operation = Cost
- Ledger / next day = Consequence

## Menu UI Constraint

Menu preparation already has dense top-level structure:

- Left top: `RumorScroll`
- Left bottom: `YesterdayEchoScroll`
- Right: `ProductScroll`
- Bottom: selected menu, recommendation detail, start button

Do not add a new top row or a new standalone clue panel for this phase.
New clue context should be folded into the existing left scroll cards with compact labels:

- `风声 · ...` for rumor text
- `菜单：...` for actionable menu advice
- One compact context line for customer groups, likely named customers, and recommended tags

The menu prep surface should remain a planning screen, not a case-board screen.
Evidence and facts belong in documents and inference UI.

## Line Matrix

| Line | Wind | Heart | Evidence | Fact | Cost | Consequence |
|---|---|---|---|---|---|---|
| Ryan | Board and mine-shift talk point toward North Mine pressure | Ryan wants work and fears being seen as weak | `bloodied_contract`, `alternative_contract` | Player understands the Bloodaxe job is unsafe | Warn, offer alternative, drug ale, or ignore | Day3 fate track and later Evelyn witness pressure |
| Toby / Mira | Old-road, trade, and ledger customers can surface old-route talk | Toby repeats "one person walks lighter"; Mira avoids old responsibility | `toby_contract` and Mira supply copies | Inference links Toby, Mira, old road, and responsibility | Build Mira trust or pay fixer | Day12 Mira/Toby fate track and Evelyn pressure |
| Evelyn / Grey Ledger | Ledger customers and Evelyn point toward suspicious payout order | Evelyn fears the account will be sealed again | Grey batch records, payout register, supply stamp | Inference links Ryan, Toby, Mira into one public account | Complete evidence, protect witnesses, push public account | Day20 sealed / amended / public outcomes |

## Current Implementation Slice

This slice makes two concrete changes:

1. Mira/Toby old-ledger customer gossip is no longer granted by any ordinary customer.
   It must come from a related current customer source: old-road, trade, or ledger.
2. Menu preparation rumor cards use compact source labels inside the existing `RumorScroll`.
   No new top-level UI surface is added.

## Future Slices

1. Ryan Day1-3 can be tightened next by making the menu prep and ledger copy explicitly say:
   Ryan gives heart, the mine gives evidence, service choices create cost.
2. Toby/Mira can then move more clue dispatch into customer group profiles instead of global random gossip.
3. Evelyn can get earlier ledger gap hints before Day20, after the first two lines are cleaner.
