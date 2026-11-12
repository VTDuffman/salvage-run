extends GutTest
## Balance simulator (dev tooling in res://tools/balance/): launchable count,
## build selection, determinism, report sections and the seed minimum. Never
## runs the full simulation and never writes a report file.

const BalanceSim = preload("res://tools/balance/balance_sim.gd")
const BalanceReport = preload("res://tools/balance/balance_report.gd")
const RunBalance = preload("res://tools/balance/run_balance.gd")

const CARGO_RUN: MissionData = preload("res://data/missions/cargo_run.tres")
const THRUSTER: PartData = preload("res://data/parts/thruster.tres")
const FUEL_TANK: PartData = preload("res://data/parts/fuel_tank.tres")
const CARGO_HOLD: PartData = preload("res://data/parts/cargo_hold.tres")
const SHIELD: PartData = preload("res://data/parts/shield.tres")
const HULL_PLATING: PartData = preload("res://data/parts/hull_plating.tres")
const GUN: PartData = preload("res://data/parts/gun.tres")

const META: Dictionary = {
	"timestamp": "2026-11-11T09:30:00Z",
	"commit": "abc123",
	"mission_id": "cargo_run",
	"launchable_total": 1000,
	"seeds": 500,
	"sample_seed": 1,
	"runtime_seconds": 1.5,
}


## Cargo Run with a smaller palette, so brute force over every layout is quick.
func _tiny(parts: Array[PartData], cargo_required: int) -> MissionData:
	var mission: MissionData = CARGO_RUN.duplicate() as MissionData
	mission.parts = parts
	mission.cargo_required = cargo_required
	return mission


func _result(code: int, wins: int, runs: int, out_of_fuel: int) -> BalanceSim.BuildResult:
	var result: BalanceSim.BuildResult = BalanceSim.BuildResult.new(code)
	result.wins = wins
	result.runs = runs
	result.losses[RunResult.LossReason.OUT_OF_FUEL] = out_of_fuel
	result.losses[RunResult.LossReason.CARGO_LOST] = runs - wins - out_of_fuel
	return result


func test_launchable_total_matches_brute_force() -> void:
	var missions: Array[MissionData] = [
		_tiny([THRUSTER, CARGO_HOLD], 2),
		_tiny([CARGO_HOLD, THRUSTER], 0),
		_tiny([GUN, THRUSTER, CARGO_HOLD], 1),
	]
	for mission: MissionData in missions:
		var entries: Array[PartData] = BalanceSim.palette(mission)
		var brute: int = 0
		for code: int in BalanceSim.layout_count(entries.size()):
			if BalanceSim.decode(code, entries).launch_refusal(mission).is_empty():
				brute += 1
		assert_gt(brute, 0)
		assert_eq(BalanceSim.launchable_total(mission), brute)
		assert_eq(BalanceSim.all_launchable(mission).size(), brute)


func test_cargo_run_launchable_total_is_a_fraction_of_all_layouts() -> void:
	var total: int = BalanceSim.launchable_total(CARGO_RUN)
	assert_eq(BalanceSim.layout_count(BalanceSim.palette(CARGO_RUN).size()), 40353607)
	assert_gt(total, 0)
	assert_lt(total, 40353607)


func test_encode_decode_round_trip() -> void:
	var entries: Array[PartData] = BalanceSim.palette(CARGO_RUN)
	var build: ShipBuild = ShipBuild.new()
	build.place(Vector2i(0, 0), GUN)
	build.place(Vector2i(1, 0), SHIELD)
	build.place(Vector2i(2, 0), HULL_PLATING)
	build.place(Vector2i(0, 1), CARGO_HOLD)
	build.place(Vector2i(1, 1), FUEL_TANK)
	build.place(Vector2i(2, 1), CARGO_HOLD)
	build.place(Vector2i(0, 2), THRUSTER)
	build.place(Vector2i(2, 2), THRUSTER)
	var code: int = BalanceSim.encode(build, entries)
	var decoded: ShipBuild = BalanceSim.decode(code, entries)
	for index: int in BalanceSim.CELLS:
		var cell: Vector2i = BalanceSim.cell_at(index)
		assert_eq(decoded.get_part(cell), build.get_part(cell))
	var letters: PackedStringArray = BalanceReport.part_letters(entries)
	assert_eq(BalanceReport.layout_text(code, entries, letters), "G S H / C F C / T . T")


func test_sampled_builds_are_distinct_launchable_and_deterministic() -> void:
	var codes: PackedInt64Array = BalanceSim.select_builds(CARGO_RUN, 300, 7)
	assert_eq(codes.size(), 300)
	var seen: Dictionary[int, bool] = {}
	var entries: Array[PartData] = BalanceSim.palette(CARGO_RUN)
	for code: int in codes:
		assert_false(seen.has(code), "duplicate build %d" % code)
		seen[code] = true
		assert_true(BalanceSim.is_launchable(code, entries, CARGO_RUN))
	assert_eq(BalanceSim.select_builds(CARGO_RUN, 300, 7), codes)
	assert_ne(BalanceSim.select_builds(CARGO_RUN, 300, 8), codes)


func test_dense_sample_and_exhaustive_selection() -> void:
	var mission: MissionData = _tiny([THRUSTER, CARGO_HOLD], 2)
	var every: PackedInt64Array = BalanceSim.all_launchable(mission)
	var total: int = BalanceSim.launchable_total(mission)
	assert_eq(BalanceSim.select_builds(mission, 0, 1), every)
	assert_eq(BalanceSim.select_builds(mission, total, 1), every)
	assert_eq(BalanceSim.select_builds(mission, total + 5, 1), every)
	var dense: PackedInt64Array = BalanceSim.select_builds(mission, total - 3, 1)
	assert_eq(dense.size(), total - 3)
	var seen: Dictionary[int, bool] = {}
	for code: int in dense:
		assert_false(seen.has(code))
		seen[code] = true
		assert_true(every.has(code))
	assert_eq(BalanceSim.select_builds(mission, total - 3, 1), dense)


func test_evaluate_matches_resolver_and_is_deterministic() -> void:
	var codes: PackedInt64Array = BalanceSim.select_builds(CARGO_RUN, 6, 3)
	var first: Array[BalanceSim.BuildResult] = BalanceSim.evaluate(CARGO_RUN, codes, 30)
	var second: Array[BalanceSim.BuildResult] = BalanceSim.evaluate(CARGO_RUN, codes, 30)
	var entries: Array[PartData] = BalanceSim.palette(CARGO_RUN)
	assert_eq(first.size(), codes.size())
	for i: int in codes.size():
		assert_eq(first[i].code, codes[i])
		assert_eq(first[i].runs, 30)
		assert_eq(first[i].wins, second[i].wins)
		assert_eq(first[i].losses, second[i].losses)
		var wins: int = 0
		var losses: PackedInt32Array = PackedInt32Array()
		losses.resize(RunResult.LossReason.size())
		var build: ShipBuild = BalanceSim.decode(codes[i], entries)
		for run_seed: int in range(1, 31):
			var run: RunResult = RunResolver.resolve(build, CARGO_RUN, run_seed)
			if run.won:
				wins += 1
			else:
				losses[run.loss_reason] += 1
		assert_eq(first[i].wins, wins)
		assert_eq(first[i].losses, losses)


func test_rank_orders_by_wins_then_code() -> void:
	var results: Array[BalanceSim.BuildResult] = [
		_result(5, 10, 20, 10), _result(3, 15, 20, 5), _result(1, 10, 20, 10),
	]
	var ranked: Array[BalanceSim.BuildResult] = BalanceSim.rank(results)
	assert_eq(ranked[0].code, 3)
	assert_eq(ranked[1].code, 1)
	assert_eq(ranked[2].code, 5)


func test_report_has_every_section_with_few_builds() -> void:
	var codes: PackedInt64Array = BalanceSim.select_builds(CARGO_RUN, 10, 1)
	var results: Array[BalanceSim.BuildResult] = []
	for i: int in codes.size():
		results.append(_result(codes[i], i * 50, 500, 500 - i * 50))
	var report: String = BalanceReport.build(CARGO_RUN, results, META)
	for expected: String in [
		"2026-11-11T09:30:00Z", "abc123", "`cargo_run`", "10 of 1000 launchable", "| Seeds per build | 500",
		"| Sample seed | 1 |", "1.5 s", "## Overall", "Average win rate across evaluated builds: **45.0%**",
		"| won |", "| no_thruster |", "| out_of_fuel |", "| cargo_lost |", "## Top 10 builds",
		"## Bottom 10 builds", "## Parts in the top 10 builds", "| (empty cell) |", "| Thruster |",
		"## Tuning snapshot", "| fuel_tank |", "| solar_flare |", "Legend: `.` empty",
	]:
		assert_string_contains(report, expected)
	# Best build (wins 450) ranks first.
	assert_string_contains(report, "| 1 | 90.0% | 450 / 500 |")


func test_bottom_list_notes_ties_at_the_lowest_rate() -> void:
	var codes: PackedInt64Array = BalanceSim.select_builds(CARGO_RUN, 30, 2)
	var results: Array[BalanceSim.BuildResult] = []
	for i: int in codes.size():
		var wins: int = 100 if i < 5 else 0
		results.append(_result(codes[i], wins, 500, 500 - wins))
	var report: String = BalanceReport.build(CARGO_RUN, results, META)
	assert_string_contains(report, "25 builds share the lowest win rate (0.0%); 20 shown, by layout code.")


func test_seed_minimum() -> void:
	assert_string_contains(BalanceSim.seeds_error(100), "500")
	assert_eq(BalanceSim.seeds_error(499).is_empty(), false)
	assert_eq(BalanceSim.seeds_error(500), "")


func test_parse_args() -> void:
	var defaults: Dictionary = RunBalance.parse_args(PackedStringArray())
	assert_eq(defaults["builds"], 20000)
	assert_eq(defaults["seeds"], 500)
	assert_eq(defaults["sample_seed"], 1)
	assert_eq(defaults["mission"], "res://data/missions/cargo_run.tres")
	var custom: Dictionary = RunBalance.parse_args(PackedStringArray(["--builds=all", "--seeds=600", "--sample-seed=9", "--mission=cargo_run"]))
	assert_eq(custom["builds"], 0)
	assert_eq(custom["seeds"], 600)
	assert_eq(custom["sample_seed"], 9)
	assert_eq(custom["mission"], "res://data/missions/cargo_run.tres")
	assert_true(RunBalance.parse_args(PackedStringArray(["--builds=abc"])).has("error"))
	assert_true(RunBalance.parse_args(PackedStringArray(["--frobnicate=1"])).has("error"))
	assert_true(RunBalance.parse_args(PackedStringArray(["stray"])).has("error"))
	assert_true(RunBalance.parse_args(PackedStringArray(["--builds=0"])).has("error"))
	assert_true(RunBalance.parse_args(PackedStringArray(["--shard=2/2"])).has("error"))
	var shard: Dictionary = RunBalance.parse_args(PackedStringArray(["--shard=1/4"]))
	assert_eq(shard["shard_index"], 1)
	assert_eq(shard["shard_count"], 4)


func test_shards_cover_every_build_once() -> void:
	var codes: PackedInt64Array = PackedInt64Array([3, 9, 12, 40, 41, 77, 90])
	var joined: PackedInt64Array = PackedInt64Array()
	for index: int in 3:
		joined.append_array(BalanceSim.shard(codes, index, 3))
	joined.sort()
	assert_eq(joined, codes)


func test_result_line_round_trip() -> void:
	var result: BalanceSim.BuildResult = _result(123456, 300, 500, 150)
	var parsed: BalanceSim.BuildResult = BalanceSim.result_from_line(BalanceSim.result_to_line(result) + "\r")
	assert_not_null(parsed)
	assert_eq(parsed.code, 123456)
	assert_eq(parsed.runs, 500)
	assert_eq(parsed.wins, 300)
	assert_eq(parsed.losses, result.losses)
	assert_null(BalanceSim.result_from_line("Godot Engine v4.7.2.stable"))
	assert_null(BalanceSim.result_from_line("R 1 2"))
