---
title: 'Story 6 fix: fuel readout counts uncountered Fuel Leak / Gravity Well'
type: 'bugfix'
created: '2026-11-10'
status: 'done'
baseline_commit: 'b26efba0b3ffa5e1604d8b74e60391fafdb5b331'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/specs/spec-vertical-slice/resolution-rules.md'
  - '{project-root}/_bmad-output/specs/spec-vertical-slice/stories/6-win-loss-screen-rebuild-retry-same-seed.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The build screen's "Fuel X / Y needed" uses `card_pool.size() × fuel_per_card` only. Every card appears in every run, so an uncountered Fuel Leak (+2) or Gravity Well (+1) always costs extra fuel; a 1-thruster, 2-tank ship shows "8 / 8" (ok color) yet runs out on the last card.

**Approach:** Lift the resolver's fuel-card counter rule into one public static on `RunResolver` that both the resolver and `MissionReadout` call. Fuel needed = base burn + `extra_fuel_loss` of every pool card that rule says the current build leaves uncountered. The readout lists each such card with its extra fuel and its counter. Then investigate whether a run can still run out of fuel with fuel ≥ needed and no uncountered fuel cards; report any genuine resolver bug separately rather than fixing it here.

## Boundaries & Constraints

**Always:** One counter rule, called from both places — no copied threshold/kind logic in `MissionReadout`. Every number and name comes from `CardData` / `PartData` / `MissionData` (counter part name from the mission's `parts` entry of that kind; row suffix from its `required_row`). Readout counts at launch use `ShipBuild.working_count`. Statically typed, Godot 4.7.

**Never:** No change to resolution rules, card order, RNG draw order, loss priority or `.tres` values. No launch refusal on fuel. No modelling of mid-run damage in the readout (it is a launch-time figure).

## I/O & Edge-Case Matrix

| Scenario | Build (Cargo Run) | Fuel line | Fuel card lines |
|----------|-------------------|-----------|-----------------|
| Both uncountered | 1 rear thruster, 1 tank | `Fuel 4 / 11 needed` | `+2 Fuel Leak: counter with 2 Fuel Tanks (have 1)`, `+1 Gravity Well: counter with 2 Thrusters in rear row (have 1)` |
| Leak countered | 1 rear thruster, 2 tanks | `Fuel 8 / 9 needed` (warning) | Gravity Well line only |
| Both countered | 2 rear thrusters, 2 tanks | `Fuel 8 / 8 needed` (ok) | none |
| Inert counter | 2 thrusters, one not in rear row | Gravity Well uncountered, `(have 1)` | as resolver |
| Tuned card | copy with `extra_fuel_loss`/`counter_threshold` changed | numbers follow data | numbers follow data |

</frozen-after-approval>

## Code Map

- `scripts/logic/run_resolver.gd` -- `_fuel_drain_card(event, card, counter_kind)` holds the rule today (`_working_count(kind) >= card.counter_threshold`); the `match` passes FUEL_TANK / THRUSTER. Replace with a const map `FUEL_CARD_COUNTERS: Dictionary[CardData.Kind, PartData.Kind]` plus statics `is_fuel_card(card)`, `fuel_counter_kind(card)`, `fuel_card_countered(card, working: int) -> bool`. RNG draws untouched (fuel cards draw none).
- `scripts/logic/mission_readout.gd` -- `fuel_needed(mission)` → `fuel_needed(build, mission)`; `fuel_line`/`fuel_met` follow; add `uncountered_fuel_cards(build, mission) -> Array[CardData]` and `fuel_card_lines(build, mission) -> Array[String]`.
- `scripts/logic/ship_build.gd` -- `working_count(kind)` reused as-is.
- `scenes/build/build_screen.gd` / `.tscn` -- `_refresh_readout()`; add a `FuelCardsReadout` Label (font 8, warning color, autowrap if the box is narrow) under `FuelReadout` in `MissionBox`.
- `test/unit/test_mission_readout.gd` -- existing "8 / 8" expectations for `_ship()` (1 thruster, 2 tanks) become "8 / 9".

## Tasks & Acceptance

**Execution:**
- [x] `scripts/logic/run_resolver.gd` -- add the shared statics; `_fuel_drain_card` uses them -- single source for the counter rule.
- [x] `scripts/logic/mission_readout.gd` -- build-aware fuel needed and fuel card lines via the resolver statics.
- [x] `scenes/build/build_screen.gd`, `scenes/build/build_screen.tscn` -- show the fuel card lines; empty label when none.
- [x] `test/unit/test_mission_readout.gd` -- matrix rows; update old 8/8 expectations; a tuned-card case.
- [x] `test/unit/test_run_resolver.gd` -- agreement test: for builds across the matrix and several seeds, a fuel card's `CardEvent.countered` at the time it resolves (no prior destruction) equals `RunResolver.fuel_card_countered` on the launch counts; a seed/build sweep checking that whenever `fuel_met` holds with no uncountered fuel cards and the run ends OUT_OF_FUEL, a Fuel Tank or Thruster was destroyed earlier in that run.
- [x] Investigation -- record the finding in Implementation Notes; if the sweep finds an OUT_OF_FUEL with no tank/thruster destroyed, stop and report it as a separate bug.

**Acceptance Criteria:**
- Given any build, when the readout and resolver evaluate a fuel card at launch, then they agree because both call the same static.
- Given readout fuel met with no uncountered fuel cards and no Fuel Tank or Thruster destroyed, when the run resolves, then it never ends OUT_OF_FUEL.

## Implementation Notes

- Implemented directly (no subagent dispatch; not authorized this session). Shared rule: `RunResolver.FUEL_CARD_COUNTERS`, `is_fuel_card`, `fuel_counter_kind`, `fuel_card_countered`; `_fuel_drain_card` now derives the counter kind from the card. RNG draw order unchanged.
- `MissionReadout.fuel_needed` now takes `(build, mission)`; added `uncountered_fuel_cards`, `fuel_card_lines`. Part name comes from the mission's `parts`, falling back to the enum name; "s" appended unless threshold is 1.
- Build screen: new `FuelCardsReadout` label (warning color, word-wrap, hidden when empty). `test_run_screen.gd` readout test updated: empty build now 0 / 11, two tanks without twin thrusters 8 / 9.
- Investigation (seeded sweep, 2000 random builds x 20 seeds, cargo requirement 0): 37 builds had fuel met with no uncountered fuel cards; 357 of their 740 runs still ended OUT_OF_FUEL, every one explained by damage: after review tightening: in 237 the fuel cap actually dropped (always after a Fuel Tank was destroyed), the other 120 drained extra fuel from a fuel card whose counter part had been destroyed earlier. No case ran dry without either, so no separate resolver bug. The readout is a launch-time figure; mid-run tank loss is the dominant real cause (tuning input for story 7).

## Spec Change Log

## Review Triage Log

| # | Source | Finding | Verdict | Evidence / route |
|---|--------|---------|---------|------------------|
| 1 | blind, edge | Resolver match still names the fuel kinds apart from `FUEL_CARD_COUNTERS` | medium | Adding a kind to the map makes the readout charge fuel the resolver never drains. Patch: resolver routes on `is_fuel_card` first; other cards go to `_apply_card_effect`. |
| 2 | blind, edge | `fuel_counter_kind` unguarded for non-fuel cards | false | Every caller checks `is_fuel_card` first, or passes only events with `extra_fuel_lost > 0`; a loud failure on misuse is correct. Rejected. |
| 3 | blind | Label colour copied into .tscn from `WARNING_COLOR` | low | Real drift risk; direct correction. Patch: override set in `_refresh_readout`, asserted in the scene test. |
| 4 | blind | Pluralisation duplicates `_plural_s` | low | Direct correction. Patch. |
| 5 | blind, edge | Row hint and name come from the first mission part, not the placed parts; null-part fallback untested | low | Cargo Run offers one part per kind, and a mission missing a thruster or tank part cannot build one. Fix needs extra branches. Rejected. |
| 6 | blind, edge | Agreement test uses one seed and one-card pools; spec says several seeds | medium | Deviation from spec. Patch: full Cargo Run pool under 5 seeds, fuel cards checked until the first destruction. |
| 7 | blind, edge | Investigation assertion too loose; causal split overstated | medium | Any tank destroyed counted as explanation. Patch: assert the cap actually lowered final fuel (and a tank was destroyed), or drains came only after the counter part was destroyed. Figures in notes updated. |
| 8 | blind | Readout shows ok for builds that run dry in ~48% of runs | medium | Real, but the frozen intent makes the readout a launch-time figure and excludes modelling damage. Rejected as out of scope; raised with Mike for a decision. |
| 9 | blind, edge | Duplicate fuel cards give duplicate lines; sorted test hides pool order | low | Pool holds one of each card. Duplicate-line fix needs grouping, rejected. Sorted comparison removed (direct correction, patch). |
| 10 | blind | Run-screen empty-build assertion checks code against itself | low | Direct correction. Patch: pinned literal text. |
| 11 | blind | Spec bookkeeping (status, route, Code Map, recorded result, suite time) | false | Status was mid-workflow; fixing would edit this spec (rejected by rule); suite runs in 3.2s. |
| 12 | edge | Null card in pool crashes `is_fuel_card` on the build screen | low | The resolver already crashes on null cards; validation is in deferred-work (story 2). Guard adds complexity. Rejected. |
| 13 | verification-gap | No gaps | — | — |

## Verification

**Commands:**
- `C:\tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . -s addons/gut/gut_cmdln.gd` -- expected: exit 0, no Warnings, Scripts count unchanged (7).
