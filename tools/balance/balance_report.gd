extends RefCounted
## Builds the balance simulator's Markdown report from evaluated builds and
## run metadata (dev tooling, never shipped). Pure text: no Node or file access.

const BalanceSim = preload("res://tools/balance/balance_sim.gd")

const LIST_SIZE: int = 20
const PART_TABLE_BUILDS: int = 50
const EMPTY_LETTER: String = "."


## The full report. [param results] in any order. [param meta] holds
## [code]timestamp[/code] (String), [code]commit[/code] (String or null),
## [code]mission_id[/code] (String), [code]launchable_total[/code] (int),
## [code]seeds[/code] (int), [code]sample_seed[/code] (int) and
## [code]runtime_seconds[/code] (float), and optionally
## [code]confirm_seeds[/code] (int; 0 or absent = confirmation skipped).
## [param valid] is the set of readout-valid codes among [param results]
## (BalanceSim.readout_valid_codes). [param confirmed] holds the confirmation
## pass results (BalanceSim.confirm), in any order.
static func build(mission: MissionData, results: Array[BalanceSim.BuildResult], meta: Dictionary, valid: Dictionary[int, bool] = {}, confirmed: Array[BalanceSim.BuildResult] = []) -> String:
	var entries: Array[PartData] = BalanceSim.palette(mission)
	var letters: PackedStringArray = part_letters(entries)
	var ranked: Array[BalanceSim.BuildResult] = BalanceSim.rank(results)
	var lines: PackedStringArray = PackedStringArray()
	lines.append("# Balance report: %s" % mission.display_name)
	lines.append("")
	_header(lines, mission, ranked, meta)
	_legend(lines, entries, letters)
	_summary(lines, ranked)
	_readout_valid(lines, ranked, valid)
	_confirmation(lines, ranked, confirmed, meta, entries, letters)
	_top(lines, ranked, entries, letters)
	_bottom(lines, ranked, entries, letters)
	_part_table(lines, ranked, entries)
	_tuning(lines, mission)
	return "\n".join(lines) + "\n"


## One letter per palette entry: "." for empty, else the first letter of the
## part's display_name not already taken (normally the initial).
static func part_letters(entries: Array[PartData]) -> PackedStringArray:
	var letters: PackedStringArray = PackedStringArray()
	for part: PartData in entries:
		if part == null:
			letters.append(EMPTY_LETTER)
			continue
		var name: String = part.display_name.to_upper().replace(" ", "")
		if name.is_empty():
			name = "?"
		var letter: String = name[0]
		for i: int in name.length():
			if not letters.has(name[i]):
				letter = name[i]
				break
		letters.append(letter)
	return letters


## Three rows, front first, e.g. "G S H / C F C / T F T".
static func layout_text(code: int, entries: Array[PartData], letters: PackedStringArray) -> String:
	var cell_digits: PackedInt32Array = BalanceSim.digits(code, entries.size())
	var rows: PackedStringArray = PackedStringArray()
	for row: int in ShipBuild.ROWS:
		var cells: PackedStringArray = PackedStringArray()
		for column: int in ShipBuild.COLUMNS:
			cells.append(letters[cell_digits[row * ShipBuild.COLUMNS + column]])
		rows.append(" ".join(cells))
	return " / ".join(rows)


static func percent(numerator: int, denominator: int) -> String:
	if denominator <= 0:
		return "0.0%"
	return "%.1f%%" % (100.0 * float(numerator) / float(denominator))


static func _header(lines: PackedStringArray, mission: MissionData, ranked: Array[BalanceSim.BuildResult], meta: Dictionary) -> void:
	var total: int = int(meta.get("launchable_total", 0))
	var commit: Variant = meta.get("commit", null)
	var mode: String = "exhaustive" if ranked.size() >= total else "uniform random sample"
	lines.append("| | |")
	lines.append("|---|---|")
	lines.append("| Generated (UTC) | %s |" % meta.get("timestamp", ""))
	lines.append("| Commit | %s |" % (commit if commit != null else "unknown"))
	lines.append("| Mission | %s (`%s`) |" % [mission.display_name, meta.get("mission_id", "")])
	lines.append("| Builds evaluated | %d of %d launchable (%s) |" % [ranked.size(), total, mode])
	lines.append("| Seeds per build | %d (seeds 1..%d, same for every build) |" % [meta.get("seeds", 0), meta.get("seeds", 0)])
	lines.append("| Sample seed | %d |" % meta.get("sample_seed", 0))
	lines.append("| Runtime | %.1f s |" % float(meta.get("runtime_seconds", 0.0)))
	lines.append("")


static func _legend(lines: PackedStringArray, entries: Array[PartData], letters: PackedStringArray) -> void:
	var keys: PackedStringArray = PackedStringArray()
	for i: int in entries.size():
		var name: String = "empty" if entries[i] == null else entries[i].display_name
		keys.append("`%s` %s" % [letters[i], name])
	lines.append("Layout: three rows, front first, left to right. Legend: %s." % ", ".join(keys))
	lines.append("")


static func _summary(lines: PackedStringArray, ranked: Array[BalanceSim.BuildResult]) -> void:
	var rate_sum: float = 0.0
	var runs: int = 0
	var wins: int = 0
	var losses: PackedInt64Array = PackedInt64Array()
	losses.resize(RunResult.LossReason.size())
	for result: BalanceSim.BuildResult in ranked:
		rate_sum += result.win_rate()
		runs += result.runs
		wins += result.wins
		for reason: int in losses.size():
			losses[reason] += result.losses[reason]
	var average: float = rate_sum / float(ranked.size()) if not ranked.is_empty() else 0.0
	lines.append("## Overall")
	lines.append("")
	lines.append("Average win rate across evaluated builds: **%.1f%%**" % (100.0 * average))
	lines.append("")
	lines.append("| Outcome | Runs | Share |")
	lines.append("|---|---:|---:|")
	lines.append("| won | %d | %s |" % [wins, percent(wins, runs)])
	for reason: int in losses.size():
		if reason == RunResult.LossReason.NONE:
			continue
		lines.append("| %s | %d | %s |" % [_reason_id(reason), losses[reason], percent(losses[reason], runs)])
	lines.append("| **total** | %d | |" % runs)
	lines.append("")


static func _readout_valid(lines: PackedStringArray, ranked: Array[BalanceSim.BuildResult], valid: Dictionary[int, bool]) -> void:
	var group: Array[BalanceSim.BuildResult] = []
	for result: BalanceSim.BuildResult in ranked:
		if valid.has(result.code):
			group.append(result)
	lines.append("## Readout-valid builds")
	lines.append("")
	lines.append("Evaluated builds whose build-screen readout shows both requirements met at launch " \
			+ "(`MissionReadout.cargo_met` and `MissionReadout.fuel_met`; exact fuel counts as met). " \
			+ "A subset of the builds above, on the same seeds.")
	lines.append("")
	lines.append("Readout-valid builds: **%d** of %d evaluated (%s)." % [
		group.size(), ranked.size(), percent(group.size(), ranked.size())])
	lines.append("")
	if group.is_empty():
		lines.append("No evaluated build passes the readout, so this group has no stats.")
		lines.append("")
		return
	var rates: PackedFloat64Array = PackedFloat64Array()
	var rate_sum: float = 0.0
	for result: BalanceSim.BuildResult in group:
		rates.append(result.win_rate())
		rate_sum += result.win_rate()
	lines.append("Average win rate: **%.1f%%**. Median win rate: **%.1f%%**." % [
		100.0 * rate_sum / float(group.size()), 100.0 * BalanceSim.median(rates)])
	lines.append("")
	var all_counts: PackedInt64Array = BalanceSim.distribution(ranked)
	var valid_counts: PackedInt64Array = BalanceSim.distribution(group)
	lines.append("| Win rate | All evaluated | Share | Readout-valid | Share |")
	lines.append("|---|---:|---:|---:|---:|")
	for bucket: int in BalanceSim.DISTRIBUTION_BUCKETS:
		lines.append("| %s | %d | %s | %d | %s |" % [
			distribution_label(bucket), all_counts[bucket], percent(all_counts[bucket], ranked.size()),
			valid_counts[bucket], percent(valid_counts[bucket], group.size())])
	lines.append("")


## Row label for a BalanceSim.distribution_bucket() index.
static func distribution_label(bucket: int) -> String:
	if bucket <= 0:
		return "0%"
	if bucket >= BalanceSim.DISTRIBUTION_BUCKETS - 1:
		return "100%"
	if bucket == 1:
		return "above 0% to below 10%"
	return "%d%% to below %d%%" % [(bucket - 1) * 10, bucket * 10]


static func _confirmation(lines: PackedStringArray, ranked: Array[BalanceSim.BuildResult], confirmed: Array[BalanceSim.BuildResult], meta: Dictionary, entries: Array[PartData], letters: PackedStringArray) -> void:
	var seeds: int = int(meta.get("seeds", 0))
	var confirm_seeds: int = int(meta.get("confirm_seeds", 0))
	lines.append("## Confirmation pass")
	lines.append("")
	if confirm_seeds <= 0:
		lines.append("Skipped (`--confirm-seeds=0`).")
		lines.append("")
		return
	var original: Dictionary[int, int] = {}
	for i: int in ranked.size():
		original[ranked[i].code] = i
	var reranked: Array[BalanceSim.BuildResult] = BalanceSim.rank(confirmed)
	lines.append("The top %d builds by ranking win rate (seeds 1..%d) re-run on %d fresh seeds (seeds %d..%d), " % [
		reranked.size(), seeds, confirm_seeds, seeds + 1, seeds + confirm_seeds] \
			+ "ranked by confirmed win rate. Difference is confirmed minus ranking, in percentage points.")
	lines.append("")
	lines.append("| Rank | Layout | Original rank | Ranking win rate | Confirmed win rate | Difference |")
	lines.append("|---:|---|---:|---:|---:|---:|")
	for i: int in reranked.size():
		var result: BalanceSim.BuildResult = reranked[i]
		var index: int = original.get(result.code, -1)
		var rank_text: String = "—"
		var ranking_rate: String = "—"
		var difference: String = "—"
		if index >= 0:
			var before: BalanceSim.BuildResult = ranked[index]
			rank_text = str(index + 1)
			ranking_rate = percent(before.wins, before.runs)
			difference = "%+.1f pp" % (100.0 * (result.win_rate() - before.win_rate()))
		lines.append("| %d | `%s` | %s | %s | %s | %s |" % [
			i + 1, layout_text(result.code, entries, letters), rank_text, ranking_rate,
			percent(result.wins, result.runs), difference])
	lines.append("")


static func _top(lines: PackedStringArray, ranked: Array[BalanceSim.BuildResult], entries: Array[PartData], letters: PackedStringArray) -> void:
	var count: int = mini(LIST_SIZE, ranked.size())
	lines.append("## Top %d builds" % count)
	lines.append("")
	_build_table(lines, ranked, 0, count, entries, letters)


static func _bottom(lines: PackedStringArray, ranked: Array[BalanceSim.BuildResult], entries: Array[PartData], letters: PackedStringArray) -> void:
	var count: int = mini(LIST_SIZE, ranked.size())
	lines.append("## Bottom %d builds" % count)
	lines.append("")
	if ranked.is_empty():
		_build_table(lines, ranked, 0, 0, entries, letters)
		return
	var lowest: BalanceSim.BuildResult = ranked[ranked.size() - 1]
	var tied: int = 0
	for result: BalanceSim.BuildResult in ranked:
		if result.wins == lowest.wins:
			tied += 1
	if tied > 1:
		lines.append("%d builds share the lowest win rate (%s); %s shown, by layout code." % [
			tied, percent(lowest.wins, lowest.runs), "all" if tied <= count else "%d" % count])
		lines.append("")
	_build_table(lines, ranked, ranked.size() - count, ranked.size(), entries, letters)


static func _build_table(lines: PackedStringArray, ranked: Array[BalanceSim.BuildResult], from: int, to: int, entries: Array[PartData], letters: PackedStringArray) -> void:
	lines.append("| Rank | Win rate | Wins / seeds | Layout | Most common loss |")
	lines.append("|---:|---:|---:|---|---|")
	for i: int in range(from, to):
		var result: BalanceSim.BuildResult = ranked[i]
		var reason: RunResult.LossReason = result.top_loss_reason()
		var loss: String = "—"
		if reason != RunResult.LossReason.NONE:
			loss = "%s (%d)" % [_reason_id(reason), result.losses[reason]]
		lines.append("| %d | %s | %d / %d | `%s` | %s |" % [
			i + 1, percent(result.wins, result.runs), result.wins, result.runs,
			layout_text(result.code, entries, letters), loss])
	lines.append("")


static func _part_table(lines: PackedStringArray, ranked: Array[BalanceSim.BuildResult], entries: Array[PartData]) -> void:
	var count: int = mini(PART_TABLE_BUILDS, ranked.size())
	var builds: PackedInt32Array = PackedInt32Array()
	var copies: PackedInt32Array = PackedInt32Array()
	var working: PackedInt32Array = PackedInt32Array()
	builds.resize(entries.size())
	copies.resize(entries.size())
	working.resize(entries.size())
	for i: int in count:
		var cell_digits: PackedInt32Array = BalanceSim.digits(ranked[i].code, entries.size())
		var seen: PackedByteArray = PackedByteArray()
		seen.resize(entries.size())
		for index: int in BalanceSim.CELLS:
			var digit: int = cell_digits[index]
			copies[digit] += 1
			seen[digit] = 1
			var part: PartData = entries[digit]
			if part != null and ShipBuild.works_in(part, BalanceSim.cell_at(index)):
				working[digit] += 1
		for digit: int in entries.size():
			builds[digit] += seen[digit]
	lines.append("## Parts in the top %d builds" % count)
	lines.append("")
	lines.append("| Part | Builds containing it | Total copies | Copies in a working cell |")
	lines.append("|---|---:|---:|---:|")
	for digit: int in entries.size():
		var part: PartData = entries[digit]
		var name: String = "(empty cell)" if part == null else part.display_name
		var working_text: String = "—" if part == null else str(working[digit])
		lines.append("| %s | %d / %d | %d | %s |" % [name, builds[digit], count, copies[digit], working_text])
	lines.append("")


static func _tuning(lines: PackedStringArray, mission: MissionData) -> void:
	var tuning: Dictionary = PlaytestRecord.tuning(mission)
	var mission_values: Dictionary = tuning["mission"]
	lines.append("## Tuning snapshot")
	lines.append("")
	lines.append("Mission: cargo_required %d, fuel_per_card %d." % [
		mission_values["cargo_required"], mission_values["fuel_per_card"]])
	lines.append("")
	lines.append("| Part | max_hp | fuel_capacity | shield_capacity |")
	lines.append("|---|---:|---:|---:|")
	var parts: Dictionary = tuning["parts"]
	for id: String in parts:
		var values: Dictionary = parts[id]
		lines.append("| %s | %d | %d | %d |" % [id, values["max_hp"], values["fuel_capacity"], values["shield_capacity"]])
	lines.append("")
	lines.append("| Card | hits | damage_per_hit | extra_fuel_loss | counter_threshold |")
	lines.append("|---|---:|---:|---:|---:|")
	var cards: Dictionary = tuning["cards"]
	for id: String in cards:
		var values: Dictionary = cards[id]
		lines.append("| %s | %d | %d | %d | %d |" % [
			id, values["hits"], values["damage_per_hit"], values["extra_fuel_loss"], values["counter_threshold"]])
	lines.append("")


static func _reason_id(reason: int) -> String:
	return PlaytestRecord.loss_reason_id(reason as RunResult.LossReason)
