extends Control
## The build screen: loads the mission, owns the player's ShipBuild, wires the
## input layer to it, redraws the grid, shows the mission's requirements with
## a live readout of the build against them, and gates Launch on the build.
## An allowed launch resolves the run and opens the run screen over this one,
## with build input switched off. The run screen's Rebuild and Retry same seed
## close it and hand control back here with the layout unchanged.
## Each finished run is appended to the playtest log (dev tooling); the run
## screen's optional feedback buttons tag that run's line.

const MISSION_PATH: String = "res://data/missions/cargo_run.tres"
const RUN_SCREEN_SCENE: PackedScene = preload("res://scenes/run/run_screen.tscn")
const HINT_TEXT: String = "Drag parts onto the grid. Drag off or right-click to remove."
const RETRY_TEXT: String = "Retry: the next launch reuses seed %d."
const LOG_PATH_TEXT: String = "Playtest log: %s"
## Readout colors: green when met with margin, amber at no margin (and for the
## uncountered fuel card lines), red when short.
const OK_COLOR: Color = Color(0.49, 0.77, 0.35)
const WARNING_COLOR: Color = Color(0.96, 0.76, 0.26)
const SHORT_COLOR: Color = Color(0.95, 0.42, 0.3)
const FUEL_STATUS_COLORS: Dictionary[MissionReadout.FuelStatus, Color] = {
	MissionReadout.FuelStatus.SHORT: SHORT_COLOR,
	MissionReadout.FuelStatus.EXACT: WARNING_COLOR,
	MissionReadout.FuelStatus.SPARE: OK_COLOR,
}

var mission: MissionData
var build: ShipBuild = ShipBuild.new()
## The seed of the latest launch, reused by the next one after Retry.
var run_seed: int = 0

var _run_screen: RunScreen = null
## True after Retry same seed: the next launch keeps run_seed.
var _retry_seed: bool = false
## Set before _ready to log elsewhere; otherwise one is made at the default path.
var playtest_log: PlaytestLog = null
## The open run's playtest record, written when its outcome appears.
var _pending_record: Dictionary = {}

@onready var _grid: GridView = %GridView
@onready var _palette: PaletteView = %PaletteView
@onready var _input_layer: BuildMouseInput = %BuildMouseInput
@onready var _launch_button: Button = %LaunchButton
@onready var _status_label: Label = %StatusLabel
@onready var _mission_title: Label = %MissionTitle
@onready var _mission_lines: Label = %MissionLines
@onready var _cargo_readout: Label = %CargoReadout
@onready var _fuel_readout: Label = %FuelReadout
## Uncountered fuel cards and their counters; hidden when there are none.
@onready var _fuel_cards_readout: Label = %FuelCardsReadout
@onready var _log_path_label: Label = %LogPathLabel


func _ready() -> void:
	mission = load(MISSION_PATH) as MissionData
	_palette.show_parts(mission.parts)
	_input_layer.build = build
	_input_layer.build_changed.connect(_on_build_changed)
	_launch_button.pressed.connect(_on_launch_pressed)
	_mission_title.text = mission.display_name.to_upper()
	_mission_lines.text = "\n".join(MissionReadout.panel_lines(mission))
	_grid.show_build(build)
	_refresh_readout()
	_status_label.text = _idle_status()
	if playtest_log == null:
		playtest_log = PlaytestLog.new()
	_log_path_label.text = LOG_PATH_TEXT % playtest_log.absolute_path()
	print(_log_path_label.text)


## The open run screen, or null while building.
func get_run_screen() -> RunScreen:
	return _run_screen


## True when the next launch will reuse run_seed.
func is_retrying_seed() -> bool:
	return _retry_seed


func _on_build_changed() -> void:
	_grid.show_build(build)
	_refresh_readout()
	_status_label.text = _idle_status()


func _on_launch_pressed() -> void:
	if _run_screen != null:
		return
	var refusal: String = build.launch_refusal(mission)
	if not refusal.is_empty():
		_status_label.text = refusal
		return
	if not _retry_seed:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.randomize()
		run_seed = rng.randi()
	_retry_seed = false
	var result: RunResult = RunResolver.resolve(build, mission, run_seed)
	_input_layer.enabled = false
	_launch_button.release_focus()
	_run_screen = RUN_SCREEN_SCENE.instantiate() as RunScreen
	add_child(_run_screen)
	_run_screen.rebuild_requested.connect(_on_rebuild_requested)
	_run_screen.retry_requested.connect(_on_retry_requested)
	_run_screen.outcome_shown.connect(_on_outcome_shown)
	_run_screen.difficulty_tagged.connect(_on_difficulty_tagged)
	_run_screen.start(build, result, mission)
	# After start(): a logging fault must never keep the run from playing.
	_pending_record = PlaytestRecord.build(build, mission, result, {
		"timestamp": PlaytestLog.utc_timestamp(),
		"commit": PlaytestLog.read_git_commit(),
		"session_id": playtest_log.session_id,
		"attempt": playtest_log.next_attempt(),
	})


## The run finished playing: log it once, untagged.
func _on_outcome_shown() -> void:
	if _pending_record.is_empty():
		return
	playtest_log.append(_pending_record)


func _on_difficulty_tagged(tag: String) -> void:
	if _pending_record.is_empty():
		return
	playtest_log.set_difficulty(_pending_record["session_id"], _pending_record["attempt"], tag)


func _on_rebuild_requested() -> void:
	_retry_seed = false
	_close_run_screen()


func _on_retry_requested() -> void:
	_retry_seed = true
	_close_run_screen()


## Frees the run screen and returns to building with the same layout.
func _close_run_screen() -> void:
	if _run_screen == null:
		return
	remove_child(_run_screen)
	_run_screen.queue_free()
	_run_screen = null
	_pending_record = {}
	_input_layer.enabled = true
	_grid.show_build(build)
	_refresh_readout()
	_status_label.text = _idle_status()


func _refresh_readout() -> void:
	_cargo_readout.text = MissionReadout.cargo_line(build, mission)
	_fuel_readout.text = MissionReadout.fuel_line(build, mission)
	_cargo_readout.add_theme_color_override("font_color",
			OK_COLOR if MissionReadout.cargo_met(build, mission) else SHORT_COLOR)
	_fuel_readout.add_theme_color_override("font_color",
			FUEL_STATUS_COLORS[MissionReadout.fuel_status(build, mission)])
	var fuel_card_lines: Array[String] = MissionReadout.fuel_card_lines(build, mission)
	_fuel_cards_readout.text = "\n".join(fuel_card_lines)
	_fuel_cards_readout.visible = not fuel_card_lines.is_empty()
	_fuel_cards_readout.add_theme_color_override("font_color", WARNING_COLOR)


func _idle_status() -> String:
	return RETRY_TEXT % run_seed if _retry_seed else HINT_TEXT
