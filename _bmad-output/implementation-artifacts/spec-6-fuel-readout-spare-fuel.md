---
title: 'Story 6 follow-up: fuel readout shows spare fuel with three-state color'
type: 'feature'
created: '2026-11-11'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The build-screen fuel line ("Fuel 8 / 8 needed") is green the moment fuel meets the launch requirement, so a build with no margin looks as safe as one with spare fuel.

**Approach:** Show the margin on the line, e.g. "Fuel 9 / 9 needed (0 spare)", and color it red when short, amber (warning) at exactly 0 spare, and green only with 1+ spare. "Needed" stays the launch-time figure from the previous fix (per-card burn + uncountered Fuel Leak / Gravity Well); no prediction of in-run damage. Mike's request, 2026-11-11.

</frozen-after-approval>

## Implementation Notes

- Short builds read "(N short)" rather than a negative spare, e.g. "Fuel 4 / 11 needed (7 short)". This was my choice; the request only gave the spare form.
- `MissionReadout` gains `fuel_spare(build, mission)` and a `FuelStatus { SHORT, EXACT, SPARE }` from `fuel_status()`. Fuel color is picked from that status, so the screen does no arithmetic.
- Build screen colors: the old `WARNING_COLOR` (coral red) becomes `SHORT_COLOR` and is still used for short cargo. The new `WARNING_COLOR` is amber, used for fuel at 0 spare and for the uncountered fuel card lines (those explain what is driving "needed" up, not a failure).

## Review Triage Log

- Spec lacks full sections / GUT record / status — false: the oneshot route drops those sections by design, status is set to done at finalize, and the GUT run passed (7 scripts, 137 tests, no warnings).
- Tank-data and spare tests hardcode the margin — low, patched: margins derived from `FUEL_TANK.fuel_capacity`.
- `fuel_line` re-derives short vs spare instead of using `fuel_status` — low, patched: text and color now share `fuel_status`.
- `fuel_needed` computed several times per refresh — low, rejected: a pool scan of 8 cards on build edits; no measurable cost.
- `FUEL_STATUS_COLORS` has no guard for a new status — low, rejected: a missing key fails loudly on the first refresh, and the build-screen test runs every refresh path.
- Screen test never checks spare back to exact — low, patched: the test now emits after the removal and asserts "(0 spare)" in the warning color.
- Fuel card lines turned amber, and "(N short)" wording, without sign-off — medium, rejected for code: both are recorded in Implementation Notes and raised with Mike in the summary.
- Cargo still two-state at zero margin — rejected: outside this request (fuel only), and cargo holds are a launch gate, not a margin.
- In-run fuel risk at 0 spare not logged in deferred-work — rejected: Mike explicitly ruled out predicting in-run damage in this request.
