class_name GridView
extends GridContainer
## Displays the Cruiser's ship grid as placeholder tiles, top-down.
## Row 0 is the front (top of screen); the last row is the rear.

const COLUMNS: int = 3
const ROWS: int = 3

@export var cell_size: int = 48
@export var cell_gap: int = 2
@export var cell_color: Color = Color("2b3140")
@export var cell_border_color: Color = Color("5a6478")

var _cells: Array[Panel] = []


func _ready() -> void:
	columns = COLUMNS
	add_theme_constant_override("h_separation", cell_gap)
	add_theme_constant_override("v_separation", cell_gap)
	_build_cells()


## Returns the cell panel at [param column], [param row], or null if out of range.
func get_cell(column: int, row: int) -> Panel:
	if column < 0 or column >= COLUMNS or row < 0 or row >= ROWS:
		return null
	return _cells[row * COLUMNS + column]


func _build_cells() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = cell_color
	style.border_color = cell_border_color
	style.set_border_width_all(1)

	for row: int in ROWS:
		for column: int in COLUMNS:
			var cell: Panel = Panel.new()
			cell.name = "Cell_%d_%d" % [column, row]
			cell.custom_minimum_size = Vector2(cell_size, cell_size)
			cell.add_theme_stylebox_override("panel", style)
			add_child(cell)
			_cells.append(cell)
