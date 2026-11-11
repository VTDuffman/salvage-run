- source_spec: `_bmad-output/specs/spec-vertical-slice/stories/2-part-card-mission-data-files.md`
  summary: Validate MissionData on load (no null entries, no duplicate cards in card_pool, a Thruster in parts) so story 4 can assert on it.
  evidence: All three mistakes are easy to make in the inspector, and nothing currently guards against them.
- source_spec: `_bmad-output/specs/spec-vertical-slice/stories/2-part-card-mission-data-files.md`
  summary: Add a GUT test in story 4 that loads cargo_run.tres and checks the parts and cards are well-formed.
  evidence: Story 2's data check used a throwaway script. GUT doesn't exist until story 4.
- source_spec: `_bmad-output/specs/spec-vertical-slice/stories/3-part-palette-drag-and-drop-launch-gate.md`
  summary: In story 4, port story 3's headless checks to GUT. That means ShipBuild place/replace, move/swap, move onto its own cell, remove, out-of-range cells, cells() order and the rear-thruster launch gate, plus the scene drag/right-click checks.
  evidence: The only checks are an uncommitted scratchpad script (verify_story3.gd), so the CAP-1/CAP-2 model story 4 builds on has no regression test in the repo.
- source_spec: `_bmad-output/specs/spec-vertical-slice/stories/3-part-palette-drag-and-drop-launch-gate.md`
  summary: Add a check that a right-click during an active left drag is ignored, so a dragged part can't be lost through a null swap.
  evidence: The `not is_dragging()` guard in build_mouse_input.gd isn't exercised. Without it, a right-click mid-drag empties the source cell and the release then swaps null into the target.
