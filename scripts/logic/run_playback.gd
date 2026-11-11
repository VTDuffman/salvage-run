class_name RunPlayback
extends RefCounted
## Display state for watching a resolved run one card at a time. It only
## replays RunResult fields (HP after each hit, destroyed cells, fuel after
## each card) onto a snapshot of the launched ship; it never applies a rule.
## Plain logic with no Node or scene dependencies.

## How a cell flashes for the card just shown.
enum Flash { NONE, DAMAGE, SHIELD }

const MISS_TEXT: String = "it missed the ship"
const WON_LINE: String = "Run won: cargo delivered"
const LOST_PREFIX: String = "Run lost: "
const SEPARATOR: String = " — "

## Snapshot of the ship at launch, so later build edits do not change playback.
var _build: ShipBuild = ShipBuild.new()
var _result: RunResult
## Current HP per launch cell.
var _hp: Dictionary[Vector2i, int] = {}
var _destroyed: Dictionary[Vector2i, bool] = {}
## Flash per cell for the card shown last; cells not listed do not flash.
var _flash: Dictionary[Vector2i, Flash] = {}
var _fuel: int = 0
## Number of card events applied so far.
var _next_event: int = 0
var _outcome_shown: bool = false
var _lines: Array[String] = []


func _init(build: ShipBuild, result: RunResult) -> void:
	_result = result
	for cell: Vector2i in build.cells():
		var part: PartData = build.get_part(cell)
		_build.place(cell, part)
		_hp[cell] = part.max_hp
	_fuel = result.starting_fuel


## Applies the next card event and returns the log lines it added: the card's
## line, followed by the outcome line when it was the last card. Once the run
## is finished, only clears the flash and returns no lines.
func step() -> Array[String]:
	_flash.clear()
	var added: Array[String] = []
	if is_finished():
		return added
	if _next_event < _result.events.size():
		var event: RunResult.CardEvent = _result.events[_next_event]
		_next_event += 1
		_apply(event)
		added.append(card_line(event, _build))
	if _next_event >= _result.events.size():
		_outcome_shown = true
		var outcome: String = outcome_line(_result)
		if not outcome.is_empty():
			added.append(outcome)
	_lines.append_array(added)
	return added


## True once every card event and the outcome line have been shown.
func is_finished() -> bool:
	return _outcome_shown


## Cards shown so far.
func card_index() -> int:
	return _next_event


## Cards in the run's deck, including any never reached after a loss.
func card_count() -> int:
	return _result.card_order.size()


## Fuel after the card shown last (starting fuel before any card).
func fuel() -> int:
	return _fuel


## The launched part at [param cell], or null if the cell was empty.
func get_part(cell: Vector2i) -> PartData:
	return _build.get_part(cell)


## Current HP of the part at [param cell]; 0 for an empty cell.
func hp(cell: Vector2i) -> int:
	return _hp.get(cell, 0)


func is_destroyed(cell: Vector2i) -> bool:
	return _destroyed.get(cell, false)


## How [param cell] flashes for the card shown last.
func flash_at(cell: Vector2i) -> Flash:
	return _flash.get(cell, Flash.NONE)


## Every log line shown so far, oldest first.
func log_lines() -> Array[String]:
	return _lines.duplicate()


## The log line for one card: "<Card> — <result>", plus the names of any
## parts it destroyed. [param build] supplies the part names.
static func card_line(event: RunResult.CardEvent, build: ShipBuild) -> String:
	var text: String
	if event.countered:
		text = event.card.countered_text
	elif _is_total_miss(event):
		text = MISS_TEXT
	else:
		text = event.card.uncountered_text
	var line: String = event.card.display_name + SEPARATOR + text
	if not event.destroyed_cells.is_empty():
		var names: PackedStringArray = PackedStringArray()
		for cell: Vector2i in event.destroyed_cells:
			var part: PartData = build.get_part(cell)
			names.append(part.display_name if part != null else "Part")
		line += " (%s destroyed)" % ", ".join(names)
	return line


## The final line of a run: the win line, "Run lost: <reason>", or "" while
## the result holds neither.
static func outcome_line(result: RunResult) -> String:
	if result.won:
		return WON_LINE
	if result.loss_reason != RunResult.LossReason.NONE:
		return LOST_PREFIX + loss_reason_text(result.loss_reason)
	return ""


static func loss_reason_text(reason: RunResult.LossReason) -> String:
	match reason:
		RunResult.LossReason.NO_THRUSTER:
			return "no working thruster"
		RunResult.LossReason.OUT_OF_FUEL:
			return "out of fuel"
		RunResult.LossReason.CARGO_LOST:
			return "too much cargo lost"
	return ""


## Every log line of the whole run, as playback would show them.
static func all_lines(build: ShipBuild, result: RunResult) -> Array[String]:
	var lines: Array[String] = []
	for event: RunResult.CardEvent in result.events:
		lines.append(card_line(event, build))
	var outcome: String = outcome_line(result)
	if not outcome.is_empty():
		lines.append(outcome)
	return lines


static func _is_total_miss(event: RunResult.CardEvent) -> bool:
	if event.hits.is_empty():
		return false
	for hit: RunResult.HitEvent in event.hits:
		if not hit.is_miss():
			return false
	return true


func _apply(event: RunResult.CardEvent) -> void:
	for hit: RunResult.HitEvent in event.hits:
		if hit.is_miss():
			continue
		var cell: Vector2i = hit.struck_cell
		_hp[cell] = hit.part_hp_after
		if hit.destroyed:
			_destroyed[cell] = true
		if hit.damage_to_part > 0:
			_flash[cell] = Flash.DAMAGE
		elif hit.absorbed > 0 and _flash.get(cell, Flash.NONE) != Flash.DAMAGE:
			_flash[cell] = Flash.SHIELD
	for cell: Vector2i in event.destroyed_cells:
		_destroyed[cell] = true
		_hp[cell] = 0
	_fuel = event.fuel_after
