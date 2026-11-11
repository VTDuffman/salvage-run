extends GutTest
## MissionReadout texts (CAP-7, CAP-8): the mission panel, the build readout
## and the outcome panel. Tuned mission copies prove every number is read from
## data rather than written into the code.

const CARGO_RUN: MissionData = preload("res://data/missions/cargo_run.tres")
const THRUSTER: PartData = preload("res://data/parts/thruster.tres")
const FUEL_TANK: PartData = preload("res://data/parts/fuel_tank.tres")
const CARGO_HOLD: PartData = preload("res://data/parts/cargo_hold.tres")
const HULL_PLATING: PartData = preload("res://data/parts/hull_plating.tres")
const FUEL_LEAK: CardData = preload("res://data/cards/fuel_leak.tres")
const GRAVITY_WELL: CardData = preload("res://data/cards/gravity_well.tres")


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


## [method _ship] with two cargo holds and a second rear thruster: counters
## both fuel cards.
func _twin_thruster_ship() -> ShipBuild:
	var build: ShipBuild = _ship(2)
	build.place(Vector2i(0, 2), THRUSTER)
	return build


## The Cargo Run with one pool card swapped for [param card].
func _with_card(card: CardData) -> MissionData:
	var mission: MissionData = CARGO_RUN.duplicate() as MissionData
	var pool: Array[CardData] = []
	for pool_card: CardData in CARGO_RUN.card_pool:
		pool.append(card if pool_card.kind == card.kind else pool_card)
	mission.card_pool = pool
	return mission


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

func test_fuel_needed_is_burn_when_fuel_cards_countered() -> void:
	var build: ShipBuild = _twin_thruster_ship()
	assert_eq(MissionReadout.fuel_needed(build, CARGO_RUN), CARGO_RUN.card_pool.size() * CARGO_RUN.fuel_per_card)
	assert_eq(MissionReadout.fuel_needed(build, _tuned(2, 3)), CARGO_RUN.card_pool.size() * 3)


func test_readout_short_on_cargo() -> void:
	var build: ShipBuild = _ship(1)
	assert_eq(MissionReadout.cargo_line(build, CARGO_RUN), "Cargo 1/2")
	assert_eq(MissionReadout.fuel_line(build, CARGO_RUN), "Fuel 8 / 9 needed")
	assert_false(MissionReadout.cargo_met(build, CARGO_RUN))
	assert_false(MissionReadout.fuel_met(build, CARGO_RUN))


func test_readout_met() -> void:
	var build: ShipBuild = _twin_thruster_ship()
	assert_eq(MissionReadout.cargo_line(build, CARGO_RUN), "Cargo 2/2")
	assert_eq(MissionReadout.fuel_line(build, CARGO_RUN), "Fuel 8 / 8 needed")
	assert_true(MissionReadout.cargo_met(build, CARGO_RUN))
	assert_true(MissionReadout.fuel_met(build, CARGO_RUN))
	assert_eq(MissionReadout.fuel_card_lines(build, CARGO_RUN), [] as Array[String])


func test_readout_follows_tuned_mission() -> void:
	var build: ShipBuild = _ship(2)
	var mission: MissionData = _tuned(3, 2)
	assert_eq(MissionReadout.cargo_line(build, mission), "Cargo 2/3")
	assert_eq(MissionReadout.fuel_line(build, mission), "Fuel 8 / 17 needed", "16 burn + 1 Gravity Well")
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
			"Fuel %d / 9 needed" % (6 + FUEL_TANK.fuel_capacity))


func test_build_fuel_equals_resolver_starting_fuel() -> void:
	var builds: Array[ShipBuild] = [_ship(0), _ship(2), ShipBuild.new()]
	var tank_in_rear: ShipBuild = _ship(1)
	tank_in_rear.place(Vector2i(0, 2), FUEL_TANK)
	builds.append(tank_in_rear)
	for build: ShipBuild in builds:
		assert_eq(build.fuel_capacity(), RunResolver.resolve(build, CARGO_RUN, 11).starting_fuel)


# --- Uncountered fuel cards ----------------------------------------------------

func test_both_fuel_cards_uncountered() -> void:
	var build: ShipBuild = ShipBuild.new()
	build.place(Vector2i(1, 2), THRUSTER)
	build.place(Vector2i(0, 1), FUEL_TANK)
	assert_eq(MissionReadout.fuel_line(build, CARGO_RUN), "Fuel 4 / 11 needed")
	assert_false(MissionReadout.fuel_met(build, CARGO_RUN))
	var expected: Array[String] = [
		"+2 Fuel Leak: counter with 2 Fuel Tanks (have 1)",
		"+1 Gravity Well: counter with 2 Thrusters in rear row (have 1)",
	]
	assert_eq(MissionReadout.fuel_card_lines(build, CARGO_RUN), expected, "pool order")
	assert_eq(MissionReadout.uncountered_fuel_cards(build, CARGO_RUN).size(), 2)


func test_fuel_leak_countered_leaves_gravity_well() -> void:
	var build: ShipBuild = _ship(2)
	assert_eq(MissionReadout.fuel_line(build, CARGO_RUN), "Fuel 8 / 9 needed")
	assert_false(MissionReadout.fuel_met(build, CARGO_RUN), "8 fuel runs out against 9")
	var expected: Array[String] = ["+1 Gravity Well: counter with 2 Thrusters in rear row (have 1)"]
	assert_eq(MissionReadout.fuel_card_lines(build, CARGO_RUN), expected)


func test_thruster_outside_rear_row_does_not_counter() -> void:
	var build: ShipBuild = _ship(2)
	build.place(Vector2i(0, 1), THRUSTER)
	build.place(Vector2i(1, 1), FUEL_TANK)
	assert_eq(build.working_count(PartData.Kind.THRUSTER), 1)
	var expected: Array[String] = ["+1 Gravity Well: counter with 2 Thrusters in rear row (have 1)"]
	assert_eq(MissionReadout.fuel_card_lines(build, CARGO_RUN), expected)
	assert_eq(MissionReadout.fuel_needed(build, CARGO_RUN), 9)


func test_fuel_cards_follow_tuned_card_data() -> void:
	var well: CardData = GRAVITY_WELL.duplicate() as CardData
	well.extra_fuel_loss = 3
	well.counter_threshold = 3
	var mission: MissionData = _with_card(well)
	var build: ShipBuild = _twin_thruster_ship()
	assert_eq(MissionReadout.fuel_line(build, mission), "Fuel 8 / 11 needed", "2 thrusters no longer counter")
	var expected: Array[String] = ["+3 Gravity Well: counter with 3 Thrusters in rear row (have 2)"]
	assert_eq(MissionReadout.fuel_card_lines(build, mission), expected)

	var leak: CardData = FUEL_LEAK.duplicate() as CardData
	leak.counter_threshold = 1
	leak.extra_fuel_loss = 5
	var one_tank: ShipBuild = ShipBuild.new()
	one_tank.place(Vector2i(1, 2), THRUSTER)
	assert_eq(MissionReadout.fuel_card_lines(one_tank, _with_card(leak))[0],
			"+5 Fuel Leak: counter with 1 Fuel Tank (have 0)", "singular part name at threshold 1")
	one_tank.place(Vector2i(0, 0), FUEL_TANK)
	assert_eq(MissionReadout.uncountered_fuel_cards(one_tank, _with_card(leak)), [GRAVITY_WELL] as Array[CardData])


func test_counter_part_name_follows_part_data() -> void:
	var mission: MissionData = CARGO_RUN.duplicate() as MissionData
	var renamed: PartData = THRUSTER.duplicate() as PartData
	renamed.display_name = "Engine"
	var parts: Array[PartData] = []
	for part: PartData in CARGO_RUN.parts:
		parts.append(renamed if part.kind == PartData.Kind.THRUSTER else part)
	mission.parts = parts
	var expected: Array[String] = ["+1 Gravity Well: counter with 2 Engines in rear row (have 1)"]
	assert_eq(MissionReadout.fuel_card_lines(_ship(2), mission), expected)


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
