extends GutTest
## Playtest record building (dev tooling): every field the run log promises,
## read from the build, mission readout and run result without re-deriving
## any rule.

const Fixtures = preload("res://test/support/fixtures.gd")

const META: Dictionary = {
	"timestamp": "2026-11-11T09:30:00Z",
	"commit": "abc123",
	"session_id": "s1",
	"attempt": 3,
}

var _fx: Fixtures = Fixtures.new()


func _cruiser() -> ShipBuild:
	var build: ShipBuild = ShipBuild.new()
	build.place(Vector2i(0, 0), _fx.cargo_hold)
	build.place(Vector2i(1, 0), _fx.hull_plating)
	build.place(Vector2i(2, 0), _fx.cargo_hold)
	build.place(Vector2i(0, 1), _fx.fuel_tank)
	build.place(Vector2i(1, 1), _fx.shield)
	build.place(Vector2i(2, 1), _fx.fuel_tank)
	build.place(Vector2i(0, 2), _fx.hull_plating)
	build.place(Vector2i(1, 2), _fx.thruster)
	build.place(Vector2i(2, 2), _fx.thruster)
	return build


## One tank, one thruster: 4 fuel against 11 needed, so it runs dry.
func _thirsty() -> ShipBuild:
	var build: ShipBuild = ShipBuild.new()
	build.place(Vector2i(0, 0), _fx.cargo_hold)
	build.place(Vector2i(2, 0), _fx.cargo_hold)
	build.place(Vector2i(1, 1), _fx.fuel_tank)
	build.place(Vector2i(1, 2), _fx.thruster)
	return build


## Cargo Run with only Calm Space in the pool: every sound build wins.
func _calm_mission() -> MissionData:
	var mission: MissionData = _fx.cargo_run.duplicate() as MissionData
	mission.card_pool = [_fx.calm_space as CardData]
	return mission


func test_meta_and_identity_fields() -> void:
	var build: ShipBuild = _cruiser()
	var result: RunResult = RunResolver.resolve(build, _fx.cargo_run, 42)
	var record: Dictionary = PlaytestRecord.build(build, _fx.cargo_run, result, META)
	assert_eq(record["schema"], PlaytestRecord.SCHEMA)
	assert_eq(record["timestamp"], "2026-11-11T09:30:00Z")
	assert_eq(record["commit"], "abc123")
	assert_eq(record["session_id"], "s1")
	assert_eq(record["attempt"], 3)
	assert_eq(record["seed"], 42)
	assert_eq(record["mission"], "cargo_run")
	assert_null(record["difficulty"], "untagged until a feedback button is pressed")


func test_layout_is_part_ids_by_row_front_first() -> void:
	var build: ShipBuild = _thirsty()
	var record: Dictionary = PlaytestRecord.build(build, _fx.cargo_run,
			RunResolver.resolve(build, _fx.cargo_run, 1), META)
	assert_eq(record["layout"], [
		["cargo_hold", null, "cargo_hold"],
		[null, "fuel_tank", null],
		[null, "thruster", null],
	])


func test_fuel_and_cargo_match_the_launch_readout() -> void:
	var build: ShipBuild = _thirsty()
	var record: Dictionary = PlaytestRecord.build(build, _fx.cargo_run,
			RunResolver.resolve(build, _fx.cargo_run, 1), META)
	assert_eq(record["fuel"]["have"], build.fuel_capacity())
	assert_eq(record["fuel"]["needed"], MissionReadout.fuel_needed(build, _fx.cargo_run))
	assert_eq(record["fuel"]["spare"], MissionReadout.fuel_spare(build, _fx.cargo_run))
	assert_eq(record["fuel"]["have"], 4)
	assert_eq(record["fuel"]["needed"], 11)
	assert_eq(record["fuel"]["spare"], -7)
	assert_eq(record["fuel"]["uncountered"], ["fuel_leak", "gravity_well"])
	assert_eq(record["cargo"], {"have": 2, "required": _fx.cargo_run.cargo_required})


func test_won_run() -> void:
	var build: ShipBuild = _cruiser()
	var mission: MissionData = _calm_mission()
	var result: RunResult = RunResolver.resolve(build, mission, 1)
	assert_true(result.won)
	var record: Dictionary = PlaytestRecord.build(build, mission, result, META)
	assert_eq(record["outcome"], "won")
	assert_null(record["loss_reason"])
	assert_null(record["loss_card"])
	assert_eq(record["cards"].size(), mission.card_pool.size())
	assert_eq(record["card_order"], ["calm_space"])


func test_lost_run_names_reason_and_card_number() -> void:
	var build: ShipBuild = _thirsty()
	var result: RunResult = RunResolver.resolve(build, _fx.cargo_run, 7)
	assert_eq(result.loss_reason, RunResult.LossReason.OUT_OF_FUEL)
	var record: Dictionary = PlaytestRecord.build(build, _fx.cargo_run, result, META)
	assert_eq(record["outcome"], "lost")
	assert_eq(record["loss_reason"], "out_of_fuel")
	assert_eq(record["loss_card"], result.events.size())
	assert_eq(record["cards"].size(), result.events.size(), "one summary per resolved card")
	assert_lt(result.events.size(), _fx.cargo_run.card_pool.size(), "lost before the last card")
	assert_eq(record["card_order"].size(), _fx.cargo_run.card_pool.size(), "card order includes unplayed cards")


func test_card_order_uses_card_ids_in_shuffled_order() -> void:
	var build: ShipBuild = _cruiser()
	var result: RunResult = RunResolver.resolve(build, _fx.cargo_run, 9)
	var record: Dictionary = PlaytestRecord.build(build, _fx.cargo_run, result, META)
	for i: int in result.card_order.size():
		assert_eq(record["card_order"][i], PlaytestRecord.card_id(result.card_order[i]))


func test_resource_id_is_the_file_basename_or_the_fallback() -> void:
	var from_file: CardData = CardData.new()
	from_file.resource_path = "res://somewhere/rock_storm.tres"
	assert_eq(PlaytestRecord.resource_id(from_file, "fallback"), "rock_storm")
	var embedded: CardData = CardData.new()
	embedded.resource_path = "res://somewhere/mission.tres::CardData_abc"
	assert_eq(PlaytestRecord.resource_id(embedded, "fallback"), "fallback")
	assert_eq(PlaytestRecord.resource_id(CardData.new(), "fallback"), "fallback")
	assert_eq(PlaytestRecord.card_id(CardData.new()), "calm_space", "code-made cards use the kind name")


func test_card_summaries_match_events() -> void:
	var build: ShipBuild = _cruiser()
	for run_seed: int in 30:
		var result: RunResult = RunResolver.resolve(build, _fx.cargo_run, run_seed)
		var record: Dictionary = PlaytestRecord.build(build, _fx.cargo_run, result, META)
		for i: int in result.events.size():
			var event: RunResult.CardEvent = result.events[i]
			var summary: Dictionary = record["cards"][i]
			assert_eq(summary["card"], PlaytestRecord.card_id(event.card))
			assert_eq(summary["countered"], event.countered)
			assert_eq(summary["fuel_after"], event.fuel_after)
			var missed: int = 0
			var absorbed: int = 0
			var damaged: int = 0
			for hit: RunResult.HitEvent in event.hits:
				if hit.is_miss():
					missed += 1
				elif hit.damage_to_part > 0:
					damaged += 1
				else:
					absorbed += 1
			assert_eq(summary["hits"], {"missed": missed, "absorbed": absorbed, "damaged": damaged})
			var destroyed: Array[String] = []
			for cell: Vector2i in event.destroyed_cells:
				destroyed.append(PlaytestRecord.part_id(build.get_part(cell)))
			assert_eq(summary["destroyed"], destroyed)


func test_some_run_records_absorbed_damaged_and_destroyed() -> void:
	var build: ShipBuild = _cruiser()
	var seen: Dictionary = {"absorbed": false, "damaged": false, "destroyed": false}
	for run_seed: int in 100:
		var record: Dictionary = PlaytestRecord.build(build, _fx.cargo_run,
				RunResolver.resolve(build, _fx.cargo_run, run_seed), META)
		for summary: Dictionary in record["cards"]:
			seen["absorbed"] = seen["absorbed"] or summary["hits"]["absorbed"] > 0
			seen["damaged"] = seen["damaged"] or summary["hits"]["damaged"] > 0
			seen["destroyed"] = seen["destroyed"] or not summary["destroyed"].is_empty()
	assert_eq(seen, {"absorbed": true, "damaged": true, "destroyed": true})


func test_tuning_snapshot_reads_the_data() -> void:
	var tuning: Dictionary = PlaytestRecord.tuning(_fx.cargo_run)
	assert_eq(tuning["parts"].size(), _fx.cargo_run.parts.size())
	assert_eq(tuning["cards"].size(), _fx.cargo_run.card_pool.size())
	assert_eq(tuning["parts"]["fuel_tank"], {
		"max_hp": _fx.fuel_tank.max_hp,
		"fuel_capacity": _fx.fuel_tank.fuel_capacity,
		"shield_capacity": _fx.fuel_tank.shield_capacity,
	})
	assert_eq(tuning["parts"]["shield"]["shield_capacity"], _fx.shield.shield_capacity)
	var leak: CardData = _fx.fuel_leak
	assert_eq(tuning["cards"]["fuel_leak"], {
		"hits": leak.hits,
		"damage_per_hit": leak.damage_per_hit,
		"extra_fuel_loss": leak.extra_fuel_loss,
		"counter_threshold": leak.counter_threshold,
	})
	assert_eq(tuning["mission"], {
		"cargo_required": _fx.cargo_run.cargo_required,
		"fuel_per_card": _fx.cargo_run.fuel_per_card,
	})


func test_tuning_follows_changed_data() -> void:
	var mission: MissionData = _fx.cargo_run.duplicate() as MissionData
	var tank: PartData = _fx.fuel_tank.duplicate() as PartData
	tank.fuel_capacity = 9
	mission.parts = [tank]
	mission.cargo_required = 1
	var tuning: Dictionary = PlaytestRecord.tuning(mission)
	assert_eq(tuning["parts"]["fuel_tank"]["fuel_capacity"], 9, "id falls back to the kind name")
	assert_eq(tuning["mission"]["cargo_required"], 1)


func test_record_survives_a_json_round_trip() -> void:
	var build: ShipBuild = _thirsty()
	var record: Dictionary = PlaytestRecord.build(build, _fx.cargo_run,
			RunResolver.resolve(build, _fx.cargo_run, 7), META)
	var line: String = JSON.stringify(record)
	assert_false(line.contains("\n"), "one line per record")
	var parsed: Variant = JSON.parse_string(line)
	assert_true(parsed is Dictionary)
	var parsed_keys: Array = (parsed as Dictionary).keys()
	var keys: Array = record.keys()
	parsed_keys.sort()
	keys.sort()
	assert_eq(parsed_keys, keys)
	assert_eq(int(parsed["loss_card"]), record["loss_card"])
	assert_false(line.contains(".0,"), "integers stay integers")
