class_name BuildMouseInput
extends Node
## Mouse input layer for the build screen: the only place that reads mouse
## events. It turns drags and right-clicks into ShipBuild commands so a touch
## layer can later issue the same commands.

## Emitted after every command that edits the build.
signal build_changed

@export var palette: PaletteView
@export var grid: GridView
## Size of the tile that follows the cursor while dragging.
@export var ghost_size: int = 24

## The build edited by this layer; assigned by the build screen.
var build: ShipBuild

var _drag_part: PartData = null
## Grid cell the drag started from, or GridView.NO_CELL when it came from the palette.
var _drag_from: Vector2i = GridView.NO_CELL
var _ghost_layer: CanvasLayer
var _ghost: ColorRect


func _ready() -> void:
	_ghost_layer = CanvasLayer.new()
	_ghost_layer.name = "GhostLayer"
	_ghost_layer.layer = 10
	add_child(_ghost_layer)

	_ghost = ColorRect.new()
	_ghost.name = "Ghost"
	_ghost.size = Vector2(ghost_size, ghost_size)
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.modulate = Color(1.0, 1.0, 1.0, 0.75)
	_ghost.visible = false
	_ghost_layer.add_child(_ghost)


## Returns true while a part is being dragged.
func is_dragging() -> bool:
	return _drag_part != null


func _input(event: InputEvent) -> void:
	if build == null:
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_begin_drag(button.position)
			else:
				_end_drag(button.position)
		elif button.button_index == MOUSE_BUTTON_RIGHT and button.pressed and not is_dragging():
			_remove_at(button.position)
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and is_dragging():
		_move_ghost(motion.position)


func _begin_drag(pos: Vector2) -> void:
	var cell: Vector2i = grid.cell_at(pos)
	if cell != GridView.NO_CELL:
		var placed: PartData = build.get_part(cell)
		if placed == null:
			return
		_drag_part = placed
		_drag_from = cell
	else:
		var offered: PartData = palette.part_at(pos)
		if offered == null:
			return
		_drag_part = offered
		_drag_from = GridView.NO_CELL
	_ghost.color = _drag_part.color
	_ghost.visible = true
	_move_ghost(pos)
	get_viewport().set_input_as_handled()


func _end_drag(pos: Vector2) -> void:
	if not is_dragging():
		return
	var part: PartData = _drag_part
	var from: Vector2i = _drag_from
	_drag_part = null
	_drag_from = GridView.NO_CELL
	_ghost.visible = false
	get_viewport().set_input_as_handled()

	var to: Vector2i = grid.cell_at(pos)
	if from == GridView.NO_CELL:
		if to == GridView.NO_CELL:
			return
		build.place(to, part)
	elif to == GridView.NO_CELL:
		build.remove(from)
	elif to == from:
		return
	else:
		build.move(from, to)
	build_changed.emit()


func _remove_at(pos: Vector2) -> void:
	var cell: Vector2i = grid.cell_at(pos)
	if cell == GridView.NO_CELL or build.get_part(cell) == null:
		return
	build.remove(cell)
	get_viewport().set_input_as_handled()
	build_changed.emit()


func _move_ghost(pos: Vector2) -> void:
	_ghost.position = pos - _ghost.size / 2.0
