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
- GUT is not installed yet. Install it under `addons/gut/` as part of the first run-resolver story, then record the verified headless test command here.

## Conventions that differ from defaults

- Statically type everything — variables, parameters, return types (`-> void` included), typed arrays and dictionaries. Otherwise follow the official Godot style guide.
- Target Godot 4.7; never write Godot 3 syntax: `await` not `yield`, `@export`/`@onready` not `export var`/`onready var`, `CharacterBody2D` not `KinematicBody2D`, `signal.connect(callable)` not string-based `connect("sig", self, "method")`.
- Keep game rules (grid, damage, card resolution) in plain logic classes with no Node/scene dependencies so GUT can test them headlessly; scenes only display results.

<!-- /bmad:context -->
