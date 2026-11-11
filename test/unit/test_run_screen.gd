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
	screen.start(build, result, CARGO_RUN)
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

## Places the mission's required cargo holds in free cells, front row first.
## Fails the test if the grid has too few free cells.
func _place_required_holds(build: ShipBuild) -> void:
	var placed: int = 0
	for row: int in ShipBuild.ROWS:
		for column: int in ShipBuild.COLUMNS:
			if placed >= CARGO_RUN.cargo_required:
				return
			var cell: Vector2i = Vector2i(column, row)
			if build.get_part(cell) == null:
				build.place(cell, CARGO_HOLD)
				placed += 1
	if placed < CARGO_RUN.cargo_required:
		fail_test("only %d free cells for %d required cargo holds" % [placed, CARGO_RUN.cargo_required])


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
	_place_required_holds(build)
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
	_place_required_holds(build)
	await wait_process_frames(2)
	(screen.get_node("%LaunchButton") as Button).pressed.emit()
	assert_not_null(screen.call("get_run_screen"), "launch must be allowed for this test")
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


# --- Outcome panel (CAP-7) -----------------------------------------------------

func test_outcome_panel_appears_only_when_playback_finishes() -> void:
	var build: ShipBuild = _cruiser()
	var result: RunResult = _result_with_first_card_hit(build)
	var screen: RunScreen = _open_run_screen(build, result)
	var panel: Control = screen.get_node("%OutcomePanel") as Control
	screen._process(0.0)
	assert_false(panel.visible)
	for i: int in result.events.size() - 1:
		screen._process(SECONDS_PER_CARD)
		assert_false(panel.visible, "hidden while cards remain (card %d)" % (i + 1))
	screen._process(SECONDS_PER_CARD)
	assert_true(screen.get_playback().is_finished())
	assert_true(panel.visible)
	assert_true(screen.is_outcome_shown())
	assert_eq((screen.get_node("%OutcomeTitle") as Label).text, MissionReadout.outcome_title(result))
	assert_eq((screen.get_node("%OutcomeDetail") as Label).text, MissionReadout.outcome_detail(result, CARGO_RUN))


func test_outcome_panel_names_the_missed_requirement() -> void:
	var build: ShipBuild = _cruiser()
	build.remove(Vector2i(2, 0))
	var result: RunResult = RunResolver.resolve(build, CARGO_RUN, 1)
	var screen: RunScreen = _open_run_screen(build, result)
	screen._process(SECONDS_PER_CARD * result.events.size() + 0.1)
	assert_eq((screen.get_node("%OutcomeTitle") as Label).text, "RUN LOST")
	assert_eq((screen.get_node("%OutcomeDetail") as Label).text, "Cargo lost: had 1 hold, needed 2")


func test_outcome_buttons_emit_signals() -> void:
	var build: ShipBuild = _cruiser()
	var screen: RunScreen = _open_run_screen(build, RunResolver.resolve(build, CARGO_RUN, 1))
	watch_signals(screen)
	(screen.get_node("%RebuildButton") as Button).pressed.emit()
	assert_signal_emit_count(screen, "rebuild_requested", 1)
	assert_signal_emit_count(screen, "retry_requested", 0)
	(screen.get_node("%RetryButton") as Button).pressed.emit()
	assert_signal_emit_count(screen, "retry_requested", 1)


# --- Build screen mission panel, readout and return path -----------------------

func _open_build_screen() -> Control:
	var screen: Control = BUILD_SCREEN_SCENE.instantiate() as Control
	add_child_autofree(screen)
	return screen


func _ready_ship(build: ShipBuild) -> void:
	build.place(Vector2i(1, 2), THRUSTER)
	build.place(Vector2i(0, 1), FUEL_TANK)
	build.place(Vector2i(2, 1), FUEL_TANK)
	_place_required_holds(build)


func _launch(screen: Control) -> RunScreen:
	(screen.get_node("%LaunchButton") as Button).pressed.emit()
	return screen.call("get_run_screen") as RunScreen


## Plays the open run to its end, presses [param button_name], and waits a
## frame so the closed run screen is freed.
func _finish_and_press(run_screen: RunScreen, button_name: String) -> void:
	run_screen._process(SECONDS_PER_CARD * (CARGO_RUN.card_pool.size() + 1))
	assert_true(run_screen.is_outcome_shown())
	(run_screen.get_node("%" + button_name) as Button).pressed.emit()
	await wait_process_frames(1)


func _layout(build: ShipBuild) -> Array[PartData]:
	var parts: Array[PartData] = []
	for row: int in ShipBuild.ROWS:
		for column: int in ShipBuild.COLUMNS:
			parts.append(build.get_part(Vector2i(column, row)))
	return parts


func _assert_back_to_building(screen: Control, layout_before: Array[PartData]) -> void:
	var build: ShipBuild = screen.get("build") as ShipBuild
	var grid: GridView = screen.get_node("%GridView") as GridView
	assert_null(screen.call("get_run_screen"))
	assert_true((screen.get_node("%BuildMouseInput") as BuildMouseInput).enabled)
	for child: Node in screen.get_children():
		assert_false(child is RunScreen, "run screen removed")
	assert_eq(_layout(build), layout_before, "layout kept")
	for cell: Vector2i in build.cells():
		assert_string_contains(grid.get_cell_text(cell), build.get_part(cell).display_name)


func test_mission_panel_shows_mission_numbers() -> void:
	var screen: Control = _open_build_screen()
	assert_eq((screen.get_node("%MissionTitle") as Label).text, CARGO_RUN.display_name.to_upper())
	var text: String = (screen.get_node("%MissionLines") as Label).text
	for line: String in MissionReadout.panel_lines(CARGO_RUN):
		assert_string_contains(text, line)
	assert_string_contains(text, "CARGO HOLDS 2")
	assert_string_contains(text, "CARDS 8")
	assert_string_contains(text, "FUEL/CARD 1")


func test_readout_updates_on_build_changed() -> void:
	var screen: Control = _open_build_screen()
	var build: ShipBuild = screen.get("build") as ShipBuild
	var input: BuildMouseInput = screen.get_node("%BuildMouseInput") as BuildMouseInput
	var cargo: Label = screen.get_node("%CargoReadout") as Label
	var fuel: Label = screen.get_node("%FuelReadout") as Label
	var constants: Dictionary = (screen.get_script() as Script).get_script_constant_map()
	var short: Color = constants["SHORT_COLOR"]
	var warning: Color = constants["WARNING_COLOR"]
	var ok: Color = constants["OK_COLOR"]
	assert_ne(short, warning)
	assert_ne(short, ok)
	assert_ne(warning, ok)
	var fuel_cards: Label = screen.get_node("%FuelCardsReadout") as Label
	assert_eq(cargo.text, "Cargo 0/2")
	assert_eq(fuel.text, "Fuel 0 / 11 needed (11 short)", "empty build counters neither fuel card")
	assert_eq(cargo.get_theme_color("font_color"), short, "empty build: cargo short")
	assert_eq(fuel.get_theme_color("font_color"), short, "empty build: fuel short")
	assert_true(fuel_cards.visible)
	assert_eq(fuel_cards.text, "+2 Fuel Leak: counter with 2 Fuel Tanks (have 0)\n"
			+ "+1 Gravity Well: counter with 2 Thrusters in rear row (have 0)")
	assert_eq(fuel_cards.get_theme_color("font_color"), warning, "uncountered fuel cards are a warning")

	build.place(Vector2i(0, 0), CARGO_HOLD)
	build.place(Vector2i(0, 1), FUEL_TANK)
	build.place(Vector2i(2, 1), FUEL_TANK)
	input.build_changed.emit()
	assert_eq(cargo.text, "Cargo 1/2")
	assert_eq(fuel.text, "Fuel 8 / 9 needed (1 short)", "Gravity Well still uncountered")
	assert_eq(cargo.get_theme_color("font_color"), short, "short cargo shows in the short color")
	assert_eq(fuel.get_theme_color("font_color"), short, "8 fuel is short of 9")
	assert_eq(fuel_cards.text, "+1 Gravity Well: counter with 2 Thrusters in rear row (have 0)")

	build.place(Vector2i(0, 2), THRUSTER)
	build.place(Vector2i(1, 2), THRUSTER)
	input.build_changed.emit()
	assert_eq(fuel.text, "Fuel 8 / 8 needed (0 spare)")
	assert_eq(fuel.get_theme_color("font_color"), warning, "no spare fuel shows in the warning color")
	assert_false(fuel_cards.visible, "no uncountered fuel cards: line hidden")

	build.place(Vector2i(1, 1), FUEL_TANK)
	input.build_changed.emit()
	assert_eq(fuel.text, "Fuel 12 / 8 needed (4 spare)")
	assert_eq(fuel.get_theme_color("font_color"), ok, "spare fuel shows in the ok color")
	build.remove(Vector2i(1, 1))
	input.build_changed.emit()
	assert_eq(fuel.text, "Fuel 8 / 8 needed (0 spare)")
	assert_eq(fuel.get_theme_color("font_color"), warning, "back to no spare: warning again")

	build.place(Vector2i(1, 0), CARGO_HOLD)
	build.move(Vector2i(2, 1), Vector2i(2, 0))
	input.build_changed.emit()
	assert_eq(cargo.text, "Cargo 2/2")
	assert_eq(fuel.text, "Fuel 8 / 8 needed (0 spare)", "a tank works in any row")
	assert_eq(cargo.get_theme_color("font_color"), ok)

	build.remove(Vector2i(2, 0))
	input.build_changed.emit()
	assert_eq(fuel.text, "Fuel 4 / 10 needed (6 short)", "one tank no longer counters Fuel Leak")
	assert_eq(fuel.get_theme_color("font_color"), short)
	assert_true(fuel_cards.visible)
	assert_eq(fuel_cards.text, "+2 Fuel Leak: counter with 2 Fuel Tanks (have 1)")


func test_launch_refused_when_cargo_short() -> void:
	var screen: Control = _open_build_screen()
	var build: ShipBuild = screen.get("build") as ShipBuild
	build.place(Vector2i(1, 2), THRUSTER)
	build.place(Vector2i(0, 0), CARGO_HOLD)
	assert_null(_launch(screen))
	assert_eq((screen.get_node("%StatusLabel") as Label).text, "Launch refused: 1 cargo hold, mission needs 2.")
	assert_true((screen.get_node("%BuildMouseInput") as BuildMouseInput).enabled)


func test_retry_same_seed_replays_card_order_with_current_build() -> void:
	var screen: Control = _open_build_screen()
	var build: ShipBuild = screen.get("build") as ShipBuild
	_ready_ship(build)
	var first: RunScreen = _launch(screen)
	var first_seed: int = screen.get("run_seed")
	assert_eq(first.get_result().seed, first_seed)
	var first_order: Array[CardData] = first.get_result().card_order
	var layout_before: Array[PartData] = _layout(build)

	await _finish_and_press(first, "RetryButton")
	_assert_back_to_building(screen, layout_before)
	assert_true(screen.call("is_retrying_seed"))
	assert_string_contains((screen.get_node("%StatusLabel") as Label).text, str(first_seed))

	build.place(Vector2i(2, 0), HULL_PLATING)
	(screen.get_node("%BuildMouseInput") as BuildMouseInput).build_changed.emit()
	var second: RunScreen = _launch(screen)
	assert_not_null(second, "relaunch allowed")
	assert_eq(screen.get("run_seed"), first_seed)
	assert_eq(second.get_result().seed, first_seed)
	assert_eq(second.get_result().card_order, first_order, "same card order")
	assert_eq(second.get_playback().get_part(Vector2i(2, 0)), HULL_PLATING, "edits are launched")
	assert_false(screen.call("is_retrying_seed"))


func test_refused_launch_after_retry_keeps_the_seed() -> void:
	var screen: Control = _open_build_screen()
	var build: ShipBuild = screen.get("build") as ShipBuild
	var input: BuildMouseInput = screen.get_node("%BuildMouseInput") as BuildMouseInput
	var status: Label = screen.get_node("%StatusLabel") as Label
	_ready_ship(build)
	var first: RunScreen = _launch(screen)
	var first_seed: int = screen.get("run_seed")
	var first_order: Array[CardData] = first.get_result().card_order
	await _finish_and_press(first, "RetryButton")
	var retry_text: String = (screen.get_script() as Script).get_script_constant_map()["RETRY_TEXT"]

	var hold_cell: Vector2i = build.cells().filter(
			func(cell: Vector2i) -> bool: return build.get_part(cell) == CARGO_HOLD)[0]
	build.remove(hold_cell)
	input.build_changed.emit()
	assert_eq(status.text, retry_text % first_seed, "retry text survives a build edit")

	assert_null(_launch(screen), "cargo short: launch refused")
	assert_string_starts_with(status.text, "Launch refused:")
	assert_true(screen.call("is_retrying_seed"), "a refused launch does not use up the retry")

	build.place(hold_cell, CARGO_HOLD)
	input.build_changed.emit()
	var second: RunScreen = _launch(screen)
	assert_not_null(second)
	assert_eq(screen.get("run_seed"), first_seed)
	assert_eq(second.get_result().seed, first_seed)
	assert_eq(second.get_result().card_order, first_order)


func test_rebuild_draws_a_new_seed() -> void:
	var screen: Control = _open_build_screen()
	var build: ShipBuild = screen.get("build") as ShipBuild
	_ready_ship(build)
	var first: RunScreen = _launch(screen)
	var first_seed: int = screen.get("run_seed")
	var layout_before: Array[PartData] = _layout(build)

	await _finish_and_press(first, "RebuildButton")
	_assert_back_to_building(screen, layout_before)
	assert_false(screen.call("is_retrying_seed"))
	assert_eq((screen.get_node("%StatusLabel") as Label).text, "Drag parts onto the grid. Drag off or right-click to remove.")

	var second: RunScreen = _launch(screen)
	assert_not_null(second, "relaunch allowed")
	assert_ne(screen.get("run_seed"), first_seed, "new seed after Rebuild")
	assert_eq(second.get_result().seed, screen.get("run_seed"))


func test_retry_then_rebuild_draws_a_new_seed() -> void:
	var screen: Control = _open_build_screen()
	_ready_ship(screen.get("build") as ShipBuild)
	var run: RunScreen = _launch(screen)
	var first_seed: int = screen.get("run_seed")
	await _finish_and_press(run, "RetryButton")
	run = _launch(screen)
	assert_eq(screen.get("run_seed"), first_seed)
	await _finish_and_press(run, "RebuildButton")
	run = _launch(screen)
	assert_ne(screen.get("run_seed"), first_seed)
	assert_eq(run.get_result().seed, screen.get("run_seed"))
