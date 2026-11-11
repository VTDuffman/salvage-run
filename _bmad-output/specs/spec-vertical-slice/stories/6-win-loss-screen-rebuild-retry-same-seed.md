---
title: 'Win/loss screen with Rebuild and Retry same seed, plus visible mission requirements'
type: 'feature'
created: '2026-11-10'
status: 'done'
baseline_commit: '7b7a3233ed27a2fdd6034c86c3e96750d9759106'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/specs/spec-vertical-slice/SPEC.md'
  - '{project-root}/_bmad-output/specs/spec-vertical-slice/resolution-rules.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A finished run leaves the player stuck on the run screen with no way back (CAP-7 unmet). The player also never sees what the mission demands, so a ship short on cargo holds launches and is lost after card 1, and losses read as "too much cargo lost" rather than the number that was missed.

**Approach:** When playback finishes, the run screen shows an outcome panel stating the result against the mission's numbers, with Rebuild (new seed) and Retry same seed; both close the run screen and return to the build screen with its layout. The build screen gains a mission panel and a live readout of cargo holds and fuel against what the mission needs, and Launch is refused when cargo holds fall short. Mike authorized the mission panel, readout and requirement-based loss text as in-scope for the slice.

## Boundaries & Constraints

**Always:** Every number shown comes from `MissionData` (`cargo_required`, `fuel_per_card`, `card_pool.size()`), `PartData` or `RunResult`; none is a literal in code. Fuel needed = `card_pool.size() × fuel_per_card`. Build fuel = sum of `fuel_capacity` of parts placed where they work, and must equal the resolver's `starting_fuel` for the same build. "Works here" (required row) is one shared static rule used by both `ShipBuild` and the resolver. Requirement and outcome texts are built by plain `RefCounted` logic, tested headlessly. The screen never re-derives a loss: cargo count at the loss comes from a new `CardEvent` field the resolver sets. Retry keeps `run_seed`; Rebuild draws a fresh one at the next launch; the next launch always runs the current build. Closing the run screen frees it, nulls `_run_screen`, and re-enables build input. Statically typed, Godot 4.7 syntax.

**Never:** No change to resolution rules, card order, loss priority or `.tres` values. No launch refusal on fuel. No scene change that discards the build screen, no autoload, no new addon. No tuning (story 7).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Mission panel | cargo_run.tres | "CARGO HOLDS 2", "CARDS 8", "FUEL/CARD 1" | N/A |
| Readout short | 1 cargo hold, 2 tanks | "Cargo 1/2" and "Fuel 8 / 8 needed"; cargo line in warning color | N/A |
| Readout met | 2 holds, 2 tanks | "Cargo 2/2", "Fuel 8 / 8 needed", both in ok color | N/A |
| Readout updates | place/move/remove a part | both lines change on the same build_changed | N/A |
| Gate: no thruster | no rear thruster | existing thruster refusal (checked first) | N/A |
| Gate: cargo short | rear thruster, 1 hold, needs 2 | "Launch refused: 1 cargo hold, mission needs 2." no run screen | N/A |
| Gate: cargo 0 needed | `cargo_required` 0, no holds | launch allowed | N/A |
| Win | `won` | "RUN WON" + "Cargo delivered: 2 of 2 holds intact" | N/A |
| Cargo loss on card n | CARGO_LOST, `cargo_holds_after` 1 | "Cargo lost: had 1 hold, needed 2" (plural "holds" when ≠ 1) | N/A |
| Fuel loss on card n | OUT_OF_FUEL at event n | "Out of fuel on card 7" | N/A |
| Thruster loss on card n | NO_THRUSTER at event n | "Lost thrust on card 3: no working rear thruster" | N/A |
| Retry same seed | press Retry, edit build, Launch | run uses previous `run_seed`, same card order, current build | N/A |
| Rebuild | press Rebuild, Launch | new `run_seed` drawn | N/A |

**Decisions (agent, open to override):** The outcome panel is an overlay on the run screen, shown when playback finishes, so the final grid and log stay readable behind/beside it. Both buttons return to the build screen; neither relaunches by itself. After Retry the status label says the next launch reuses the seed. The mission panel and readout sit on the build screen's empty right side. The log's own outcome line is unchanged.

</frozen-after-approval>

## Code Map

- `scripts/data/mission_data.gd` -- `cargo_required`, `fuel_per_card`, `card_pool` already exist; no change.
- `scripts/logic/ship_build.gd` -- `launch_refusal()` (no args) → take `MissionData`; add `REFUSAL_CARGO_SHORT` format, `working_count(kind)`, `fuel_capacity()`, static `works_in(part, cell)` (required-row rule).
- `scripts/logic/run_resolver.gd` -- `_is_working` duplicates the required-row match; route it through `ShipBuild.works_in`. Set `event.cargo_holds_after = _working_count(CARGO_HOLD)` in step 4.
- `scripts/logic/run_result.gd` -- add `CardEvent.cargo_holds_after: int`.
- `scripts/logic/run_playback.gd` -- untouched; `outcome_line`/`loss_reason_text` stay for the log.
- `scenes/build/build_screen.gd/.tscn` -- `_on_launch_pressed` draws seed via `rng.randomize()`; `_on_build_changed` resets status; `run_seed` public. Right side of 640×360 is empty.
- `scenes/run/run_screen.gd/.tscn` -- `start(build, result)`; `_process` steps playback; add overlay + signals. 8 px fonts, dark bg `Color(0.078, 0.09, 0.125)`.
- `test/unit/test_ship_build.gd` -- launch_refusal tests call no-arg form; update.
- `test/unit/test_run_screen.gd:232` -- allowed-launch test has no cargo holds; it must now place `cargo_required` holds.

## Tasks & Acceptance

**Execution:**
- [x] `scripts/logic/ship_build.gd` -- add `works_in`, `working_count`, `fuel_capacity`; `launch_refusal(mission)` with thruster then cargo check.
- [x] `scripts/logic/run_result.gd` + `run_resolver.gd` -- `cargo_holds_after`; `_is_working` uses `ShipBuild.works_in`.
- [x] `scripts/logic/mission_readout.gd` -- `MissionReadout` (static): panel lines, `cargo_line(build, mission)`, `fuel_line(build, mission)`, `fuel_needed(mission)`, met flags; `outcome_title(result)`, `outcome_detail(result, mission)`.
- [x] `scenes/build/build_screen.gd/.tscn` -- mission panel + readout refreshed on every build change; launch passes mission; `_retry_seed` flag; handles run screen `rebuild_requested`/`retry_requested`: free run screen, null it, re-enable input, redraw grid and readout.
- [x] `scenes/run/run_screen.gd/.tscn` -- `start(build, result, mission)`; hidden OutcomePanel shown once playback `is_finished()`; Rebuild/Retry buttons emit signals.
- [x] `test/unit/test_mission_readout.gd` -- matrix rows for panel, readout, gate text, outcome texts with tuned mission copies (proves data-driven); build fuel equals resolver `starting_fuel`.
- [x] `test/unit/test_ship_build.gd`, `test_run_resolver.gd`, `test_run_screen.gd` -- cargo gate; `cargo_holds_after`; outcome panel appears only at finish; Retry reuses seed and card order; Rebuild gets a new seed; each launch's `result.seed == run_seed`; return path nulls `_run_screen`, re-enables input, keeps layout, allows relaunch.

**Acceptance Criteria:**
- Given a finished run, when Retry same seed is pressed and Launch pressed again, then the new run's card order equals the previous one (CAP-7).
- Given a finished run, when Rebuild is pressed, then the build screen shows the previous layout, accepts edits, and the next launch uses a new seed (CAP-7).
- Given `cargo_required` or `fuel_per_card` changed on a mission copy, when the readout and gate are evaluated, then the shown numbers and refusal follow with no code edit (CAP-8).

## Implementation Notes

- Verified after review: headless import clean; GUT runs 7 scripts, 128 tests, all passing, exit code 0. Review fixes in fc0e069.
- Outcome panel sits at the bottom of the run screen's log column (shown when playback finishes), not floating over it: at 640×360 a floating panel would cover the newest log lines, and the decision's goal was that grid and log stay readable. The log column shrinks to make room.
- Win detail is "Cargo delivered: <holds intact after last card> of <cargo_required> hold(s) intact". A ship with more holds than required reads e.g. "3 of 2 holds intact"; the matrix format was kept as written.
- `outcome_detail` returns "" for a result with no events (empty card pool); `ShipBuild` pluralizes the cargo refusal inline to avoid a ShipBuild↔MissionReadout dependency.
- The run screen is removed from the tree and `queue_free`d (it emits from its own button). Return-path tests wait one frame so GUT reports no orphans.
- After Retry the status reads "Retry: the next launch reuses seed <n>." and stays through build edits until the next launch or Rebuild.
- No `project.godot` settings changed.

## Spec Change Log

## Review Triage Log

- `has_rear_thruster` keeps its own copy of the required-row rule (blind) — low, real: the gate and resolver diverge if thruster `required_row` data changes; the spec requires one shared rule. Patched: it goes through `working_count`.
- Readout colors only compared label-to-label (verification-gap) — low, real: inverting OK/WARNING passes every test. Patched: assertions against the screen's constants, including the empty build.
- Retry across a refused launch and retry status after edits untested (verification-gap, blind) — low, real: clearing the flag on refusal or resetting status on `build_changed` would pass. Patched: new test.
- `MissionTitle` never asserted (blind) — low, real. Patched.
- `_place_required_holds` breaks above 3 holds (blind) — low, real: story 7 tuning can raise `cargo_required`. Patched: fills row by row.
- Win text "3 of 2 holds intact" and "N of 0 holds" when none required; plural keyed on required (blind, edge, verification-gap) — low, real: common with surplus holds. The wording is set by the frozen matrix, so it goes to Mike instead of being patched.
- Empty card pool shows RUN WON with no detail; won false + NONE shows empty panel (blind, edge) — low, rejected: needs malformed mission data (already logged as a MissionData validation follow-up), and the resolver always sets one of the two.
- `remove_child` of the run screen inside its own button's `pressed` (edge) — maybe-false: tests emit `pressed` directly, not via a real click; settle by clicking Retry in the running game and checking for `!is_inside_tree` errors. Would be low (log noise) if real; rejected, covered by the manual check.
- Rebuild can redraw the same seed; test can flake (edge) — low, rejected: 1 in 2^32.
- Retry/Rebuild set `_retry_seed` with no run screen open on a same-frame double press (blind) — false: `remove_child` takes the buttons out of the tree on the first press, so no second press reaches them.
- Buttons emit before the panel is visible (blind) — false: hidden buttons receive no input; the test emits the signal directly.
- Mission panel has no wrap/clip for longer text (blind) — low, rejected: current data fits; covered by the manual 640×360 check.
- Hold-count text in three formats, pluralization duplicated, log line still "too much cargo lost" (blind) — low, rejected: the log line is unchanged by spec decision; the formats follow the request's examples.
- No focus on Retry/Rebuild when the panel appears (blind) — low, rejected: keyboard focus is new scope (mouse-only slice).
- Test nits: `_no_cargo` relies on `cargo_required` default 0, const order, header comment (blind) — low, rejected: cosmetic.

## Verification

**Commands:**
- `C:\tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --import` -- expected: no errors or warnings
- `C:\tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . -s addons/gut/gut_cmdln.gd` -- expected: exit code 0, 7 scripts, no `Warnings` line

**Manual checks:**
- Build with 1 cargo hold: readout shows "Cargo 1/2", Launch refused with the cargo message. Fix it, launch, let it finish: outcome panel names the requirement; Retry then Launch replays the same card order; layout readable at 640×360.
