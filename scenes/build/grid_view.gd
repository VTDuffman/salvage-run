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
@export var destroyed_color: Color = Color("15171c")
@export var destroyed_text_color: Color = Color("c04040")
@export var damage_flash_color: Color = Color("e03030")
@export var shield_flash_color: Color = Color("3a8cff")

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


## Redraws every cell from [param playback]: part name and current HP,
## destroyed cells dark with the part name over an "X", and the last card's
## struck cells tinted red (damage) or blue (fully absorbed by a shield).
## [param flash_strength] sets the tint: 0 is none, 1 is the full flash color.
func show_playback(playback: RunPlayback, flash_strength: float) -> void:
	var strength: float = clampf(flash_strength, 0.0, 1.0)
	for row: int in ROWS:
		for column: int in COLUMNS:
			var cell: Vector2i = Vector2i(column, row)
			var index: int = row * COLUMNS + column
			var part: PartData = playback.get_part(cell)
			var label: Label = _labels[index]
			var background: Color = cell_color
			var destroyed: bool = part != null and playback.is_destroyed(cell)
			if part == null:
				label.text = ""
			elif destroyed:
				background = destroyed_color
				label.text = "%s\nX" % part.display_name
			else:
				background = part.color
				label.text = "%s\n%d/%d HP" % [part.display_name, playback.hp(cell), part.max_hp]
			var flash: RunPlayback.Flash = playback.flash_at(cell)
			if flash == RunPlayback.Flash.DAMAGE:
				background = background.lerp(damage_flash_color, strength)
			elif flash == RunPlayback.Flash.SHIELD:
				background = background.lerp(shield_flash_color, strength)
			_styles[index].bg_color = background
			var text_color: Color = text_color_for(background)
			if destroyed and (flash == RunPlayback.Flash.NONE or strength <= 0.0):
				text_color = destroyed_text_color
			label.add_theme_color_override("font_color", text_color)


## Returns the whole text shown in the cell at [param cell]: the part name
## (plus HP, or "X" once destroyed, during playback), or "" if blank.
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
