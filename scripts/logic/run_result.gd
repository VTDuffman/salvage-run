class_name RunResult
extends RefCounted
## The full outcome of one resolved run: the shuffled card order, one event per
## resolved card with per-hit detail, and whether the run was won. Produced by
## RunResolver; playback only displays it and never re-derives a rule.

## Why a run was lost. When several apply on the same card, the first one in
## this order is reported.
enum LossReason { NONE, NO_THRUSTER, OUT_OF_FUEL, CARGO_LOST }

## Which side of the grid a hit came from. NONE is used for Solar Flare, which
## strikes parts directly instead of travelling down a lane.
enum Side { NONE, FRONT, REAR, LEFT, RIGHT }

## Stands in for "no cell" (a miss, or no shield absorbed the damage).
const NO_CELL: Vector2i = Vector2i(-1, -1)

## The seed the run was resolved with.
var seed: int = 0
## Every card in the pool in shuffled order, including cards after a loss.
var card_order: Array[CardData] = []
var starting_fuel: int = 0
## One event per resolved card. Stops at the losing card.
var events: Array[CardEvent] = []
var won: bool = false
var loss_reason: LossReason = LossReason.NONE


## What happened when one card resolved.
class CardEvent:
	extends RefCounted

	var card: CardData
	## True when the card was cancelled outright, or when no part lost HP and at
	## least one hit was absorbed by a shield.
	var countered: bool = false
	var hits: Array[HitEvent] = []
	## Fuel lost by the card's effect, on top of the per-card burn.
	var extra_fuel_lost: int = 0
	## Fuel after the card's effect and burn. Negative means the ship ran dry.
	var fuel_after: int = 0
	## Cells whose parts were destroyed by this card, in destruction order.
	var destroyed_cells: Array[Vector2i] = []
	## The loss this card caused, or NONE.
	var loss_reason: RunResult.LossReason = RunResult.LossReason.NONE


## One hit of a card: where it came from, what it struck, and the damage.
class HitEvent:
	extends RefCounted

	var entry_side: RunResult.Side = RunResult.Side.NONE
	## Column for FRONT/REAR hits, row for LEFT/RIGHT hits, -1 for Solar Flare.
	var lane: int = -1
	## The struck cell, or NO_CELL for a miss.
	var struck_cell: Vector2i = RunResult.NO_CELL
	## The first shield that absorbed damage from this hit, or NO_CELL.
	var shield_cell: Vector2i = RunResult.NO_CELL
	## Damage drawn from shield capacity.
	var absorbed: int = 0
	## Damage dealt to the struck part's HP.
	var damage_to_part: int = 0
	## The struck part's HP after the hit (0 for a miss).
	var part_hp_after: int = 0
	var destroyed: bool = false

	func is_miss() -> bool:
		return struck_cell == RunResult.NO_CELL
