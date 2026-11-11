class_name CardData
extends Resource
## One challenge card. The resolver picks the card's behavior by [member kind]
## and reads every number from these fields.

## Saved by number in .tres files: append new values only, never reorder.
enum Kind {
	PIRATE_AMBUSH,
	ASTEROID_FIELD,
	DEBRIS_STRIKE,
	REAR_RAIDER,
	SOLAR_FLARE,
	FUEL_LEAK,
	GRAVITY_WELL,
	CALM_SPACE,
}

## Where the card's damage comes from. FLANK is a random side per the run seed.
## Append only (saved by number).
enum Direction { NONE, FRONT, FLANK, REAR, ALL, INTERNAL }

## Default is not neutral: files of this kind omit the line. Do not change it.
@export var kind: Kind = Kind.CALM_SPACE
@export var display_name: String = ""
@export var direction: Direction = Direction.NONE

@export_group("Effect")
## Hits when uncountered. Pirate Ambush: one down each front column (count must
## match the grid width). Asteroid Field: random front lanes, picked
## independently. Debris Strike / Rear Raider: random lanes. Solar Flare: per part.
@export_range(0, 99) var hits: int = 0
@export_range(0, 99) var damage_per_hit: int = 0
## Fuel lost on top of the normal per-card burn when uncountered.
@export_range(0, 99) var extra_fuel_loss: int = 0
## Working parts needed to counter (Pirate Ambush: front-row guns,
## Fuel Leak: tanks, Gravity Well: rear-row thrusters).
@export_range(0, 99) var counter_threshold: int = 0

@export_group("Log text")
@export_multiline var countered_text: String = ""
@export_multiline var uncountered_text: String = ""
