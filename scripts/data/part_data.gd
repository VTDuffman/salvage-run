class_name PartData
extends Resource
## One ship part type. Values are starting points tuned in the inspector;
## rules read them from here and never hard-code them.

## Saved by number in .tres files: append new values only, never reorder.
enum Kind { THRUSTER, FUEL_TANK, CARGO_HOLD, SHIELD, HULL_PLATING, GUN }

## Grid row a part must sit in to work. Outside it the part is inert but
## still occupies its cell and absorbs hits. Append only (saved by number).
enum RequiredRow { ANY, FRONT, REAR }

## Default is not neutral: files of this kind omit the line. Do not change it.
@export var kind: Kind = Kind.HULL_PLATING
@export var display_name: String = ""
@export_range(1, 99) var max_hp: int = 1
## Placeholder tile color until real art exists.
@export var color: Color = Color.WHITE
@export var required_row: RequiredRow = RequiredRow.ANY

@export_group("Function")
## Fuel this part adds to the shared pool while working (Fuel Tank).
@export_range(0, 99) var fuel_capacity: int = 0
## Damage this part's shield absorbs per card (Shield).
@export_range(0, 99) var shield_capacity: int = 0
