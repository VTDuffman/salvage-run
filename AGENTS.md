<!-- bmad:context -->
<!-- Verified 2026-11-10 against be79266. Managed by bmad-project-context; edits inside this block are replaced on refresh. Keep anything you want preserved outside the markers. -->

## Salvage Run

Pixel-art roguelike ship-builder: assemble a ship on a grid, then watch a passive run resolve challenge cards. Godot 4.7 / GDScript, GL Compatibility renderer, desktop first with mobile planned. Design lives in `docs/salvage-run-gdd.md`; BMad planning output goes to `_bmad-output/`.

## Policy

- Build only what GDD §15 (Vertical Slice) scopes. Never build anything on its "Explicitly Out of Scope" list; if something outside §15 seems needed, ask Mike first instead of building it.
- Work directly on `main`. Commit after each completed story with a clear message, so each story can be rolled back on its own.
- Never touch `.godot/` — editor cache.
- Ask before adding any addon or plugin; GUT is the only pre-approved one.
- Editing `project.godot` settings is allowed; report every setting changed, with old and new values.

## Running and verifying

- Godot is not on PATH. Use `C:\tools\godot\Godot_v4.7.2-stable_win64_console.exe`; the non-console `Godot_v4.7.2-stable_win64.exe` beside it prints nothing to the terminal.
- Re-import headlessly after adding assets or `class_name` scripts: `<godot-console> --headless --path . --import`.
- Run tests (GUT 9.7.1, config in `.gutconfig.json`, tests in `test/`, files named `test_*.gd`): `<godot-console> --headless --path . -s addons/gut/gut_cmdln.gd`. Exit code 0 means every test passed, 1 means a failure.
- A test script that fails to parse is skipped with only a `[GUT WARNING] Ignoring script ... does not extend GutTest`, and the run still exits 0. Check that the summary shows `Warnings` absent and the expected `Scripts` count.

## Conventions that differ from defaults

- Statically type everything — variables, parameters, return types (`-> void` included), typed arrays and dictionaries. Otherwise follow the official Godot style guide.
- Target Godot 4.7; never write Godot 3 syntax: `await` not `yield`, `@export`/`@onready` not `export var`/`onready var`, `CharacterBody2D` not `KinematicBody2D`, `signal.connect(callable)` not string-based `connect("sig", self, "method")`.
- Keep game rules (grid, damage, card resolution) in plain logic classes with no Node/scene dependencies so GUT can test them headlessly; scenes only display results.

<!-- /bmad:context -->

## Balance simulator

- Dev tooling in `tools/balance/` (behind `.gdignore`; no `class_name`, scripts `preload` each other; nothing in the game references it). Run: `<godot-console> --headless --path . -s res://tools/balance/run_balance.gd -- [--builds=N|all] [--seeds=N] [--sample-seed=N] [--mission=ID] [--confirm-seeds=N]`. Defaults: 20000 sampled builds, 500 seeds (the minimum), sample seed 1, `cargo_run`, 5000 confirmation seeds (0 skips). Writes `_bmad-output/balance/balance-<UTC yyyymmdd-hhmmss>.md` and prints the path; exit 1 on bad args. See `README.md` for flag details.
- It shards work across one child Godot process per core: GDScript object creation is serialized engine-wide, so more than ~4 threads per process slows `RunResolver` down.
