---
id: SPEC-vertical-slice
companions:
  - parts-and-cards.md
  - resolution-rules.md
  - build-order.md
  - ../../../AGENTS.md
sources:
  - ../../../docs/salvage-run-gdd.md  # §15 only, plus §14 notes that bind the slice
---

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate. Source documents listed in frontmatter are for traceability — consult them only if you need narrative rationale or prose color this contract intentionally omits.

# Salvage Run — Vertical Slice

## Why

A vision bet to validate cheaply: **is it fun to build a ship and then watch a passive run play out?** Everything else in the GDD (§4–11: map, crew, shop, progression) builds on that premise. If the slice works, the rest is content and systems; if not, the core changes (e.g. one small mid-run decision) before more is invested. The slice is also Mike's Godot 4 learning project: scenes, a grid, drag-and-drop, data-driven content, and a turn-by-turn resolution loop.

## Capabilities

- **CAP-1**
  - **intent:** Player assembles a ship by placing, moving, and removing parts on the Cruiser's 3×3 grid via drag-and-drop from a palette offering unlimited copies of all six parts.
  - **success:** Every part type can be placed in every cell, moved, and removed; cells may stay empty; the build the resolver receives matches the grid on screen.
- **CAP-2**
  - **intent:** A run cannot launch without a thruster in the rear row.
  - **success:** Launch is refused for any build lacking a rear-row thruster and allowed otherwise.
- **CAP-3**
  - **intent:** The run resolves deterministically from build, mission, and seed, independent of any scene.
  - **success:** A headless GUT test running the same build, mission, and seed twice gets identical card order, log, and outcome.
- **CAP-4**
  - **intent:** Each challenge card resolves per `parts-and-cards.md` and `resolution-rules.md`; destroyed parts lose function immediately, so failures cascade.
  - **success:** GUT covers countered and uncountered outcomes for all eight cards, shield absorption and overlap, the fuel cap on tank loss, and a cascade (e.g. a destroyed shield leaves its former coverage exposed to the next Solar Flare).
- **CAP-5**
  - **intent:** The run ends in a win or loss per the conditions in `resolution-rules.md`.
  - **success:** GUT covers the win (including finishing at exactly 0 fuel) and each of the three loss conditions.
- **CAP-6**
  - **intent:** Player watches playback one card at a time, with a short animation and a log line per card, and controls speed (play, pause, fast-forward).
  - **success:** Each card produces a visible grid change where damage occurred and a log line naming the card and its result (e.g. "Pirate Ambush — your gun drove them off"); all three speed controls work mid-run.
- **CAP-7**
  - **intent:** After the run, a win/loss screen offers Rebuild (new seed) and Retry same seed (same card order); both return to the build screen with the previous layout, and the next launch uses the current ship including edits.
  - **success:** After Retry same seed, the next run's card order matches the previous run's; after Rebuild, a new seed is used; in both cases the grid shows the previous layout.
- **CAP-8**
  - **intent:** Parts, cards, and mission parameters live in data files so balance is tunable in the Godot inspector without touching game logic.
  - **success:** Changing a part's HP, the fuel per tank, or the mission's cargo requirement in the inspector changes run behavior with no code edit.

## Constraints

- Cruiser hull only, 3×3 grid, top-down: front = top row, rear = bottom row, flanks = left and right columns.
- All parts 1×1.
- No player input between launch and result except playback speed.
- All randomness (card shuffle, random lanes) flows from the run seed.
- Game rules live in plain logic classes with no Node/scene dependencies; scenes only display results.
- Content in Godot Resources (`.tres`), editable in the Godot inspector — not JSON, not hard-coded.
- Godot 4.7 / GDScript, desktop only; layout stays readable at a phone aspect ratio.
- Mouse input only, with input handling isolated so touch can be added later.
- Placeholder art (colored tiles, simple icons) under pixel-art render settings.

## Non-goals

- Crew and crew quarters
- Galaxy map, nodes, and routing
- Shop, money, and progression
- Other hulls (Freighter, Battleship, Smuggler's Sloop)
- Grid sizes other than 3×3
- Multi-cell part shapes
- Alien tech, factions, reputation
- Final pixel art
- Mobile build and touch input
- Save/load and meta-progression

## Success signal

After a week of play: (1) losses prompt an immediate rebuild; (2) the playback explains why a run failed; (3) at least three meaningfully different builds can win; (4) a build-plus-run cycle takes roughly 1–2 minutes; (5) at least one run produces a cascading failure that feels like a story. If 1 and 2 fail, revisit the passive-run premise before building anything else.
