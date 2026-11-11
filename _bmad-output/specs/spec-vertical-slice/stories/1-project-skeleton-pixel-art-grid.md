---
title: 'Project skeleton with pixel-art settings and a 3×3 grid on screen'
type: 'feature'
created: '2026-11-10'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/specs/spec-vertical-slice/SPEC.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The Godot project has no main scene, and nothing is configured for pixel art, so later stories have no screen to build on.

**Approach:** Configure pixel-art rendering at a 640×360 landscape base resolution with whole-number scaling (decided with Mike, 2026-11-10). Add a main build screen that shows the Cruiser's empty 3×3 grid as placeholder tiles, viewed top-down with the front at the top. Report every project.godot setting changed, with old and new values.

</frozen-after-approval>

## Implementation Notes

- Base viewport 640×360; window override 1280×720 so the desktop window opens at 2×. Keep stretch mode `canvas_items` and aspect `expand` (so phone aspect ratios expand rather than letterbox), and add integer scale mode. Use nearest texture filtering and snap 2D transforms and vertices to pixels.
- The grid view builds its cells in code (not hand-placed in the .tscn) so story 3 can attach drag-and-drop to each cell. Grid dimensions are a single 3×3 constant pair in the view, so nothing in the logic layer is pre-empted before story 3 or 4 defines the build model.
- FRONT and REAR labels above and below the grid make the orientation readable.
- Files: `project.godot`, `scenes/build/build_screen.tscn`, `scenes/build/grid_view.gd` (+ `.uid`).
- project.godot changes (old → new; "default" means the key was previously unset):
  - `application/run/main_scene`: unset → `res://scenes/build/build_screen.tscn`
  - `display/window/size/viewport_width`: default 1152 → 640
  - `display/window/size/viewport_height`: default 648 → 360
  - `display/window/size/window_width_override`: default 0 → 1280
  - `display/window/size/window_height_override`: default 0 → 720
  - `display/window/stretch/scale_mode`: default "fractional" → "integer"
  - `rendering/textures/canvas_textures/default_texture_filter`: default 1 (Linear) → 0 (Nearest)
  - `rendering/2d/snap/snap_2d_transforms_to_pixel`: default false → true
  - `rendering/2d/snap/snap_2d_vertices_to_pixel`: default false → true
- Verified: headless `--import` and a headless run show no errors or warnings, and a `--write-movie` frame shows the centred 3×3 grid at 2× with FRONT and REAR labels.
- Surprise: a hand-written .tscn lacks the editor's `uid=` fields. Resaved it through Godot and added the scene and script UIDs, so the first editor save won't produce diff noise.

## Review Triage Log

- Settings report missing — low, real: patched (list above; also reported to Mike).
- No ACs or verification record — ACs: false, because the oneshot route omits them by design; verification record: low, patched above.
- Uncommitted — false: the commit is the workflow's next step.
- Labels not pixel-font — false for readability: the rendered frame shows crisp, legible text. Placeholder art is in scope.
- Shared StyleBoxFlat — low, rejected: no per-cell highlight exists yet. Story 3 will add one.
- get_cell before _ready — false: there is no caller before ready, and failing loudly there is acceptable.
- Exports apply only in _ready — low, rejected: this is the standard Godot pattern, and nothing changes them at runtime.
- tscn missing uids / load_steps — low, real: patched by resaving through Godot and adding the UIDs.
- Background mouse_filter — low, rejected: no input exists yet. Story 3 owns the input layer.
- d3d12 driver line — false: it predates this change and has no effect under gl_compatibility.
