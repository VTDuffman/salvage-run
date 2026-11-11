extends Control
## The build screen: loads the mission, owns the player's ShipBuild, wires the
## input layer to it, redraws the grid, and gates Launch on the build. An
## allowed launch resolves the run with a fresh seed and opens the run screen
## over this one, with build input switched off.

const MISSION_PATH: String = "res://data/missions/cargo_run.tres"
const RUN_SCREEN_SCENE: PackedScene = preload("res://scenes/run/run_screen.tscn")
const HINT_TEXT: String = "Drag parts onto the grid. Drag off or right-click to remove."

var mission: MissionData
var build: ShipBuild = ShipBuild.new()
## The seed of the latest launch.
var run_seed: int = 0

var _run_screen: RunScreen = null

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


## The open run screen, or null while building.
func get_run_screen() -> RunScreen:
	return _run_screen


func _on_build_changed() -> void:
	_grid.show_build(build)
	_status_label.text = HINT_TEXT


func _on_launch_pressed() -> void:
	if _run_screen != null:
		return
	var refusal: String = build.launch_refusal()
	if not refusal.is_empty():
		_status_label.text = refusal
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	run_seed = rng.randi()
	var result: RunResult = RunResolver.resolve(build, mission, run_seed)
	_input_layer.enabled = false
	_launch_button.release_focus()
	_run_screen = RUN_SCREEN_SCENE.instantiate() as RunScreen
	add_child(_run_screen)
	_run_screen.start(build, result)
