# salvage-run

## Balance simulator (dev tooling)

Runs the live `.tres` tuning over many launchable 3x3 builds, each against seeds 1..N, and writes a Markdown report to `_bmad-output/balance/balance-<UTC yyyymmdd-hhmmss>.md`. From the project root:

```
C:\tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tools/balance/run_balance.gd -- [flags]
```

| Flag | Default | Meaning |
|---|---|---|
| `--builds=N` or `--builds=all` | `20000` | Launchable builds to evaluate. `all`, or N at or above the launchable total, evaluates every one; otherwise a uniform random sample of distinct builds. |
| `--seeds=N` | `500` | Seeds per build (1..N, same for every build). Minimum 500. |
| `--sample-seed=N` | `1` | Seed for picking the build sample. Same flags give the same builds and numbers. |
| `--mission=ID` | `cargo_run` | Mission id under `res://data/missions/`, or a full `res://` path. |
| `--confirm-seeds=C` | `5000` | Fresh seeds for the confirmation pass: the top 20 builds are re-run on seeds N+1..N+C, disjoint from the ranking seeds. `0` skips the pass. |

Besides the overall stats, top/bottom lists, part table and tuning snapshot, the report has two sections after Overall:

- **Readout-valid builds**: the evaluated builds whose build-screen readout shows cargo and fuel both met at launch (`MissionReadout.cargo_met` and `fuel_met`; exact fuel counts), the ones a player would actually launch. Count and share, average and median win rate, and a win-rate distribution table (exactly 0%, 10-point bands, exactly 100%) for all evaluated builds next to the readout-valid ones.
- **Confirmation pass**: the top 20 re-ranked by their win rate on the fresh seeds, with original rank, ranking win rate, confirmed win rate and the difference in percentage points. Builds that ranked high on lucky seeds drop here.

The default run takes about 140 s on a 16-thread machine (it splits the work across one child Godot process per core); the confirmation pass is about 10-15 s of that. The tool lives in `tools/balance/` behind a `.gdignore`, so it is never imported or exported.

Reports in `_bmad-output/balance/` are committed to git, so tuning changes can be compared run against run.
