extends Control
## The build screen: loads the mission, owns the player's ShipBuild, wires the
## input layer to it, redraws the grid, and gates Launch on the build.

const MISSION_PATH: String = "res://data/missions/cargo_run.tres"
const LAUNCH_OK_TEXT: String = "Launch OK (run not implemented yet)."
const HINT_TEXT: String = "Drag parts onto the grid. Drag off or right-click to remove."

var mission: MissionData
var build: ShipBuild = ShipBuild.new()

@onready var _grid: GridView = %GridView
@onready var _palette: PaletteView = %PaletteView
@onready var _input_layer: BuildMouseInput = %BuildMouseInput
@onready var _launch_button: Button = %LaunchButton
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	mission = load(MISSION_PATH) as MissionData
	_palette.show_parts(mission.parts)
	_input_layer.build = build
	_input_layer.build_changed.connect(_on_build_changed)
	_launch_button.pressed.connect(_on_launch_pressed)
	_grid.show_build(build)
	_status_label.text = HINT_TEXT


func _on_build_changed() -> void:
	_grid.show_build(build)


func _on_launch_pressed() -> void:
	var refusal: String = build.launch_refusal()
	_status_label.text = refusal if not refusal.is_empty() else LAUNCH_OK_TEXT
