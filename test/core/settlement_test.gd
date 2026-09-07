extends GdUnitTestSuite

const SYNC := "2026-09-07T12:00:00Z"
const SYNC_UNIX := 1788782400.0


func _own_json() -> Dictionary:
	return {
		"world": "w1", "x": 10, "y": 15, "ownerId": 7, "name": "Koralowa",
		"resources": {"wood": 500, "stone": 200, "food": 1000},
		"productionPerHour": {"wood": 120, "food": 200},
		"capacity": 8000, "population": 42, "populationMax": 120,
		"buildings": {"TOWN_HALL": 1, "SAWMILL": 2, "FARM": 1},
		"lastSyncAt": SYNC,
	}


func test_from_json_full() -> void:
	var s := Settlement.from_json(_own_json(), Biome.Type.TROPICAL)
	assert_object(s).is_not_null()
	assert_bool(s.is_own).is_true()
	assert_that(s.coord).is_equal(Vector2i(10, 15))
	assert_str(s.name).is_equal("Koralowa")
	assert_float(s.resources["wood"]).is_equal(500.0)
	assert_float(s.resources["iron"]).is_equal(0.0)
	assert_float(s.capacity).is_equal(8000.0)
	assert_int(s.level(Buildings.Type.SAWMILL)).is_equal(2)
	assert_int(s.level(Buildings.Type.BARRACKS)).is_equal(0)
	assert_float(s.last_sync_at).is_equal(SYNC_UNIX)


func test_from_json_public_only() -> void:
	var s := Settlement.from_json({"x": 1, "y": 2, "ownerId": 9, "name": "Obca"}, Biome.Type.VOLCANIC)
	assert_bool(s.is_own).is_false()
	assert_int(s.owner_id).is_equal(9)
	assert_float(s.current_resources(SYNC_UNIX)["wood"]).is_equal(0.0)


func test_from_json_without_coords_returns_null() -> void:
	assert_object(Settlement.from_json({"ownerId": 1}, Biome.Type.TEMPERATE)).is_null()


func test_building_outside_biome_is_ignored() -> void:
	var d := _own_json()
	d["buildings"]["QUARRY"] = 3
	var s := Settlement.from_json(d, Biome.Type.TROPICAL)
	assert_int(s.level(Buildings.Type.QUARRY)).is_equal(0)
	assert_int(s.level(Buildings.Type.SAWMILL)).is_equal(2)


func test_current_resources_at_sync_time() -> void:
	var s := Settlement.from_json(_own_json(), Biome.Type.TROPICAL)
	var r := s.current_resources(SYNC_UNIX)
	assert_float(r["wood"]).is_equal(500.0)
	assert_float(r["food"]).is_equal(1000.0)


func test_current_resources_after_two_hours() -> void:
	var s := Settlement.from_json(_own_json(), Biome.Type.TROPICAL)
	var r := s.current_resources(SYNC_UNIX + 7200.0)
	assert_float(r["wood"]).is_equal(740.0)
	assert_float(r["food"]).is_equal(1400.0)
	assert_float(r["stone"]).is_equal(200.0)


func test_current_resources_capped() -> void:
	var s := Settlement.from_json(_own_json(), Biome.Type.TROPICAL)
	var r := s.current_resources(SYNC_UNIX + 3600.0 * 1000.0)
	assert_float(r["wood"]).is_equal(8000.0)
	assert_float(r["food"]).is_equal(8000.0)


func test_current_resources_negative_delta_does_not_go_back() -> void:
	var s := Settlement.from_json(_own_json(), Biome.Type.TROPICAL)
	assert_float(s.current_resources(SYNC_UNIX - 3600.0)["wood"]).is_equal(500.0)


func test_produces() -> void:
	var s := Settlement.from_json(_own_json(), Biome.Type.TROPICAL)
	assert_bool(s.produces("wood")).is_true()
	assert_bool(s.produces("iron")).is_false()
