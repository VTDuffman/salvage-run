---
title: 'Run resolver as pure logic with GUT tests'
type: 'feature'
created: '2026-11-10'
status: 'in-progress'
baseline_commit: '2b8862316c30d6b745b1c6d60686ca37a918de87'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/specs/spec-vertical-slice/SPEC.md'
  - '{project-root}/_bmad-output/specs/spec-vertical-slice/resolution-rules.md'
  - '{project-root}/_bmad-output/specs/spec-vertical-slice/parts-and-cards.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A launchable build has nowhere to go: nothing resolves a run, so CAP-3/4/5 are unmet, and the repo has no automated tests at all.

**Approach:** Install GUT 9.7.1 (the release built for Godot 4.7) under `addons/gut/`. Add a seeded, scene-free `RunResolver` that takes a `ShipBuild`, a `MissionData` and a seed and returns a `RunResult`: the card order, one event per card with per-hit detail, and the outcome. Playback (story 5) renders that result without re-deriving any rule. GUT tests cover every success criterion of CAP-3, CAP-4 and CAP-5.

## Boundaries & Constraints

**Always:** Resolver classes extend `RefCounted` with no Node/scene dependencies. Every number comes from `PartData`/`CardData`/`MissionData` fields (HP, `fuel_capacity`, `shield_capacity`, `hits`, `damage_per_hit`, `extra_fuel_loss`, `counter_threshold`, `fuel_per_card`, `cargo_required`); "working" means not destroyed and, when `required_row` is set, in that row. All randomness comes from one `RandomNumberGenerator` seeded with the run seed: shuffle first, then lane picks in card order — never the global RNG or `Array.shuffle()`. The resolver never mutates the `ShipBuild` or any Resource. Statically typed, Godot 4.7 syntax.

**Never:** Playback, a scene, a seed generator, win/loss UI, or changes to `.tres` data, data scripts or the build screen. No addon other than GUT.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Same seed twice | same build, mission, seed | identical card order, events and outcome | N/A |
| Hit lane empty | all cells in the lane empty or destroyed | hit recorded as a miss, no damage | N/A |
| Double shield coverage | struck cell covered by two working shields | damage drawn from the one with more capacity left (tie: first in `ShipBuild.cells()` order) | N/A |
| Shield exhausted | covering shields at 0 capacity | the part takes the damage | N/A |
| Tank destroyed | fuel above new cap | fuel drops to working-tank total immediately | N/A |
| Exactly 0 fuel after last card | — | win | N/A |
| Fuel below 0 after burn | — | loss, out of fuel; run stops | N/A |
| Two losses on the same card | e.g. thruster and cargo lost together | one reason, priority: no thruster, out of fuel, cargo lost | N/A |
| Too few cargo holds from the start | cargo holds < `cargo_required` | loss after the first card (loss is checked after each card per the rules) | N/A |

**Decisions (agent, open to override):** A card is `countered` when it was cancelled outright (Gun, Fuel Leak, Gravity Well counters) or when no part lost HP and at least one hit was absorbed; per-hit results (miss / absorbed / damaged) are in the event, so playback can word a total miss. Solar Flare strikes parts front row first, left to right, so shield capacity runs out in that order. Damage is applied one point at a time, so a multi-damage hit can be partly absorbed.

**Decisions (Mike, 2026-11-10):** Port story 3's `ShipBuild` checks to GUT and add a well-formedness test for `cargo_run.tres`. The scene drag/right-click tests stay deferred. Keep the full spec (~1,900 tokens) rather than split.

</frozen-after-approval>

## Code Map

- `scripts/logic/ship_build.gd` -- `ShipBuild`: `get_part(cell)`, `cells()` (front row first, left to right), `COLUMNS`/`ROWS`/`REAR_ROW`, `is_valid_cell`. Read-only input to the resolver; don't change it.
- `scripts/data/part_data.gd` -- `Kind`, `RequiredRow {ANY, FRONT, REAR}`, `max_hp`, `fuel_capacity`, `shield_capacity`. Front row is row 0.
- `scripts/data/card_data.gd` -- `Kind` picks behavior; `Direction` (FLANK = random side); effect and log-text fields. `calm_space.tres` has only `uncountered_text`.
- `scripts/data/mission_data.gd` -- `cargo_required` (2), `fuel_per_card` (1), `card_pool` (8 cards).
- `data/missions/cargo_run.tres` -- real data for the integration and determinism tests.
- `project.godot` -- `untyped_declaration=2` makes untyped declarations errors; GUT's own scripts must still parse under it (verify on import).
- `AGENTS.md` -- the "GUT is not installed yet" bullet gets replaced with the verified test command.

## Tasks & Acceptance

**Execution:**
- [x] `addons/gut/` -- copy `addons/gut` from the GUT v9.7.1 release; enable the plugin in `project.godot` (report the setting). Add `.gutconfig.json` pointing at `res://test/` with subdirectories and exit-on-finish.
- [x] `scripts/logic/run_result.gd` -- `RunResult` (`seed`, `card_order`, `starting_fuel`, `events: Array[CardEvent]`, `won`, `loss_reason` enum NONE/NO_THRUSTER/OUT_OF_FUEL/CARGO_LOST) with inner classes `CardEvent` (card, countered, hits, extra fuel lost, fuel after, destroyed cells, loss reason) and `HitEvent` (entry side, lane, struck cell or none, absorbing shield cell or none, damage to part, part HP after, destroyed).
- [x] `scripts/logic/run_resolver.gd` -- `RunResolver.resolve(build, mission, seed) -> RunResult` implementing `resolution-rules.md` with per-cell HP and per-shield capacity state kept inside the resolver.
- [x] `test/unit/test_run_resolver.gd` -- tests built from hand-made `CardData`/`MissionData` with one-card pools where lanes must be controlled; real `cargo_run.tres` for determinism. Cover every matrix row.
- [x] `test/unit/test_ship_build.gd` -- port of story 3's checks: place/replace, move/swap, move onto its own cell, remove, out-of-range cells ignored, `cells()` order, and the rear-thruster launch gate (none, only in rows 0–1, in row 2).
- [x] `test/unit/test_cargo_run_data.gd` -- loads `cargo_run.tres`: six parts and eight cards, no nulls, no duplicate cards, every `PartData.Kind` and `CardData.Kind` present exactly once, a thruster among the parts.
- [x] `AGENTS.md` -- record the verified headless test command.

**Acceptance Criteria:**
- Given one build, mission and seed, when resolved twice, then card order, every event field and outcome are equal (CAP-3).
- Given each of the eight cards, when resolved countered and uncountered, then the events match `parts-and-cards.md` (CAP-4).
- Given a shield beside a cargo hold, when an earlier card destroys the shield and a Solar Flare follows, then the cargo hold takes the flare's damage (cascade, CAP-4).
- Given builds that win, win at exactly 0 fuel, and lose each way, when resolved, then `won`/`loss_reason` match and no events follow the losing card (CAP-5).
- Given `fuel_tank.tres` `fuel_capacity` changed, when resolved, then starting fuel follows with no code edit (CAP-8).

## Verification

**Commands:**
- `C:\tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --import` -- expected: no errors or warnings
- `C:\tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . -s addons/gut/gut_cmdln.gd` -- expected: all tests pass, exit code 0

## Implementation Notes

- Verified: headless `--import` shows no errors or warnings; GUT runs 3 scripts, 63 tests, 1,045 asserts, all passing, exit code 0. Mutation checks (wrong shield tie-break, no fuel cap on tank loss, wrong `countered` rule, random Pirate Ambush lanes) each made tests fail with exit code 1.
- project.godot: added `[editor_plugins] enabled=PackedStringArray("res://addons/gut/plugin.cfg")` (previously absent). No other setting changed. GUT's own scripts load without errors under `untyped_declaration=2` (addon warnings are excluded by default).
- `RunResult` adds `Side` {NONE, FRONT, REAR, LEFT, RIGHT} for `HitEvent.entry_side` (NONE for Solar Flare, lane -1), `NO_CELL` = (-1, -1), `HitEvent.absorbed` (points drawn from shields) and `HitEvent.is_miss()`. `shield_cell` is the first shield that absorbed from the hit. Inner classes must name the outer enums as `RunResult.Side`/`RunResult.LossReason`; bare `Side` fails to parse in Godot 4.7.
- RNG order: Fisher-Yates shuffle, then per card: Debris Strike picks its side (0 left, 1 right) then each hit's row; Asteroid Field and Rear Raider pick one column per hit. Pirate Ambush hit i goes down column i % COLUMNS.
- `fuel_after` is not clamped: a negative value is the "would go below 0" loss. The tank-loss fuel cap is applied right after each destruction.
- Shields are any working part with `shield_capacity` > 0. Countered checks count working parts of the countering kind (Gun, Fuel Tank, Thruster) against `counter_threshold`.
- GUT skips a test script that fails to parse, logs only a warning, and still exits 0. This is recorded in AGENTS.md.

## Spec Change Log

## Review Triage Log
