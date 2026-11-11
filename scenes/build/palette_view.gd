class_name PaletteView
extends VBoxContainer
## Lists the parts on offer, one colored tile and name per entry, in the
## mission's order. Every entry offers unlimited copies.
## Display and hit-testing only: it never reads input.

@export var tile_size: int = 16
@export var label_font_size: int = 8

var _rows: Array[Control] = []
var _parts: Array[PartData] = []


## Rebuilds the palette from [param parts], keeping their order and colors.
func show_parts(parts: Array[PartData]) -> void:
	for row: Control in _rows:
		remove_child(row)
		row.queue_free()
	_rows.clear()
	_parts.clear()

	for part: PartData in parts:
		if part == null:
			continue
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "Part_%s" % part.display_name.to_snake_case()
		row.add_theme_constant_override("separation", 4)

		var tile: ColorRect = ColorRect.new()
		tile.name = "Tile"
		tile.custom_minimum_size = Vector2(tile_size, tile_size)
		tile.color = part.color
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tile)

		var label: Label = Label.new()
		label.name = "Name"
		label.text = part.display_name
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", label_font_size)
		row.add_child(label)

		add_child(row)
		_rows.append(row)
		_parts.append(part)


## Returns the part whose entry is under [param global_pos], or null.
func part_at(global_pos: Vector2) -> PartData:
	for index: int in _rows.size():
		if _rows[index].get_global_rect().has_point(global_pos):
			return _parts[index]
	return null


## Returns the palette tile color shown for entry [param index].
func get_tile_color(index: int) -> Color:
	if index < 0 or index >= _rows.size():
		return Color.TRANSPARENT
	var tile: ColorRect = _rows[index].get_node("Tile") as ColorRect
	return tile.color


## Returns the number of entries shown.
func entry_count() -> int:
	return _rows.size()


## Returns the global center of entry [param index]'s tile.
func entry_center(index: int) -> Vector2:
	return _rows[index].get_global_rect().get_center()
