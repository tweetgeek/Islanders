extends GdUnitTestSuite

const DEPART := 1788782400.0
const ARRIVE := DEPART + 3600.0


func _json() -> Dictionary:
	return {
		"id": "f1", "world": "w1", "ownerId": 7, "mission": "EXPEDITION",
		"from": {"x": 0, "y": 0}, "to": {"x": 4, "y": 0},
		"ships": {"SLOOP": 10, "GALLEON": 2},
		"cargo": {"units": {"MILITIA": 20}, "resources": {"iron": 300}},
		"departAt": "2026-09-07T12:00:00Z", "arriveAt": "2026-09-07T13:00:00Z",
	}


func test_from_json() -> void:
	var f := Fleet.from_json(_json())
	assert_object(f).is_not_null()
	assert_str(f.id).is_equal("f1")
	assert_that(f.to).is_equal(Vector2i(4, 0))
	assert_int(f.total_ships()).is_equal(12)
	assert_int(f.cargo_units["MILITIA"]).is_equal(20)
	assert_float(f.cargo_resources["iron"]).is_equal(300.0)
	assert_float(f.depart_at).is_equal(DEPART)
	assert_bool(f.is_own(7)).is_true()
	assert_bool(f.is_own(9)).is_false()


func test_from_json_missing_fields_returns_null() -> void:
	assert_object(Fleet.from_json({"id": "x", "from": {"x": 0, "y": 0}})).is_null()
	assert_object(Fleet.from_json({"from": {"x": 0, "y": 0}, "to": {"x": 1, "y": 1}})).is_null()


func test_incoming_fleet_without_ships() -> void:
	var d := _json()
	d.erase("ships")
	d.erase("cargo")
	var f := Fleet.from_json(d)
	assert_int(f.total_ships()).is_equal(0)


func test_progress() -> void:
	var f := Fleet.from_json(_json())
	assert_float(f.progress(DEPART - 100.0)).is_equal(0.0)
	assert_float(f.progress(DEPART + 1800.0)).is_equal(0.5)
	assert_float(f.progress(ARRIVE + 100.0)).is_equal(1.0)


func test_position_at_midpoint() -> void:
	var f := Fleet.from_json(_json())
	var expected := WorldGrid.cell_to_world(Vector2i(0, 0)).lerp(WorldGrid.cell_to_world(Vector2i(4, 0)), 0.5)
	assert_that(f.position_at(DEPART + 1800.0)).is_equal(expected)


func test_is_arrived_and_remaining() -> void:
	var f := Fleet.from_json(_json())
	assert_bool(f.is_arrived(ARRIVE - 1.0)).is_false()
	assert_bool(f.is_arrived(ARRIVE)).is_true()
	assert_float(f.remaining_seconds(DEPART + 600.0)).is_equal(3000.0)
	assert_float(f.remaining_seconds(ARRIVE + 600.0)).is_equal(0.0)
