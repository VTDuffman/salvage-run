extends GutTest
## MissionReadout texts (CAP-7, CAP-8): the mission panel, the build readout
## and the outcome panel. Tuned mission copies prove every number is read from
## data rather than written into the code.

const Fixtures = preload("res://test/support/fixtures.gd")

var _fx: Fixtures = Fixtures.new()


## A copy of the Cargo Run with its requirement numbers changed.
func _tuned(cargo_required: int, fuel_per_card: int) -> MissionData:
	var mission: MissionData = _fx.cargo_run.duplicate() as MissionData
	mission.cargo_required = cargo_required
	mission.fuel_per_card = fuel_per_card
	return mission


## Rear thruster, two tanks, and [param holds] cargo holds in the front row.
func _ship(holds: int) -> ShipBuild:
	var build: ShipBuild = ShipBuild.new()
	build.place(Vector2i(1, 2), _fx.thruster)
	build.place(Vector2i(0, 1), _fx.fuel_tank)
	build.place(Vector2i(2, 1), _fx.fuel_tank)
	for column: int in holds:
		build.place(Vector2i(column, 0), _fx.cargo_hold)
	return build


## [method _ship] with two cargo holds and a second rear thruster: counters
## both fuel cards.
func _twin_thruster_ship() -> ShipBuild:
	var build: ShipBuild = _ship(2)
	build.place(Vector2i(0, 2), _fx.thruster)
	return build


## The Cargo Run with one pool card swapped for [param card].
func _with_card(card: CardData) -> MissionData:
	var mission: MissionData = _fx.cargo_run.duplicate() as MissionData
	var pool: Array[CardData] = []
	for pool_card: CardData in _fx.cargo_run.card_pool:
		pool.append(card if pool_card.kind == card.kind else pool_card)
	mission.card_pool = pool
	return mission


## A hand-built result whose last of [param cards] events carries the given
## loss and cargo count.
func _result(cards: int, won: bool, loss: RunResult.LossReason, holds_after: int) -> RunResult:
	var result: RunResult = RunResult.new()
	for i: int in cards:
		var event: RunResult.CardEvent = RunResult.CardEvent.new()
		event.card = _fx.cargo_run.card_pool[i % _fx.cargo_run.card_pool.size()]
		event.cargo_holds_after = holds_after
		result.events.append(event)
	result.events[cards - 1].loss_reason = loss
	result.won = won
	result.loss_reason = loss
	return result


# --- Mission panel -------------------------------------------------------------

func test_panel_lines_for_cargo_run() -> void:
	var expected: Array[String] = ["CARGO HOLDS 2", "CARDS 8", "FUEL/CARD 1"]
	assert_eq(MissionReadout.panel_lines(_fx.cargo_run), expected)


func test_panel_lines_follow_tuned_mission() -> void:
	var mission: MissionData = _tuned(3, 2)
	mission.card_pool = mission.card_pool.slice(0, 5)
	var expected: Array[String] = ["CARGO HOLDS 3", "CARDS 5", "FUEL/CARD 2"]
	assert_eq(MissionReadout.panel_lines(mission), expected)


# --- Readout -------------------------------------------------------------------

func test_fuel_needed_is_burn_when_fuel_cards_countered() -> void:
	var build: ShipBuild = _twin_thruster_ship()
	assert_eq(MissionReadout.fuel_needed(build, _fx.cargo_run), _fx.cargo_run.card_pool.size() * _fx.cargo_run.fuel_per_card)
	assert_eq(MissionReadout.fuel_needed(build, _tuned(2, 3)), _fx.cargo_run.card_pool.size() * 3)


func test_readout_short_on_cargo() -> void:
	var build: ShipBuild = _ship(1)
	assert_eq(MissionReadout.cargo_line(build, _fx.cargo_run), "Cargo 1/2")
	assert_eq(MissionReadout.fuel_line(build, _fx.cargo_run), "Fuel 8 / 9 needed (1 short)")
	assert_false(MissionReadout.cargo_met(build, _fx.cargo_run))
	assert_false(MissionReadout.fuel_met(build, _fx.cargo_run))


func test_readout_met() -> void:
	var build: ShipBuild = _twin_thruster_ship()
	assert_eq(MissionReadout.cargo_line(build, _fx.cargo_run), "Cargo 2/2")
	assert_eq(MissionReadout.fuel_line(build, _fx.cargo_run), "Fuel 8 / 8 needed (0 spare)")
	assert_true(MissionReadout.cargo_met(build, _fx.cargo_run))
	assert_true(MissionReadout.fuel_met(build, _fx.cargo_run))
	assert_eq(MissionReadout.fuel_card_lines(build, _fx.cargo_run), [] as Array[String])


func test_readout_follows_tuned_mission() -> void:
	var build: ShipBuild = _ship(2)
	var mission: MissionData = _tuned(3, 2)
	assert_eq(MissionReadout.cargo_line(build, mission), "Cargo 2/3")
	assert_eq(MissionReadout.fuel_line(build, mission), "Fuel 8 / 17 needed (9 short)", "16 burn + 1 Gravity Well")
	assert_false(MissionReadout.cargo_met(build, mission))
	assert_false(MissionReadout.fuel_met(build, mission))
	assert_eq(build.launch_refusal(mission), "Launch refused: 2 cargo holds, mission needs 3.")
	assert_eq(build.launch_refusal(_tuned(0, 2)), "", "no holds needed, no cargo refusal")


func test_readout_fuel_follows_tank_data() -> void:
	var build: ShipBuild = _ship(2)
	var big_tank: PartData = _fx.fuel_tank.duplicate() as PartData
	big_tank.fuel_capacity = 6
	build.place(Vector2i(0, 1), big_tank)
	assert_eq(MissionReadout.fuel_line(build, _fx.cargo_run),
			"Fuel %d / 9 needed (%d spare)" % [6 + _fx.fuel_tank.fuel_capacity, 6 + _fx.fuel_tank.fuel_capacity - 9])


func test_build_fuel_equals_resolver_starting_fuel() -> void:
	var builds: Array[ShipBuild] = [_ship(0), _ship(2), ShipBuild.new()]
	var tank_in_rear: ShipBuild = _ship(1)
	tank_in_rear.place(Vector2i(0, 2), _fx.fuel_tank)
	builds.append(tank_in_rear)
	for build: ShipBuild in builds:
		assert_eq(build.fuel_capacity(), RunResolver.resolve(build, _fx.cargo_run, 11).starting_fuel)


func test_fuel_spare_and_status_three_states() -> void:
	var exact: ShipBuild = _twin_thruster_ship()
	assert_eq(MissionReadout.fuel_spare(exact, _fx.cargo_run), 0)
	assert_eq(MissionReadout.fuel_status(exact, _fx.cargo_run), MissionReadout.FuelStatus.EXACT)
	assert_true(MissionReadout.fuel_met(exact, _fx.cargo_run), "0 spare still meets the need")

	var spare: ShipBuild = _twin_thruster_ship()
	spare.place(Vector2i(1, 1), _fx.fuel_tank)
	assert_eq(MissionReadout.fuel_spare(spare, _fx.cargo_run), _fx.fuel_tank.fuel_capacity)
	assert_eq(MissionReadout.fuel_status(spare, _fx.cargo_run), MissionReadout.FuelStatus.SPARE)
	assert_eq(MissionReadout.fuel_line(spare, _fx.cargo_run), "Fuel %d / 8 needed (%d spare)"
			% [3 * _fx.fuel_tank.fuel_capacity, 3 * _fx.fuel_tank.fuel_capacity - 8])

	var short: ShipBuild = _ship(2)
	assert_eq(MissionReadout.fuel_spare(short, _fx.cargo_run), -1)
	assert_eq(MissionReadout.fuel_status(short, _fx.cargo_run), MissionReadout.FuelStatus.SHORT)
	assert_false(MissionReadout.fuel_met(short, _fx.cargo_run))

	var one_spare: MissionData = _tuned(2, 1)
	one_spare.card_pool = _fx.cargo_run.card_pool.slice(0, 7)
	assert_eq(MissionReadout.fuel_line(exact, one_spare), "Fuel 8 / 7 needed (1 spare)", "1 spare is the green edge")
	assert_eq(MissionReadout.fuel_status(exact, one_spare), MissionReadout.FuelStatus.SPARE)


# --- Uncountered fuel cards ----------------------------------------------------

func test_both_fuel_cards_uncountered() -> void:
	var build: ShipBuild = ShipBuild.new()
	build.place(Vector2i(1, 2), _fx.thruster)
	build.place(Vector2i(0, 1), _fx.fuel_tank)
	assert_eq(MissionReadout.fuel_line(build, _fx.cargo_run), "Fuel 4 / 11 needed (7 short)")
	assert_false(MissionReadout.fuel_met(build, _fx.cargo_run))
	var expected: Array[String] = [
		"+2 Fuel Leak: counter with 2 Fuel Tanks (have 1)",
		"+1 Gravity Well: counter with 2 Thrusters in rear row (have 1)",
	]
	assert_eq(MissionReadout.fuel_card_lines(build, _fx.cargo_run), expected, "pool order")
	assert_eq(MissionReadout.uncountered_fuel_cards(build, _fx.cargo_run).size(), 2)


func test_fuel_leak_countered_leaves_gravity_well() -> void:
	var build: ShipBuild = _ship(2)
	assert_eq(MissionReadout.fuel_line(build, _fx.cargo_run), "Fuel 8 / 9 needed (1 short)")
	assert_false(MissionReadout.fuel_met(build, _fx.cargo_run), "8 fuel runs out against 9")
	var expected: Array[String] = ["+1 Gravity Well: counter with 2 Thrusters in rear row (have 1)"]
	assert_eq(MissionReadout.fuel_card_lines(build, _fx.cargo_run), expected)


func test_thruster_outside_rear_row_does_not_counter() -> void:
	var build: ShipBuild = _ship(2)
	build.place(Vector2i(0, 1), _fx.thruster)
	build.place(Vector2i(1, 1), _fx.fuel_tank)
	assert_eq(build.working_count(PartData.Kind.THRUSTER), 1)
	var expected: Array[String] = ["+1 Gravity Well: counter with 2 Thrusters in rear row (have 1)"]
	assert_eq(MissionReadout.fuel_card_lines(build, _fx.cargo_run), expected)
	assert_eq(MissionReadout.fuel_needed(build, _fx.cargo_run), 9)


func test_fuel_cards_follow_tuned_card_data() -> void:
	var well: CardData = _fx.gravity_well.duplicate() as CardData
	well.extra_fuel_loss = 3
	well.counter_threshold = 3
	var mission: MissionData = _with_card(well)
	var build: ShipBuild = _twin_thruster_ship()
	assert_eq(MissionReadout.fuel_line(build, mission), "Fuel 8 / 11 needed (3 short)", "2 thrusters no longer counter")
	var expected: Array[String] = ["+3 Gravity Well: counter with 3 Thrusters in rear row (have 2)"]
	assert_eq(MissionReadout.fuel_card_lines(build, mission), expected)

	var leak: CardData = _fx.fuel_leak.duplicate() as CardData
	leak.counter_threshold = 1
	leak.extra_fuel_loss = 5
	var one_tank: ShipBuild = ShipBuild.new()
	one_tank.place(Vector2i(1, 2), _fx.thruster)
	assert_eq(MissionReadout.fuel_card_lines(one_tank, _with_card(leak))[0],
			"+5 Fuel Leak: counter with 1 Fuel Tank (have 0)", "singular part name at threshold 1")
	one_tank.place(Vector2i(0, 0), _fx.fuel_tank)
	assert_eq(MissionReadout.uncountered_fuel_cards(one_tank, _with_card(leak)), [_fx.gravity_well] as Array[CardData])


func test_counter_part_name_follows_part_data() -> void:
	var mission: MissionData = _fx.cargo_run.duplicate() as MissionData
	var renamed: PartData = _fx.thruster.duplicate() as PartData
	renamed.display_name = "Engine"
	var parts: Array[PartData] = []
	for part: PartData in _fx.cargo_run.parts:
		parts.append(renamed if part.kind == PartData.Kind.THRUSTER else part)
	mission.parts = parts
	var expected: Array[String] = ["+1 Gravity Well: counter with 2 Engines in rear row (have 1)"]
	assert_eq(MissionReadout.fuel_card_lines(_ship(2), mission), expected)


# --- Outcome panel -------------------------------------------------------------

func test_won_outcome() -> void:
	var result: RunResult = _result(8, true, RunResult.LossReason.NONE, 2)
	assert_eq(MissionReadout.outcome_title(result), "RUN WON")
	assert_eq(MissionReadout.outcome_detail(result, _fx.cargo_run), "Cargo delivered: 2 of 2 holds intact")


func test_cargo_lost_outcome() -> void:
	var result: RunResult = _result(4, false, RunResult.LossReason.CARGO_LOST, 1)
	assert_eq(MissionReadout.outcome_title(result), "RUN LOST")
	assert_eq(MissionReadout.outcome_detail(result, _fx.cargo_run), "Cargo lost: had 1 hold, needed 2")
	var none_left: RunResult = _result(4, false, RunResult.LossReason.CARGO_LOST, 0)
	assert_eq(MissionReadout.outcome_detail(none_left, _fx.cargo_run), "Cargo lost: had 0 holds, needed 2")
	var two_left: RunResult = _result(4, false, RunResult.LossReason.CARGO_LOST, 2)
	assert_eq(MissionReadout.outcome_detail(two_left, _tuned(3, 1)), "Cargo lost: had 2 holds, needed 3")


func test_out_of_fuel_outcome() -> void:
	var result: RunResult = _result(7, false, RunResult.LossReason.OUT_OF_FUEL, 2)
	assert_eq(MissionReadout.outcome_title(result), "RUN LOST")
	assert_eq(MissionReadout.outcome_detail(result, _fx.cargo_run), "Out of fuel on card 7")


func test_no_thruster_outcome() -> void:
	var result: RunResult = _result(3, false, RunResult.LossReason.NO_THRUSTER, 2)
	assert_eq(MissionReadout.outcome_title(result), "RUN LOST")
	assert_eq(MissionReadout.outcome_detail(result, _fx.cargo_run), "Lost thrust on card 3: no working rear thruster")


func test_resolved_short_cargo_run_names_the_requirement() -> void:
	var build: ShipBuild = _ship(1)
	var result: RunResult = RunResolver.resolve(build, _fx.cargo_run, 5)
	assert_eq(result.loss_reason, RunResult.LossReason.CARGO_LOST)
	assert_eq(result.events.size(), 1)
	assert_eq(MissionReadout.outcome_detail(result, _fx.cargo_run), "Cargo lost: had 1 hold, needed 2")


func test_resolved_won_run_reports_holds_from_result() -> void:
	var build: ShipBuild = ShipBuild.new()
	build.place(Vector2i(1, 2), _fx.thruster)
	build.place(Vector2i(0, 0), _fx.cargo_hold)
	build.place(Vector2i(2, 0), _fx.cargo_hold)
	var mission: MissionData = _tuned(2, 0)
	var calm: Array[CardData] = []
	for card: CardData in _fx.cargo_run.card_pool:
		if card.kind == CardData.Kind.CALM_SPACE:
			calm.append(card)
	mission.card_pool = calm
	var result: RunResult = RunResolver.resolve(build, mission, 1)
	assert_true(result.won)
	assert_eq(MissionReadout.outcome_detail(result, mission), "Cargo delivered: 2 of 2 holds intact")
