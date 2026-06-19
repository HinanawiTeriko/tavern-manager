# Narrative And Management Integration Design

Date: 2026-06-18

## Problem

The current game already has useful pieces: tavern service, DayMap gathering, rumors, important NPC nights, investigation scenes, inference puzzles, and fate notes. The problem is not that the game lacks systems. The problem is that the systems can feel like separate layers.

The player can cook, buy ingredients, hear rumors, meet important NPCs, investigate scenes, and solve inference questions, but the game does not always make it clear why those actions belong to the same story loop.

This phase fixes the structural problem:

> Tavern management must become the way the player discovers, tests, pays for, and acts on narrative information.

## Scope

This design covers the first integration phase only:

- Define what each clue source is allowed to do.
- Reframe Ryan, Mira/Toby, and Evelyn as tavern-driven routes.
- Decide which UI/data surfaces should carry clue context.
- Define what "done" means before moving to balance, pacing, UI polish, and text rewrites.

This phase does not:

- Rewrite all dialogue.
- Replace the menu UI.
- Add new investigation scenes.
- Change node paths, signals, public methods, or autoload APIs.
- Expand content beyond the existing three character lines.

## Recommended Approach

### Option A: Rewrite the narrative first

Rewrite dialogue and clue text across all three lines, then adjust systems afterward.

Tradeoff: This may improve tone quickly, but it risks rewriting around unclear gameplay contracts. The same source confusion can return.

### Option B: Add a new case-board layer

Create a separate clue board that collects everything and explains relationships.

Tradeoff: It could clarify the story, but it adds another screen and may make the tavern feel even less central.

### Option C: Source-contract integration

Keep existing systems, but assign each system a strict narrative job. Then route every clue through that source contract.

Recommendation: Use Option C. It preserves the current implementation, lowers risk, and directly addresses the problem: the player needs to know where information came from and why management matters.

## Source Contract

Every narrative item must belong to exactly one primary source kind.

| Source kind | Meaning | Primary surface | Allowed output | Must not do |
|---|---|---|---|---|
| Wind | Public noise, likely movement, menu pressure, location hints | Normal customers, DayMap rumors, menu prep | Suggest what to prepare or where to look | Prove core facts |
| Heart | Motive, fear, denial, trust, pressure | Important NPC dialogue, service reactions, item delivery reactions | Show what a person wants or avoids | Replace evidence or inference |
| Evidence | Physical or written proof | Investigation scenes, documents, copied records | Enter the ledger as proof | Come only from casual talk |
| Fact | Player-confirmed conclusion | Inference puzzles and unlock flags | Change route logic and later consequences | Appear as a one-line rumor |
| Cost | What the player spends or risks | Menu choices, gold, service quality, seasoning, story item delivery | Make story action feel like management | Stay hidden as a variable flip |
| Consequence | What changes later | Ledger fate notes, next-day state, endings, pressure on later routes | Show result of prior decisions | Exist only inside dialogue branches |

Short rule:

- Normal customers create Wind.
- Important NPCs reveal Heart.
- Investigation gives Evidence.
- Inference creates Fact.
- Tavern management creates Cost.
- Ledger and later days show Consequence.

## Core Loop

The integrated loop should read like this:

1. DayMap and customer Wind suggest what matters tonight.
2. Menu preparation lets the player convert Wind into operational choices.
3. Tavern service creates Cost through ingredients, quality, trust, gold, timing, and seasoning.
4. Important NPCs reveal Heart when served or confronted.
5. DayMap investigation gives Evidence.
6. Inference turns Wind, Heart, and Evidence into Fact.
7. Facts and costs produce Consequences in ledger notes, route state, and endings.

If a new narrative beat cannot be placed in this loop, it should not enter the game yet.

## Surface Responsibilities

### DayMap

DayMap should answer: "Where can I push today?"

It may show:

- Materials gained.
- Actual Wind text after visiting a location.
- Investigation entries that clearly say Evidence was found.
- Location hints unlocked by prior Facts or Heart.

It should not silently grant core story truth without telling the player what was learned.

### Menu Preparation

Menu prep should answer: "What should I prepare tonight, and why?"

It may show compact context inside the existing prep cards:

- `风声 · ...`
- `菜单：...`
- relevant customer groups or likely named customers

It should not become a full case-board. Evidence and Facts belong to documents and inference screens.

### Normal Customers

Normal customers should answer: "What is the town saying?"

They may grant Wind if:

- the customer group is relevant,
- the player served them successfully,
- the current route state makes the Wind useful.

They should not directly reveal facts like "Mira is responsible" or "the Grey Ledger pays before closing cases."

### Important NPCs

Important NPCs should answer: "What does this person want, fear, or refuse to admit?"

They may reveal Heart through:

- pre-service dialogue,
- post-service dialogue,
- service style reactions,
- story item delivery reactions.

They should not replace investigation or inference. If an NPC states a truth, the game should treat it as Heart unless the player also has Evidence or Fact.

### Investigation Scenes

Investigation should answer: "What proof did I physically obtain?"

It should grant Evidence and show a `证据 · ...` feedback line. This is already partially implemented and should remain the preferred route for hard proof.

### Inference Puzzles

Inference should answer: "What did the player prove by connecting sources?"

It should unlock Facts. These Facts are the only stable source for route logic that depends on conclusions.

### Ledger

Ledger should answer: "What happened because of what I did?"

It should show Consequence and route gaps. It should also preserve source labels so the player can distinguish Wind, Heart, Evidence, and Fact after the night ends.

## Character Route Structure

### Ryan

Role in the game: early teaching route for evidence delivery, trust, and moral cost.

Core question:

> Do you help Ryan act with knowledge, redirect him, drug him, or let him go?

| Beat | Day / surface | Source kind | Management link | Result |
|---|---|---|---|---|
| Ryan wants dangerous advancement | Day1 important NPC | Heart | Serve him, build initial trust | Player understands his motive |
| Bloodaxe job enters town | Day2 board / Wind | Wind | Menu prep can point toward mine-shift guests | Player knows where pressure is |
| Bloodied contract | Mine investigation | Evidence | Spend DayMap stamina | Player can warn Ryan |
| Alternative contract | Guild counter | Evidence | Spend DayMap stamina after reading evidence | Player can redirect Ryan |
| Sleep powder | Shop Wind + forest material + seasoning/service | Cost | Use seasoning as a risky intervention | Saves Ryan with trust cost |
| Ryan outcome | Day3 fate reveal / ledger | Consequence | Prior evidence delivery and service choices matter | Later Evelyn witness pressure changes |

Ryan is complete for this integration phase when:

- Day1-3 clearly teach Heart -> Evidence -> Cost -> Consequence.
- Sleep powder is framed as a costly intervention, not just a hidden solution.
- Ledger and post-dialogue feedback tell the player what kind of information they just received.

### Mira / Toby

Role in the game: main route for ordinary customer Wind, old-road history, trust, and responsibility.

Core question:

> Can the player prove Toby's danger, connect it to Mira, and create enough trust or cost for someone to act?

| Beat | Day / surface | Source kind | Management link | Result |
|---|---|---|---|---|
| Mira avoids old road | Day4 / Day6+ Mira stall | Heart | Visit stall, build trust | Player sees avoidance, not proof |
| Toby name and suspicious job | Mercenary board | Wind | DayMap stamina | Opens Toby identity thread |
| Toby as back-alley boy | Toby night + inference | Fact | Serve Toby, then infer from Heart and Wind inputs | Player connects name to person |
| "One person walks lighter" | Toby dialogue | Heart | Serve Toby and observe the repeated wound | Player sees the phrase before proving its origin |
| Old road mentor story | Old-road/trade/ledger customers | Wind | Menu prep targets relevant guests | Opens Mira/Toby relation inference |
| Toby contract | Lodging investigation | Evidence | Spend DayMap stamina after Fact | Hard proof of danger |
| Mira responsibility | Inference | Fact | Requires Wind + Heart | Player can confront Mira properly |
| Deliver contract to Mira | Story item delivery | Cost | Trust changes response after Evidence and Fact are available | Mira may act or refuse |
| Fixer route | Fixer den | Cost | Spend large gold amount | Saves Toby without Mira's responsibility |
| Day12 outcome | Important NPC + ledger | Consequence | Trust, Fact, fixer cost decide | Mira/Toby route resolves |

Mira/Toby is complete for this integration phase when:

- Ordinary customers only grant relevant Wind, not hard truth.
- The player understands why menu prep can target old-road, trade, or ledger customers.
- `toby_contract` remains the hard Evidence source.
- Inference owns the responsibility Fact.
- Day12 clearly reflects whether the player used trust, money, or did nothing.

### Evelyn / Grey Ledger

Role in the game: late route that binds Ryan and Mira/Toby into one public account.

Core question:

> Can the player gather enough proof and living pressure to keep the Grey Ledger from being sealed again?

| Beat | Day / surface | Source kind | Management link | Result |
|---|---|---|---|---|
| Evelyn notices payout irregularity | Day5 / Day8 important NPC | Heart | Serve Evelyn, maintain access | Player knows account order matters |
| Payout office records | Day14 DayMap | Evidence | Spend stamina | Ryan records enter ledger |
| Blacktooth ledger | Day16 DayMap | Evidence | Spend stamina | Toby records enter ledger |
| Mira supply copy | Day17 DayMap | Evidence | Spend stamina | Mira records enter ledger |
| Clearing table | Investigation scene | Evidence | Physical proof action | Converts copied records into stronger evidence |
| Same batch / payout method / supply link | Inference | Fact | Requires prior route facts and evidence | Grey Ledger becomes coherent |
| Public account | Final inference | Fact | Requires three route strands | Public route becomes possible |
| Ryan and Toby/Mira outcomes | Prior consequences | Consequence | Living witnesses increase pressure | Evelyn ending weight changes |
| Day20 route | Important NPC + ledger | Consequence | Evidence completeness and witness pressure matter | Sealed, amended, or public account |

Evelyn is complete for this integration phase when:

- Day20 does not feel like a sudden checklist.
- Missing public-account gaps appear earlier in ledger or DayMap context.
- Grey evidence is clearly Evidence, even when copied from DayMap rather than a full investigation scene.
- Ryan and Mira/Toby consequences visibly affect Evelyn pressure.

## First Implementation Slice

The first code implementation after this design should be small:

1. Build a route-source table in docs first, using the contract above.
2. Tighten Mira/Toby ordinary-customer Wind dispatch:
   - old-road guests can reveal old-road Wind,
   - trade guests can reveal Mira route Wind,
   - ledger guests can reveal account-related Wind,
   - unrelated customers should not grant core Mira/Toby clues.
3. Keep menu prep compact:
   - no new top-row UI,
   - reuse existing rumor cards,
   - show `风声 · ...` and `菜单：...`.
4. Add tests that prove unrelated ordinary customers cannot grant route-critical Wind.

This slice is recommended first because it targets the most confusing source problem without rewriting endings or scenes.

## Completion Definition

The integration problem is considered solved when these are all true:

1. Every route-critical clue has one primary source kind.
2. Every route-critical clue has a clear player action that explains why the player knows it.
3. Normal customers only provide Wind.
4. Important NPCs only provide Heart unless the player gives them Evidence or uses a proven Fact.
5. Investigation scenes and copied records are labeled as Evidence.
6. Inference puzzles are the only source of route Facts.
7. Menu preparation explains why tonight's menu matters without becoming a new case-board.
8. Ledger can answer: what did the player learn, what did the player prove, and what consequence followed?
9. Ryan, Mira/Toby, and Evelyn each have at least one visible management Cost that affects the route.
10. Day3 teaches the loop, Day12 tests it, and Day20 resolves it.

## Explicit Non-Goals For This Phase

- Do not rebalance all recipes yet.
- Do not redesign the entire menu screen yet.
- Do not make all Grey Ledger locations into full investigation scenes yet.
- Do not add new character lines.
- Do not expand beyond the current 30-day structure.
- Do not rewrite old legacy dialogue files until runtime usage is audited.

## Follow-Up Problem Queue

After integration, the remaining work should be handled in this order:

1. Pacing: decide how many story beats a night can carry.
2. Menu and material balance: make story dishes feel like choices, not chores.
3. Inference difficulty: make correct answers feel reasoned, not guessed.
4. Investigation readability: make evidence acquisition legible and not slow.
5. UI density: improve menu, DayMap toasts, ledger, and inference display without adding clutter.
6. Text rewrite: tighten voice and emotional progression after structure is stable.
7. First-three-days onboarding: ensure Day3 teaches the full core loop.

## Acceptance Tests And Verification

Documentation acceptance:

- The source contract has no overlapping responsibilities.
- Each character line has Wind, Heart, Evidence, Fact, Cost, and Consequence accounted for.
- The first implementation slice is small enough to test without migrating scenes.

Future code acceptance:

- `test_ryan_slice_system.tscn` covers Ryan route structure and important NPC timing.
- `test_mira_toby_route_matrix.tscn` covers Mira/Toby outcomes.
- `test_evelyn_grey_ledger_line.tscn` covers Evelyn outcomes.
- `test_inference_system.tscn` covers clue sources and facts.
- `test_rumor_appetite_system.tscn` covers Wind/menu/customer group behavior.
- `test_day_map_system.tscn` or focused DayMap tests cover location reward feedback.
- `test_tavern_patience_ui.tscn` covers Tavern caption/menu UI contracts when UI text changes.

## Final Rule

Before adding or changing any story content, answer this:

> Is this Wind, Heart, Evidence, Fact, Cost, or Consequence?

If the answer is unclear, the content should stay out of the game until its source role is defined.
