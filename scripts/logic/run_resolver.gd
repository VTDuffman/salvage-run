class_name RunResolver
extends RefCounted
## Resolves a run from a ShipBuild, a MissionData and a seed into a RunResult.
## Plain logic with no Node or scene dependencies. Every number comes from the
## PartData, CardData and MissionData fields; the build and the Resources are
## never modified. All randomness comes from one RandomNumberGenerator seeded
## with the run seed: the card shuffle first, then lane picks in card order.

var _mission: MissionData
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Occupied cells at launch, front row first, left to right.
var _cells: Array[Vector2i] = []
var _parts: Dictionary[Vector2i, PartData] = {}
## Current HP per launch cell; 0 means destroyed.
var _hp: Dictionary[Vector2i, int] = {}
## Shield capacity left this card, per launch cell.
var _shield_left: Dictionary[Vector2i, int] = {}
var _fuel: int = 0


## Resolves the whole run. The same arguments always give an equal result.
static func resolve(build: ShipBuild, mission: MissionData, run_seed: int) -> RunResult:
	var resolver: RunResolver = RunResolver.new()
	return resolver._resolve(build, mission, run_seed)


func _resolve(build: ShipBuild, mission: MissionData, run_seed: int) -> RunResult:
	_mission = mission
	_rng.seed = run_seed
	_cells = build.cells()
	for cell: Vector2i in _cells:
		var part: PartData = build.get_part(cell)
		_parts[cell] = part
		_hp[cell] = part.max_hp
		_shield_left[cell] = 0

	var result: RunResult = RunResult.new()
	result.seed = run_seed
	result.card_order = _shuffled(mission.card_pool)
	_fuel = _fuel_cap()
	result.starting_fuel = _fuel

	for card: CardData in result.card_order:
		var event: RunResult.CardEvent = _resolve_card(card)
		result.events.append(event)
		if event.loss_reason != RunResult.LossReason.NONE:
			result.loss_reason = event.loss_reason
			return result
	result.won = true
	return result


## Fisher-Yates shuffle driven by the run RNG (never the global RNG).
func _shuffled(pool: Array[CardData]) -> Array[CardData]:
	var order: Array[CardData] = pool.duplicate()
	for i: int in range(order.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var swap: CardData = order[i]
		order[i] = order[j]
		order[j] = swap
	return order


func _resolve_card(card: CardData) -> RunResult.CardEvent:
	var event: RunResult.CardEvent = RunResult.CardEvent.new()
	event.card = card

	# 1. Refresh shield capacity.
	for cell: Vector2i in _cells:
		_shield_left[cell] = _parts[cell].shield_capacity if _is_working(cell) else 0

	# 2. Apply the card's countered or uncountered effect.
	match card.kind:
		CardData.Kind.PIRATE_AMBUSH:
			if _working_count(PartData.Kind.GUN) >= card.counter_threshold:
				event.countered = true
			else:
				for i: int in card.hits:
					_lane_hit(event, card, RunResult.Side.FRONT, i % ShipBuild.COLUMNS)
				event.countered = _absorbed_without_damage(event)
		CardData.Kind.ASTEROID_FIELD:
			for i: int in card.hits:
				_lane_hit(event, card, RunResult.Side.FRONT, _random_lane(RunResult.Side.FRONT))
			event.countered = _absorbed_without_damage(event)
		CardData.Kind.DEBRIS_STRIKE:
			var side: RunResult.Side = RunResult.Side.LEFT
			if _rng.randi_range(0, 1) == 1:
				side = RunResult.Side.RIGHT
			for i: int in card.hits:
				_lane_hit(event, card, side, _random_lane(side))
			event.countered = _absorbed_without_damage(event)
		CardData.Kind.REAR_RAIDER:
			for i: int in card.hits:
				_lane_hit(event, card, RunResult.Side.REAR, _random_lane(RunResult.Side.REAR))
			event.countered = _absorbed_without_damage(event)
		CardData.Kind.SOLAR_FLARE:
			for i: int in card.hits:
				for cell: Vector2i in _cells:
					if _hp[cell] > 0:
						_strike(event, card, RunResult.Side.NONE, -1, cell)
			event.countered = _absorbed_without_damage(event)
		CardData.Kind.FUEL_LEAK:
			_fuel_drain_card(event, card, PartData.Kind.FUEL_TANK)
		CardData.Kind.GRAVITY_WELL:
			_fuel_drain_card(event, card, PartData.Kind.THRUSTER)
		CardData.Kind.CALM_SPACE:
			pass

	# 3. Burn fuel.
	_fuel -= _mission.fuel_per_card
	event.fuel_after = _fuel

	# 4. Check for loss, in priority order.
	if _working_count(PartData.Kind.THRUSTER) == 0:
		event.loss_reason = RunResult.LossReason.NO_THRUSTER
	elif _fuel < 0:
		event.loss_reason = RunResult.LossReason.OUT_OF_FUEL
	elif _working_count(PartData.Kind.CARGO_HOLD) < _mission.cargo_required:
		event.loss_reason = RunResult.LossReason.CARGO_LOST
	return event


## Fuel Leak and Gravity Well: countered by enough working parts of
## [param counter_kind], otherwise the card drains extra fuel.
func _fuel_drain_card(event: RunResult.CardEvent, card: CardData, counter_kind: PartData.Kind) -> void:
	if _working_count(counter_kind) >= card.counter_threshold:
		event.countered = true
		return
	event.extra_fuel_lost = card.extra_fuel_loss
	_fuel -= card.extra_fuel_loss


func _random_lane(side: RunResult.Side) -> int:
	if side == RunResult.Side.LEFT or side == RunResult.Side.RIGHT:
		return _rng.randi_range(0, ShipBuild.ROWS - 1)
	return _rng.randi_range(0, ShipBuild.COLUMNS - 1)


## Sends one hit inward from [param side] along [param lane] and strikes the
## first intact part, or records a miss.
func _lane_hit(event: RunResult.CardEvent, card: CardData, side: RunResult.Side, lane: int) -> void:
	for cell: Vector2i in _lane_cells(side, lane):
		if _hp.get(cell, 0) > 0:
			_strike(event, card, side, lane, cell)
			return
	var miss: RunResult.HitEvent = RunResult.HitEvent.new()
	miss.entry_side = side
	miss.lane = lane
	event.hits.append(miss)


## The cells of a lane in the order a hit from [param side] travels them.
func _lane_cells(side: RunResult.Side, lane: int) -> Array[Vector2i]:
	var lane_cells: Array[Vector2i] = []
	match side:
		RunResult.Side.FRONT:
			for row: int in ShipBuild.ROWS:
				lane_cells.append(Vector2i(lane, row))
		RunResult.Side.REAR:
			for row: int in range(ShipBuild.ROWS - 1, -1, -1):
				lane_cells.append(Vector2i(lane, row))
		RunResult.Side.LEFT:
			for column: int in ShipBuild.COLUMNS:
				lane_cells.append(Vector2i(column, lane))
		RunResult.Side.RIGHT:
			for column: int in range(ShipBuild.COLUMNS - 1, -1, -1):
				lane_cells.append(Vector2i(column, lane))
	return lane_cells


## Applies one hit's damage to the part at [param cell], one point at a time,
## drawing each point from covering shield capacity before the part's HP.
func _strike(event: RunResult.CardEvent, card: CardData, side: RunResult.Side, lane: int, cell: Vector2i) -> void:
	var hit: RunResult.HitEvent = RunResult.HitEvent.new()
	hit.entry_side = side
	hit.lane = lane
	hit.struck_cell = cell
	for point: int in card.damage_per_hit:
		var shield: Vector2i = _best_covering_shield(cell)
		if shield != RunResult.NO_CELL:
			_shield_left[shield] -= 1
			hit.absorbed += 1
			if hit.shield_cell == RunResult.NO_CELL:
				hit.shield_cell = shield
			continue
		_hp[cell] -= 1
		hit.damage_to_part += 1
		if _hp[cell] == 0:
			hit.destroyed = true
			event.destroyed_cells.append(cell)
			_fuel = mini(_fuel, _fuel_cap())
			break
	hit.part_hp_after = _hp[cell]
	event.hits.append(hit)


## The working shield covering [param cell] with the most capacity left (ties
## go to the first in ShipBuild.cells() order), or NO_CELL if none has any.
func _best_covering_shield(cell: Vector2i) -> Vector2i:
	var best: Vector2i = RunResult.NO_CELL
	var best_left: int = 0
	for shield: Vector2i in _cells:
		if not _is_working(shield) or _shield_left[shield] <= best_left:
			continue
		var offset: Vector2i = (shield - cell).abs()
		if offset.x + offset.y <= 1:
			best = shield
			best_left = _shield_left[shield]
	return best


## True when no part lost HP and at least one hit was absorbed by a shield.
func _absorbed_without_damage(event: RunResult.CardEvent) -> bool:
	var absorbed_any: bool = false
	for hit: RunResult.HitEvent in event.hits:
		if hit.damage_to_part > 0:
			return false
		if hit.absorbed > 0:
			absorbed_any = true
	return absorbed_any


## Working means not destroyed and, when the part has a required row, in it.
func _is_working(cell: Vector2i) -> bool:
	if _hp[cell] <= 0:
		return false
	match _parts[cell].required_row:
		PartData.RequiredRow.FRONT:
			return cell.y == 0
		PartData.RequiredRow.REAR:
			return cell.y == ShipBuild.REAR_ROW
	return true


func _working_count(kind: PartData.Kind) -> int:
	var count: int = 0
	for cell: Vector2i in _cells:
		if _parts[cell].kind == kind and _is_working(cell):
			count += 1
	return count


## Total fuel_capacity of working parts: the starting fuel and the fuel cap.
func _fuel_cap() -> int:
	var total: int = 0
	for cell: Vector2i in _cells:
		if _is_working(cell):
			total += _parts[cell].fuel_capacity
	return total
