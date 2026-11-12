extends GutTest
## RunPlayback and PlaybackClock (CAP-6): log lines for every playback case,
## per-cell HP / destroyed state and fuel after each step of real resolved
## runs, flashes, and clock pause / speed / large-delta timing.

const Fixtures = preload("res://test/support/fixtures.gd")

const NO_CELL: Vector2i = RunResult.NO_CELL
const SEED_SEARCH: int = 300

var _fx: Fixtures = Fixtures.new()


# --- Helpers -----------------------------------------------------------------

func _build(layout: Dictionary[Vector2i, PartData]) -> ShipBuild:
	var build: ShipBuild = ShipBuild.new()
	for cell: Vector2i in layout:
		build.place(cell, layout[cell])
	return build


## A typical full ship: cargo up front, a shield in the middle, two tanks and
## two rear thrusters. It loses parts on many seeds.
func _cruiser() -> ShipBuild:
	return _build({
		Vector2i(0, 0): _fx.cargo_hold, Vector2i(1, 0): _fx.hull_plating, Vector2i(2, 0): _fx.cargo_hold,
		Vector2i(0, 1): _fx.fuel_tank, Vector2i(1, 1): _fx.shield, Vector2i(2, 1): _fx.fuel_tank,
		Vector2i(0, 2): _fx.hull_plating, Vector2i(1, 2): _fx.thruster, Vector2i(2, 2): _fx.thruster,
	})


func _event(card: CardData, countered: bool = false) -> RunResult.CardEvent:
	var event: RunResult.CardEvent = RunResult.CardEvent.new()
	event.card = card
	event.countered = countered
	return event


func _hit(cell: Vector2i, absorbed: int, damage: int, hp_after: int, destroyed: bool = false) -> RunResult.HitEvent:
	var hit: RunResult.HitEvent = RunResult.HitEvent.new()
	hit.struck_cell = cell
	hit.absorbed = absorbed
	hit.damage_to_part = damage
	hit.part_hp_after = hp_after
	hit.destroyed = destroyed
	return hit


func _result(events: Array[RunResult.CardEvent], won: bool, loss: RunResult.LossReason) -> RunResult:
	var result: RunResult = RunResult.new()
	for event: RunResult.CardEvent in events:
		result.card_order.append(event.card)
	result.events = events
	result.won = won
	result.loss_reason = loss
	return result


## The first seed whose run on [param build] satisfies [param wanted].
func _find_seed(build: ShipBuild, wanted: Callable) -> int:
	for run_seed: int in SEED_SEARCH:
		if wanted.call(RunResolver.resolve(build, _fx.cargo_run, run_seed)):
			return run_seed
	fail_test("no seed found for the wanted run")
	return 0


static func _destroys_a_part(result: RunResult) -> bool:
	for event: RunResult.CardEvent in result.events:
		if not event.destroyed_cells.is_empty():
			return true
	return false


# --- Log lines (matrix rows) -------------------------------------------------

func test_countered_card_line() -> void:
	var line: String = RunPlayback.card_line(_event(_fx.pirate_ambush, true), ShipBuild.new())
	assert_eq(line, "Pirate Ambush — your gun drove them off")


func test_uncountered_card_line() -> void:
	var event: RunResult.CardEvent = _event(_fx.pirate_ambush)
	event.hits.append(_hit(Vector2i(1, 0), 0, 1, 3))
	var build: ShipBuild = _build({Vector2i(1, 0): _fx.hull_plating})
	assert_eq(RunPlayback.card_line(event, build), "Pirate Ambush — pirates raked the front")


func test_calm_space_uses_uncountered_text() -> void:
	assert_eq(RunPlayback.card_line(_event(_fx.calm_space), ShipBuild.new()),
			"Calm Space — " + _fx.calm_space.uncountered_text)


func test_total_miss_line() -> void:
	var event: RunResult.CardEvent = _event(_fx.pirate_ambush)
	for lane: int in 3:
		var miss: RunResult.HitEvent = RunResult.HitEvent.new()
		miss.lane = lane
		event.hits.append(miss)
	assert_eq(RunPlayback.card_line(event, ShipBuild.new()), "Pirate Ambush — it missed the ship")


func test_partial_miss_is_not_a_total_miss() -> void:
	var event: RunResult.CardEvent = _event(_fx.pirate_ambush)
	event.hits.append(RunResult.HitEvent.new())
	event.hits.append(_hit(Vector2i(1, 0), 0, 1, 3))
	var build: ShipBuild = _build({Vector2i(1, 0): _fx.hull_plating})
	assert_eq(RunPlayback.card_line(event, build), "Pirate Ambush — pirates raked the front")


func test_destroyed_parts_are_named_at_line_end() -> void:
	var build: ShipBuild = _build({Vector2i(0, 1): _fx.cargo_hold, Vector2i(2, 1): _fx.shield})
	var event: RunResult.CardEvent = _event(_fx.debris_strike)
	event.hits.append(_hit(Vector2i(0, 1), 0, 2, 0, true))
	event.destroyed_cells.append(Vector2i(0, 1))
	assert_eq(RunPlayback.card_line(event, build), "Debris Strike — debris hit a flank (Cargo Hold destroyed)")
	event.destroyed_cells.append(Vector2i(2, 1))
	assert_string_ends_with(RunPlayback.card_line(event, build), "(Cargo Hold, Shield destroyed)")


func test_losing_card_is_followed_by_loss_line_and_playback_stops() -> void:
	var first: RunResult.CardEvent = _event(_fx.calm_space)
	var losing: RunResult.CardEvent = _event(_fx.pirate_ambush)
	losing.loss_reason = RunResult.LossReason.OUT_OF_FUEL
	losing.fuel_after = -1
	var events: Array[RunResult.CardEvent] = [first, losing]
	var result: RunResult = _result(events, false, RunResult.LossReason.OUT_OF_FUEL)
	result.card_order.append(_fx.debris_strike) # never reached
	var playback: RunPlayback = RunPlayback.new(ShipBuild.new(), result)

	assert_eq(playback.step().size(), 1)
	assert_false(playback.is_finished())
	var last: Array[String] = playback.step()
	assert_eq(last.size(), 2)
	assert_eq(last[1], "Run lost: out of fuel")
	assert_true(playback.is_finished())
	assert_eq(playback.step().size(), 0, "no line after the loss")
	assert_eq(playback.card_index(), 2)
	assert_eq(playback.card_count(), 3)
	assert_eq(playback.log_lines(), RunPlayback.all_lines(ShipBuild.new(), result))


func test_every_loss_reason_has_text() -> void:
	for reason: RunResult.LossReason in [RunResult.LossReason.NO_THRUSTER,
			RunResult.LossReason.OUT_OF_FUEL, RunResult.LossReason.CARGO_LOST]:
		assert_ne(RunPlayback.loss_reason_text(reason), "")


func test_won_run_ends_with_win_line() -> void:
	var events: Array[RunResult.CardEvent] = [_event(_fx.calm_space)]
	var result: RunResult = _result(events, true, RunResult.LossReason.NONE)
	var playback: RunPlayback = RunPlayback.new(ShipBuild.new(), result)
	var lines: Array[String] = playback.step()
	assert_eq(lines, ["Calm Space — " + _fx.calm_space.uncountered_text, "Run won: cargo delivered"] as Array[String])
	assert_true(playback.is_finished())


func test_real_run_log_has_one_line_per_card_plus_outcome() -> void:
	var build: ShipBuild = _cruiser()
	for run_seed: int in 20:
		var result: RunResult = RunResolver.resolve(build, _fx.cargo_run, run_seed)
		var playback: RunPlayback = RunPlayback.new(build, result)
		while not playback.is_finished():
			playback.step()
		var lines: Array[String] = playback.log_lines()
		assert_eq(lines.size(), result.events.size() + 1)
		for i: int in result.events.size():
			assert_string_starts_with(lines[i], result.events[i].card.display_name + " — ")
		var outcome: String = lines[lines.size() - 1]
		assert_true(outcome == "Run won: cargo delivered" or outcome.begins_with("Run lost: "), outcome)


# --- Display state against real runs -----------------------------------------

func test_hp_destroyed_and_fuel_follow_each_event() -> void:
	var build: ShipBuild = _cruiser()
	var run_seed: int = _find_seed(build, _destroys_a_part)
	var result: RunResult = RunResolver.resolve(build, _fx.cargo_run, run_seed)
	var playback: RunPlayback = RunPlayback.new(build, result)

	assert_eq(playback.fuel(), result.starting_fuel)
	assert_eq(playback.card_index(), 0)
	var expected_hp: Dictionary[Vector2i, int] = {}
	for cell: Vector2i in build.cells():
		expected_hp[cell] = build.get_part(cell).max_hp
		assert_eq(playback.hp(cell), expected_hp[cell])
		assert_false(playback.is_destroyed(cell))

	var destroyed: Dictionary[Vector2i, bool] = {}
	var saw_destruction: bool = false
	for index: int in result.events.size():
		var event: RunResult.CardEvent = result.events[index]
		playback.step()
		assert_eq(playback.card_index(), index + 1)
		assert_eq(playback.fuel(), event.fuel_after)
		for hit: RunResult.HitEvent in event.hits:
			if not hit.is_miss():
				expected_hp[hit.struck_cell] = hit.part_hp_after
		for cell: Vector2i in event.destroyed_cells:
			destroyed[cell] = true
			saw_destruction = true
		for cell: Vector2i in build.cells():
			assert_eq(playback.hp(cell), expected_hp[cell], "HP of %s after card %d" % [cell, index + 1])
			assert_eq(playback.is_destroyed(cell), destroyed.has(cell), "destroyed %s after card %d" % [cell, index + 1])
	assert_true(saw_destruction)


func test_flash_marks_damage_and_shield_absorption() -> void:
	var build: ShipBuild = _build({Vector2i(0, 0): _fx.hull_plating, Vector2i(1, 0): _fx.shield, Vector2i(2, 0): _fx.cargo_hold})
	var event: RunResult.CardEvent = _event(_fx.pirate_ambush)
	event.hits.append(_hit(Vector2i(0, 0), 1, 0, 4))
	event.hits.append(_hit(Vector2i(1, 0), 1, 0, 2))
	event.hits.append(_hit(Vector2i(2, 0), 0, 1, 1))
	var events: Array[RunResult.CardEvent] = [event, _event(_fx.calm_space)]
	var playback: RunPlayback = RunPlayback.new(build, _result(events, true, RunResult.LossReason.NONE))

	assert_eq(playback.flash_at(Vector2i(2, 0)), RunPlayback.Flash.NONE)
	playback.step()
	assert_eq(playback.flash_at(Vector2i(0, 0)), RunPlayback.Flash.SHIELD)
	assert_eq(playback.flash_at(Vector2i(1, 0)), RunPlayback.Flash.SHIELD)
	assert_eq(playback.flash_at(Vector2i(2, 0)), RunPlayback.Flash.DAMAGE)
	assert_eq(playback.hp(Vector2i(2, 0)), 1)
	playback.step()
	assert_eq(playback.flash_at(Vector2i(2, 0)), RunPlayback.Flash.NONE, "next card clears the flash")


func test_playback_ignores_build_edits_after_launch() -> void:
	var build: ShipBuild = _cruiser()
	var result: RunResult = RunResolver.resolve(build, _fx.cargo_run, 1)
	var playback: RunPlayback = RunPlayback.new(build, result)
	build.remove(Vector2i(0, 0))
	assert_eq(playback.get_part(Vector2i(0, 0)), _fx.cargo_hold)


# --- Clock ---------------------------------------------------------------------

func test_clock_normal_speed_one_card_per_interval() -> void:
	var clock: PlaybackClock = PlaybackClock.new()
	assert_eq(clock.seconds_per_card, 1.5)
	assert_eq(clock.advance(1.0), 0)
	assert_almost_eq(clock.progress(), 1.0 / 1.5, 0.0001)
	assert_eq(clock.advance(0.5), 1)
	assert_almost_eq(clock.progress(), 0.0, 0.0001)
	assert_almost_eq(clock.flash_strength(), 1.0, 0.0001)


func test_clock_pause_freezes_cards_and_flash() -> void:
	var clock: PlaybackClock = PlaybackClock.new()
	clock.advance(0.3)
	var progress_before: float = clock.progress()
	var flash_before: float = clock.flash_strength()
	clock.pause()
	assert_eq(clock.advance(100.0), 0)
	assert_eq(clock.progress(), progress_before)
	assert_eq(clock.flash_strength(), flash_before)
	clock.play()
	assert_eq(clock.advance(1.2), 1, "play resumes from the same point in the card")


func test_clock_fast_forward_is_four_times_faster_until_play_or_pause() -> void:
	var clock: PlaybackClock = PlaybackClock.new()
	clock.fast_forward()
	assert_eq(clock.speed, PlaybackClock.Speed.FAST)
	assert_eq(clock.advance(1.5), 4)
	clock.pause()
	assert_eq(clock.advance(1.5), 0)
	clock.fast_forward()
	assert_eq(clock.advance(0.375), 1)
	clock.play()
	assert_eq(clock.speed, PlaybackClock.Speed.NORMAL)
	assert_eq(clock.advance(0.375), 0)
	assert_eq(clock.advance(1.125), 1)


func test_large_delta_applies_each_due_card_in_order() -> void:
	var build: ShipBuild = _cruiser()
	var result: RunResult = RunResolver.resolve(build, _fx.cargo_run, _find_seed(build,
			func(r: RunResult) -> bool: return r.events.size() >= 4))
	var playback: RunPlayback = RunPlayback.new(build, result)
	var clock: PlaybackClock = PlaybackClock.new()
	var due: int = clock.advance(3.0 * clock.seconds_per_card + 0.1)
	assert_eq(due, 3)
	for i: int in due:
		playback.step()
	assert_eq(playback.card_index(), 3)
	var expected: Array[String] = RunPlayback.all_lines(build, result).slice(0, 3)
	assert_eq(playback.log_lines(), expected)
	assert_eq(playback.fuel(), result.events[2].fuel_after)
