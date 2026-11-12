extends GutTest
## cargo_run.tres is well-formed: six parts, eight distinct cards, no nulls,
## every part and card kind exactly once, a thruster on offer, and every part
## and card named and saved in its own file. The only test that loads shipped
## data: it checks structure, never tuning numbers, so values can change freely
## in the inspector. Rule tests use test/support/fixtures.gd instead.

const CARGO_RUN_PATH: String = "res://data/missions/cargo_run.tres"

var _mission: MissionData


func before_all() -> void:
	_mission = load(CARGO_RUN_PATH) as MissionData


func test_mission_loads() -> void:
	assert_not_null(_mission)


func test_six_parts_without_nulls() -> void:
	assert_eq(_mission.parts.size(), 6)
	for part: PartData in _mission.parts:
		assert_not_null(part)


func test_eight_cards_without_nulls_or_duplicates() -> void:
	assert_eq(_mission.card_pool.size(), 8)
	for card: CardData in _mission.card_pool:
		assert_not_null(card)
		assert_eq(_mission.card_pool.count(card), 1, "duplicate card %s" % card.display_name)


func test_every_part_kind_exactly_once() -> void:
	for kind: int in PartData.Kind.values():
		var count: int = 0
		for part: PartData in _mission.parts:
			if part != null and part.kind == kind:
				count += 1
		assert_eq(count, 1, "PartData.Kind %s" % PartData.Kind.keys()[kind])


func test_every_card_kind_exactly_once() -> void:
	for kind: int in CardData.Kind.values():
		var count: int = 0
		for card: CardData in _mission.card_pool:
			if card != null and card.kind == kind:
				count += 1
		assert_eq(count, 1, "CardData.Kind %s" % CardData.Kind.keys()[kind])


func test_a_thruster_is_on_offer() -> void:
	var has_thruster: bool = false
	for part: PartData in _mission.parts:
		if part != null and part.kind == PartData.Kind.THRUSTER:
			has_thruster = true
	assert_true(has_thruster)


## Playtest log ids are the file basenames, so each part and card needs a name
## and its own .tres file rather than an embedded sub-resource.
func test_every_part_and_card_is_named_and_in_its_own_file() -> void:
	var resources: Array[Resource] = []
	resources.append_array(_mission.parts)
	resources.append_array(_mission.card_pool)
	for resource: Resource in resources:
		if resource == null:
			continue
		var display_name: String = resource.get("display_name")
		assert_false(display_name.is_empty(), "%s has no display_name" % resource.resource_path)
		assert_true(resource.resource_path.ends_with(".tres") and not resource.resource_path.contains("::"),
				"%s is not saved in its own file" % display_name)
