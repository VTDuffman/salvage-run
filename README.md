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

The default run takes about two minutes on a 16-thread machine (it splits the work across one child Godot process per core). The tool lives in `tools/balance/` behind a `.gdignore`, so it is never imported or exported.
