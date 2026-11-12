---
title: 'Dev tooling: balance report readout-valid group and confirmation pass'
type: 'feature'
created: '2026-11-11'
status: 'done'
baseline_commit: '72629e98507aeefb52789ed79a3c2abc94a63bf9'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-balance-simulator.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The balance report's averages are dragged down by nonsense layouts a player would never launch, since the build screen's readout already warns them off. Its top 20 are also ranked on 500 seeds, so some builds are there on lucky seeds.

**Approach:** (1) Tag each evaluated build as *readout-valid* when `MissionReadout.cargo_met` and `MissionReadout.fuel_met` both hold at launch, the same functions the build screen uses. Report that group's win rates separately: count and share, average, median, and a distribution table. (2) After ranking, re-run the top 20 builds against 5,000 fresh seeds, disjoint from the ranking seeds, and report a confirmed list ranked by those win rates. Balance reports in `_bmad-output/balance/` are committed to git (decided by Mike).

## Boundaries & Constraints

**Always:** Readout-valid is decided only by `MissionReadout.cargo_met(build, mission) and MissionReadout.fuel_met(build, mission)`, so an EXACT fuel status counts as valid. The group is a subset of the evaluated builds, not a separate sample. Confirmation seeds are `N+1..N+C`, where N is `--seeds` and C is `--confirm-seeds`. Outcomes come only from `RunResolver.resolve`. Same args give the same report apart from timestamp and runtime. Keep the existing sections, flags, shard protocol and the `.gdignore` placement. Statically typed. Pure logic stays free of I/O.

**Never:** No change to game rules, MissionReadout, the resolver or `.tres` files. No addon. Don't drop or rename existing report sections.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Default run | no args | Report gains "Readout-valid builds" and "Confirmation pass" sections; confirmation uses 5,000 seeds 501..5500 | N/A |
| No valid builds | none in sample pass the readout | Section states 0 builds and shows no stats | N/A |
| Even-size group | e.g. 4 valid builds | Median = mean of the two middle win rates | N/A |
| Fewer than 20 builds | `--builds=10` | Confirms all 10 | N/A |
| Confirmation off | `--confirm-seeds=0` | Section says it was skipped | N/A |
| Bad value | `--confirm-seeds=-1` / `abc` | Usage printed | exit 1 |
| Fuel exactly met | spare 0 | Counted as readout-valid | N/A |

</frozen-after-approval>

## Code Map

- `scripts/logic/mission_readout.gd`: reuse `cargo_met`, `fuel_met` (static; take `ShipBuild` + `MissionData`). Read only.
- `tools/balance/balance_sim.gd`: `decode(code, entries)` gives a `ShipBuild`. `evaluate(mission, codes, seeds, threads, progress, chunk_size)` runs seeds `1..seeds`, so it needs an optional first-seed parameter, defaulting to 1, for the confirmation seeds. `rank` sorts by wins, then code. `BuildResult.win_rate()`.
- `tools/balance/balance_report.gd`: `build(mission, results, meta)` assembles sections. `_summary` holds the overall stats, `_build_table`/`layout_text` the layout rows, `percent()` the formatting. Add the new sections after Overall. Pass confirmation results and the valid set in through `meta` or extra parameters; keep `build()` pure.
- `tools/balance/run_balance.gd`: `parse_args` (add `--confirm-seeds`, default 5000, integer ≥ 0), `shard_args` (children don't need the new flag, but parse must not reject it if it is passed), `_run` (after merging results: rank, take the top 20, `evaluate` in-process with the first seed set to `seeds + 1`, then classify valid codes), `USAGE`.
- `test/unit/test_balance_sim.gd`: existing helpers `_tiny`, `_result`, `META`.
- `README.md`: flags table, plus a note that reports are committed.

## Tasks & Acceptance

**Execution:**
- [x] `tools/balance/balance_sim.gd`: add a first-seed parameter to `evaluate`; add static `readout_valid(code, entries, mission) -> bool`, plus a median helper and a distribution helper (buckets: exactly 0%, then 10-point bands, with exactly 100% as its own row).
- [x] `tools/balance/balance_report.gd`: add a "Readout-valid builds" section with count and share of evaluated builds, average, median, and a distribution table with "All evaluated" and "Readout-valid" columns. Add a "Confirmation pass" section with seeds used, then rank by confirmed rate, with layout, original rank, ranking win rate, confirmed win rate, and the difference in percentage points.
- [x] `tools/balance/run_balance.gd`: add the `--confirm-seeds` flag, run the confirmation and the classification, and update the usage text.
- [x] `test/unit/test_balance_sim.gd`: cover every matrix row. `readout_valid` must agree with MissionReadout on sampled codes, including an EXACT-fuel build. Confirmation seeds must start at N+1, and `evaluate` with a first seed must match direct resolver calls.
- [x] `README.md`: document `--confirm-seeds`, the new sections, and that reports are committed.

**Acceptance Criteria:**
- Given the documented command with no args, when it finishes, then the run takes under 3 minutes on this machine and the report contains both new sections.
- Given the suite runs, then nothing is written under `_bmad-output/balance/`.

## Verification

**Commands:**
- `<godot-console> --headless --path . -s addons/gut/gut_cmdln.gd`: exit 0, no Warnings, 10 scripts.
- `<godot-console> --headless --path . -s res://tools/balance/run_balance.gd`: exit 0, both new sections present.

## Implementation Notes

- `BalanceSim.evaluate` gains a trailing `first_seed: int = 1`; existing call sites are unchanged. New statics: `confirm(mission, results, ranking_seeds, confirm_seeds)` (top `CONFIRM_BUILDS` = 20 by `rank`, evaluated in-process from seed `ranking_seeds + 1`; empty when `confirm_seeds` is 0), `top_codes`, `readout_valid`, `readout_valid_codes` (a `Dictionary[int, bool]` set), `median`, `distribution_bucket` / `distribution` (12 rows; integer arithmetic so band edges are exact).
- `BalanceReport.build` takes two optional parameters, `valid` and `confirmed`, plus `meta["confirm_seeds"]` (absent or 0 = section says skipped). New sections sit after Overall: "Readout-valid builds", then "Confirmation pass".
- Shard children never run the confirmation; `shard_args` does not forward `--confirm-seeds`, but `parse_args` accepts it.
- `AGENTS.md` balance command line also gained `[--confirm-seeds=N]` so it stays accurate (not listed in the code map).
- Default run: 139 s wall on this machine (was ~128 s), exit 0, both sections present. Report runtime now includes the confirmation pass.

## Spec Change Log

## Review Triage Log

| # | Source | Finding | Verdict | Evidence | Route |
|---|---|---|---|---|---|
| 1 | verification-gap, blind, edge | `_run` wiring (meta `confirm_seeds`, `valid`, `confirmed` → `BalanceReport.build`) untested; `build()` defaults silently yield "0 valid" / "Skipped" / empty confirmation table | medium | Pre-verified: no test calls `_run`; report tests pass hand-built values; dropping any argument keeps the suite green | patch |
| 2 | verification-gap, edge | "Skipped (`--confirm-seeds=0`)" printed when `meta` lacks the key | low | `meta.get("confirm_seeds", 0)` in `_confirmation`; names a flag the user never passed; direct text fix | patch |
| 3 | blind | `USAGE` uses N for both the confirm count and the ranking seeds | low | `--confirm-seeds=N  fresh seeds N+1..`; direct text fix | patch |
| 4 | blind | README timing inconsistent ("+~10 s" vs two → two and a half minutes) | low | Both figures in the same README passage; direct text fix | patch |
| 5 | edge, blind | No upper bound on `--confirm-seeds`; `seeds + confirm_seeds` can overflow | low | Needs a value near int64 max; nobody types that; fix adds a guard | reject |
| 6 | blind | Confirmation re-runs the overall top 20, not the top readout-valid builds | false | Intent says the top 20 builds, i.e. the existing top list, so this matches what was asked | reject |
| 7 | blind | Top/Bottom/Confirmation tables don't mark readout-valid builds | low | Real but a feature addition (new column) beyond intent | reject |
| 8 | blind | All-builds distribution hidden when no build is readout-valid | low | Matrix row asks for no stats; 7.4% of the default sample is valid, so rarely met | reject |
| 9 | blind | No noise/standard-error note on confirmation rows | low | Feature addition beyond intent | reject |
| 10 | blind | `--confirm-seeds` has no lower bound (1 allowed) | low | User-chosen value; not in intent; fix adds a rule | reject |
| 11 | blind | Confirmation runs in-process, not sharded | low | 20 × 5000 runs ≈ 10 s; acceptable; sharding adds surface | reject |
