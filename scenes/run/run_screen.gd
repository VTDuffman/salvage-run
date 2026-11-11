class_name RunScreen
extends Control
## The run screen: plays a resolved RunResult one card at a time over the
## build screen. Shows the grid with HP, destroyed parts and hit flashes, the
## fuel and card counters, one log line per card, and Play / Pause /
## Fast-forward controls. Display only: it never calls the resolver or
## applies a rule; RunPlayback and PlaybackClock hold the state and timing.

const FUEL_TEXT: String = "FUEL %d"
const CARD_TEXT: String = "CARD %d/%d"

var _playback: RunPlayback = null
var _clock: PlaybackClock = PlaybackClock.new()
var _speed_buttons: ButtonGroup = ButtonGroup.new()

@onready var _grid: GridView = %GridView
@onready var _fuel_label: Label = %FuelLabel
@onready var _card_label: Label = %CardLabel
@onready var _log: RichTextLabel = %Log
@onready var _play_button: Button = %PlayButton
@onready var _pause_button: Button = %PauseButton
@onready var _fast_button: Button = %FastButton


func _ready() -> void:
	for button: Button in [_play_button, _pause_button, _fast_button]:
		button.toggle_mode = true
		button.button_group = _speed_buttons
	_play_button.pressed.connect(_on_play_pressed)
	_pause_button.pressed.connect(_on_pause_pressed)
	_fast_button.pressed.connect(_on_fast_pressed)
	_sync_buttons()
	set_process(_playback != null)


## Starts playing [param result] for the ship [param build] from its first
## card, at normal speed.
func start(build: ShipBuild, result: RunResult) -> void:
	_playback = RunPlayback.new(build, result)
	_clock = PlaybackClock.new()
	_log.text = ""
	_sync_buttons()
	_refresh()
	set_process(true)


func _process(delta: float) -> void:
	if _playback == null:
		return
	var due: int = _clock.advance(delta)
	var log_changed: bool = false
	for i: int in due:
		var finished_before: bool = _playback.is_finished()
		if not _playback.step().is_empty():
			log_changed = true
		if finished_before:
			break
	if log_changed:
		_log.text = "\n".join(_playback.log_lines())
	_refresh()


func get_playback() -> RunPlayback:
	return _playback


func get_clock() -> PlaybackClock:
	return _clock


func get_grid() -> GridView:
	return _grid


## The log as shown, one line per entry.
func get_log_text() -> String:
	return _log.text


func _refresh() -> void:
	if _playback == null:
		return
	_grid.show_playback(_playback, _clock.flash_strength())
	_fuel_label.text = FUEL_TEXT % _playback.fuel()
	_card_label.text = CARD_TEXT % [_playback.card_index(), _playback.card_count()]


func _on_play_pressed() -> void:
	_clock.play()
	_sync_buttons()


func _on_pause_pressed() -> void:
	_clock.pause()
	_sync_buttons()


func _on_fast_pressed() -> void:
	_clock.fast_forward()
	_sync_buttons()


## Shows the active control as pressed.
func _sync_buttons() -> void:
	_play_button.set_pressed_no_signal(not _clock.paused and _clock.speed == PlaybackClock.Speed.NORMAL)
	_pause_button.set_pressed_no_signal(_clock.paused)
	_fast_button.set_pressed_no_signal(not _clock.paused and _clock.speed == PlaybackClock.Speed.FAST)
