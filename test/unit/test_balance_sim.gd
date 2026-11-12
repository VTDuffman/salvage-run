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
	# Chunks of 4 over 6 codes: a full chunk then a partial one.
	var chunked: Array[BalanceSim.BuildResult] = BalanceSim.evaluate(
			CARGO_RUN, codes, 30, BalanceSim.DEFAULT_THREADS, Callable(), 4)
	var entries: Array[PartData] = BalanceSim.palette(CARGO_RUN)
	assert_eq(first.size(), codes.size())
	assert_eq(chunked.size(), codes.size())
	for i: int in codes.size():
		assert_eq(first[i].code, codes[i])
		assert_eq(chunked[i].code, codes[i])
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
		assert_eq(chunked[i].wins, wins)
		assert_eq(chunked[i].losses, losses)


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


func test_exhaustive_header_and_all_ties_shown() -> void:
	var mission: MissionData = _tiny([THRUSTER, CARGO_HOLD], 2)
	var codes: PackedInt64Array = BalanceSim.select_builds(mission, 0, 1)
	var total: int = BalanceSim.launchable_total(mission)
	assert_eq(codes.size(), total)
	var results: Array[BalanceSim.BuildResult] = []
	for i: int in codes.size():
		var wins: int = 0 if i < 12 else 100
		results.append(_result(codes[i], wins, 500, 500 - wins))
	var meta: Dictionary = META.duplicate()
	meta["launchable_total"] = total
	var report: String = BalanceReport.build(mission, results, meta)
	assert_string_contains(report, "%d of %d launchable (exhaustive)" % [total, total])
	assert_string_contains(report, "12 builds share the lowest win rate (0.0%); all shown, by layout code.")


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


func test_write_report_creates_missing_folders() -> void:
	var root: String = ProjectSettings.globalize_path("user://test_balance_out")
	var path: String = root.path_join("nested/report.md")
	_remove_tree(root)
	assert_eq(RunBalance.write_report(path, "# hi\n"), "")
	assert_eq(FileAccess.get_file_as_string(path), "# hi\n")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(root.path_join("nested"))
	DirAccess.remove_absolute(root)


func test_write_report_fails_when_folder_cannot_be_made() -> void:
	var blocker: String = ProjectSettings.globalize_path("user://test_balance_blocker")
	_remove_tree(blocker)
	var file: FileAccess = FileAccess.open(blocker, FileAccess.WRITE)
	file.close()
	var message: String = RunBalance.write_report(blocker.path_join("sub/report.md"), "x")
	assert_string_contains(message, "Could not")
	assert_engine_error("Could not create directory")
	DirAccess.remove_absolute(blocker)


func test_shard_args_round_trip_through_parse_args() -> void:
	var parents: Array[Dictionary] = [
		RunBalance.parse_args(PackedStringArray(["--builds=all", "--seeds=600", "--sample-seed=9", "--mission=cargo_run"])),
		RunBalance.parse_args(PackedStringArray(["--builds=1234", "--sample-seed=-3", "--mission=res://data/missions/cargo_run.tres"])),
	]
	for parent: Dictionary in parents:
		var args: PackedStringArray = RunBalance.shard_args(parent, 2, 5)
		var split: int = args.find("--")
		assert_gt(split, -1)
		assert_eq(args[args.find("-s") + 1], "res://tools/balance/run_balance.gd")
		var child: Dictionary = RunBalance.parse_args(args.slice(split + 1))
		assert_false(child.has("error"), str(child.get("error", "")))
		for key: String in ["builds", "seeds", "sample_seed", "mission"]:
			assert_eq(child[key], parent[key], key)
		assert_eq(child["shard_index"], 2)
		assert_eq(child["shard_count"], 5)
	assert_eq(parents[0]["builds"], 0)
	assert_eq(parents[0]["seeds"], 600)


func test_parse_args_confirm_seeds() -> void:
	assert_eq(RunBalance.parse_args(PackedStringArray())["confirm_seeds"], 5000)
	assert_eq(RunBalance.parse_args(PackedStringArray(["--confirm-seeds=0"]))["confirm_seeds"], 0)
	assert_eq(RunBalance.parse_args(PackedStringArray(["--confirm-seeds=1200"]))["confirm_seeds"], 1200)
	for bad: String in ["--confirm-seeds=-1", "--confirm-seeds=abc", "--confirm-seeds="]:
		var parsed: Dictionary = RunBalance.parse_args(PackedStringArray([bad]))
		assert_true(parsed.has("error"), bad)
		assert_string_contains(str(parsed.get("error", "")), "--confirm-seeds")
	assert_string_contains(RunBalance.USAGE, "--confirm-seeds")
	# A shard child must not reject the flag if it is ever passed along.
	var child: Dictionary = RunBalance.parse_args(PackedStringArray(["--confirm-seeds=7", "--shard=0/2"]))
	assert_false(child.has("error"))


## The Cargo Run ship with fuel exactly met: two rear thrusters (counter
## Gravity Well), two side fuel tanks, two front cargo holds.
func _exact_fuel_build() -> ShipBuild:
	var build: ShipBuild = ShipBuild.new()
	build.place(Vector2i(0, 2), THRUSTER)
	build.place(Vector2i(1, 2), THRUSTER)
	build.place(Vector2i(0, 1), FUEL_TANK)
	build.place(Vector2i(2, 1), FUEL_TANK)
	build.place(Vector2i(0, 0), CARGO_HOLD)
	build.place(Vector2i(1, 0), CARGO_HOLD)
	return build


func test_readout_valid_counts_exact_fuel() -> void:
	var entries: Array[PartData] = BalanceSim.palette(CARGO_RUN)
	var exact: ShipBuild = _exact_fuel_build()
	assert_eq(MissionReadout.fuel_status(exact, CARGO_RUN), MissionReadout.FuelStatus.EXACT)
	assert_true(MissionReadout.cargo_met(exact, CARGO_RUN))
	assert_true(BalanceSim.readout_valid(BalanceSim.encode(exact, entries), entries, CARGO_RUN))
	var short: ShipBuild = _exact_fuel_build()
	short.remove(Vector2i(2, 1))
	assert_eq(MissionReadout.fuel_status(short, CARGO_RUN), MissionReadout.FuelStatus.SHORT)
	assert_false(BalanceSim.readout_valid(BalanceSim.encode(short, entries), entries, CARGO_RUN))


func test_readout_valid_agrees_with_mission_readout_on_sampled_codes() -> void:
	var entries: Array[PartData] = BalanceSim.palette(CARGO_RUN)
	var codes: PackedInt64Array = BalanceSim.select_builds(CARGO_RUN, 3000, 11)
	codes.append(BalanceSim.encode(_exact_fuel_build(), entries))
	var counts: Dictionary[MissionReadout.FuelStatus, int] = {}
	var valid_count: int = 0
	var results: Array[BalanceSim.BuildResult] = []
	for code: int in codes:
		var build: ShipBuild = BalanceSim.decode(code, entries)
		var expected: bool = MissionReadout.cargo_met(build, CARGO_RUN) and MissionReadout.fuel_met(build, CARGO_RUN)
		assert_eq(BalanceSim.readout_valid(code, entries, CARGO_RUN), expected, "code %d" % code)
		var status: MissionReadout.FuelStatus = MissionReadout.fuel_status(build, CARGO_RUN)
		counts[status] = counts.get(status, 0) + 1
		if expected:
			valid_count += 1
		results.append(_result(code, 0, 10, 10))
	for status: MissionReadout.FuelStatus in [MissionReadout.FuelStatus.SHORT, MissionReadout.FuelStatus.EXACT, MissionReadout.FuelStatus.SPARE]:
		assert_gt(counts.get(status, 0), 0, "sample has a %s build" % MissionReadout.FuelStatus.keys()[status])
	assert_gt(valid_count, 0)
	assert_lt(valid_count, codes.size())
	var valid: Dictionary[int, bool] = BalanceSim.readout_valid_codes(results, CARGO_RUN)
	assert_eq(valid.size(), valid_count)
	for code: int in valid:
		assert_true(BalanceSim.readout_valid(code, entries, CARGO_RUN))


func test_median_odd_even_and_empty() -> void:
	assert_eq(BalanceSim.median(PackedFloat64Array()), 0.0)
	assert_eq(BalanceSim.median(PackedFloat64Array([0.3, 0.1, 0.2])), 0.2)
	assert_almost_eq(BalanceSim.median(PackedFloat64Array([0.4, 0.1, 0.3, 0.2])), 0.25, 1e-9)


func test_distribution_buckets() -> void:
	var cases: Dictionary[int, int] = {0: 0, 1: 1, 49: 1, 50: 2, 99: 2, 250: 6, 450: 10, 499: 10, 500: 11}
	var results: Array[BalanceSim.BuildResult] = []
	for wins: int in cases:
		var result: BalanceSim.BuildResult = _result(wins, wins, 500, 500 - wins)
		assert_eq(BalanceSim.distribution_bucket(result), cases[wins], "%d wins" % wins)
		results.append(result)
	var counts: PackedInt64Array = BalanceSim.distribution(results)
	assert_eq(counts.size(), BalanceSim.DISTRIBUTION_BUCKETS)
	assert_eq(counts, PackedInt64Array([1, 2, 2, 0, 0, 0, 1, 0, 0, 0, 2, 1]))
	assert_eq(BalanceReport.distribution_label(0), "0%")
	assert_eq(BalanceReport.distribution_label(1), "above 0% to below 10%")
	assert_eq(BalanceReport.distribution_label(10), "90% to below 100%")
	assert_eq(BalanceReport.distribution_label(11), "100%")


func test_evaluate_from_first_seed_matches_resolver() -> void:
	var codes: PackedInt64Array = BalanceSim.select_builds(CARGO_RUN, 3, 5)
	var shifted: Array[BalanceSim.BuildResult] = BalanceSim.evaluate(
			CARGO_RUN, codes, 20, BalanceSim.DEFAULT_THREADS, Callable(), BalanceSim.CHUNK_SIZE, 41)
	var entries: Array[PartData] = BalanceSim.palette(CARGO_RUN)
	for i: int in codes.size():
		assert_eq(shifted[i].runs, 20)
		assert_eq(shifted[i].wins, _direct_wins(BalanceSim.decode(codes[i], entries), 41, 60))


func test_confirm_uses_fresh_seeds_after_ranking_seeds() -> void:
	var codes: PackedInt64Array = BalanceSim.select_builds(CARGO_RUN, 30, 4)
	var results: Array[BalanceSim.BuildResult] = []
	for i: int in codes.size():
		results.append(_result(codes[i], i, 500, 500 - i))
	var confirmed: Array[BalanceSim.BuildResult] = BalanceSim.confirm(CARGO_RUN, results, 500, 12)
	var top: PackedInt64Array = BalanceSim.top_codes(results, BalanceSim.CONFIRM_BUILDS)
	assert_eq(top.size(), 20)
	assert_eq(top[0], codes[29], "best ranking build first")
	assert_eq(confirmed.size(), 20)
	var entries: Array[PartData] = BalanceSim.palette(CARGO_RUN)
	for i: int in confirmed.size():
		assert_eq(confirmed[i].code, top[i])
		assert_eq(confirmed[i].runs, 12)
		assert_eq(confirmed[i].wins, _direct_wins(BalanceSim.decode(top[i], entries), 501, 512))
	assert_eq(BalanceSim.confirm(CARGO_RUN, results, 500, 0).size(), 0)


func test_confirm_takes_every_build_when_fewer_than_20() -> void:
	var codes: PackedInt64Array = BalanceSim.select_builds(CARGO_RUN, 10, 1)
	var results: Array[BalanceSim.BuildResult] = []
	for i: int in codes.size():
		results.append(_result(codes[i], i * 50, 500, 500 - i * 50))
	var confirmed: Array[BalanceSim.BuildResult] = BalanceSim.confirm(CARGO_RUN, results, 500, 5)
	assert_eq(confirmed.size(), 10)
	var meta: Dictionary = META.duplicate()
	meta["confirm_seeds"] = 5
	var report: String = BalanceReport.build(CARGO_RUN, results, meta, {}, confirmed)
	assert_string_contains(report, "The top 10 builds by ranking win rate (seeds 1..500) re-run on 5 fresh seeds (seeds 501..505)")
	# Confirmation rows are "| rank | `layout` |..."; the other tables put the win rate second.
	assert_string_contains(report, "| 10 | `")
	assert_false(report.contains("| 11 | `"))


func test_report_confirmation_section() -> void:
	var codes: PackedInt64Array = BalanceSim.select_builds(CARGO_RUN, 3, 2)
	var results: Array[BalanceSim.BuildResult] = [
		_result(codes[0], 400, 500, 100), _result(codes[1], 300, 500, 200), _result(codes[2], 100, 500, 400),
	]
	# Confirmed rates reorder the first two builds.
	var confirmed: Array[BalanceSim.BuildResult] = [
		_result(codes[0], 3500, 5000, 1500), _result(codes[1], 3750, 5000, 1250), _result(codes[2], 500, 5000, 4500),
	]
	var meta: Dictionary = META.duplicate()
	meta["confirm_seeds"] = 5000
	var report: String = BalanceReport.build(CARGO_RUN, results, meta, {}, confirmed)
	var entries: Array[PartData] = BalanceSim.palette(CARGO_RUN)
	var letters: PackedStringArray = BalanceReport.part_letters(entries)
	assert_string_contains(report, "## Confirmation pass")
	assert_string_contains(report, "re-run on 5000 fresh seeds (seeds 501..5500)")
	assert_string_contains(report, "| 1 | `%s` | 2 | 60.0%% | 75.0%% | +15.0 pp |" % BalanceReport.layout_text(codes[1], entries, letters))
	assert_string_contains(report, "| 2 | `%s` | 1 | 80.0%% | 70.0%% | -10.0 pp |" % BalanceReport.layout_text(codes[0], entries, letters))
	assert_string_contains(report, "| 3 | `%s` | 3 | 20.0%% | 10.0%% | -10.0 pp |" % BalanceReport.layout_text(codes[2], entries, letters))
	assert_lt(report.find("## Overall"), report.find("## Readout-valid builds"))
	assert_lt(report.find("## Readout-valid builds"), report.find("## Confirmation pass"))
	assert_lt(report.find("## Confirmation pass"), report.find("## Top 3 builds"))


func test_report_confirmation_skipped() -> void:
	var codes: PackedInt64Array = BalanceSim.select_builds(CARGO_RUN, 3, 2)
	var results: Array[BalanceSim.BuildResult] = [_result(codes[0], 400, 500, 100)]
	var meta: Dictionary = META.duplicate()
	meta["confirm_seeds"] = 0
	var report: String = BalanceReport.build(CARGO_RUN, results, meta)
	assert_string_contains(report, "## Confirmation pass\n\nSkipped (`--confirm-seeds=0`).")


func test_report_readout_valid_with_no_valid_builds() -> void:
	var codes: PackedInt64Array = BalanceSim.select_builds(CARGO_RUN, 5, 3)
	var results: Array[BalanceSim.BuildResult] = []
	for code: int in codes:
		results.append(_result(code, 250, 500, 250))
	var report: String = BalanceReport.build(CARGO_RUN, results, META, {})
	assert_string_contains(report, "## Readout-valid builds")
	assert_string_contains(report, "Readout-valid builds: **0** of 5 evaluated (0.0%).")
	assert_string_contains(report, "No evaluated build passes the readout")
	assert_false(report.contains("Median win rate"))
	assert_false(report.contains("| Win rate | All evaluated |"))


func test_report_readout_valid_even_group() -> void:
	var codes: PackedInt64Array = BalanceSim.select_builds(CARGO_RUN, 6, 3)
	# Valid builds: 0%, 10%, 30%, 100%. Two invalid at 50%.
	var wins: PackedInt32Array = PackedInt32Array([0, 50, 150, 500, 250, 250])
	var results: Array[BalanceSim.BuildResult] = []
	var valid: Dictionary[int, bool] = {}
	for i: int in codes.size():
		results.append(_result(codes[i], wins[i], 500, 500 - wins[i]))
		if i < 4:
			valid[codes[i]] = true
	var report: String = BalanceReport.build(CARGO_RUN, results, META, valid)
	assert_string_contains(report, "Readout-valid builds: **4** of 6 evaluated (66.7%).")
	assert_string_contains(report, "Average win rate: **35.0%**. Median win rate: **20.0%**.")
	assert_string_contains(report, "| Win rate | All evaluated | Share | Readout-valid | Share |")
	assert_string_contains(report, "| 0% | 1 | 16.7% | 1 | 25.0% |")
	assert_string_contains(report, "| 10% to below 20% | 1 | 16.7% | 1 | 25.0% |")
	assert_string_contains(report, "| 30% to below 40% | 1 | 16.7% | 1 | 25.0% |")
	assert_string_contains(report, "| 50% to below 60% | 2 | 33.3% | 0 | 0.0% |")
	assert_string_contains(report, "| 100% | 1 | 16.7% | 1 | 25.0% |")


## Wins for [param build] over seeds [param from]..[param to], straight from the resolver.
func _direct_wins(build: ShipBuild, from: int, to: int) -> int:
	var wins: int = 0
	for run_seed: int in range(from, to + 1):
		if RunResolver.resolve(build, CARGO_RUN, run_seed).won:
			wins += 1
	return wins


## Deletes a file, or a folder and everything in it, if present.
func _remove_tree(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		return
	if not DirAccess.dir_exists_absolute(path):
		return
	for file: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	for sub: String in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(sub))
	DirAccess.remove_absolute(path)


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
