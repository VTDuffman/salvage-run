extends RefCounted
## Test-owned parts, cards and mission, built in code so no test depends on the
## shipped tuning in res://data/. Designers can change any value in the
## inspector without breaking a test; only test_cargo_run_data.gd loads the
## real .tres files, and it checks structure only.
##
## The values are fixed numbers the rule tests are written against (they match
## the pre-tuning slice data). The mission lists parts and cards in the same
## order as cargo_run.tres, so a seed shuffles the fixture pool the same way.
## Every instance is fresh per Fixtures.new(); tests must not mutate them.

var thruster: PartData = _part(PartData.Kind.THRUSTER, "Thruster", 2, Color(0.85, 0.51, 0.17), PartData.RequiredRow.REAR)
var fuel_tank: PartData = _part(PartData.Kind.FUEL_TANK, "Fuel Tank", 2, Color(0.77, 0.28, 0.24), PartData.RequiredRow.ANY, 4)
var cargo_hold: PartData = _part(PartData.Kind.CARGO_HOLD, "Cargo Hold", 2, Color(0.63, 0.47, 0.29))
var shield: PartData = _part(PartData.Kind.SHIELD, "Shield", 2, Color(0.31, 0.64, 0.85), PartData.RequiredRow.ANY, 0, 2)
var hull_plating: PartData = _part(PartData.Kind.HULL_PLATING, "Hull Plating", 4, Color(0.54, 0.58, 0.65))
var gun: PartData = _part(PartData.Kind.GUN, "Gun", 2, Color(0.49, 0.77, 0.35), PartData.RequiredRow.FRONT)

var pirate_ambush: CardData = _card(CardData.Kind.PIRATE_AMBUSH, "Pirate Ambush", CardData.Direction.FRONT,
		3, 1, 0, 1, "your gun drove them off", "pirates raked the front")
var asteroid_field: CardData = _card(CardData.Kind.ASTEROID_FIELD, "Asteroid Field", CardData.Direction.FRONT,
		2, 1, 0, 0, "shields deflected the rocks", "asteroids struck the front")
var debris_strike: CardData = _card(CardData.Kind.DEBRIS_STRIKE, "Debris Strike", CardData.Direction.FLANK,
		1, 1, 0, 0, "shields caught the debris", "debris hit a flank")
var rear_raider: CardData = _card(CardData.Kind.REAR_RAIDER, "Rear Raider", CardData.Direction.REAR,
		1, 1, 0, 0, "shields turned the raider away", "a raider hit the rear")
var solar_flare: CardData = _card(CardData.Kind.SOLAR_FLARE, "Solar Flare", CardData.Direction.ALL,
		1, 1, 0, 0, "shields soaked up the flare", "the flare scorched every unshielded part")
var fuel_leak: CardData = _card(CardData.Kind.FUEL_LEAK, "Fuel Leak", CardData.Direction.INTERNAL,
		0, 0, 2, 2, "spare tanks covered the leak", "fuel leaked away")
var gravity_well: CardData = _card(CardData.Kind.GRAVITY_WELL, "Gravity Well", CardData.Direction.INTERNAL,
		0, 0, 1, 2, "twin thrusters pulled free", "the well dragged on the engines")
var calm_space: CardData = _card(CardData.Kind.CALM_SPACE, "Calm Space", CardData.Direction.NONE,
		0, 0, 0, 0, "", "quiet stretch of space")

var cargo_run: MissionData = _mission()


func _part(kind: PartData.Kind, display_name: String, max_hp: int, color: Color,
		required_row: PartData.RequiredRow = PartData.RequiredRow.ANY,
		fuel_capacity: int = 0, shield_capacity: int = 0) -> PartData:
	var part: PartData = PartData.new()
	part.kind = kind
	part.display_name = display_name
	part.max_hp = max_hp
	part.color = color
	part.required_row = required_row
	part.fuel_capacity = fuel_capacity
	part.shield_capacity = shield_capacity
	return part


func _card(kind: CardData.Kind, display_name: String, direction: CardData.Direction,
		hits: int, damage_per_hit: int, extra_fuel_loss: int, counter_threshold: int,
		countered_text: String, uncountered_text: String) -> CardData:
	var card: CardData = CardData.new()
	card.kind = kind
	card.display_name = display_name
	card.direction = direction
	card.hits = hits
	card.damage_per_hit = damage_per_hit
	card.extra_fuel_loss = extra_fuel_loss
	card.counter_threshold = counter_threshold
	card.countered_text = countered_text
	card.uncountered_text = uncountered_text
	return card


func _mission() -> MissionData:
	var mission: MissionData = MissionData.new()
	mission.display_name = "Cargo Run"
	mission.cargo_required = 2
	mission.fuel_per_card = 1
	mission.parts = [thruster, fuel_tank, cargo_hold, shield, hull_plating, gun]
	mission.card_pool = [pirate_ambush, asteroid_field, debris_strike, rear_raider,
			solar_flare, fuel_leak, gravity_well, calm_space]
	return mission
