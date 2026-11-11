class_name ShipBuild
extends RefCounted
## The player's ship layout on the Cruiser's 3x3 grid: which part sits in
## which cell. Plain logic with no Node or scene dependencies; the build
## screen edits it and the run resolver receives it.
## Row 0 is the front, row 2 is the rear. Out-of-range cells are ignored.

const COLUMNS: int = 3
const ROWS: int = 3
const REAR_ROW: int = 2

const REFUSAL_NO_REAR_THRUSTER: String = "Launch refused: no thruster in the rear row."
## Filled with: cargo holds on the ship, "s" or "", holds the mission needs.
const REFUSAL_CARGO_SHORT: String = "Launch refused: %d cargo hold%s, mission needs %d."

## One entry per cell, indexed row * COLUMNS + column; null means empty.
var _parts: Array[PartData] = []


func _init() -> void:
	_parts.resize(COLUMNS * ROWS)


## Returns true if [param cell] lies on the grid.
static func is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLUMNS and cell.y >= 0 and cell.y < ROWS


## Returns the part at [param cell], or null if the cell is empty or off the grid.
func get_part(cell: Vector2i) -> PartData:
	if not is_valid_cell(cell):
		return null
	return _parts[_index(cell)]


## Puts [param part] in [param cell], replacing whatever was there.
func place(cell: Vector2i, part: PartData) -> void:
	if not is_valid_cell(cell):
		return
	_parts[_index(cell)] = part


## Moves the part at [param from] to [param to]. If [param to] is occupied,
## the two parts swap cells.
func move(from: Vector2i, to: Vector2i) -> void:
	if not is_valid_cell(from) or not is_valid_cell(to) or from == to:
		return
	var moving: PartData = _parts[_index(from)]
	_parts[_index(from)] = _parts[_index(to)]
	_parts[_index(to)] = moving


## Empties [param cell].
func remove(cell: Vector2i) -> void:
	if not is_valid_cell(cell):
		return
	_parts[_index(cell)] = null


## Returns the occupied cells, front row first, left to right.
func cells() -> Array[Vector2i]:
	var occupied: Array[Vector2i] = []
	for row: int in ROWS:
		for column: int in COLUMNS:
			var cell: Vector2i = Vector2i(column, row)
			if _parts[_index(cell)] != null:
				occupied.append(cell)
	return occupied


## Returns true if at least one thruster sits where it works (the rear row).
func has_rear_thruster() -> bool:
	return working_count(PartData.Kind.THRUSTER) > 0


## True when [param part] does its job in [param cell]: a part with a required
## row works only in that row. The one rule ShipBuild and RunResolver share.
static func works_in(part: PartData, cell: Vector2i) -> bool:
	match part.required_row:
		PartData.RequiredRow.FRONT:
			return cell.y == 0
		PartData.RequiredRow.REAR:
			return cell.y == REAR_ROW
	return true


## Number of parts of [param kind] placed where they work.
func working_count(kind: PartData.Kind) -> int:
	var count: int = 0
	for cell: Vector2i in cells():
		var part: PartData = _parts[_index(cell)]
		if part.kind == kind and works_in(part, cell):
			count += 1
	return count


## Total fuel_capacity of parts placed where they work: the run's starting fuel.
func fuel_capacity() -> int:
	var total: int = 0
	for cell: Vector2i in cells():
		var part: PartData = _parts[_index(cell)]
		if works_in(part, cell):
			total += part.fuel_capacity
	return total


## Returns why launch is refused for [param mission], or an empty string if
## launch is allowed. The rear thruster is checked first, then cargo holds.
## Fuel never refuses a launch.
func launch_refusal(mission: MissionData) -> String:
	if not has_rear_thruster():
		return REFUSAL_NO_REAR_THRUSTER
	var holds: int = working_count(PartData.Kind.CARGO_HOLD)
	if holds < mission.cargo_required:
		return REFUSAL_CARGO_SHORT % [holds, "" if holds == 1 else "s", mission.cargo_required]
	return ""


func _index(cell: Vector2i) -> int:
	return cell.y * COLUMNS + cell.x
