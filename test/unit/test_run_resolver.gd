extends GutTest
## RunResolver: determinism (CAP-3), every card countered and uncountered plus
## shields and cascades (CAP-4), win and every loss (CAP-5), and data-driven
## starting fuel (CAP-8).

const CARGO_RUN: MissionData = preload("res://data/missions/cargo_run.tres")
const THRUSTER: PartData = preload("res://data/parts/thruster.tres")
const FUEL_TANK: PartData = preload("res://data/parts/fuel_tank.tres")
const CARGO_HOLD: PartData = preload("res://data/parts/cargo_hold.tres")
const SHIELD: PartData = preload("res://data/parts/shield.tres")
const HULL_PLATING: PartData = preload("res://data/parts/hull_plating.tres")
const GUN: PartData = preload("res://data/parts/gun.tres")
const PIRATE_AMBUSH: CardData = preload("res://data/cards/pirate_ambush.tres")
const ASTEROID_FIELD: CardData = preload("res://data/cards/asteroid_field.tres")
const DEBRIS_STRIKE: CardData = preload("res://data/cards/debris_strike.tres")
const REAR_RAIDER: CardData = preload("res://data/cards/rear_raider.tres")
const SOLAR_FLARE: CardData = preload("res://data/cards/solar_flare.tres")
const FUEL_LEAK: CardData = preload("res://data/cards/fuel_leak.tres")
const GRAVITY_WELL: CardData = preload("res://data/cards/gravity_well.tres")
const CALM_SPACE: CardData = preload("res://data/cards/calm_space.tres")

const NO_CELL: Vector2i = RunResult.NO_CELL
const REAR_MIDDLE: Vector2i = Vector2i(1, 2)


# --- Helpers -----------------------------------------------------------------

## A mission with no fuel burn and no cargo requirement unless given, so card
## tests see only the card's own effect.
func _mission(pool: Array[CardData], cargo_required: int = 0, fuel_per_card: int = 0) -> MissionData:
	var mission: MissionData = MissionData.new()
	mission.cargo_required = cargo_required
	mission.fuel_per_card = fuel_per_card
	mission.card_pool = pool
	return mission


func _build(layout: Dictionary[Vector2i, PartData]) -> ShipBuild:
	var build: ShipBuild = ShipBuild.new()
	for cell: Vector2i in layout:
		build.place(cell, layout[cell])
	return build


## A hand-made card of [param kind] that is never countered by parts
## (counter_threshold 99). A PIRATE_AMBUSH card's hit i goes down front column i.
func _card(kind: CardData.Kind, hits: int, damage_per_hit: int) -> CardData:
	var card: CardData = CardData.new()
	card.kind = kind
	card.hits = hits
	card.damage_per_hit = damage_per_hit
	card.counter_threshold = 99
	return card


func _part(kind: PartData.Kind, max_hp: int, shield_capacity: int = 0) -> PartData:
	var part: PartData = PartData.new()
	part.kind = kind
	part.max_hp = max_hp
	part.shield_capacity = shield_capacity
	return part


func _resolve_one(card: CardData, layout: Dictionary[Vector2i, PartData]) -> RunResult.CardEvent:
	var pool: Array[CardData] = [card]
	return RunResolver.resolve(_build(layout), _mission(pool), 1).events[0]


## The first seed from 0 whose shuffle puts the pool in the given order.
func _seed_for_order(build: ShipBuild, mission: MissionData, order: Array[CardData]) -> int:
	for run_seed: int in 1000:
		if RunResolver.resolve(build, mission, run_seed).card_order == order:
			return run_seed
	fail_test("no seed gives the wanted card order")
	return -1


## Expected first cell a hit from [param side] along [param lane] strikes.
func _first_in_lane(build: ShipBuild, side: RunResult.Side, lane: int) -> Vector2i:
	for step: int in 3:
		var cell: Vector2i
		match side:
			RunResult.Side.FRONT:
				cell = Vector2i(lane, step)
			RunResult.Side.REAR:
				cell = Vector2i(lane, 2 - step)
			RunResult.Side.LEFT:
				cell = Vector2i(step, lane)
			RunResult.Side.RIGHT:
				cell = Vector2i(2 - step, lane)
		if build.get_part(cell) != null:
			return cell
	return NO_CELL


## Every field of a result flattened, for deep equality checks.
func _flatten(result: RunResult) -> Array:
	var flat: Array = [result.seed, result.card_order, result.starting_fuel, result.won, result.loss_reason]
	for event: RunResult.CardEvent in result.events:
		flat.append([event.card, event.countered, event.extra_fuel_lost, event.fuel_after,
				event.destroyed_cells, event.loss_reason])
		for hit: RunResult.HitEvent in event.hits:
			flat.append([hit.entry_side, hit.lane, hit.struck_cell, hit.shield_cell, hit.absorbed,
					hit.damage_to_part, hit.part_hp_after, hit.destroyed])
	return flat


## Cells covered by one shield at (1,1): a "plus" whose every lane hit lands
## on a covered cell or misses.
func _plus_layout() -> Dictionary[Vector2i, PartData]:
	return {
		Vector2i(1, 0): HULL_PLATING,
		Vector2i(0, 1): CARGO_HOLD,
		Vector2i(1, 1): SHIELD,
		Vector2i(2, 1): CARGO_HOLD,
		REAR_MIDDLE: THRUSTER,
	}


## Every cell filled, no shields.
func _full_layout() -> Dictionary[Vector2i, PartData]:
	var layout: Dictionary[Vector2i, PartData] = {}
	for row: int in 3:
		for column: int in 3:
			layout[Vector2i(column, row)] = HULL_PLATING
	layout[REAR_MIDDLE] = THRUSTER
	return layout


# --- CAP-3: determinism -------------------------------------------------------

func test_same_seed_gives_identical_result() -> void:
	var build: ShipBuild = _build({
		Vector2i(0, 0): GUN, Vector2i(1, 0): SHIELD, Vector2i(2, 0): HULL_PLATING,
		Vector2i(0, 1): CARGO_HOLD, Vector2i(1, 1): FUEL_TANK, Vector2i(2, 1): CARGO_HOLD,
		Vector2i(0, 2): FUEL_TANK, REAR_MIDDLE: THRUSTER, Vector2i(2, 2): SHIELD,
	})
	for run_seed: int in [0, 7, 12345, -99]:
		var first: RunResult = RunResolver.resolve(build, CARGO_RUN, run_seed)
		var second: RunResult = RunResolver.resolve(build, CARGO_RUN, run_seed)
		assert_eq(first.seed, run_seed)
		assert_eq_deep(_flatten(first), _flatten(second))


func test_card_order_is_a_permutation_of_the_pool() -> void:
	var build: ShipBuild = _build(_full_layout())
	var orders: Dictionary = {}
	for run_seed: int in 20:
		var order: Array[CardData] = RunResolver.resolve(build, CARGO_RUN, run_seed).card_order
		assert_eq(order.size(), CARGO_RUN.card_pool.size())
		for card: CardData in CARGO_RUN.card_pool:
			assert_eq(order.count(card), 1)
		orders[order] = true
	assert_gt(orders.size(), 1, "different seeds should give different orders")


func test_debris_strike_reaches_both_flanks_and_all_rows() -> void:
	var pool: Array[CardData] = [DEBRIS_STRIKE]
	var mission: MissionData = _mission(pool)
	var build: ShipBuild = _build(_full_layout())
	var picks: Dictionary = {}
	for run_seed: int in 40:
		var hit: RunResult.HitEvent = RunResolver.resolve(build, mission, run_seed).events[0].hits[0]
		picks[[hit.entry_side, hit.lane]] = true
	assert_eq(picks.size(), 6, "both flanks and all three rows should appear")


func test_resolver_does_not_mutate_build_or_resources() -> void:
	var layout: Dictionary[Vector2i, PartData] = _full_layout()
	var build: ShipBuild = _build(layout)
	var pool: Array[CardData] = [_card(CardData.Kind.SOLAR_FLARE, 1, 9)]
	RunResolver.resolve(build, _mission(pool), 3)
	for cell: Vector2i in layout:
		assert_eq(build.get_part(cell), layout[cell])
	assert_eq(HULL_PLATING.max_hp, 4)
	assert_eq(THRUSTER.max_hp, 2)


# --- CAP-4: each card ---------------------------------------------------------

func test_pirate_ambush_countered_by_front_row_gun() -> void:
	var layout: Dictionary[Vector2i, PartData] = _full_layout()
	layout[Vector2i(2, 0)] = GUN
	var event: RunResult.CardEvent = _resolve_one(PIRATE_AMBUSH, layout)
	assert_true(event.countered)
	assert_eq(event.hits.size(), 0)


func test_pirate_ambush_uncountered_hits_each_front_column() -> void:
	var layout: Dictionary[Vector2i, PartData] = {
		Vector2i(0, 1): GUN, # outside the front row: inert, still absorbs hits
		Vector2i(1, 0): HULL_PLATING,
		REAR_MIDDLE: THRUSTER,
	}
	var event: RunResult.CardEvent = _resolve_one(PIRATE_AMBUSH, layout)
	assert_false(event.countered)
	assert_eq(event.hits.size(), 3)
	var expected_cells: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), NO_CELL]
	for lane: int in 3:
		var hit: RunResult.HitEvent = event.hits[lane]
		assert_eq(hit.entry_side, RunResult.Side.FRONT)
		assert_eq(hit.lane, lane)
		assert_eq(hit.struck_cell, expected_cells[lane])
	assert_eq(event.hits[0].damage_to_part, 1)
	assert_eq(event.hits[0].part_hp_after, 1)
	assert_eq(event.hits[1].part_hp_after, 3)
	assert_true(event.hits[2].is_miss())
	assert_eq(event.hits[2].damage_to_part, 0)


func test_destroyed_gun_no_longer_counters() -> void:
	var layout: Dictionary[Vector2i, PartData] = {Vector2i(0, 0): GUN, REAR_MIDDLE: THRUSTER}
	var smash: CardData = _card(CardData.Kind.PIRATE_AMBUSH, 1, 2)
	var pool: Array[CardData] = [smash, PIRATE_AMBUSH]
	var build: ShipBuild = _build(layout)
	var mission: MissionData = _mission(pool)
	var result: RunResult = RunResolver.resolve(build, mission, _seed_for_order(build, mission, pool))
	assert_eq(result.events[0].destroyed_cells, [Vector2i(0, 0)] as Array[Vector2i])
	assert_false(result.events[1].countered)
	assert_eq(result.events[1].hits.size(), 3)


func test_asteroid_field_uncountered_strikes_random_front_lanes() -> void:
	var build_layout: Dictionary[Vector2i, PartData] = _full_layout()
	var build: ShipBuild = _build(build_layout)
	for run_seed: int in 10:
		var pool: Array[CardData] = [ASTEROID_FIELD]
		var event: RunResult.CardEvent = RunResolver.resolve(build, _mission(pool), run_seed).events[0]
		assert_false(event.countered)
		assert_eq(event.hits.size(), 2)
		for hit: RunResult.HitEvent in event.hits:
			assert_eq(hit.entry_side, RunResult.Side.FRONT)
			assert_between(hit.lane, 0, 2)
			assert_eq(hit.struck_cell, Vector2i(hit.lane, 0))
			assert_eq(hit.damage_to_part, 1)


func test_asteroid_field_countered_by_shield_coverage() -> void:
	var layout: Dictionary[Vector2i, PartData] = {
		Vector2i(0, 0): HULL_PLATING, Vector2i(1, 0): SHIELD, Vector2i(2, 0): HULL_PLATING,
		REAR_MIDDLE: THRUSTER,
	}
	var event: RunResult.CardEvent = _resolve_one(ASTEROID_FIELD, layout)
	assert_true(event.countered)
	for hit: RunResult.HitEvent in event.hits:
		assert_eq(hit.shield_cell, Vector2i(1, 0))
		assert_eq(hit.absorbed, 1)
		assert_eq(hit.damage_to_part, 0)


func test_total_miss_is_not_countered() -> void:
	var empty: Dictionary[Vector2i, PartData] = {}
	var event: RunResult.CardEvent = _resolve_one(ASTEROID_FIELD, empty)
	assert_eq(event.hits.size(), 2)
	for hit: RunResult.HitEvent in event.hits:
		assert_true(hit.is_miss())
		assert_eq(hit.entry_side, RunResult.Side.FRONT)
	assert_false(event.countered)


func test_debris_strike_uncountered_strikes_from_a_flank() -> void:
	var layout: Dictionary[Vector2i, PartData] = {
		Vector2i(1, 0): HULL_PLATING, Vector2i(0, 1): CARGO_HOLD, Vector2i(2, 2): HULL_PLATING,
		REAR_MIDDLE: THRUSTER,
	}
	var build: ShipBuild = _build(layout)
	for run_seed: int in 20:
		var pool: Array[CardData] = [DEBRIS_STRIKE]
		var event: RunResult.CardEvent = RunResolver.resolve(build, _mission(pool), run_seed).events[0]
		assert_false(event.countered)
		assert_eq(event.hits.size(), 1)
		var hit: RunResult.HitEvent = event.hits[0]
		assert_true(hit.entry_side == RunResult.Side.LEFT or hit.entry_side == RunResult.Side.RIGHT)
		assert_eq(hit.struck_cell, _first_in_lane(build, hit.entry_side, hit.lane))
		if not hit.is_miss():
			assert_eq(hit.damage_to_part, 1)


func test_rear_raider_uncountered_strikes_from_the_rear() -> void:
	var layout: Dictionary[Vector2i, PartData] = {
		Vector2i(0, 0): HULL_PLATING, Vector2i(1, 1): CARGO_HOLD, REAR_MIDDLE: THRUSTER,
		Vector2i(2, 1): FUEL_TANK,
	}
	var build: ShipBuild = _build(layout)
	for run_seed: int in 20:
		var pool: Array[CardData] = [REAR_RAIDER]
		var event: RunResult.CardEvent = RunResolver.resolve(build, _mission(pool), run_seed).events[0]
		assert_false(event.countered)
		var hit: RunResult.HitEvent = event.hits[0]
		assert_eq(hit.entry_side, RunResult.Side.REAR)
		assert_eq(hit.struck_cell, _first_in_lane(build, RunResult.Side.REAR, hit.lane))
		assert_eq(hit.damage_to_part, 1)


func test_directional_cards_countered_inside_shield_coverage() -> void:
	var build: ShipBuild = _build(_plus_layout())
	for card: CardData in [ASTEROID_FIELD, DEBRIS_STRIKE, REAR_RAIDER] as Array[CardData]:
		for run_seed: int in 20:
			var pool: Array[CardData] = [card]
			var event: RunResult.CardEvent = RunResolver.resolve(build, _mission(pool), run_seed).events[0]
			assert_true(event.countered, "%s seed %d" % [card.display_name, run_seed])
			for hit: RunResult.HitEvent in event.hits:
				assert_eq(hit.damage_to_part, 0)
				assert_eq(hit.shield_cell, Vector2i(1, 1))


func test_solar_flare_uncountered_damages_every_part_front_first() -> void:
	var layout: Dictionary[Vector2i, PartData] = {
		Vector2i(2, 0): HULL_PLATING, Vector2i(0, 1): CARGO_HOLD, REAR_MIDDLE: THRUSTER,
	}
	var event: RunResult.CardEvent = _resolve_one(SOLAR_FLARE, layout)
	assert_false(event.countered)
	assert_eq(event.hits.size(), 3)
	var expected: Array[Vector2i] = [Vector2i(2, 0), Vector2i(0, 1), REAR_MIDDLE]
	for i: int in 3:
		assert_eq(event.hits[i].struck_cell, expected[i])
		assert_eq(event.hits[i].entry_side, RunResult.Side.NONE)
		assert_eq(event.hits[i].damage_to_part, 1)
	assert_eq(event.hits[0].part_hp_after, 3)
	assert_eq(event.hits[1].part_hp_after, 1)


func test_solar_flare_countered_by_shield_capacity() -> void:
	var layout: Dictionary[Vector2i, PartData] = {Vector2i(1, 1): SHIELD, REAR_MIDDLE: THRUSTER}
	var event: RunResult.CardEvent = _resolve_one(SOLAR_FLARE, layout)
	assert_true(event.countered)
	for hit: RunResult.HitEvent in event.hits:
		assert_eq(hit.absorbed, 1)
		assert_eq(hit.damage_to_part, 0)


func test_solar_flare_exhausts_shield_in_front_first_order() -> void:
	# Five covered parts, capacity 2: the first two in cells() order are spared.
	var event: RunResult.CardEvent = _resolve_one(SOLAR_FLARE, _plus_layout())
	assert_false(event.countered)
	var absorbed: Array[Vector2i] = []
	var damaged: Array[Vector2i] = []
	for hit: RunResult.HitEvent in event.hits:
		if hit.absorbed > 0:
			absorbed.append(hit.struck_cell)
		else:
			damaged.append(hit.struck_cell)
	assert_eq(absorbed, [Vector2i(1, 0), Vector2i(0, 1)] as Array[Vector2i])
	assert_eq(damaged, [Vector2i(1, 1), Vector2i(2, 1), REAR_MIDDLE] as Array[Vector2i])


func test_fuel_leak_countered_by_two_tanks() -> void:
	var layout: Dictionary[Vector2i, PartData] = {
		Vector2i(0, 0): FUEL_TANK, Vector2i(1, 0): FUEL_TANK, REAR_MIDDLE: THRUSTER,
	}
	var event: RunResult.CardEvent = _resolve_one(FUEL_LEAK, layout)
	assert_true(event.countered)
	assert_eq(event.extra_fuel_lost, 0)
	assert_eq(event.fuel_after, 8)


func test_fuel_leak_uncountered_drains_extra_fuel() -> void:
	var layout: Dictionary[Vector2i, PartData] = {Vector2i(0, 0): FUEL_TANK, REAR_MIDDLE: THRUSTER}
	var pool: Array[CardData] = [FUEL_LEAK]
	var result: RunResult = RunResolver.resolve(_build(layout), _mission(pool, 0, 1), 1)
	var event: RunResult.CardEvent = result.events[0]
	assert_false(event.countered)
	assert_eq(event.extra_fuel_lost, 2)
	assert_eq(event.fuel_after, 4 - 2 - 1)


func test_gravity_well_countered_by_two_rear_thrusters() -> void:
	var layout: Dictionary[Vector2i, PartData] = {
		Vector2i(0, 0): FUEL_TANK, Vector2i(0, 2): THRUSTER, REAR_MIDDLE: THRUSTER,
	}
	var event: RunResult.CardEvent = _resolve_one(GRAVITY_WELL, layout)
	assert_true(event.countered)
	assert_eq(event.extra_fuel_lost, 0)
	assert_eq(event.fuel_after, 4)


func test_gravity_well_ignores_thruster_outside_rear_row() -> void:
	var layout: Dictionary[Vector2i, PartData] = {
		Vector2i(0, 0): FUEL_TANK, Vector2i(0, 1): THRUSTER, REAR_MIDDLE: THRUSTER,
	}
	var event: RunResult.CardEvent = _resolve_one(GRAVITY_WELL, layout)
	assert_false(event.countered)
	assert_eq(event.extra_fuel_lost, 1)
	assert_eq(event.fuel_after, 3)


func test_calm_space_does_nothing() -> void:
	var layout: Dictionary[Vector2i, PartData] = {Vector2i(0, 0): FUEL_TANK, REAR_MIDDLE: THRUSTER}
	var pool: Array[CardData] = [CALM_SPACE]
	var result: RunResult = RunResolver.resolve(_build(layout), _mission(pool, 0, 1), 1)
	var event: RunResult.CardEvent = result.events[0]
	assert_false(event.countered)
	assert_eq(event.hits.size(), 0)
	assert_eq(event.extra_fuel_lost, 0)
	assert_eq(event.destroyed_cells.size(), 0)
	assert_eq(event.fuel_after, 3)
	assert_true(result.won)


# --- CAP-4: hits, shields, destruction ----------------------------------------

func test_hit_passes_through_destroyed_part() -> void:
	var weak: PartData = _part(PartData.Kind.HULL_PLATING, 1)
	var probe: CardData = _card(CardData.Kind.PIRATE_AMBUSH, 1, 1)
	var pool: Array[CardData] = [probe, probe]
	var layout: Dictionary[Vector2i, PartData] = {Vector2i(0, 0): weak, Vector2i(0, 2): HULL_PLATING, REAR_MIDDLE: THRUSTER}
	var result: RunResult = RunResolver.resolve(_build(layout), _mission(pool), 1)
	assert_eq(result.events[0].hits[0].struck_cell, Vector2i(0, 0))
	assert_true(result.events[0].hits[0].destroyed)
	assert_eq(result.events[0].destroyed_cells, [Vector2i(0, 0)] as Array[Vector2i])
	assert_eq(result.events[1].hits[0].struck_cell, Vector2i(0, 2))


func test_lane_with_only_destroyed_parts_is_a_miss() -> void:
	var weak: PartData = _part(PartData.Kind.HULL_PLATING, 1)
	var probe: CardData = _card(CardData.Kind.PIRATE_AMBUSH, 1, 1)
	var pool: Array[CardData] = [probe, probe]
	var layout: Dictionary[Vector2i, PartData] = {Vector2i(0, 0): weak, REAR_MIDDLE: THRUSTER}
	var result: RunResult = RunResolver.resolve(_build(layout), _mission(pool), 1)
	var hit: RunResult.HitEvent = result.events[1].hits[0]
	assert_true(hit.is_miss())
	assert_eq(hit.damage_to_part, 0)
	assert_eq(hit.shield_cell, NO_CELL)
	assert_eq(result.events[1].destroyed_cells.size(), 0)


func test_double_coverage_draws_from_shield_with_more_capacity() -> void:
	# (0,1) is covered by both shields; the one listed later has more capacity.
	var small: PartData = _part(PartData.Kind.SHIELD, 2, 1)
	var big: PartData = _part(PartData.Kind.SHIELD, 2, 3)
	var layout: Dictionary[Vector2i, PartData] = {
		Vector2i(0, 1): HULL_PLATING, Vector2i(1, 1): small, Vector2i(0, 2): big, REAR_MIDDLE: THRUSTER,
	}
	var hit: RunResult.HitEvent = _resolve_one(_card(CardData.Kind.PIRATE_AMBUSH, 1, 1), layout).hits[0]
	assert_eq(hit.struck_cell, Vector2i(0, 1))
	assert_eq(hit.shield_cell, Vector2i(0, 2))


func test_double_coverage_tie_goes_to_first_shield_in_cell_order() -> void:
	var layout: Dictionary[Vector2i, PartData] = {
		Vector2i(0, 1): HULL_PLATING, Vector2i(1, 1): SHIELD, Vector2i(0, 2): SHIELD, REAR_MIDDLE: THRUSTER,
	}
	var hit: RunResult.HitEvent = _resolve_one(_card(CardData.Kind.PIRATE_AMBUSH, 1, 1), layout).hits[0]
	assert_eq(hit.shield_cell, Vector2i(1, 1))


func test_double_coverage_spreads_damage_across_shields() -> void:
	# Two shields of 2 each cover the cell: 4 of 5 damage absorbed, 1 to the part.
	var layout: Dictionary[Vector2i, PartData] = {
		Vector2i(0, 1): HULL_PLATING, Vector2i(1, 1): SHIELD, Vector2i(0, 2): SHIELD, REAR_MIDDLE: THRUSTER,
	}
	var hit: RunResult.HitEvent = _resolve_one(_card(CardData.Kind.PIRATE_AMBUSH, 1, 5), layout).hits[0]
	assert_eq(hit.absorbed, 4)
	assert_eq(hit.damage_to_part, 1)
	assert_eq(hit.part_hp_after, 3)


func test_exhausted_shield_lets_damage_through() -> void:
	var layout: Dictionary[Vector2i, PartData] = {
		Vector2i(0, 0): HULL_PLATING, Vector2i(1, 0): SHIELD, REAR_MIDDLE: THRUSTER,
	}
	# Hit 1 on (0,0) takes 2 from the shield, hit 2 on the shield itself finds none left.
	var event: RunResult.CardEvent = _resolve_one(_card(CardData.Kind.PIRATE_AMBUSH, 2, 2), layout)
	assert_eq(event.hits[0].absorbed, 2)
	assert_eq(event.hits[0].damage_to_part, 0)
	assert_eq(event.hits[1].struck_cell, Vector2i(1, 0))
	assert_eq(event.hits[1].absorbed, 0)
	assert_eq(event.hits[1].shield_cell, NO_CELL)
	assert_eq(event.hits[1].damage_to_part, 2)
	assert_true(event.hits[1].destroyed)
	assert_false(event.countered)


func test_overkill_damage_stops_at_zero_hp() -> void:
	var layout: Dictionary[Vector2i, PartData] = {Vector2i(0, 0): CARGO_HOLD, REAR_MIDDLE: THRUSTER}
	var event: RunResult.CardEvent = _resolve_one(_card(CardData.Kind.PIRATE_AMBUSH, 1, 3), layout)
	var hit: RunResult.HitEvent = event.hits[0]
	assert_eq(hit.struck_cell, Vector2i(0, 0))
	assert_eq(hit.absorbed, 0)
	assert_eq(hit.damage_to_part, 2)
	assert_eq(hit.part_hp_after, 0)
	assert_true(hit.destroyed)
	assert_eq(event.destroyed_cells, [Vector2i(0, 0)] as Array[Vector2i])


func test_shield_destroyed_mid_card_stops_covering() -> void:
	# Hit 1 drains the weak shield on (0,0), hit 2 destroys it, hit 3 on (2,0),
	# which it covered, takes part damage.
	var weak_shield: PartData = _part(PartData.Kind.SHIELD, 1, 1)
	var layout: Dictionary[Vector2i, PartData] = {
		Vector2i(0, 0): HULL_PLATING, Vector2i(1, 0): weak_shield, Vector2i(2, 0): HULL_PLATING,
		REAR_MIDDLE: THRUSTER,
	}
	var event: RunResult.CardEvent = _resolve_one(_card(CardData.Kind.PIRATE_AMBUSH, 3, 1), layout)
	assert_eq(event.hits[0].shield_cell, Vector2i(1, 0))
	assert_eq(event.hits[0].absorbed, 1)
	assert_eq(event.hits[1].struck_cell, Vector2i(1, 0))
	assert_true(event.hits[1].destroyed)
	assert_eq(event.hits[2].struck_cell, Vector2i(2, 0))
	assert_eq(event.hits[2].absorbed, 0)
	assert_eq(event.hits[2].shield_cell, NO_CELL)
	assert_eq(event.hits[2].damage_to_part, 1)
	assert_eq(event.destroyed_cells, [Vector2i(1, 0)] as Array[Vector2i])


func test_partial_absorption_of_a_multi_damage_hit() -> void:
	var layout: Dictionary[Vector2i, PartData] = {Vector2i(0, 0): SHIELD, REAR_MIDDLE: THRUSTER}
	var hit: RunResult.HitEvent = _resolve_one(_card(CardData.Kind.PIRATE_AMBUSH, 1, 3), layout).hits[0]
	assert_eq(hit.absorbed, 2)
	assert_eq(hit.damage_to_part, 1)
	assert_eq(hit.part_hp_after, 1)


func test_shield_capacity_refreshes_every_card() -> void:
	var probe: CardData = _card(CardData.Kind.PIRATE_AMBUSH, 1, 2)
	var pool: Array[CardData] = [probe, probe]
	var layout: Dictionary[Vector2i, PartData] = {Vector2i(0, 0): HULL_PLATING, Vector2i(1, 0): SHIELD, REAR_MIDDLE: THRUSTER}
	var result: RunResult = RunResolver.resolve(_build(layout), _mission(pool), 1)
	for event: RunResult.CardEvent in result.events:
		assert_eq(event.hits[0].absorbed, 2)
		assert_true(event.countered)


func test_destroyed_tank_caps_fuel_immediately() -> void:
	var layout: Dictionary[Vector2i, PartData] = {
		Vector2i(0, 0): FUEL_TANK, Vector2i(0, 1): FUEL_TANK, REAR_MIDDLE: THRUSTER,
	}
	var pool: Array[CardData] = [_card(CardData.Kind.PIRATE_AMBUSH, 1, 2)]
	var result: RunResult = RunResolver.resolve(_build(layout), _mission(pool, 0, 1), 1)
	assert_eq(result.starting_fuel, 8)
	assert_eq(result.events[0].destroyed_cells, [Vector2i(0, 0)] as Array[Vector2i])
	assert_eq(result.events[0].fuel_after, 4 - 1)


func test_tank_loss_does_not_raise_fuel_below_cap() -> void:
	# Fuel 8 -> leak and burns leave 3 after two cards; losing a tank (cap 4) changes nothing.
	var layout: Dictionary[Vector2i, PartData] = {
		Vector2i(0, 0): FUEL_TANK, Vector2i(0, 1): FUEL_TANK, REAR_MIDDLE: THRUSTER,
	}
	var drain: CardData = _card(CardData.Kind.FUEL_LEAK, 0, 0)
	drain.extra_fuel_loss = 2
	var smash: CardData = _card(CardData.Kind.PIRATE_AMBUSH, 1, 2)
	var pool: Array[CardData] = [drain, drain, smash]
	var build: ShipBuild = _build(layout)
	var mission: MissionData = _mission(pool, 0, 1)
	var result: RunResult = RunResolver.resolve(build, mission, _seed_for_order(build, mission, pool))
	assert_eq(result.events[1].fuel_after, 2)
	assert_eq(result.events[2].destroyed_cells, [Vector2i(0, 0)] as Array[Vector2i])
	assert_eq(result.events[2].fuel_after, 1)


func test_cascade_destroyed_shield_exposes_cargo_to_solar_flare() -> void:
	var layout: Dictionary[Vector2i, PartData] = {
		Vector2i(0, 0): SHIELD, Vector2i(1, 0): CARGO_HOLD, REAR_MIDDLE: THRUSTER,
	}
	var build: ShipBuild = _build(layout)
	# With the shield intact, the flare on the cargo hold is absorbed.
	var flare_only: Array[CardData] = [SOLAR_FLARE]
	var intact: RunResult.CardEvent = RunResolver.resolve(build, _mission(flare_only), 1).events[0]
	assert_eq(intact.hits[1].struck_cell, Vector2i(1, 0))
	assert_eq(intact.hits[1].absorbed, 1)
	assert_eq(intact.hits[1].damage_to_part, 0)
	# An earlier card destroys the shield; the flare then damages the cargo hold.
	var smash: CardData = _card(CardData.Kind.PIRATE_AMBUSH, 1, 4)
	var pool: Array[CardData] = [smash, SOLAR_FLARE]
	var mission: MissionData = _mission(pool)
	var result: RunResult = RunResolver.resolve(build, mission, _seed_for_order(build, mission, pool))
	assert_eq(result.events[0].destroyed_cells, [Vector2i(0, 0)] as Array[Vector2i])
	var flare: RunResult.CardEvent = result.events[1]
	assert_eq(flare.hits.size(), 2, "the destroyed shield is not struck")
	assert_eq(flare.hits[0].struck_cell, Vector2i(1, 0))
	assert_eq(flare.hits[0].absorbed, 0)
	assert_eq(flare.hits[0].damage_to_part, 1)
	assert_false(flare.countered)


# --- CAP-5: win and loss ------------------------------------------------------

func _calm_pool(count: int) -> Array[CardData]:
	var pool: Array[CardData] = []
	for i: int in count:
		pool.append(CALM_SPACE)
	return pool


func test_win_with_fuel_to_spare() -> void:
	var layout: Dictionary[Vector2i, PartData] = {
		Vector2i(0, 0): FUEL_TANK, Vector2i(1, 0): FUEL_TANK, Vector2i(0, 1): CARGO_HOLD,
		Vector2i(1, 1): CARGO_HOLD, REAR_MIDDLE: THRUSTER,
	}
	var result: RunResult = RunResolver.resolve(_build(layout), _mission(_calm_pool(4), 2, 1), 1)
	assert_true(result.won)
	assert_eq(result.loss_reason, RunResult.LossReason.NONE)
	assert_eq(result.events.size(), 4)
	assert_eq(result.events[3].fuel_after, 4)


func test_win_at_exactly_zero_fuel() -> void:
	var layout: Dictionary[Vector2i, PartData] = {Vector2i(0, 0): FUEL_TANK, REAR_MIDDLE: THRUSTER}
	var result: RunResult = RunResolver.resolve(_build(layout), _mission(_calm_pool(4), 0, 1), 1)
	assert_true(result.won)
	assert_eq(result.events.size(), 4)
	assert_eq(result.events[3].fuel_after, 0)


func test_loss_out_of_fuel_stops_the_run() -> void:
	var layout: Dictionary[Vector2i, PartData] = {Vector2i(0, 0): FUEL_TANK, REAR_MIDDLE: THRUSTER}
	var result: RunResult = RunResolver.resolve(_build(layout), _mission(_calm_pool(8), 0, 1), 1)
	assert_false(result.won)
	assert_eq(result.loss_reason, RunResult.LossReason.OUT_OF_FUEL)
	assert_eq(result.events.size(), 5, "no events follow the losing card")
	assert_eq(result.events[4].loss_reason, RunResult.LossReason.OUT_OF_FUEL)
	assert_eq(result.events[3].loss_reason, RunResult.LossReason.NONE)
	assert_eq(result.card_order.size(), 8)


func test_loss_no_thruster() -> void:
	var layout: Dictionary[Vector2i, PartData] = {Vector2i(1, 0): FUEL_TANK, REAR_MIDDLE: THRUSTER}
	var raid: CardData = _card(CardData.Kind.REAR_RAIDER, 1, 2)
	var pool: Array[CardData] = [raid, CALM_SPACE, CALM_SPACE]
	var build: ShipBuild = _build(layout)
	var mission: MissionData = _mission(pool, 0, 0)
	# Find a seed whose raid comes down the middle column.
	for run_seed: int in 200:
		var result: RunResult = RunResolver.resolve(build, mission, run_seed)
		var raid_index: int = result.card_order.find(raid)
		if result.events.size() <= raid_index or result.events[raid_index].hits[0].lane != 1:
			continue
		assert_false(result.won)
		assert_eq(result.loss_reason, RunResult.LossReason.NO_THRUSTER)
		assert_eq(result.events.size(), raid_index + 1, "no events follow the losing card")
		return
	fail_test("no seed sent the raid down the middle column")


func test_thruster_outside_rear_row_loses_after_first_card() -> void:
	var layout: Dictionary[Vector2i, PartData] = {Vector2i(1, 1): THRUSTER}
	var result: RunResult = RunResolver.resolve(_build(layout), _mission(_calm_pool(3)), 1)
	assert_eq(result.loss_reason, RunResult.LossReason.NO_THRUSTER)
	assert_eq(result.events.size(), 1)


func test_loss_cargo_lost() -> void:
	var layout: Dictionary[Vector2i, PartData] = {
		Vector2i(0, 0): CARGO_HOLD, Vector2i(1, 0): HULL_PLATING, Vector2i(2, 0): HULL_PLATING,
		Vector2i(0, 1): CARGO_HOLD, REAR_MIDDLE: THRUSTER,
	}
	var smash: CardData = _card(CardData.Kind.PIRATE_AMBUSH, 1, 2)
	var pool: Array[CardData] = [smash, CALM_SPACE, CALM_SPACE]
	var build: ShipBuild = _build(layout)
	var mission: MissionData = _mission(pool, 2, 0)
	var result: RunResult = RunResolver.resolve(build, mission, _seed_for_order(build, mission, [CALM_SPACE, smash, CALM_SPACE] as Array[CardData]))
	assert_false(result.won)
	assert_eq(result.loss_reason, RunResult.LossReason.CARGO_LOST)
	assert_eq(result.events.size(), 2)
	assert_eq(result.events[0].loss_reason, RunResult.LossReason.NONE)


func test_too_few_cargo_holds_loses_after_first_card() -> void:
	var layout: Dictionary[Vector2i, PartData] = {Vector2i(0, 0): CARGO_HOLD, REAR_MIDDLE: THRUSTER}
	var result: RunResult = RunResolver.resolve(_build(layout), _mission(_calm_pool(3), 2, 0), 1)
	assert_eq(result.loss_reason, RunResult.LossReason.CARGO_LOST)
	assert_eq(result.events.size(), 1)


func test_loss_priority_no_thruster_over_cargo() -> void:
	var layout: Dictionary[Vector2i, PartData] = {
		Vector2i(0, 0): CARGO_HOLD, Vector2i(2, 0): CARGO_HOLD, REAR_MIDDLE: THRUSTER,
	}
	var pool: Array[CardData] = [_card(CardData.Kind.SOLAR_FLARE, 1, 2)]
	var result: RunResult = RunResolver.resolve(_build(layout), _mission(pool, 2, 0), 1)
	assert_eq(result.events[0].destroyed_cells.size(), 3)
	assert_eq(result.loss_reason, RunResult.LossReason.NO_THRUSTER)
	assert_false(result.won)
	assert_eq(result.events.size(), 1)


func test_loss_priority_out_of_fuel_over_cargo() -> void:
	var layout: Dictionary[Vector2i, PartData] = {Vector2i(0, 0): CARGO_HOLD, REAR_MIDDLE: THRUSTER}
	var result: RunResult = RunResolver.resolve(_build(layout), _mission(_calm_pool(2), 2, 1), 1)
	assert_eq(result.loss_reason, RunResult.LossReason.OUT_OF_FUEL)
	assert_eq(result.events.size(), 1)


func test_loss_priority_no_thruster_over_out_of_fuel() -> void:
	var layout: Dictionary[Vector2i, PartData] = {Vector2i(0, 0): CARGO_HOLD}
	var result: RunResult = RunResolver.resolve(_build(layout), _mission(_calm_pool(2), 2, 1), 1)
	assert_eq(result.loss_reason, RunResult.LossReason.NO_THRUSTER)
	assert_false(result.won)
	assert_eq(result.events.size(), 1)


# --- CAP-8: data-driven numbers -----------------------------------------------

func test_starting_fuel_follows_tank_capacity_data() -> void:
	var big_tank: PartData = FUEL_TANK.duplicate() as PartData
	big_tank.fuel_capacity = 7
	var pool: Array[CardData] = [CALM_SPACE]
	var normal: RunResult = RunResolver.resolve(
			_build({Vector2i(0, 0): FUEL_TANK, REAR_MIDDLE: THRUSTER} as Dictionary[Vector2i, PartData]),
			_mission(pool), 1)
	var bigger: RunResult = RunResolver.resolve(
			_build({Vector2i(0, 0): big_tank, Vector2i(1, 0): big_tank, REAR_MIDDLE: THRUSTER} as Dictionary[Vector2i, PartData]),
			_mission(pool), 1)
	assert_eq(normal.starting_fuel, FUEL_TANK.fuel_capacity)
	assert_eq(bigger.starting_fuel, 14)


func test_cargo_run_starting_fuel_is_tanks_times_capacity() -> void:
	var layout: Dictionary[Vector2i, PartData] = {
		Vector2i(0, 0): FUEL_TANK, Vector2i(1, 0): FUEL_TANK, Vector2i(2, 0): FUEL_TANK, REAR_MIDDLE: THRUSTER,
	}
	var result: RunResult = RunResolver.resolve(_build(layout), CARGO_RUN, 5)
	assert_eq(result.starting_fuel, 3 * FUEL_TANK.fuel_capacity)
