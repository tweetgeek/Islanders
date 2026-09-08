extends GdUnitTestSuite

const SHEET := preload("res://scenes/ui/FleetsSheet.tscn")


func before_test() -> void:
	GameState.reset()
	GameState.apply_world(FixtureCells.world_json())


func after_test() -> void:
	GameState.reset()


func _fleet(id: String, owner: int, arrive_in: float) -> Dictionary:
	var now := TimeUtil.now()
	return {
		"id": id, "ownerId": owner, "mission": "TRANSPORT",
		"from": {"x": 0, "y": 0}, "to": {"x": 4, "y": 0}, "ships": {"SLOOP": 1},
		"departAt": TimeUtil.to_iso8601(now - 60.0), "arriveAt": TimeUtil.to_iso8601(now + arrive_in),
	}


func _sheet() -> FleetsSheet:
	var s: FleetsSheet = auto_free(SHEET.instantiate())
	add_child(s)
	return s


func test_refresh_splits_incoming_and_own_and_skips_arrived() -> void:
	GameState.apply_fleets([_fleet("a", 7, 600.0), _fleet("b", 9, 300.0), _fleet("c", 7, -5.0), _fleet("d", 7, 100.0)])
	var s := _sheet()
	s.refresh()
	assert_int(s.cards().size()).is_equal(3)
	assert_bool(s.incoming_header.visible).is_true()
	assert_str(s.incoming_header.text).is_equal("NADCHODZĄCE · 1")
	assert_str(s.own_header.text).is_equal("W DRODZE · 2")
	assert_bool(s.empty_label.visible).is_false()
	# kolejność: nagłówek nadchodzących, karta b, nagłówek własnych, karta d (100 s), karta a (600 s)
	var order: Array = []
	for c in s.list.get_children():
		if c is FleetCard:
			order.append((c as FleetCard).fleet.id)
	assert_that(order).is_equal(["b", "d", "a"])


func test_empty_state() -> void:
	var s := _sheet()
	s.refresh()
	assert_int(s.cards().size()).is_equal(0)
	assert_bool(s.incoming_header.visible).is_false()
	assert_bool(s.own_header.visible).is_false()
	assert_bool(s.empty_label.visible).is_true()


func test_card_tap_is_forwarded() -> void:
	GameState.apply_fleets([_fleet("a", 7, 600.0)])
	var s := _sheet()
	s.refresh()
	var got: Array = []
	s.fleet_tapped.connect(func(f: Fleet) -> void: got.append(f.id))
	(s.cards()[0] as FleetCard).tapped.emit((s.cards()[0] as FleetCard).fleet)
	assert_that(got).is_equal(["a"])
