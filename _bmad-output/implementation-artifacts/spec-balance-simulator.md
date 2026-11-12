---
title: 'Dev tooling: headless balance simulator'
type: 'feature'
created: '2026-11-11'
status: 'done'
baseline_commit: '21edb3aa9d6d69437c5645358fb41c1b212b852d'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/specs/spec-vertical-slice/resolution-rules.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Story 7's tuning pass has only hand-played runs to go on; nobody can see which builds the current `.tres` numbers favour, how often any build wins, or what usually kills runs.

**Approach:** A headless dev script runs `RunResolver` over many launchable 3×3 builds, each against the same seed set (≥500 seeds), using the live `.tres` data, and writes a Markdown report to `_bmad-output/balance/`. Exhaustive when the requested build count covers every launchable build, otherwise a uniform random sample of distinct launchable builds. Authorized by Mike as in-scope dev tooling for the slice (GDD §15 step 7).

**Report contents:** header (UTC timestamp, commit, mission id, builds evaluated / launchable total, seeds per build, sample seed, runtime, tuning snapshot); top 20 and bottom 20 builds (rank, win rate, wins/seeds, layout, most common loss reason); overall average win rate across evaluated builds; outcome share across all runs (won, no_thruster, out_of_fuel, cargo_lost); per-part appearance in the top 50 builds (builds containing it, total copies, copies in a working cell), empty cells included.

## Boundaries & Constraints

**Always:** Lives in `tools/balance/` with a `.gdignore`, so Godot never imports or exports it; no game scene or script references it. Simulation and report text are pure logic (no Node, no file I/O); only the runner script touches the filesystem. Launchability is `ShipBuild.launch_refusal(mission).is_empty()`; every outcome comes from `RunResolver.resolve` — no rule re-derived. Every build uses the same seeds `1..N`. Same args → same builds and numbers. Statically typed, Godot 4.7. One documented command in `README.md` and `AGENTS.md`.

**Never:** No change to resolver, rules, RNG, game scenes or `.tres` values. No addon. No `class_name` in `tools/` (not registered there). No `project.godot` or export preset changes.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Default run | no args | 20,000 sampled builds × 500 seeds; report written; path printed; exit 0 | N/A |
| Exhaustive | `--builds` ≥ launchable total, or `--builds=all` | Every launchable build evaluated once | N/A |
| Too few seeds | `--seeds=100` | Refused, message names the 500 minimum | exit 1, no report |
| Bad arg | `--builds=abc` / unknown flag | Usage printed | exit 1 |
| Fewer than 50 builds | `--builds=10` | Top/bottom lists and part table use what exists | N/A |
| Ties at the bottom | many 0% builds | Bottom list notes how many builds share the lowest rate | N/A |
| Output dir missing | fresh clone | Directory created | exit 1 with message if it cannot be |

</frozen-after-approval>

## Code Map

- `scripts/logic/run_resolver.gd` -- `RunResolver.resolve(build, mission, seed) -> RunResult` (static, instance per call, thread-safe for read-only Resources). ~165 µs/run single-thread, so exhaustive (~5.6M launchable × 500) is ~130 CPU-hours: sample by default.
- `scripts/logic/ship_build.gd` -- `place`, `get_part`, `launch_refusal`, `works_in`, `ROWS`/`COLUMNS`.
- `scripts/logic/run_result.gd` -- `won`, `loss_reason`, `LossReason`.
- `scripts/playtest/playtest_record.gd` -- reuse `PlaytestRecord.tuning(mission)`, `part_id`, `loss_reason_id`.
- `scripts/playtest/playtest_log.gd` -- reuse static `PlaytestLog.read_git_commit()`.
- `data/missions/cargo_run.tres` -- default mission; `mission.parts` is the 6-part palette (unlimited copies, cells may be empty → 7^9 layouts).
- `test/unit/test_suite_integrity.gd` -- new test must be a valid GutTest.
- Verified: `-s res://tools/balance/<x>.gd` runs from a `.gdignore`d folder, `preload` of sibling scripts works, `OS.get_cmdline_user_args()` sees args after `--`.

## Tasks & Acceptance

**Execution:**
- [x] `tools/balance/.gdignore` -- empty marker -- keeps the tool out of import and export.
- [x] `tools/balance/balance_sim.gd` -- layout encoding (base-7 int over `[empty] + mission.parts`), exact launchable count, deterministic distinct sampling or full enumeration, multithreaded evaluation via `WorkerThreadPool` returning per-build wins and loss-reason counts -- the testable core.
- [x] `tools/balance/balance_report.gd` -- pure Markdown builder from sim results + meta -- report formatting separate from I/O.
- [x] `tools/balance/run_balance.gd` -- `extends SceneTree`: parse `--builds`, `--seeds`, `--sample-seed`, `--mission`; run; write `_bmad-output/balance/balance-<UTC yyyymmdd-hhmmss>.md`; print path; quit with exit code.
- [x] `test/unit/test_balance_sim.gd` -- matrix rows that don't need a full run: launchable count matches brute force on a tiny check, sampled builds are distinct and launchable, determinism, report sections and tie note, seed minimum.
- [x] `README.md`, `AGENTS.md` -- document the one command and its flags.

**Acceptance Criteria:**
- Given the documented command, when run with no args, then it finishes in a few minutes on this machine and writes a report with every section listed in Intent.
- Given the test suite, when it runs, then no file is written under `_bmad-output/balance/`.

## Design Notes

Layout column in report: three rows, front first, one letter per cell from the part's `display_name` initial (`.` = empty), e.g. `G S H / C F C / T F T`, with a legend. Ranking: wins desc, then layout code asc, for stable output. Mutex-guarded result writes from worker tasks.

## Verification

**Commands:**
- `<godot-console> --headless --path . -s addons/gut/gut_cmdln.gd` -- expected: exit 0, no Warnings, Scripts count +1.
- `<godot-console> --headless --path . -s res://tools/balance/run_balance.gd` -- expected: exit 0, report path printed, report has all sections.

## Implementation Notes

- Threads alone do not reach "a few minutes": every run allocates many script objects and Godot serializes object creation engine-wide (measured: 4 threads ~2.4x, 16 threads slower than 1). `balance_sim.evaluate` keeps WorkerThreadPool with a default cap of 4 threads; `run_balance.gd` additionally splits the sorted build list into one shard per core, each a child Godot process of the same script (internal flag `--shard=i/n`) launched from a WorkerThreadPool task. Children re-select the same builds from the same args and print `R code runs wins losses...` lines; the parent merges them under a mutex and fails if any build is missing. Default run: ~128 s on 16 threads.
- Launchable total is counted cell by cell over the two launch_refusal conditions (working rear thruster, enough working cargo holds via `ShipBuild.works_in`); tests check it against brute force over `launch_refusal` on three small palettes. Cargo Run: 4,910,383 of 40,353,607 layouts.
- AGENTS.md section added after the bmad:context block so a context refresh does not drop it.
- Matrix audit (step 3): the output-dir row had no test. Report writing moved into static `RunBalance.write_report(path, text) -> String` (creates missing folders; returns an error message instead of writing). Two tests use `user://` paths: a missing nested folder gets created, and a folder blocked by a file returns "Could not ...". The default-run row is covered by `test_parse_args` (defaults) plus the manual default run (128 s, exit 0, all sections).

## Spec Change Log

## Review Triage Log

| # | Source | Finding | Verdict | Evidence | Route |
|---|---|---|---|---|---|
| 1 | verification-gap | Shard child arg list never checked against parent options | medium | Pre-verified gap; no test builds `shards.args`; seeds/builds mismatch would leave report header wrong with suite green | patch |
| 2 | verification-gap | `evaluate()` chunk loop beyond chunk 1 never run | medium | Pre-verified; test uses 6 codes < CHUNK_SIZE 1000, real shards hold ~1250 | patch |
| 3 | verification-gap | "(exhaustive)" label and "all shown" tie note never asserted | low | Pre-verified; both report tests hit only the other branch; fix is two asserts | patch |
| 4 | verification-gap, blind, edge | `test_write_report_creates_missing_folders` fails forever after an aborted run | low | `assert_false(dir_exists)` runs before cleanup; leftover `user://test_balance_out` breaks every later run; direct fix | patch |
| 5 | verification-gap, blind | Child stderr discarded; failed shard reports only an exit code | low | `OS.execute(..., output, false)`; developers hit this whenever a shard errors; fix is a flag plus appending output tail | patch |
| 6 | blind, edge | `randi_range(0, layout_count-1)` breaks for palettes ≥11 (32-bit range) | low | Not reachable with the 6-part slice palette (7^9 = 40M), but drawing per-cell digits is a direct, simpler correction | patch |
| 7 | edge | Outcome totals in `_summary` use PackedInt32Array; `--builds=all` gives ~2.46e9 runs per bucket | low | 4.9M × 500 = 2.46e9 > 2^31; only `all` reaches it; direct type change | patch |
| 8 | blind, edge | `--builds=all` / dense sample re-enumerates 40M layouts in every child | low | Real, but that path already costs ~130 CPU-hours of evaluation, so it is impractical anyway; fix (passing codes to children) adds surface | reject |
| 9 | blind | Report lacks noise measure / confidence for top builds | low | True that top-of-sample is upward-biased; intent's report list does not ask for it; adds features | reject |
| 10 | blind | Report lacks win-rate spread | low | Not in intent's report list; feature addition | reject |
| 11 | blind | No loss-by-card breakdown | low | Not in intent's report list; feature addition | reject |
| 12 | blind | Commit shown even with uncommitted tuning edits | low | Tuning snapshot is in the report; dirty flag adds git status parsing | reject |
| 13 | blind | Top/bottom overlap with <40 builds; no note for ties at the top | low | Cosmetic; default run has 3 builds at 100% | reject |
| 14 | blind | `_bmad-output/balance/` neither ignored nor committed | low | Process choice for Mike, raised in summary | reject |
| 15 | blind | Test hard-codes 40353607 | false | Computing it from palette would make the assert tautological; it is meant to pin the 6-part palette | reject |
| 16 | blind, edge | `encode` maps unknown part to empty; `part_letters` collision; tie-breaking of top loss | low | Unreachable: codes come from the palette; current names give unique initials; tie order documented in code | reject |
| 17 | edge | Palette ≥128 overflows int64 | false | Unreachable; palette is mission.parts + empty (7) | reject |
| 18 | edge | Same-second filename collision overwrites a report | low | Runs take minutes; two in one second is unlikely; fix adds a guard | reject |
| 19 | edge | `store_string` error unchecked | low | Disk-full during a few-KB write is unlikely; fix adds a guard | reject |
| 20 | edge | Duplicate PartData in mission.parts | false | cargo_run lists six distinct parts; nothing else feeds palette | reject |
| 21 | edge | User passing `--shard` gets raw lines, exit 0 | low | Internal flag documented as such in script header; unlikely use | reject |
