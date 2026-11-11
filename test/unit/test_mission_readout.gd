extends GutTest
## MissionReadout texts (CAP-7, CAP-8): the mission panel, the build readout
## and the outcome panel. Tuned mission copies prove every number is read from
## data rather than written into the code.

const CARGO_RUN: MissionData = preload("res://data/missions/cargo_run.tres")
const THRUSTER: PartData = preload("res://data/parts/thruster.tres")
const FUEL_TANK: PartData = preload("res://data/parts/fuel_tank.tres")
const CARGO_HOLD: PartData = preload("res://data/parts/cargo_hold.tres")
const HULL_PLATING: PartData = preload("res://data/parts/hull_plating.tres")


## A copy of the Cargo Run with its requirement numbers changed.
func _tuned(cargo_required: int, fuel_per_card: int) -> MissionData:
	var mission: MissionData = CARGO_RUN.duplicate() as MissionData
	mission.cargo_required = cargo_required
	mission.fuel_per_card = fuel_per_card
	return mission


## Rear thruster, two tanks, and [param holds] cargo holds in the front row.
func _ship(holds: int) -> ShipBuild:
	var build: ShipBuild = ShipBuild.new()
	build.place(Vector2i(1, 2), THRUSTER)
	build.place(Vector2i(0, 1), FUEL_TANK)
	build.place(Vector2i(2, 1), FUEL_TANK)
	for column: int in holds:
		build.place(Vector2i(column, 0), CARGO_HOLD)
	return build


## A hand-built result whose last of [param cards] events carries the given
## loss and cargo count.
func _result(cards: int, won: bool, loss: RunResult.LossReason, holds_after: int) -> RunResult:
	var result: RunResult = RunResult.new()
	for i: int in cards:
		var event: RunResult.CardEvent = RunResult.CardEvent.new()
		event.card = CARGO_RUN.card_pool[i % CARGO_RUN.card_pool.size()]
		event.cargo_holds_after = holds_after
		result.events.append(event)
	result.events[cards - 1].loss_reason = loss
	result.won = won
	result.loss_reason = loss
	return result


# --- Mission panel -------------------------------------------------------------

func test_panel_lines_for_cargo_run() -> void:
	var expected: Array[String] = ["CARGO HOLDS 2", "CARDS 8", "FUEL/CARD 1"]
	assert_eq(MissionReadout.panel_lines(CARGO_RUN), expected)


func test_panel_lines_follow_tuned_mission() -> void:
	var mission: MissionData = _tuned(3, 2)
	mission.card_pool = mission.card_pool.slice(0, 5)
	var expected: Array[String] = ["CARGO HOLDS 3", "CARDS 5", "FUEL/CARD 2"]
	assert_eq(MissionReadout.panel_lines(mission), expected)


# --- Readout -------------------------------------------------------------------

func test_fuel_needed_is_cards_times_fuel_per_card() -> void:
	assert_eq(MissionReadout.fuel_needed(CARGO_RUN), CARGO_RUN.card_pool.size() * CARGO_RUN.fuel_per_card)
	assert_eq(MissionReadout.fuel_needed(_tuned(2, 3)), CARGO_RUN.card_pool.size() * 3)


func test_readout_short_on_cargo() -> void:
	var build: ShipBuild = _ship(1)
	assert_eq(MissionReadout.cargo_line(build, CARGO_RUN), "Cargo 1/2")
	assert_eq(MissionReadout.fuel_line(build, CARGO_RUN), "Fuel 8 / 8 needed")
	assert_false(MissionReadout.cargo_met(build, CARGO_RUN))
	assert_true(MissionReadout.fuel_met(build, CARGO_RUN))


func test_readout_met() -> void:
	var build: ShipBuild = _ship(2)
	assert_eq(MissionReadout.cargo_line(build, CARGO_RUN), "Cargo 2/2")
	assert_eq(MissionReadout.fuel_line(build, CARGO_RUN), "Fuel 8 / 8 needed")
	assert_true(MissionReadout.cargo_met(build, CARGO_RUN))
	assert_true(MissionReadout.fuel_met(build, CARGO_RUN))


func test_readout_follows_tuned_mission() -> void:
	var build: ShipBuild = _ship(2)
	var mission: MissionData = _tuned(3, 2)
	assert_eq(MissionReadout.cargo_line(build, mission), "Cargo 2/3")
	assert_eq(MissionReadout.fuel_line(build, mission), "Fuel 8 / 16 needed")
	assert_false(MissionReadout.cargo_met(build, mission))
	assert_false(MissionReadout.fuel_met(build, mission))
	assert_eq(build.launch_refusal(mission), "Launch refused: 2 cargo holds, mission needs 3.")
	assert_eq(build.launch_refusal(_tuned(0, 2)), "", "no holds needed, no cargo refusal")


func test_readout_fuel_follows_tank_data() -> void:
	var build: ShipBuild = _ship(2)
	var big_tank: PartData = FUEL_TANK.duplicate() as PartData
	big_tank.fuel_capacity = 6
	build.place(Vector2i(0, 1), big_tank)
	assert_eq(MissionReadout.fuel_line(build, CARGO_RUN),
			"Fuel %d / 8 needed" % (6 + FUEL_TANK.fuel_capacity))


func test_build_fuel_equals_resolver_starting_fuel() -> void:
	var builds: Array[ShipBuild] = [_ship(0), _ship(2), ShipBuild.new()]
	var tank_in_rear: ShipBuild = _ship(1)
	tank_in_rear.place(Vector2i(0, 2), FUEL_TANK)
	builds.append(tank_in_rear)
	for build: ShipBuild in builds:
		assert_eq(build.fuel_capacity(), RunResolver.resolve(build, CARGO_RUN, 11).starting_fuel)


# --- Outcome panel -------------------------------------------------------------

func test_won_outcome() -> void:
	var result: RunResult = _result(8, true, RunResult.LossReason.NONE, 2)
	assert_eq(MissionReadout.outcome_title(result), "RUN WON")
	assert_eq(MissionReadout.outcome_detail(result, CARGO_RUN), "Cargo delivered: 2 of 2 holds intact")


func test_cargo_lost_outcome() -> void:
	var result: RunResult = _result(4, false, RunResult.LossReason.CARGO_LOST, 1)
	assert_eq(MissionReadout.outcome_title(result), "RUN LOST")
	assert_eq(MissionReadout.outcome_detail(result, CARGO_RUN), "Cargo lost: had 1 hold, needed 2")
	var none_left: RunResult = _result(4, false, RunResult.LossReason.CARGO_LOST, 0)
	assert_eq(MissionReadout.outcome_detail(none_left, CARGO_RUN), "Cargo lost: had 0 holds, needed 2")
	var two_left: RunResult = _result(4, false, RunResult.LossReason.CARGO_LOST, 2)
	assert_eq(MissionReadout.outcome_detail(two_left, _tuned(3, 1)), "Cargo lost: had 2 holds, needed 3")


func test_out_of_fuel_outcome() -> void:
	var result: RunResult = _result(7, false, RunResult.LossReason.OUT_OF_FUEL, 2)
	assert_eq(MissionReadout.outcome_title(result), "RUN LOST")
	assert_eq(MissionReadout.outcome_detail(result, CARGO_RUN), "Out of fuel on card 7")


func test_no_thruster_outcome() -> void:
	var result: RunResult = _result(3, false, RunResult.LossReason.NO_THRUSTER, 2)
	assert_eq(MissionReadout.outcome_title(result), "RUN LOST")
	assert_eq(MissionReadout.outcome_detail(result, CARGO_RUN), "Lost thrust on card 3: no working rear thruster")


func test_resolved_short_cargo_run_names_the_requirement() -> void:
	var build: ShipBuild = _ship(1)
	var result: RunResult = RunResolver.resolve(build, CARGO_RUN, 5)
	assert_eq(result.loss_reason, RunResult.LossReason.CARGO_LOST)
	assert_eq(result.events.size(), 1)
	assert_eq(MissionReadout.outcome_detail(result, CARGO_RUN), "Cargo lost: had 1 hold, needed 2")


func test_resolved_won_run_reports_holds_from_result() -> void:
	var build: ShipBuild = ShipBuild.new()
	build.place(Vector2i(1, 2), THRUSTER)
	build.place(Vector2i(0, 0), CARGO_HOLD)
	build.place(Vector2i(2, 0), CARGO_HOLD)
	var mission: MissionData = _tuned(2, 0)
	var calm: Array[CardData] = []
	for card: CardData in CARGO_RUN.card_pool:
		if card.kind == CardData.Kind.CALM_SPACE:
			calm.append(card)
	mission.card_pool = calm
	var result: RunResult = RunResolver.resolve(build, mission, 1)
	assert_true(result.won)
	assert_eq(MissionReadout.outcome_detail(result, mission), "Cargo delivered: 2 of 2 holds intact")
