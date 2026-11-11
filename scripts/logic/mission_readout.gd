class_name MissionReadout
extends RefCounted
## Text for what a mission demands and how a build or a finished run measures
## up to it: the build screen's mission panel and readout, and the run
## screen's outcome panel. Plain logic with no Node or scene dependencies.
## Every number comes from MissionData, PartData (via ShipBuild) or RunResult.

const PANEL_CARGO: String = "CARGO HOLDS %d"
const PANEL_CARDS: String = "CARDS %d"
const PANEL_FUEL_PER_CARD: String = "FUEL/CARD %d"
const CARGO_LINE: String = "Cargo %d/%d"
const FUEL_LINE: String = "Fuel %d / %d needed"

const TITLE_WON: String = "RUN WON"
const TITLE_LOST: String = "RUN LOST"
const WON_DETAIL: String = "Cargo delivered: %d of %d hold%s intact"
const CARGO_LOST_DETAIL: String = "Cargo lost: had %d hold%s, needed %d"
const OUT_OF_FUEL_DETAIL: String = "Out of fuel on card %d"
const NO_THRUSTER_DETAIL: String = "Lost thrust on card %d: no working rear thruster"


## The mission panel, one line per requirement.
static func panel_lines(mission: MissionData) -> Array[String]:
	return [
		PANEL_CARGO % mission.cargo_required,
		PANEL_CARDS % mission.card_pool.size(),
		PANEL_FUEL_PER_CARD % mission.fuel_per_card,
	]


## Fuel a run burns if every card resolves.
static func fuel_needed(mission: MissionData) -> int:
	return mission.card_pool.size() * mission.fuel_per_card


## "Cargo <working holds>/<required>".
static func cargo_line(build: ShipBuild, mission: MissionData) -> String:
	return CARGO_LINE % [build.working_count(PartData.Kind.CARGO_HOLD), mission.cargo_required]


## "Fuel <build fuel> / <needed> needed".
static func fuel_line(build: ShipBuild, mission: MissionData) -> String:
	return FUEL_LINE % [build.fuel_capacity(), fuel_needed(mission)]


static func cargo_met(build: ShipBuild, mission: MissionData) -> bool:
	return build.working_count(PartData.Kind.CARGO_HOLD) >= mission.cargo_required


static func fuel_met(build: ShipBuild, mission: MissionData) -> bool:
	return build.fuel_capacity() >= fuel_needed(mission)


## "RUN WON", "RUN LOST", or "" while the result holds neither.
static func outcome_title(result: RunResult) -> String:
	if result.won:
		return TITLE_WON
	if result.loss_reason != RunResult.LossReason.NONE:
		return TITLE_LOST
	return ""


## The result measured against the mission, e.g. "Cargo lost: had 1 hold,
## needed 2". Card numbers count from 1; the losing card is the last event.
static func outcome_detail(result: RunResult, mission: MissionData) -> String:
	if result.events.is_empty():
		return ""
	var last: RunResult.CardEvent = result.events[result.events.size() - 1]
	var card_number: int = result.events.size()
	if result.won:
		return WON_DETAIL % [last.cargo_holds_after, mission.cargo_required,
				_plural_s(mission.cargo_required)]
	match result.loss_reason:
		RunResult.LossReason.CARGO_LOST:
			return CARGO_LOST_DETAIL % [last.cargo_holds_after, _plural_s(last.cargo_holds_after),
					mission.cargo_required]
		RunResult.LossReason.OUT_OF_FUEL:
			return OUT_OF_FUEL_DETAIL % card_number
		RunResult.LossReason.NO_THRUSTER:
			return NO_THRUSTER_DETAIL % card_number
	return ""


static func _plural_s(count: int) -> String:
	return "" if count == 1 else "s"
