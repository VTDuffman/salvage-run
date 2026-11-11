extends GutTest
## ShipBuild edits (CAP-1) and the rear-thruster launch gate (CAP-2), ported
## from story 3's headless checks.

const THRUSTER: PartData = preload("res://data/parts/thruster.tres")
const CARGO_HOLD: PartData = preload("res://data/parts/cargo_hold.tres")
const GUN: PartData = preload("res://data/parts/gun.tres")
const CARGO_RUN: MissionData = preload("res://data/missions/cargo_run.tres")


func test_new_build_is_empty() -> void:
	var build: ShipBuild = ShipBuild.new()
	assert_eq(build.cells().size(), 0)
	for row: int in ShipBuild.ROWS:
		for column: int in ShipBuild.COLUMNS:
			assert_null(build.get_part(Vector2i(column, row)))


func test_every_part_can_be_placed_in_every_cell() -> void:
	for part: PartData in CARGO_RUN.parts:
		for row: int in ShipBuild.ROWS:
			for column: int in ShipBuild.COLUMNS:
				var build: ShipBuild = ShipBuild.new()
				var cell: Vector2i = Vector2i(column, row)
				build.place(cell, part)
				assert_eq(build.get_part(cell), part)
				assert_eq(build.cells(), [cell] as Array[Vector2i])


func test_place_replaces_existing_part() -> void:
	var build: ShipBuild = ShipBuild.new()
	build.place(Vector2i(1, 1), GUN)
	build.place(Vector2i(1, 1), CARGO_HOLD)
	assert_eq(build.get_part(Vector2i(1, 1)), CARGO_HOLD)
	assert_eq(build.cells().size(), 1)


func test_move_to_empty_cell() -> void:
	var build: ShipBuild = ShipBuild.new()
	build.place(Vector2i(0, 0), GUN)
	build.move(Vector2i(0, 0), Vector2i(2, 1))
	assert_null(build.get_part(Vector2i(0, 0)))
	assert_eq(build.get_part(Vector2i(2, 1)), GUN)


func test_move_onto_occupied_cell_swaps() -> void:
	var build: ShipBuild = ShipBuild.new()
	build.place(Vector2i(0, 0), GUN)
	build.place(Vector2i(1, 2), THRUSTER)
	build.move(Vector2i(0, 0), Vector2i(1, 2))
	assert_eq(build.get_part(Vector2i(0, 0)), THRUSTER)
	assert_eq(build.get_part(Vector2i(1, 2)), GUN)


func test_move_onto_its_own_cell_changes_nothing() -> void:
	var build: ShipBuild = ShipBuild.new()
	build.place(Vector2i(1, 1), GUN)
	build.move(Vector2i(1, 1), Vector2i(1, 1))
	assert_eq(build.get_part(Vector2i(1, 1)), GUN)
	assert_eq(build.cells().size(), 1)


func test_remove_empties_cell() -> void:
	var build: ShipBuild = ShipBuild.new()
	build.place(Vector2i(2, 2), CARGO_HOLD)
	build.remove(Vector2i(2, 2))
	assert_null(build.get_part(Vector2i(2, 2)))
	assert_eq(build.cells().size(), 0)
	build.remove(Vector2i(2, 2))
	assert_eq(build.cells().size(), 0, "removing an empty cell is harmless")


func test_out_of_range_cells_are_ignored() -> void:
	var build: ShipBuild = ShipBuild.new()
	build.place(Vector2i(1, 1), GUN)
	for bad: Vector2i in [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(3, 0), Vector2i(0, 3), Vector2i(5, 5)]:
		assert_false(ShipBuild.is_valid_cell(bad))
		build.place(bad, CARGO_HOLD)
		assert_null(build.get_part(bad))
		build.move(Vector2i(1, 1), bad)
		build.move(bad, Vector2i(1, 1))
		build.remove(bad)
	assert_eq(build.get_part(Vector2i(1, 1)), GUN)
	assert_eq(build.cells(), [Vector2i(1, 1)] as Array[Vector2i])


func test_cells_are_front_row_first_left_to_right() -> void:
	var build: ShipBuild = ShipBuild.new()
	build.place(Vector2i(2, 2), GUN)
	build.place(Vector2i(0, 1), GUN)
	build.place(Vector2i(2, 0), GUN)
	build.place(Vector2i(0, 0), GUN)
	build.place(Vector2i(1, 1), GUN)
	var expected: Array[Vector2i] = [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 2)]
	assert_eq(build.cells(), expected)


func test_launch_refused_without_thruster() -> void:
	var build: ShipBuild = ShipBuild.new()
	build.place(Vector2i(1, 2), CARGO_HOLD)
	assert_false(build.has_rear_thruster())
	assert_eq(build.launch_refusal(), ShipBuild.REFUSAL_NO_REAR_THRUSTER)


func test_launch_refused_with_thrusters_only_in_rows_0_and_1() -> void:
	var build: ShipBuild = ShipBuild.new()
	for column: int in ShipBuild.COLUMNS:
		build.place(Vector2i(column, 0), THRUSTER)
		build.place(Vector2i(column, 1), THRUSTER)
	assert_false(build.has_rear_thruster())
	assert_eq(build.launch_refusal(), ShipBuild.REFUSAL_NO_REAR_THRUSTER)


func test_launch_allowed_with_thruster_in_rear_row() -> void:
	for column: int in ShipBuild.COLUMNS:
		var build: ShipBuild = ShipBuild.new()
		build.place(Vector2i(column, ShipBuild.REAR_ROW), THRUSTER)
		assert_true(build.has_rear_thruster())
		assert_eq(build.launch_refusal(), "")


func test_launch_refused_again_after_rear_thruster_removed() -> void:
	var build: ShipBuild = ShipBuild.new()
	build.place(Vector2i(0, 2), THRUSTER)
	build.move(Vector2i(0, 2), Vector2i(0, 1))
	assert_false(build.has_rear_thruster())
	build.move(Vector2i(0, 1), Vector2i(0, 2))
	assert_true(build.has_rear_thruster())
	build.remove(Vector2i(0, 2))
	assert_false(build.has_rear_thruster())
