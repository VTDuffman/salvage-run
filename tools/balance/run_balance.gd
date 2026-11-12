extends SceneTree
## Balance simulator entry point (dev tooling, never shipped). Runs
## RunResolver over many launchable builds and writes a Markdown report to
## _bmad-output/balance/. Run from the project root:
##   <godot-console> --headless --path . -s res://tools/balance/run_balance.gd -- [flags]
## Flags: --builds=N|all (default 20000), --seeds=N (default 500, minimum 500),
## --sample-seed=N (default 1), --mission=<id or res:// path> (default cargo_run).
##
## Each run allocates many script objects and Godot serializes object creation
## engine-wide, so threads alone barely scale. The build list is therefore
## split into shards, one child process of this same script per CPU core
## (internal flag --shard=i/n), each launched and read from a WorkerThreadPool
## task. A child re-selects the same builds from the same arguments,
## evaluates its shard and prints one result line per build to stdout.

const BalanceSim = preload("res://tools/balance/balance_sim.gd")
const BalanceReport = preload("res://tools/balance/balance_report.gd")

const SCRIPT_PATH: String = "res://tools/balance/run_balance.gd"
const DEFAULT_BUILDS: int = 20000
const DEFAULT_SAMPLE_SEED: int = 1
const DEFAULT_MISSION: String = "cargo_run"
const MISSION_DIR: String = "res://data/missions/"
const OUTPUT_DIR: String = "res://_bmad-output/balance"
## Below this many builds per process, child start-up costs more than it saves.
const MIN_BUILDS_PER_SHARD: int = 25
const USAGE: String = """Usage: <godot-console> --headless --path . -s res://tools/balance/run_balance.gd -- [flags]
  --builds=N|all     launchable builds to evaluate (default 20000; all or >= the launchable total = every one)
  --seeds=N          seeds per build, 1..N (default 500, minimum 500)
  --sample-seed=N    seed for picking the build sample (default 1)
  --mission=ID|PATH  mission id under res://data/missions/ or a res:// path (default cargo_run)"""


## Collects shard results from worker tasks, guarded by a mutex.
class _Shards:
	extends RefCounted

	var args: PackedStringArray = PackedStringArray()
	var count: int = 1
	var results: Dictionary[int, BalanceSim.BuildResult] = {}
	var errors: PackedStringArray = PackedStringArray()
	var done: int = 0
	var mutex: Mutex = Mutex.new()

	func run_shard(index: int) -> void:
		var shard_args: PackedStringArray = args.duplicate()
		shard_args.append("--shard=%d/%d" % [index, count])
		var output: Array = []
		var exit_code: int = OS.execute(OS.get_executable_path(), shard_args, output, false)
		var parsed: Array[BalanceSim.BuildResult] = []
		for chunk: Variant in output:
			for line: String in String(chunk).split("\n", false):
				var result: BalanceSim.BuildResult = BalanceSim.result_from_line(line)
				if result != null:
					parsed.append(result)
		mutex.lock()
		if exit_code != 0:
			errors.append("Shard %d/%d exited with code %d." % [index, count, exit_code])
		for result: BalanceSim.BuildResult in parsed:
			results[result.code] = result
		done += 1
		print("  shard %d/%d done (%d of %d shards finished)" % [index + 1, count, done, count])
		mutex.unlock()


func _initialize() -> void:
	quit(_run())


@warning_ignore("integer_division")
func _run() -> int:
	var options: Dictionary = parse_args(OS.get_cmdline_user_args())
	if options.has("error"):
		printerr(options["error"])
		printerr(USAGE)
		return 1
	if options.has("help"):
		print(USAGE)
		return 0
	var seeds: int = options["seeds"]
	var seeds_error: String = BalanceSim.seeds_error(seeds)
	if not seeds_error.is_empty():
		printerr(seeds_error)
		return 1
	var mission_path: String = options["mission"]
	var mission: MissionData = null
	if ResourceLoader.exists(mission_path):
		mission = load(mission_path) as MissionData
	if mission == null:
		printerr("Could not load a MissionData from %s." % mission_path)
		return 1
	var requested: int = options["builds"]
	var sample_seed: int = options["sample_seed"]

	if options.has("shard_index"):
		return _run_shard(mission, requested, sample_seed, seeds, options["shard_index"], options["shard_count"])

	var started: int = Time.get_ticks_msec()
	var total: int = BalanceSim.launchable_total(mission)
	print("Launchable builds: %d. Selecting %s..." % [total, "all" if requested <= 0 or requested >= total else str(requested)])
	var codes: PackedInt64Array = BalanceSim.select_builds(mission, requested, sample_seed)
	var results: Array[BalanceSim.BuildResult] = []
	var shard_count: int = clampi(codes.size() / MIN_BUILDS_PER_SHARD, 1, OS.get_processor_count())
	if shard_count == 1:
		print("Evaluating %d builds x %d seeds in this process..." % [codes.size(), seeds])
		results = BalanceSim.evaluate(mission, codes, seeds, BalanceSim.DEFAULT_THREADS, _progress)
	else:
		print("Evaluating %d builds x %d seeds in %d processes..." % [codes.size(), seeds, shard_count])
		var shards: _Shards = _Shards.new()
		shards.count = shard_count
		shards.args = PackedStringArray([
			"--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", SCRIPT_PATH, "--",
			"--builds=%s" % ("all" if requested <= 0 else str(requested)),
			"--seeds=%d" % seeds, "--sample-seed=%d" % sample_seed, "--mission=%s" % mission_path,
		])
		var task: int = WorkerThreadPool.add_group_task(shards.run_shard, shard_count, shard_count, true, "balance_shards")
		WorkerThreadPool.wait_for_group_task_completion(task)
		if not shards.errors.is_empty():
			printerr("\n".join(shards.errors))
			return 1
		for code: int in codes:
			if not shards.results.has(code):
				printerr("No result came back for build %d." % code)
				return 1
			results.append(shards.results[code])
	var runtime: float = float(Time.get_ticks_msec() - started) / 1000.0

	var meta: Dictionary = {
		"timestamp": PlaytestLog.utc_timestamp(),
		"commit": PlaytestLog.read_git_commit(),
		"mission_id": PlaytestRecord.resource_id(mission, mission.display_name.to_snake_case()),
		"launchable_total": total,
		"seeds": seeds,
		"sample_seed": sample_seed,
		"runtime_seconds": runtime,
	}
	var report: String = BalanceReport.build(mission, results, meta)

	var dir: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(dir)
	if dir_error != OK:
		printerr("Could not create %s (%s)." % [dir, error_string(dir_error)])
		return 1
	var path: String = dir.path_join("balance-%s.md" % _file_stamp())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("Could not write %s (%s)." % [path, error_string(FileAccess.get_open_error())])
		return 1
	file.store_string(report)
	file.close()
	print("Report written: %s" % path)
	return 0


## Child process: evaluates one shard on this thread and prints result lines.
func _run_shard(mission: MissionData, requested: int, sample_seed: int, seeds: int, index: int, count: int) -> int:
	var codes: PackedInt64Array = BalanceSim.select_builds(mission, requested, sample_seed)
	var part: PackedInt64Array = BalanceSim.shard(codes, index, count)
	for result: BalanceSim.BuildResult in BalanceSim.evaluate(mission, part, seeds, 1):
		print(BalanceSim.result_to_line(result))
	return 0


## Parses user args (after "--"). Returns builds (0 = all), seeds, sample_seed
## and mission (a res:// path), plus shard_index and shard_count for the
## internal --shard=i/n flag; or "error" with a message; or "help".
static func parse_args(args: PackedStringArray) -> Dictionary:
	var options: Dictionary = {
		"builds": DEFAULT_BUILDS,
		"seeds": BalanceSim.MIN_SEEDS,
		"sample_seed": DEFAULT_SAMPLE_SEED,
		"mission": MISSION_DIR.path_join(DEFAULT_MISSION + ".tres"),
	}
	for arg: String in args:
		if arg == "--help" or arg == "-h":
			return {"help": true}
		var split: int = arg.find("=")
		if not arg.begins_with("--") or split < 0:
			return {"error": "Unknown argument: %s" % arg}
		var key: String = arg.substr(2, split - 2)
		var value: String = arg.substr(split + 1)
		match key:
			"builds":
				if value == "all":
					options["builds"] = 0
				elif value.is_valid_int() and value.to_int() > 0:
					options["builds"] = value.to_int()
				else:
					return {"error": "--builds must be a positive integer or 'all' (got '%s')." % value}
			"seeds":
				if not value.is_valid_int():
					return {"error": "--seeds must be an integer (got '%s')." % value}
				options["seeds"] = value.to_int()
			"sample-seed":
				if not value.is_valid_int():
					return {"error": "--sample-seed must be an integer (got '%s')." % value}
				options["sample_seed"] = value.to_int()
			"mission":
				if value.is_empty():
					return {"error": "--mission needs a value."}
				options["mission"] = value if value.begins_with("res://") else MISSION_DIR.path_join(value + ".tres")
			"shard":
				var pair: PackedStringArray = value.split("/")
				if pair.size() != 2 or not pair[0].is_valid_int() or not pair[1].is_valid_int() \
						or pair[0].to_int() < 0 or pair[0].to_int() >= pair[1].to_int():
					return {"error": "--shard must be i/n with 0 <= i < n (got '%s')." % value}
				options["shard_index"] = pair[0].to_int()
				options["shard_count"] = pair[1].to_int()
			_:
				return {"error": "Unknown flag: --%s" % key}
	return options


func _progress(done: int, total: int) -> void:
	print("  %d / %d builds" % [done, total])


## UTC yyyymmdd-hhmmss.
static func _file_stamp() -> String:
	var now: Dictionary = Time.get_datetime_dict_from_system(true)
	return "%04d%02d%02d-%02d%02d%02d" % [now["year"], now["month"], now["day"], now["hour"], now["minute"], now["second"]]
