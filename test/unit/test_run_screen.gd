extends GutTest
## Run screen and launch flow (CAP-6, CAP-2): the run screen plays a resolved
## result headlessly, each card adds a log line and changes the struck cell,
## each control changes the clock mid-run, and the build screen opens the run
## screen only for an allowed launch.

const RUN_SCREEN_SCENE: PackedScene = preload("res://scenes/run/run_screen.tscn")
const BUILD_SCREEN_SCENE: PackedScene = preload("res://scenes/build/build_screen.tscn")
const CARGO_RUN: MissionData = preload("res://data/missions/cargo_run.tres")
const THRUSTER: PartData = preload("res://data/parts/thruster.tres")
const FUEL_TANK: PartData = preload("res://data/parts/fuel_tank.tres")
const CARGO_HOLD: PartData = preload("res://data/parts/cargo_hold.tres")
const SHIELD: PartData = preload("res://data/parts/shield.tres")
const HULL_PLATING: PartData = preload("res://data/parts/hull_plating.tres")

const SECONDS_PER_CARD: float = PlaybackClock.DEFAULT_SECONDS_PER_CARD


func _cruiser() -> ShipBuild:
	var build: ShipBuild = ShipBuild.new()
	build.place(Vector2i(0, 0), CARGO_HOLD)
	build.place(Vector2i(1, 0), HULL_PLATING)
	build.place(Vector2i(2, 0), CARGO_HOLD)
	build.place(Vector2i(0, 1), FUEL_TANK)
	build.place(Vector2i(1, 1), SHIELD)
	build.place(Vector2i(2, 1), FUEL_TANK)
	build.place(Vector2i(0, 2), HULL_PLATING)
	build.place(Vector2i(1, 2), THRUSTER)
	build.place(Vector2i(2, 2), THRUSTER)
	return build


## A run whose first card strikes a part without destroying it, so the grid
## must visibly change and still show the part's HP.
func _result_with_first_card_hit(build: ShipBuild) -> RunResult:
	for run_seed: int in 300:
		var result: RunResult = RunResolver.resolve(build, CARGO_RUN, run_seed)
		if result.events.size() < 3:
			continue
		var cell: Vector2i = _first_struck_cell(result)
		if cell != RunResult.NO_CELL and not result.events[0].destroyed_cells.has(cell):
			return result
	fail_test("no seed whose first card strikes a part without destroying it")
	return null


## HP of [param cell] after the first card: its last hit's part_hp_after.
func _hp_after_first_card(result: RunResult, cell: Vector2i) -> int:
	var hp: int = -1
	for hit: RunResult.HitEvent in result.events[0].hits:
		if hit.struck_cell == cell:
			hp = hit.part_hp_after
	return hp


func _first_struck_cell(result: RunResult) -> Vector2i:
	for hit: RunResult.HitEvent in result.events[0].hits:
		if not hit.is_miss():
			return hit.struck_cell
	return RunResult.NO_CELL


func _open_run_screen(build: ShipBuild, result: RunResult) -> RunScreen:
	var screen: RunScreen = RUN_SCREEN_SCENE.instantiate() as RunScreen
	add_child_autofree(screen)
	screen.start(build, result)
	return screen


func _line_count(text: String) -> int:
	return 0 if text.is_empty() else text.split("\n").size()


# --- Run screen ----------------------------------------------------------------

func test_stepping_adds_log_line_and_changes_struck_cell() -> void:
	var build: ShipBuild = _cruiser()
	var result: RunResult = _result_with_first_card_hit(build)
	var screen: RunScreen = _open_run_screen(build, result)
	var cell: Vector2i = _first_struck_cell(result)
	var card_label: Label = screen.get_node("%CardLabel") as Label
	var fuel_label: Label = screen.get_node("%FuelLabel") as Label

	screen._process(0.0)
	assert_eq(_line_count(screen.get_log_text()), 0)
	assert_eq(card_label.text, "CARD 0/8")
	assert_eq(fuel_label.text, "FUEL %d" % result.starting_fuel)
	var text_before: String = screen.get_grid().get_cell_text(cell)
	var color_before: Color = screen.get_grid().get_cell_color(cell)
	assert_string_contains(text_before, build.get_part(cell).display_name)

	screen._process(SECONDS_PER_CARD)
	assert_eq(_line_count(screen.get_log_text()), 1)
	assert_string_starts_with(screen.get_log_text(), result.events[0].card.display_name + " — ")
	assert_eq(card_label.text, "CARD 1/8")
	assert_eq(fuel_label.text, "FUEL %d" % result.events[0].fuel_after)
	var changed: bool = screen.get_grid().get_cell_text(cell) != text_before \
			or screen.get_grid().get_cell_color(cell) != color_before
	assert_true(changed, "struck cell %s should change text or color" % cell)
	var part: PartData = build.get_part(cell)
	assert_string_contains(screen.get_grid().get_cell_text(cell),
			"%d/%d HP" % [_hp_after_first_card(result, cell), part.max_hp])


func test_flash_fades_within_the_card() -> void:
	var build: ShipBuild = _cruiser()
	var result: RunResult = _result_with_first_card_hit(build)
	var screen: RunScreen = _open_run_screen(build, result)
	var cell: Vector2i = _first_struck_cell(result)
	screen._process(SECONDS_PER_CARD)
	var flashing: Color = screen.get_grid().get_cell_color(cell)
	screen._process(SECONDS_PER_CARD * 0.9)
	assert_ne(screen.get_grid().get_cell_color(cell), flashing, "flash should fade before the next card")


func test_destroyed_cell_shows_x_and_hp_drops() -> void:
	var build: ShipBuild = _cruiser()
	var result: RunResult = null
	for run_seed: int in 300:
		var candidate: RunResult = RunResolver.resolve(build, CARGO_RUN, run_seed)
		for event: RunResult.CardEvent in candidate.events:
			if not event.destroyed_cells.is_empty():
				result = candidate
				break
		if result != null:
			break
	assert_not_null(result, "no seed destroys a part")
	if result == null:
		return
	var screen: RunScreen = _open_run_screen(build, result)
	screen._process(SECONDS_PER_CARD * result.events.size() + 0.1)
	assert_true(screen.get_playback().is_finished())
	for event: RunResult.CardEvent in result.events:
		for cell: Vector2i in event.destroyed_cells:
			assert_eq(screen.get_grid().get_cell_text(cell), build.get_part(cell).display_name + "\nX")
	var lines: PackedStringArray = screen.get_log_text().split("\n")
	assert_eq(lines.size(), result.events.size() + 1, "one line per card plus the outcome")


func test_each_button_changes_clock_mid_run() -> void:
	var build: ShipBuild = _cruiser()
	var result: RunResult = _result_with_first_card_hit(build)
	var screen: RunScreen = _open_run_screen(build, result)
	var clock: PlaybackClock = screen.get_clock()
	screen._process(SECONDS_PER_CARD)
	assert_eq(screen.get_playback().card_index(), 1)

	(screen.get_node("%PauseButton") as Button).pressed.emit()
	assert_true(clock.paused)
	screen._process(SECONDS_PER_CARD * 5.0)
	assert_eq(screen.get_playback().card_index(), 1, "paused: no new card")

	(screen.get_node("%FastButton") as Button).pressed.emit()
	assert_false(clock.paused)
	assert_eq(clock.speed, PlaybackClock.Speed.FAST)
	assert_true((screen.get_node("%FastButton") as Button).button_pressed)
	screen._process(SECONDS_PER_CARD / PlaybackClock.FAST_MULTIPLIER)
	assert_eq(screen.get_playback().card_index(), 2)

	(screen.get_node("%PlayButton") as Button).pressed.emit()
	assert_false(clock.paused)
	assert_eq(clock.speed, PlaybackClock.Speed.NORMAL)
	assert_true((screen.get_node("%PlayButton") as Button).button_pressed)
	assert_false((screen.get_node("%FastButton") as Button).button_pressed)
	screen._process(SECONDS_PER_CARD / PlaybackClock.FAST_MULTIPLIER)
	assert_eq(screen.get_playback().card_index(), 2, "normal speed again")


func test_grid_shows_damage_shield_and_destroyed_colors() -> void:
	var build: ShipBuild = ShipBuild.new()
	build.place(Vector2i(0, 0), HULL_PLATING)
	build.place(Vector2i(1, 0), SHIELD)
	build.place(Vector2i(2, 0), CARGO_HOLD)
	var event: RunResult.CardEvent = RunResult.CardEvent.new()
	event.card = CARGO_RUN.card_pool[0]
	event.hits.append(_hit(Vector2i(0, 0), 0, 1, 3, false))
	event.hits.append(_hit(Vector2i(1, 0), 1, 0, 2, false))
	event.hits.append(_hit(Vector2i(2, 0), 0, 2, 0, true))
	event.destroyed_cells.append(Vector2i(2, 0))
	var result: RunResult = RunResult.new()
	result.card_order.append(event.card)
	result.events.append(event)
	result.won = true
	var playback: RunPlayback = RunPlayback.new(build, result)
	playback.step()
	var grid: GridView = GridView.new()
	add_child_autofree(grid)

	grid.show_playback(playback, 1.0)
	assert_true(grid.get_cell_color(Vector2i(0, 0)).is_equal_approx(grid.damage_flash_color), "damage flashes red")
	assert_true(grid.get_cell_color(Vector2i(1, 0)).is_equal_approx(grid.shield_flash_color), "shield-only hit flashes blue")
	grid.show_playback(playback, 0.0)
	assert_eq(grid.get_cell_color(Vector2i(2, 0)), grid.destroyed_color)
	assert_eq(grid.get_cell_text(Vector2i(2, 0)), CARGO_HOLD.display_name + "\nX")


func test_fuel_counter_never_shows_negative() -> void:
	var event: RunResult.CardEvent = RunResult.CardEvent.new()
	event.card = CARGO_RUN.card_pool[0]
	event.fuel_after = -1
	event.loss_reason = RunResult.LossReason.OUT_OF_FUEL
	var result: RunResult = RunResult.new()
	result.card_order.append(event.card)
	result.events.append(event)
	result.loss_reason = RunResult.LossReason.OUT_OF_FUEL
	var screen: RunScreen = _open_run_screen(_cruiser(), result)
	screen._process(SECONDS_PER_CARD)
	assert_eq((screen.get_node("%FuelLabel") as Label).text, "FUEL 0")


func _hit(cell: Vector2i, absorbed: int, damage: int, hp_after: int, destroyed: bool) -> RunResult.HitEvent:
	var hit: RunResult.HitEvent = RunResult.HitEvent.new()
	hit.struck_cell = cell
	hit.absorbed = absorbed
	hit.damage_to_part = damage
	hit.part_hp_after = hp_after
	hit.destroyed = destroyed
	return hit


# --- Launch flow ---------------------------------------------------------------

func test_refused_launch_opens_no_run_screen() -> void:
	var screen: Control = BUILD_SCREEN_SCENE.instantiate() as Control
	add_child_autofree(screen)
	(screen.get_node("%LaunchButton") as Button).pressed.emit()
	assert_null(screen.call("get_run_screen"))
	assert_eq((screen.get_node("%StatusLabel") as Label).text, ShipBuild.REFUSAL_NO_REAR_THRUSTER)
	assert_true((screen.get_node("%BuildMouseInput") as BuildMouseInput).enabled)


func test_allowed_launch_opens_run_screen_and_disables_build_input() -> void:
	var screen: Control = BUILD_SCREEN_SCENE.instantiate() as Control
	add_child_autofree(screen)
	var build: ShipBuild = screen.get("build") as ShipBuild
	build.place(Vector2i(1, 2), THRUSTER)
	build.place(Vector2i(0, 1), FUEL_TANK)
	build.place(Vector2i(2, 1), FUEL_TANK)
	(screen.get_node("%LaunchButton") as Button).pressed.emit()

	var run_screen: RunScreen = screen.call("get_run_screen") as RunScreen
	assert_not_null(run_screen)
	assert_eq(run_screen.get_parent(), screen)
	assert_false((screen.get_node("%BuildMouseInput") as BuildMouseInput).enabled)
	assert_eq(run_screen.get_playback().card_count(), CARGO_RUN.card_pool.size())

	(screen.get_node("%LaunchButton") as Button).pressed.emit()
	assert_eq(screen.call("get_run_screen"), run_screen, "a second press opens nothing new")
	var run_screens: int = 0
	for child: Node in screen.get_children():
		if child is RunScreen:
			run_screens += 1
	assert_eq(run_screens, 1)


func _mouse_button(button_index: MouseButton, pressed: bool, pos: Vector2) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	event.position = pos
	event.global_position = pos
	return event


func _cell_center(screen: Control, cell: Vector2i) -> Vector2:
	var grid: GridView = screen.get_node("%GridView") as GridView
	return grid.get_cell(cell.x, cell.y).get_global_rect().get_center()


func test_right_click_after_launch_does_not_remove_part() -> void:
	var screen: Control = BUILD_SCREEN_SCENE.instantiate() as Control
	add_child_autofree(screen)
	var build: ShipBuild = screen.get("build") as ShipBuild
	var cell: Vector2i = Vector2i(1, 2)
	build.place(cell, THRUSTER)
	await wait_process_frames(2)
	(screen.get_node("%LaunchButton") as Button).pressed.emit()
	var input: BuildMouseInput = screen.get_node("%BuildMouseInput") as BuildMouseInput

	input._input(_mouse_button(MOUSE_BUTTON_RIGHT, true, _cell_center(screen, cell)))
	assert_eq(build.get_part(cell), THRUSTER, "build must not change under the run screen")


func test_disabling_input_cancels_drag() -> void:
	var screen: Control = BUILD_SCREEN_SCENE.instantiate() as Control
	add_child_autofree(screen)
	var build: ShipBuild = screen.get("build") as ShipBuild
	var cell: Vector2i = Vector2i(1, 2)
	build.place(cell, THRUSTER)
	await wait_process_frames(2)
	var input: BuildMouseInput = screen.get_node("%BuildMouseInput") as BuildMouseInput

	input._input(_mouse_button(MOUSE_BUTTON_LEFT, true, _cell_center(screen, cell)))
	assert_true(input.is_dragging(), "left press on a part starts a drag")
	input.enabled = false
	assert_false(input.is_dragging())
	assert_eq(build.get_part(cell), THRUSTER)
