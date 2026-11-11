class_name MissionData
extends Resource
## A mission: what the ship must deliver, the parts on offer, and the card
## pool the run seed shuffles. The single entry point for slice content.

@export var display_name: String = ""
## Intact cargo holds required; fewer at any point is a loss.
@export_range(0, 9) var cargo_required: int = 0
## Fuel burned after every card.
@export_range(0, 99) var fuel_per_card: int = 0
## Parts offered in the build palette, in display order.
@export var parts: Array[PartData] = []
## Cards shuffled into the run; each appears exactly once.
@export var card_pool: Array[CardData] = []
