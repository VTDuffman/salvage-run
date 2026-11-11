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
- source_spec: `_bmad-output/specs/spec-vertical-slice/stories/4-run-resolver-pure-logic-gut-tests.md`
  summary: In story 7, watch whether shields are nearly indestructible because their own coverage protects them; candidate fixes are excluding the shield's own cell from coverage or lowering shield capacity to 1.
  evidence: Coverage includes the shield's own cell (resolution-rules.md), so hits on a shield draw from its 2 per-card capacity before its HP. Excluding its own cell is a rule change and goes back to the spec first; lowering capacity is a data-only change.
- source_spec: `_bmad-output/specs/spec-vertical-slice/stories/4-run-resolver-pure-logic-gut-tests.md`
  summary: In story 6, extend the launch gate to refuse launch when the build has fewer cargo holds than the mission's cargo_required, with a message explaining why.
  evidence: Story 4's resolver checks the cargo loss only after each card, so a build short on cargo holds launches and is lost after the first card; the gate should stop a run that can never be won from starting.
- source_spec: `_bmad-output/specs/spec-vertical-slice/stories/5-run-playback-scene-log-speed-controls.md`
  summary: In story 6, test that build_screen.run_seed is the seed the played run used and that each launch gets a new one; the return path must also null _run_screen and re-enable build input.
  evidence: Removing rng.randomize() or passing a different seed to resolve keeps every story 5 test green; story 6's Retry/Rebuild is the first code that reads run_seed back.
