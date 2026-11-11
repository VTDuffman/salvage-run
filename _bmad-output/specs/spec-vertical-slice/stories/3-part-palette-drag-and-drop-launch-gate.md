---
title: 'Part palette, drag-and-drop placement, and launch gate'
type: 'feature'
created: '2026-11-10'
status: 'in-progress'
baseline_commit: 'e9937437eb5200be5775bfffcadee9c2385fd236'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/specs/spec-vertical-slice/SPEC.md'
  - '{project-root}/_bmad-output/specs/spec-vertical-slice/parts-and-cards.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The build screen shows an empty 3×3 grid, and nothing on it responds to input, so the player can't assemble a ship (CAP-1). Nothing stops a launch without a rear-row thruster (CAP-2).

**Approach:** Add a palette built from `cargo_run.tres` `parts` that offers unlimited copies of each part. Mouse drag-and-drop places parts, moves them, and removes them. All of these edits change a plain-logic `ShipBuild` model, and the grid only redraws from it. A Launch button checks `ShipBuild` and refuses to launch when no thruster sits in the rear row. Mouse handling lives in its own input layer that issues build commands, so a touch layer can issue the same commands later.

## Boundaries & Constraints

**Always:** `ShipBuild` extends `RefCounted` and has no Node or scene dependencies. It stores `PartData` references per cell, with row 0 as the front and row 2 as the rear. The views (palette, grid) only display and hit-test, and the input layer is the only place that reads mouse events. Any part may go in any cell, a thruster outside the rear row included, and cells may stay empty. The palette reads its order and colors from `MissionData.parts`, never from literals. Everything is statically typed, and the code is Godot 4.7 syntax.

**Never:** Touch input, a run resolver, playback, or a seed. The checks for a gun's row and a working thruster belong to story 4, which also owns HP. No new addons. Don't change the `.tres` data or the data scripts.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Place | drag a palette part onto an empty cell | the cell shows that part, and the palette still offers it | N/A |
| Move | drag a placed part onto an empty cell | the part moves there, and its old cell is empty | N/A |
| Drop in place | drag a placed part and release it on its own cell | nothing changes | N/A |
| Drop off-grid from palette | drag a palette part and release it off the grid | nothing changes | N/A |
| Launch refused | no thruster in row 2 (none at all, or only in rows 0–1) | the status line says the launch was refused because no thruster is in the rear row | no launch |
| Launch allowed | at least one thruster in row 2 | the status line shows a placeholder "Launch OK" message, and the screen stays on the build | N/A |
| Remove by drag | drag a placed part and release it off the grid | the cell becomes empty | N/A |
| Remove by right-click | right-click a placed part | the cell becomes empty | right-click on an empty cell does nothing |
| Palette onto occupied cell | drag a palette part onto a filled cell | the new part replaces the one there | N/A |
| Move onto occupied cell | drag a placed part onto a filled cell | the two parts swap cells | N/A |

**Decisions (Mike, 2026-11-10):** Removal works two ways: drag the part off the grid, or right-click it. A palette drop onto a filled cell replaces the part there, and a grid drop onto a filled cell swaps the two. Launch stays clickable at all times. It shows the refusal reason, or a placeholder "Launch OK" message once the build is valid, and it never leaves the build screen.

</frozen-after-approval>

## Code Map

- `scenes/build/grid_view.gd` -- `GridView` (GridContainer) builds 9 `Panel` cells in code. It has `COLUMNS`/`ROWS` = 3, `get_cell(column, row)`, and one shared `StyleBoxFlat`. Extend it with `show_build(build: ShipBuild)`, which tints and labels each cell from its part's `color`/`display_name`, and with `cell_at(global_pos) -> Vector2i` (returns -1,-1 when the point is off the grid). Each cell needs its own stylebox once the cells are tinted.
- `scenes/build/build_screen.tscn` -- root Control > Background, Center > Ship (VBox: FrontLabel, GridView, RearLabel). Add the palette, the Launch button, the status label, the input layer and a script. Keep the 640×360 layout readable, and keep the existing node names.
- `scripts/data/part_data.gd` -- `PartData.kind` (THRUSTER = 0), `display_name`, `color`. Read-only for this story.
- `scripts/data/mission_data.gd` -- `MissionData.parts: Array[PartData]` gives the palette its order.
- `data/missions/cargo_run.tres` -- the single entry point the build screen loads.
- `project.godot` -- no changes expected. `untyped_declaration` warnings are treated as errors.

## Tasks & Acceptance

**Execution:**
- [x] `scripts/logic/ship_build.gd` -- `class_name ShipBuild extends RefCounted`. It has `COLUMNS`/`ROWS` = 3, `REAR_ROW` = 2, `get_part(cell: Vector2i) -> PartData`, `place(cell, part)`, `move(from, to)` (swaps if `to` is occupied), `remove(cell)`, `cells() -> Array[Vector2i]` for occupied cells, `has_rear_thruster() -> bool`, and `launch_refusal() -> String`, which is empty when launch is allowed. Out-of-range cells are ignored. This is the model story 4's resolver receives.
- [x] `scenes/build/palette_view.gd` -- `PaletteView` (VBoxContainer) builds one colored tile and name for each entry in `MissionData.parts`, and has `part_at(global_pos) -> PartData`. It does not handle input.
- [x] `scenes/build/grid_view.gd` -- add `show_build` and `cell_at` as in the Code Map, and give each cell its own stylebox.
- [x] `scenes/build/build_mouse_input.gd` -- `BuildMouseInput` (Node), the input layer. On left press it hit-tests the palette and grid to pick a drag source, shows a ghost tile that follows the cursor while dragging, and on release turns the drop into a `ShipBuild` command (place, move/swap, or remove when dropped off the grid). A right-click on a placed part removes it. After each command it emits `build_changed`. It handles only mouse events.
- [x] `scenes/build/build_screen.gd` + `build_screen.tscn` -- loads `cargo_run.tres`, owns the `ShipBuild`, wires the input layer to it, redraws the grid on `build_changed`, and handles Launch through `launch_refusal()` and the status label.
- [x] Headless verification script in the scratchpad (not committed) -- tests the `ShipBuild` edge cases and drives `BuildMouseInput` with synthetic mouse events against the real scene.

**Acceptance Criteria:**
- Given any of the 6 parts and any of the 9 cells, when the part is dragged from the palette onto that cell, then the cell shows that part and `ShipBuild.get_part(cell)` returns it.
- Given any build edit, when it completes, then every grid cell's display matches `ShipBuild` (CAP-1: the build the resolver receives is the build on screen).
- Given `thruster.tres` with its color changed in the inspector, when the screen runs, then the palette and the grid show the new color, with no code edit.
- Given a fresh screen, when Launch is pressed, then it is refused with the reason shown.

## Verification

**Commands:**
- `C:\tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --import` -- expected: no errors or warnings
- `C:\tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script <scratchpad>/verify_story3.gd` -- expected: every check prints PASS
- `--write-movie` a frame with a placed build -- expected: the palette, the tinted cells and the status line are legible at 640×360

## Implementation Notes

- `cell_at` maps any point inside the grid's rect to a cell, so a point in a gap snaps to a cell (the rect is split into thirds). A point outside the rect returns (-1,-1).
- `BuildMouseInput` reads mouse events in `_input`. The cells are `Panel`s with the default STOP mouse filter, so `_unhandled_input` would never see clicks on them. It marks an event handled only when it starts or ends a drag or removes a part. The ghost tile sits on its own `CanvasLayer` (layer 10).
- Right-click is ignored while a left drag is active.
- `GridView.get_cell_text`/`get_cell_color` and `PaletteView.get_tile_color`/`entry_center`/`entry_count` exist so tests can compare the display with `ShipBuild`.

## Spec Change Log

## Review Triage Log
