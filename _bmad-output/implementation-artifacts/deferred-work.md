- source_spec: `_bmad-output/specs/spec-vertical-slice/stories/2-part-card-mission-data-files.md`
  summary: Validate MissionData on load (no null entries, no duplicate cards in card_pool, a Thruster in parts) so story 4 can assert on it.
  evidence: All three mistakes are easy to make in the inspector, and nothing currently guards against them.
- source_spec: `_bmad-output/specs/spec-vertical-slice/stories/2-part-card-mission-data-files.md`
  summary: Add a GUT test in story 4 that loads cargo_run.tres and checks the parts and cards are well-formed.
  evidence: Story 2's data check used a throwaway script. GUT doesn't exist until story 4.
