class_name GridView
extends GridContainer
## Displays the Cruiser's ship grid as placeholder tiles, top-down.
## Row 0 is the front (top of screen); the last row is the rear.
## Display and hit-testing only: it never reads input or edits the build.

const COLUMNS: int = ShipBuild.COLUMNS
const ROWS: int = ShipBuild.ROWS
const NO_CELL: Vector2i = Vector2i(-1, -1)

@export var cell_size: int = 48
@export var cell_gap: int = 2
@export var cell_color: Color = Color("2b3140")
@export var cell_border_color: Color = Color("5a6478")
@export var label_font_size: int = 8

var _cells: Array[Panel] = []
var _styles: Array[StyleBoxFlat] = []
var _labels: Array[Label] = []


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


## Redraws every cell from [param build]: tinted and labeled with its part,
## or blank when empty.
func show_build(build: ShipBuild) -> void:
	for row: int in ROWS:
		for column: int in COLUMNS:
			var index: int = row * COLUMNS + column
			var part: PartData = build.get_part(Vector2i(column, row))
			var label: Label = _labels[index]
			if part == null:
				_styles[index].bg_color = cell_color
				label.text = ""
			else:
				_styles[index].bg_color = part.color
				label.text = part.display_name
				label.add_theme_color_override("font_color", text_color_for(part.color))


## Returns the part name shown in the cell at [param cell], or "" if blank.
func get_cell_text(cell: Vector2i) -> String:
	if not ShipBuild.is_valid_cell(cell):
		return ""
	return _labels[cell.y * COLUMNS + cell.x].text


## Returns the background color of the cell at [param cell].
func get_cell_color(cell: Vector2i) -> Color:
	if not ShipBuild.is_valid_cell(cell):
		return Color.TRANSPARENT
	return _styles[cell.y * COLUMNS + cell.x].bg_color


## Returns the cell under [param global_pos], or (-1, -1) if the point is off
## the grid. Points in the gaps between cells snap to the nearest cell.
func cell_at(global_pos: Vector2) -> Vector2i:
	var rect: Rect2 = get_global_rect()
	if not rect.has_point(global_pos):
		return NO_CELL
	var local: Vector2 = global_pos - rect.position
	var column: int = clampi(int(local.x * COLUMNS / rect.size.x), 0, COLUMNS - 1)
	var row: int = clampi(int(local.y * ROWS / rect.size.y), 0, ROWS - 1)
	return Vector2i(column, row)


## Black or white text, whichever reads better on [param background].
static func text_color_for(background: Color) -> Color:
	return Color.BLACK if background.get_luminance() > 0.5 else Color.WHITE


func _build_cells() -> void:
	for row: int in ROWS:
		for column: int in COLUMNS:
			var style: StyleBoxFlat = StyleBoxFlat.new()
			style.bg_color = cell_color
			style.border_color = cell_border_color
			style.set_border_width_all(1)

			var cell: Panel = Panel.new()
			cell.name = "Cell_%d_%d" % [column, row]
			cell.custom_minimum_size = Vector2(cell_size, cell_size)
			cell.add_theme_stylebox_override("panel", style)

			var label: Label = Label.new()
			label.name = "PartLabel"
			label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.autowrap_mode = TextServer.AUTOWRAP_WORD
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.add_theme_font_size_override("font_size", label_font_size)
			cell.add_child(label)

			add_child(cell)
			_cells.append(cell)
			_styles.append(style)
			_labels.append(label)
