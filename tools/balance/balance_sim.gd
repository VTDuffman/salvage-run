extends RefCounted
## Headless balance simulator core (dev tooling, never shipped). Picks
## launchable 3x3 builds for a mission and resolves each against the same seeds
## with RunResolver. Plain logic: no Node, scene or file access.
##
## A layout is a base-P integer, P = palette size ([empty] + mission.parts):
## one digit per cell, cell index row * COLUMNS + column, cell 0 (front left)
## the most significant digit. Digit 0 is an empty cell, digit k is
## mission.parts[k - 1]. Launchability is always ShipBuild.launch_refusal and
## every outcome comes from RunResolver.resolve.

## Fewest seeds per build the tool accepts.
const MIN_SEEDS: int = 500
const CELLS: int = ShipBuild.ROWS * ShipBuild.COLUMNS
## Builds per WorkerThreadPool group task, between progress reports.
const CHUNK_SIZE: int = 1000
## Worker threads per process for evaluate(); measured best at 2-4.
const DEFAULT_THREADS: int = 4
const RESULT_PREFIX: String = "R"


## One evaluated build: its layout code, wins, and losses by reason.
class BuildResult:
	extends RefCounted

	var code: int = 0
	var wins: int = 0
	var runs: int = 0
	## Indexed by RunResult.LossReason; NONE stays 0.
	var losses: PackedInt32Array = PackedInt32Array()

	func _init(layout_code: int = 0) -> void:
		code = layout_code
		losses.resize(RunResult.LossReason.size())

	func win_rate() -> float:
		return float(wins) / float(runs) if runs > 0 else 0.0

	## The loss reason seen most often (ties go to the first in enum order),
	## or NONE when the build never lost.
	func top_loss_reason() -> RunResult.LossReason:
		var best: RunResult.LossReason = RunResult.LossReason.NONE
		var best_count: int = 0
		for reason: int in losses.size():
			if losses[reason] > best_count:
				best = reason as RunResult.LossReason
				best_count = losses[reason]
		return best


## Shared state for one evaluate() call; worker tasks write results under the mutex.
class _Evaluator:
	extends RefCounted

	var mission: MissionData
	var seeds: int
	var results: Array[BuildResult] = []
	## The current chunk: its builds, their codes, and where it starts in results.
	var builds: Array[ShipBuild] = []
	var codes: PackedInt64Array = PackedInt64Array()
	var offset: int = 0
	var mutex: Mutex = Mutex.new()

	func evaluate_one(index: int) -> void:
		var build: ShipBuild = builds[index]
		var result: BuildResult = BuildResult.new(codes[index])
		for run_seed: int in range(1, seeds + 1):
			var run: RunResult = RunResolver.resolve(build, mission, run_seed)
			result.runs += 1
			if run.won:
				result.wins += 1
			else:
				result.losses[run.loss_reason] += 1
		mutex.lock()
		results[offset + index] = result
		mutex.unlock()


## [empty] (null) followed by the mission's parts, in palette order.
static func palette(mission: MissionData) -> Array[PartData]:
	var entries: Array[PartData] = [null]
	for part: PartData in mission.parts:
		if part != null:
			entries.append(part)
	return entries


## Every layout of the grid, launchable or not: palette size ^ CELLS.
static func layout_count(palette_size: int) -> int:
	return palette_size ** CELLS


## The palette digit of each cell, cell index order.
@warning_ignore("integer_division")
static func digits(code: int, palette_size: int) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	result.resize(CELLS)
	var rest: int = code
	for index: int in range(CELLS - 1, -1, -1):
		result[index] = rest % palette_size
		rest = rest / palette_size
	return result


@warning_ignore("integer_division")
static func cell_at(index: int) -> Vector2i:
	return Vector2i(index % ShipBuild.COLUMNS, index / ShipBuild.COLUMNS)


static func decode(code: int, entries: Array[PartData]) -> ShipBuild:
	var build: ShipBuild = ShipBuild.new()
	var cell_digits: PackedInt32Array = digits(code, entries.size())
	for index: int in CELLS:
		if cell_digits[index] != 0:
			build.place(cell_at(index), entries[cell_digits[index]])
	return build


static func encode(build: ShipBuild, entries: Array[PartData]) -> int:
	var code: int = 0
	for index: int in CELLS:
		code = code * entries.size() + maxi(entries.find(build.get_part(cell_at(index))), 0)
	return code


static func is_launchable(code: int, entries: Array[PartData], mission: MissionData) -> bool:
	return decode(code, entries).launch_refusal(mission).is_empty()


## Exact number of launchable layouts, counted cell by cell over the two
## things ShipBuild.launch_refusal checks: a working thruster and enough
## working cargo holds (both via ShipBuild.works_in). The test suite checks
## it against brute force over launch_refusal.
static func launchable_total(mission: MissionData) -> int:
	var entries: Array[PartData] = palette(mission)
	# Key: x = has a working thruster (0/1), y = working cargo holds, capped.
	var states: Dictionary[Vector2i, int] = {Vector2i.ZERO: 1}
	for index: int in CELLS:
		var cell: Vector2i = cell_at(index)
		var next: Dictionary[Vector2i, int] = {}
		for state: Vector2i in states:
			for part: PartData in entries:
				var key: Vector2i = state
				if part != null and ShipBuild.works_in(part, cell):
					if part.kind == PartData.Kind.THRUSTER:
						key.x = 1
					elif part.kind == PartData.Kind.CARGO_HOLD:
						key.y = mini(key.y + 1, mission.cargo_required)
				next[key] = next.get(key, 0) + states[state]
		states = next
	var total: int = 0
	for state: Vector2i in states:
		if state.x == 1 and state.y >= mission.cargo_required:
			total += states[state]
	return total


## Every launchable layout code, ascending, by brute force over launch_refusal.
static func all_launchable(mission: MissionData) -> PackedInt64Array:
	var entries: Array[PartData] = palette(mission)
	var codes: PackedInt64Array = PackedInt64Array()
	for code: int in layout_count(entries.size()):
		if is_launchable(code, entries, mission):
			codes.append(code)
	return codes


## The builds to evaluate. [param requested] <= 0 or >= the launchable total
## means every launchable build; otherwise a uniform random sample of that
## many distinct launchable builds, fixed by [param sample_seed].
static func select_builds(mission: MissionData, requested: int, sample_seed: int) -> PackedInt64Array:
	var total: int = launchable_total(mission)
	if requested <= 0 or requested >= total:
		return all_launchable(mission)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = sample_seed
	var codes: PackedInt64Array = PackedInt64Array()
	if requested * 2 > total:
		# Dense sample: partial Fisher-Yates over the full list.
		var pool: PackedInt64Array = all_launchable(mission)
		for i: int in requested:
			var j: int = rng.randi_range(i, pool.size() - 1)
			var swap: int = pool[i]
			pool[i] = pool[j]
			pool[j] = swap
		codes = pool.slice(0, requested)
	else:
		# Sparse sample: draw layouts uniformly, keep new launchable ones.
		var entries: Array[PartData] = palette(mission)
		var last: int = layout_count(entries.size()) - 1
		var seen: Dictionary[int, bool] = {}
		while codes.size() < requested:
			var code: int = rng.randi_range(0, last)
			if seen.has(code):
				continue
			seen[code] = true
			if is_launchable(code, entries, mission):
				codes.append(code)
	codes.sort()
	return codes


## Resolves every build in [param codes] against seeds 1..[param seeds] on the
## WorkerThreadPool, using at most [param threads] worker threads. Each run
## allocates many script objects and object creation is serialized engine-wide,
## so more than a few threads per process is slower, not faster; scale out
## with shard() and separate processes instead. [param progress] is called
## with (done, total) after each chunk. Results come back in [param codes] order.
static func evaluate(mission: MissionData, codes: PackedInt64Array, seeds: int, threads: int = DEFAULT_THREADS, progress: Callable = Callable()) -> Array[BuildResult]:
	var entries: Array[PartData] = palette(mission)
	var evaluator: _Evaluator = _Evaluator.new()
	evaluator.mission = mission
	evaluator.seeds = seeds
	evaluator.results.resize(codes.size())
	while evaluator.offset < codes.size():
		var count: int = mini(CHUNK_SIZE, codes.size() - evaluator.offset)
		evaluator.codes = codes.slice(evaluator.offset, evaluator.offset + count)
		evaluator.builds.clear()
		for code: int in evaluator.codes:
			evaluator.builds.append(decode(code, entries))
		var task: int = WorkerThreadPool.add_group_task(evaluator.evaluate_one, count, maxi(threads, 1), true, "balance_sim")
		WorkerThreadPool.wait_for_group_task_completion(task)
		evaluator.offset += count
		if progress.is_valid():
			progress.call(evaluator.offset, codes.size())
	return evaluator.results


## Every [param count]-th code starting at [param index] (0-based): shard
## [param index] of [param count] disjoint shards that together cover [param codes].
static func shard(codes: PackedInt64Array, index: int, count: int) -> PackedInt64Array:
	var part: PackedInt64Array = PackedInt64Array()
	for i: int in range(index, codes.size(), count):
		part.append(codes[i])
	return part


## One result as a text line: "R code runs wins loss0 loss1 ...", losses
## indexed by RunResult.LossReason. Used to pass results between processes.
static func result_to_line(result: BuildResult) -> String:
	var fields: PackedStringArray = PackedStringArray([RESULT_PREFIX, str(result.code), str(result.runs), str(result.wins)])
	for count: int in result.losses:
		fields.append(str(count))
	return " ".join(fields)


## Parses result_to_line() output, or returns null for any other line.
static func result_from_line(line: String) -> BuildResult:
	var fields: PackedStringArray = line.strip_edges().split(" ", false)
	if fields.size() != 4 + RunResult.LossReason.size() or fields[0] != RESULT_PREFIX:
		return null
	for i: int in range(1, fields.size()):
		if not fields[i].is_valid_int():
			return null
	var result: BuildResult = BuildResult.new(fields[1].to_int())
	result.runs = fields[2].to_int()
	result.wins = fields[3].to_int()
	for reason: int in RunResult.LossReason.size():
		result.losses[reason] = fields[4 + reason].to_int()
	return result


## Best first: wins descending, then layout code ascending.
static func rank(results: Array[BuildResult]) -> Array[BuildResult]:
	var ranked: Array[BuildResult] = results.duplicate()
	ranked.sort_custom(func(a: BuildResult, b: BuildResult) -> bool:
		if a.wins != b.wins:
			return a.wins > b.wins
		return a.code < b.code)
	return ranked


## Why [param seeds] is refused, or "" when it is allowed.
static func seeds_error(seeds: int) -> String:
	if seeds < MIN_SEEDS:
		return "--seeds must be at least %d (got %d)." % [MIN_SEEDS, seeds]
	return ""
