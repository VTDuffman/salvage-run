---
title: 'Run playback scene with log and speed controls'
type: 'feature'
created: '2026-11-10'
status: 'done'
baseline_commit: '194249ee800379c29c2cd6ca588c835bcb17941c'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/specs/spec-vertical-slice/SPEC.md'
  - '{project-root}/_bmad-output/specs/spec-vertical-slice/resolution-rules.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Launch only prints "Launch OK (run not implemented yet)." The resolver (story 4) produces a full `RunResult`, but the player never sees it, so CAP-6 is unmet and nobody can tell why a run failed.

**Approach:** On an allowed launch, the build screen picks a fresh seed, resolves the run, and opens a run screen over itself. The run screen plays the `RunResult` one card at a time: a short flash on struck cells, HP and destroyed parts on the grid, a fuel and card counter, and one log line per card. Play, Pause and Fast-forward work at any point. Pure logic classes hold the display state, the log text and the timing, so GUT can test them headlessly.

## Boundaries & Constraints

**Always:** The run screen renders only `RunResult` fields (`HitEvent.part_hp_after`, `destroyed`, `absorbed`, `CardEvent.fuel_after`, `destroyed_cells`, `countered`, `loss_reason`) and never calls the resolver or applies a rule. Playback logic classes extend `RefCounted` with no Node dependency. The flash animation follows pause and speed. While the run screen is open, the build screen's mouse input edits nothing. The seed comes from a freshly randomized `RandomNumberGenerator` per launch and is kept on the build screen. Statically typed, Godot 4.7 syntax.

**Never:** No win/loss screen, Rebuild or Retry button, or return to the build screen (story 6). No change to the resolver, `RunResult`, `ShipBuild` rules, `.tres` data or data scripts. No autoload, no scene change that discards the build screen, no new addon.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Countered card | `countered` true | log `"<Card> — <countered_text>"`, e.g. "Pirate Ambush — your gun drove them off" | N/A |
| Uncountered card | `countered` false | log `"<Card> — <uncountered_text>"` | N/A |
| Total miss | uncountered, has hits, every hit `is_miss()` | log `"<Card> — it missed the ship"` | N/A |
| Parts destroyed | `destroyed_cells` non-empty | log line ends with the destroyed part names, e.g. "(Cargo Hold destroyed)"; those cells show as destroyed | N/A |
| Losing card | event `loss_reason` ≠ NONE | its line is followed by "Run lost: <reason>"; playback stops | N/A |
| Last card, no loss | `won` true | final line "Run won: cargo delivered"; playback stops | N/A |
| Pause mid-run | paused | no new card, flash frozen; Play resumes from the same card | N/A |
| Fast-forward | pressed mid-run | cards and flashes run at the fast speed until Play or Pause | N/A |
| Large frame delta | delta spans several card intervals | each due card is applied in order, none skipped | N/A |

**Decisions (agent, open to override):** Fast-forward speeds playback up (4×) and does not skip to the end. One card every 1.5 s at normal speed, so 8 cards take about 12 s. Playback starts on its own when the run screen opens. Damage flashes red, a hit fully absorbed by a shield flashes blue on the struck cell, and destroyed cells turn dark with an "X". When the run ends, the run screen stays on the final log line; story 6 adds the way back.

</frozen-after-approval>

## Code Map

- `scripts/logic/run_result.gd` -- `RunResult`, `CardEvent`, `HitEvent` (`is_miss()`), `LossReason`. Read-only input; don't change it.
- `scripts/logic/run_resolver.gd` -- `RunResolver.resolve(build, mission, run_seed) -> RunResult` (static). Call once per launch.
- `scripts/logic/ship_build.gd` -- `get_part(cell)`, `cells()`, `COLUMNS`/`ROWS`, `launch_refusal()`. Starting HP comes from `PartData.max_hp`.
- `scripts/data/card_data.gd` -- `display_name`, `countered_text`, `uncountered_text` (Calm Space has only uncountered).
- `scenes/build/build_screen.gd` -- `_on_launch_pressed` and `LAUNCH_OK_TEXT` are replaced by the resolve-and-open flow; `mission` and `build` live here.
- `scenes/build/build_mouse_input.gd` -- reads mouse events in `_input` regardless of what is on top, so it needs a way to be switched off while the run screen is open.
- `scenes/build/grid_view.gd` -- `show_build`, `get_cell_text`, `get_cell_color`, `text_color_for`. Extend it for HP, destroyed and flash state rather than writing a second grid.
- `scenes/build/build_screen.tscn` -- 640×360 viewport, 8 px fonts, dark background; match that look.
- `test/unit/test_suite_integrity.gd` -- new test scripts must load as `GutTest` or the run fails.

## Tasks & Acceptance

**Execution:**
- [x] `scripts/logic/run_playback.gd` -- `RunPlayback`: built from a `ShipBuild` and `RunResult`; `step()` applies the next event to per-cell HP/destroyed and fuel; exposes card index and count, `is_finished()`, and log lines per the matrix (static, testable without stepping).
- [x] `scripts/logic/playback_clock.gd` -- `PlaybackClock`: seconds per card, speed (normal/fast), paused; `advance(delta) -> int` returns cards due; `progress()` 0–1 within the current card for the flash.
- [x] `scenes/build/grid_view.gd` -- show part name plus HP, destroyed cells, and a flash tint whose strength the caller sets.
- [x] `scenes/run/run_screen.tscn` + `run_screen.gd` -- full-rect opaque screen: grid with FRONT/REAR labels, fuel and "Card n/8" labels, scrolling log, Play/Pause/Fast-forward buttons; `start(build, result)`; `_process` drives the clock and `RunPlayback`.
- [x] `scenes/build/build_screen.gd` + `build_mouse_input.gd` -- on allowed launch: new seed, resolve, add run screen as a child, disable build input. Refusal text unchanged.
- [x] `test/unit/test_run_playback.gd` -- every matrix row, HP/destroyed/fuel after each step against a real resolved run, and clock pause/speed/large delta.
- [x] `test/unit/test_run_screen.gd` -- instantiate the run screen headless with a resolved result; stepping adds a log line and changes the struck cell's text or color; each button changes clock state mid-run.

**Acceptance Criteria:**
- Given a build that loses parts, when the run plays, then each damaged cell's shown HP drops and each destroyed cell shows as destroyed by the card that did it (CAP-6).
- Given any run, when it finishes, then the log has one line per resolved card naming the card and its result, plus one outcome line (CAP-6).
- Given a running playback, when Pause, Play and Fast-forward are pressed in any order, then card timing follows the last control pressed (CAP-6).
- Given a refused launch, when Launch is pressed, then no run screen opens and the refusal shows as before (CAP-2).

## Verification

**Commands:**
- `C:\tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --import` -- expected: no errors or warnings
- `C:\tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . -s addons/gut/gut_cmdln.gd` -- expected: exit code 0, 6 scripts, no `Warnings` line

**Manual checks:**
- Run the game, build a ship with a rear thruster, launch: cards play with flashes and log lines; Pause, Play and Fast-forward respond mid-run; layout readable at 640×360.

## Implementation Notes
- Verified after review: headless `--import` clean; GUT runs 6 scripts, 93 tests, all passing, exit code 0. Review fixes in 0341dac.

## Spec Change Log

## Review Triage Log

- Grid HP text never asserted (verification-gap) — low, real: the stepping test passes on the flash color alone, so the HP readout could break unnoticed. Patched: assertion on "hp/max HP" after the first card.
- Build input gating checked only as a flag (verification-gap, blind) — medium, real: removing the `_input` early return or `_cancel_drag()` keeps every test green while the ship stays editable under the run screen. Patched: right-click-after-launch and disable-mid-drag tests.
- Flash and destroyed colors never asserted at the grid (verification-gap) — low, real: swapping red and blue passes every test. Patched: grid color test.
- Per-launch seed untested (verification-gap, blind) — low, real: removing `randomize()` passes every test. Deferred to story 6, the first code that reads `run_seed` back.
- Seed not shown on screen (blind) — low, rejected: not in the spec; no reader for it before story 6.
- Story file changes not committed (blind) — false: the workflow commits the spec's status updates when the story finishes.
- `_process` keeps redrawing after the run ends (blind) — low, rejected: 9 cells per frame on a static screen; the fix adds a stop condition for negligible cost.
- FUEL counter shows -1 (blind, edge) — low, real: seen on every out-of-fuel loss. Patched: the display is clamped at 0.
- Destroyed cell shows a bare "X" (blind) — low, real: the grid loses which part stood there. Patched: "<name>\nX", still dark with an X.
- Stale doc comments on `get_cell_text`, `progress()`, `start()` (blind, edge) — low, real. Patched.
- Shield cell and remaining capacity not shown (blind) — low, rejected: the spec decision sets the flashes on the struck cell; showing shield capacity is new display scope.
- Zero events, or neither won nor a loss reason (blind, edge) — false: the resolver always produces at least one event and sets one of the two.
- Pause flash frozen only tested at clock level (blind) — low, rejected: the screen's flash reads only `clock.flash_strength()`, which the clock test freezes.
- Test helpers continue after `fail_test` (blind, edge) — low, rejected: only adds noise to an already-failed test (same call as story 4).
- Hard-coded "CARD n/8", "FAST x4", 1.5 in tests (blind, edge) — low, rejected: the pool is 8 cards by spec, and the 1.5 test asserts the documented default.
- `start()` before entering the tree crashes (edge) — false: the only caller adds the child first; the doc comment now says so.
- Large delta skips drawing intermediate cards (edge) — low, rejected: each due card is still applied in order and logged, per the matrix; only a frame hitch triggers it.
- NaN/INF delta (edge) — false: the engine never passes a non-finite delta to `_process`.
- Freed run screen blocks relaunch; build input never re-enabled (edge) — false today: no return path exists until story 6, which must null `_run_screen` and set `enabled = true` when it closes the run screen.
