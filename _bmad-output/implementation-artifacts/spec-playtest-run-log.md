---
title: 'Dev tooling: playtest run log (JSONL) with difficulty tags'
type: 'feature'
created: '2026-11-11'
status: 'done'
baseline_commit: '274c04fcae322eeb0db5a05657a4e757fe8bec43'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/specs/spec-vertical-slice/resolution-rules.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Playtests leave no record, so story 7's tuning pass has no data on which builds, seeds and cards win or lose, or how hard runs felt.

**Approach:** After each run, append one JSON line to `user://playtest_log.jsonl` (never in the repo) describing the build, launch readout, card-by-card result, outcome and a snapshot of the tuning values. The win/loss panel gets optional Too hard / Fair / Too easy buttons that tag that run's line. Authorized by Mike as in-scope dev tooling for the slice.

**Record fields:** `schema` (1), `timestamp` (UTC ISO 8601), `commit` (full hash or null), `session_id` (new each launch), `attempt` (1-based launch count in the session), `seed`, `mission` (id), `layout` (3 rows × 3 part ids or null, front row first), `fuel` {`have`, `needed`, `spare`, `uncountered`: card ids}, `cargo` {`have`, `required`}, `card_order` (all card ids), `cards` (one per resolved card: `card`, `countered`, `hits` {`missed`, `absorbed`, `damaged`}, `destroyed` (part ids), `fuel_after`), `outcome` ("won"/"lost"), `loss_reason` (lowercase enum name or null), `loss_card` (1-based or null), `tuning` {`parts`: id → `max_hp`, `fuel_capacity`, `shield_capacity`; `cards`: id → `hits`, `damage_per_hit`, `extra_fuel_loss`, `counter_threshold`; `mission`: `cargo_required`, `fuel_per_card`}, `difficulty` ("too_hard"/"fair"/"too_easy" or null).

## Boundaries & Constraints

**Always:** Record building is pure logic (no Node, no file I/O, timestamp/commit/session passed in) in its own `scripts/playtest/` folder, separate from `scripts/logic/`. Ids are the resource file basename (`fuel_tank`, `pirate_ambush`, `cargo_run`). Every number comes from `ShipBuild`, `MissionReadout`, `RunResult` or the Resources — no rule re-derived. One line per run. Tests never write to the real log. Statically typed, Godot 4.7.

**Never:** No change to resolver, readout, rules, RNG, or `.tres` values. No addon. No in-game log viewer or analysis. A logging failure never blocks or breaks play (warn via `push_warning` only).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Won run | Outcome panel shown | One line appended; `outcome` "won", `loss_reason`/`loss_card`/`difficulty` null | N/A |
| Lost on card 5 | OUT_OF_FUEL on 5th event | `loss_reason` "out_of_fuel", `loss_card` 5, `cards` has 5 entries, `card_order` all 8 | N/A |
| Tag clicked | "Too hard" then "Fair" | That run's line rewritten in place; final `difficulty` "fair"; other lines untouched | N/A |
| No tag | Rebuild without tagging | Line stays with `difficulty` null | N/A |
| Second launch | Same session | Same `session_id`, `attempt` 2 | N/A |
| No git | Exported build / no `.git` | `commit` null | N/A |
| Unwritable file | Open fails | Game continues | `push_warning` |

</frozen-after-approval>

## Code Map

- `scripts/logic/run_result.gd` -- `RunResult` / `CardEvent` / `HitEvent` (`is_miss`, `absorbed`, `damage_to_part`, `destroyed_cells`, `fuel_after`, `LossReason`). Read only. Hit classes: miss = `is_miss()`; damaged = `damage_to_part > 0`; absorbed = otherwise.
- `scripts/logic/mission_readout.gd` -- reuse `fuel_needed`, `fuel_spare`, `uncountered_fuel_cards`.
- `scripts/logic/ship_build.gd` -- `get_part`, `fuel_capacity`, `working_count(CARGO_HOLD)`, `ROWS`/`COLUMNS`.
- `scenes/build/build_screen.gd` -- owns launch (`_on_launch_pressed`: seed, build, result) and run screen signals; add the log owner here. Build state at launch must be snapshotted (layout can't change until run screen closes, so capture at launch).
- `scenes/run/run_screen.gd` / `.tscn` -- `_show_outcome()`; `OutcomeBox` VBox; add a feedback row of three font-8 buttons, emit `outcome_shown` and `difficulty_tagged(tag: String)`; display only.
- `scenes/build/build_screen.tscn` -- add a small font-8 `LogPathLabel`.
- `test/unit/test_run_screen.gd` -- launches from the build screen and reaches the outcome; must hit the test log path.
- `.gutconfig.json` + `addons/gut/hook_script.gd` (`GutHookScript`) -- `pre_run_script` redirects the log for the whole suite.

## Tasks & Acceptance

**Execution:**
- [x] `scripts/playtest/playtest_record.gd` -- `PlaytestRecord` static `build(build, mission, result, meta: Dictionary) -> Dictionary`, `part_id`/`card_id` helpers, `tuning(mission)`.
- [x] `scripts/playtest/playtest_log.gd` -- `PlaytestLog` (RefCounted): static `default_path`; `session_id` (random hex at init), `next_attempt()`, `append(record) -> Error`, `set_difficulty(session_id, attempt, tag) -> Error` (rewrites the matching line), `absolute_path()`, static `read_git_commit() -> Variant` (`.git/HEAD` → loose ref → `packed-refs`; null if absent).
- [x] `scenes/run/run_screen.gd`, `.tscn` -- feedback buttons, signals; selected tag shown pressed.
- [x] `scenes/build/build_screen.gd`, `.tscn` -- create log in `_ready` (overridable var), print and show its absolute path, build record at launch, append on `outcome_shown`, tag on `difficulty_tagged`.
- [x] `test/playtest_hook.gd`, `.gutconfig.json` -- point `PlaytestLog.default_path` at `user://test_playtest_log.jsonl` and delete it.
- [x] `test/unit/test_playtest_record.gd`, `test/unit/test_playtest_log.gd` -- matrix rows; record field shapes; JSON round-trip; tag rewrite; scene flow (launch → outcome → line written → tag → rewritten).

**Acceptance Criteria:**
- Given the suite runs, when any test reaches an outcome, then the real `user://playtest_log.jsonl` is not modified.
- Given the game starts, then the absolute log path is printed and shown on the build screen.

## Implementation Notes

- Implemented directly, without an implementation subagent; review used three subagents (Mike approved).
- `scripts/playtest/playtest_record.gd` (pure) and `scripts/playtest/playtest_log.gd` (file I/O, session, attempts, git lookup). `PlaytestLog.default_path` is a static var. The GUT pre-run hook (`test/playtest_hook.gd`) and `test_run_screen.gd`'s `before_all` both redirect it.
- The tag rewrite edits the line's text with a regex. `JSON.parse_string` returns every number as a float, so re-encoding would turn `3` into `3.0`. The rewrite writes `<log>.tmp` and renames it over the log.
- The commit is read from `.git/HEAD`, then the loose ref, then `packed-refs`. It is null outside the editor binary.
- Run screen: FEEL: TOO HARD / FAIR / TOO EASY toggle row, plus `outcome_shown` and `difficulty_tagged` signals. Build screen: `LogPathLabel` (50% alpha, font 8) under the launch bar, which moved up 6 px. The path is also printed at startup.
- Cargo Run never wins with the cruiser test build on the current tuning, so the won-run test uses a Calm-Space-only copy of the mission.
- `project.godot` unchanged. `.gutconfig.json` gained `"pre_run_script": "res://test/playtest_hook.gd"`.

## Spec Change Log

## Review Triage Log

| # | Source | Finding | Verdict | Evidence / route |
|---|--------|---------|---------|------------------|
| 1 | verification-gap | `utc_timestamp()` format/UTC never asserted | medium | Gap filed with evidence. Patch: regex + same-hour-as-UTC test; build-screen record checks `timestamp`/`commit`. |
| 2 | blind, edge | `.git` as a file (worktree/submodule) gives null commit; repo-commit test fails there | low | Mike works on `main` in a normal checkout; fix adds a gitdir/commondir branch. Rejected. |
| 3 | blind | Tooling ships in release exports | low | No export pipeline in the slice; logging in an exported playtest build is arguably wanted. Rejected; raised with Mike. |
| 4 | blind | Tag rewrite truncates the log before writing; a crash loses all records | medium | `FileAccess.WRITE` truncated on open. Patch: write `.tmp`, `DirAccess.rename_absolute` over the log. |
| 5 | blind, edge | GUT editor panel skips `pre_run_script`; `test_run_screen` would write the real log | medium | Real; breaks AC 1 from the panel. Patch: `test_run_screen.gd` `before_all`/`after_all` redirect the static path. |
| 6 | blind | Out-of-set tag breaks later re-tags | low | Regex accepted only `[a-z_]`. Direct correction: pattern now `"[^"]*"`; test added. Patch. |
| 7 | blind, edge | Test hit classification (`elif absorbed > 0`) disagrees with code/spec ("absorbed = otherwise") | low | Direct correction to the test. Patch. |
| 8 | blind, edge | `won` false with `loss_reason` NONE logs a half-filled loss | false | The resolver always sets `won` or a loss reason (`run_resolver.gd` `_resolve`); state unreachable. |
| 9 | blind | Abandoned playback leaves attempt gaps | false | Spec defines `attempt` as the launch count; gaps are intended. |
| 10 | blind, edge | Append onto a partial last line glues records | low | Needs a crash mid-`store_line`; the fix adds a seek/check branch. Rejected. |
| 11 | edge | Two game instances: rewrite drops the other's appended lines | low | Unlikely in solo playtesting; the fix needs locking or a different format. Rejected. |
| 12 | edge | Record built before `start()`; an error would block the run | low | Direct reorder. Patch: `start()` first. |
| 13 | edge | Exported build may resolve `res://.git` relative to its working dir | medium | Plausible wrong commit; one-line guard. Patch: null unless `OS.has_feature("editor")`. |
| 14 | edge | Mission id fallback uses display text | low | Direct correction: `to_snake_case()`. Patch. |
| 15 | blind | `LogPathLabel` long path may overflow at narrow widths | low | Desktop-only slice; ~80 chars fits 608 px. Rejected. |
| 16 | blind | Run-screen doc comment line > 100 chars | low | Direct correction. Patch. |
| 17 | blind | Hook never deletes its log after the run | low | Hook deletes it before each run; leftover is harmless. Rejected. |
| 18 | blind | Commit re-read every launch | low | Microseconds of file reads; no harm. Rejected. |
| 19 | blind | Unwritable-log matrix row untested at build-screen level | low | `PlaytestLog` returns errors and only warns; the build screen ignores return values. Adding a scene test adds little. Rejected. |

## Design Notes

Write the line when the outcome panel appears (the run is complete), not at launch, so abandoned playbacks are not logged. A tag rewrites that run's existing line (match `session_id` + `attempt`, last match wins) so the file keeps exactly one line per run and the record survives a quit without tagging. Rewrite = read all lines, replace one, write whole file; fine at playtest volumes.

## Verification

**Commands:**
- `C:\tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --import` -- registers new class_names.
- `C:\tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . -s addons/gut/gut_cmdln.gd` -- exit 0, no Warnings, Scripts 9.
