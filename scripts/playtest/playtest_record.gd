class_name PlaytestRecord
extends RefCounted
## Builds one playtest log record (a JSON-ready Dictionary) from a launched
## build, its mission and the resolved run. Dev tooling only: plain logic with
## no Node, scene or file access. Timestamp, commit, session and attempt come
## in through [code]meta[/code] so the result is fully determined by its inputs.
## Every number is read from ShipBuild, MissionReadout, RunResult or the
## Resources; no rule is re-derived here.

const SCHEMA: int = 1

const TAG_TOO_HARD: String = "too_hard"
const TAG_FAIR: String = "fair"
const TAG_TOO_EASY: String = "too_easy"
const TAGS: Array[String] = [TAG_TOO_HARD, TAG_FAIR, TAG_TOO_EASY]


## The full record. [param meta] holds [code]timestamp[/code] (String),
## [code]commit[/code] (String or null), [code]session_id[/code] (String) and
## [code]attempt[/code] (int). [code]difficulty[/code] starts null.
static func build(ship: ShipBuild, mission: MissionData, result: RunResult, meta: Dictionary) -> Dictionary:
	var uncountered: Array[String] = []
	for card: CardData in MissionReadout.uncountered_fuel_cards(ship, mission):
		uncountered.append(card_id(card))
	var card_order: Array[String] = []
	for card: CardData in result.card_order:
		card_order.append(card_id(card))
	var cards: Array[Dictionary] = []
	for event: RunResult.CardEvent in result.events:
		cards.append(_card_summary(ship, event))
	var lost: bool = not result.won and result.loss_reason != RunResult.LossReason.NONE
	return {
		"schema": SCHEMA,
		"timestamp": meta.get("timestamp", ""),
		"commit": meta.get("commit", null),
		"session_id": meta.get("session_id", ""),
		"attempt": meta.get("attempt", 0),
		"seed": result.seed,
		"mission": resource_id(mission, mission.display_name.to_snake_case()),
		"layout": layout(ship),
		"fuel": {
			"have": ship.fuel_capacity(),
			"needed": MissionReadout.fuel_needed(ship, mission),
			"spare": MissionReadout.fuel_spare(ship, mission),
			"uncountered": uncountered,
		},
		"cargo": {
			"have": ship.working_count(PartData.Kind.CARGO_HOLD),
			"required": mission.cargo_required,
		},
		"card_order": card_order,
		"cards": cards,
		"outcome": "won" if result.won else "lost",
		"loss_reason": loss_reason_id(result.loss_reason) if lost else null,
		"loss_card": result.events.size() if lost else null,
		"tuning": tuning(mission),
		"difficulty": null,
	}


## Part ids by row, front row first; null for an empty cell.
static func layout(ship: ShipBuild) -> Array:
	var rows: Array = []
	for row: int in ShipBuild.ROWS:
		var cells: Array = []
		for column: int in ShipBuild.COLUMNS:
			var part: PartData = ship.get_part(Vector2i(column, row))
			cells.append(part_id(part) if part != null else null)
		rows.append(cells)
	return rows


## The tuning values the run used, keyed by part and card id.
static func tuning(mission: MissionData) -> Dictionary:
	var parts: Dictionary = {}
	for part: PartData in mission.parts:
		if part == null:
			continue
		parts[part_id(part)] = {
			"max_hp": part.max_hp,
			"fuel_capacity": part.fuel_capacity,
			"shield_capacity": part.shield_capacity,
		}
	var cards: Dictionary = {}
	for card: CardData in mission.card_pool:
		if card == null:
			continue
		cards[card_id(card)] = {
			"hits": card.hits,
			"damage_per_hit": card.damage_per_hit,
			"extra_fuel_loss": card.extra_fuel_loss,
			"counter_threshold": card.counter_threshold,
		}
	return {
		"parts": parts,
		"cards": cards,
		"mission": {
			"cargo_required": mission.cargo_required,
			"fuel_per_card": mission.fuel_per_card,
		},
	}


static func part_id(part: PartData) -> String:
	return resource_id(part, String(PartData.Kind.keys()[part.kind]).to_lower())


static func card_id(card: CardData) -> String:
	return resource_id(card, String(CardData.Kind.keys()[card.kind]).to_lower())


## The resource file's basename (e.g. "fuel_tank"), or [param fallback] for a
## resource with no file (made in code).
static func resource_id(resource: Resource, fallback: String) -> String:
	if resource.resource_path.is_empty() or resource.resource_path.contains("::"):
		return fallback
	return resource.resource_path.get_file().get_basename()


## "out_of_fuel", "cargo_lost", "no_thruster" or "none".
static func loss_reason_id(reason: RunResult.LossReason) -> String:
	return String(RunResult.LossReason.keys()[reason]).to_lower()


static func _card_summary(ship: ShipBuild, event: RunResult.CardEvent) -> Dictionary:
	var missed: int = 0
	var absorbed: int = 0
	var damaged: int = 0
	for hit: RunResult.HitEvent in event.hits:
		if hit.is_miss():
			missed += 1
		elif hit.damage_to_part > 0:
			damaged += 1
		else:
			absorbed += 1
	var destroyed: Array[String] = []
	for cell: Vector2i in event.destroyed_cells:
		destroyed.append(part_id(ship.get_part(cell)))
	return {
		"card": card_id(event.card),
		"countered": event.countered,
		"hits": {"missed": missed, "absorbed": absorbed, "damaged": damaged},
		"destroyed": destroyed,
		"fuel_after": event.fuel_after,
	}
