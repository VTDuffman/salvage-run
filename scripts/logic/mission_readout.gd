class_name MissionReadout
extends RefCounted
## Text for what a mission demands and how a build or a finished run measures
## up to it: the build screen's mission panel and readout, and the run
## screen's outcome panel. Plain logic with no Node or scene dependencies.
## Every number comes from MissionData, CardData, PartData (via ShipBuild) or
## RunResult.

## How a build's launch fuel compares with what it needs.
enum FuelStatus { SHORT, EXACT, SPARE }

const PANEL_CARGO: String = "CARGO HOLDS %d"
const PANEL_CARDS: String = "CARDS %d"
const PANEL_FUEL_PER_CARD: String = "FUEL/CARD %d"
const CARGO_LINE: String = "Cargo %d/%d"
## Filled with: build fuel, fuel needed, FUEL_SPARE or FUEL_SHORT.
const FUEL_LINE: String = "Fuel %d / %d needed (%s)"
const FUEL_SPARE: String = "%d spare"
const FUEL_SHORT: String = "%d short"
## Filled with: extra fuel, card name, counter threshold, counter part name
## (plural unless 1), row suffix, working counter parts now.
const FUEL_CARD_LINE: String = "+%d %s: counter with %d %s%s (have %d)"
const ROW_SUFFIX_FRONT: String = " in front row"
const ROW_SUFFIX_REAR: String = " in rear row"

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


## Fuel [param build] burns if every card resolves and nothing is destroyed:
## the per-card burn for every card plus the extra fuel of each fuel card the
## build leaves uncountered at launch.
static func fuel_needed(build: ShipBuild, mission: MissionData) -> int:
	var needed: int = mission.card_pool.size() * mission.fuel_per_card
	for card: CardData in uncountered_fuel_cards(build, mission):
		needed += card.extra_fuel_loss
	return needed


## Pool cards that drain extra fuel because [param build] does not counter
## them at launch, in pool order. Uses the resolver's own counter rule.
static func uncountered_fuel_cards(build: ShipBuild, mission: MissionData) -> Array[CardData]:
	var uncountered: Array[CardData] = []
	for card: CardData in mission.card_pool:
		if not RunResolver.is_fuel_card(card):
			continue
		var working: int = build.working_count(RunResolver.fuel_counter_kind(card))
		if not RunResolver.fuel_card_countered(card, working):
			uncountered.append(card)
	return uncountered


## One line per uncountered fuel card: its extra fuel and what counters it,
## e.g. "+1 Gravity Well: counter with 2 Thrusters in rear row (have 1)".
static func fuel_card_lines(build: ShipBuild, mission: MissionData) -> Array[String]:
	var lines: Array[String] = []
	for card: CardData in uncountered_fuel_cards(build, mission):
		var kind: PartData.Kind = RunResolver.fuel_counter_kind(card)
		var part: PartData = _mission_part(mission, kind)
		var part_name: String = part.display_name if part != null \
				else String(PartData.Kind.keys()[kind]).capitalize()
		part_name += _plural_s(card.counter_threshold)
		lines.append(FUEL_CARD_LINE % [card.extra_fuel_loss, card.display_name,
				card.counter_threshold, part_name, _row_suffix(part), build.working_count(kind)])
	return lines


## "Cargo <working holds>/<required>".
static func cargo_line(build: ShipBuild, mission: MissionData) -> String:
	return CARGO_LINE % [build.working_count(PartData.Kind.CARGO_HOLD), mission.cargo_required]


## "Fuel <build fuel> / <needed> needed (<n> spare)", or "(<n> short)" when
## the build has less fuel than it needs.
static func fuel_line(build: ShipBuild, mission: MissionData) -> String:
	var spare: int = fuel_spare(build, mission)
	var short: bool = fuel_status(build, mission) == FuelStatus.SHORT
	var margin: String = FUEL_SHORT % -spare if short else FUEL_SPARE % spare
	return FUEL_LINE % [build.fuel_capacity(), fuel_needed(build, mission), margin]


## Build fuel minus fuel needed; negative when short. Launch-time only: no
## in-run damage is predicted.
static func fuel_spare(build: ShipBuild, mission: MissionData) -> int:
	return build.fuel_capacity() - fuel_needed(build, mission)


## SHORT below the need, EXACT at 0 spare, SPARE with 1+ spare.
static func fuel_status(build: ShipBuild, mission: MissionData) -> FuelStatus:
	var spare: int = fuel_spare(build, mission)
	if spare < 0:
		return FuelStatus.SHORT
	if spare == 0:
		return FuelStatus.EXACT
	return FuelStatus.SPARE


static func cargo_met(build: ShipBuild, mission: MissionData) -> bool:
	return build.working_count(PartData.Kind.CARGO_HOLD) >= mission.cargo_required


## True unless the build is short (0 spare counts as met).
static func fuel_met(build: ShipBuild, mission: MissionData) -> bool:
	return fuel_status(build, mission) != FuelStatus.SHORT


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


## The mission's first offered part of [param kind], or null.
static func _mission_part(mission: MissionData, kind: PartData.Kind) -> PartData:
	for part: PartData in mission.parts:
		if part != null and part.kind == kind:
			return part
	return null


## Where a counter part must sit to count, from its required_row.
static func _row_suffix(part: PartData) -> String:
	if part == null:
		return ""
	match part.required_row:
		PartData.RequiredRow.FRONT:
			return ROW_SUFFIX_FRONT
		PartData.RequiredRow.REAR:
			return ROW_SUFFIX_REAR
	return ""


static func _plural_s(count: int) -> String:
	return "" if count == 1 else "s"
