extends GdUnitTestSuite

const NOW := 1788782400.0


func _provider(now: float = NOW) -> MockProvider:
	var p := MockProvider.new()
	p.clock = func() -> float: return now
	return p


func test_world_has_seed_and_server_time() -> void:
	var w := _provider().fetch_world()
	assert_str(w["id"]).is_equal("w1")
	assert_int(int(w["seed"])).is_equal(1337)
	assert_str(w["serverTime"]).is_equal("2026-09-07T12:00:00Z")


func test_settlements_are_stamped_with_now_on_first_fetch() -> void:
	var arr := _provider().fetch_settlements()
	assert_int(arr.size()).is_equal(3)
	for d in arr:
		if d.has("resources"):
			assert_str(d["lastSyncAt"]).is_equal("2026-09-07T12:00:00Z")


func test_settlements_lie_on_land_and_buildings_match_biome() -> void:
	var seed_val := int(_provider().fetch_world()["seed"])
	for d in _provider().fetch_settlements():
		var island := WorldGrid.island_at(seed_val, Coord.from_json(d))
		assert_object(island).is_not_null()
		var allowed := Biome.slots(island.biome)
		for k in d.get("buildings", {}).keys():
			var msg := "%s niedozwolony na %s" % [k, Coord.key(island.coord)]
			assert_bool(allowed.has(Buildings.from_key(k))).override_failure_message(msg).is_true()


func test_second_fetch_advances_resources() -> void:
	var p := _provider()
	var first := p.fetch_settlements()
	p.clock = func() -> float: return NOW + 3600.0
	var second := p.fetch_settlements()
	assert_float(second[0]["resources"]["wood"]).is_equal(first[0]["resources"]["wood"] + 120.0)
	assert_str(second[0]["lastSyncAt"]).is_equal("2026-09-07T13:00:00Z")


func test_fleets_have_relative_times() -> void:
	var arr := _provider().fetch_fleets()
	assert_int(arr.size()).is_equal(3)
	var f := Fleet.from_json(arr[0])
	assert_float(f.depart_at).is_equal(NOW - 600.0)
	assert_float(f.arrive_at).is_equal(NOW + 1800.0)
	assert_bool(arr[0].has("departOffsetMin")).is_false()


func test_fleet_endpoints_lie_on_land() -> void:
	var seed_val := int(_provider().fetch_world()["seed"])
	for d in _provider().fetch_fleets():
		assert_object(WorldGrid.island_at(seed_val, Coord.from_json(d["from"]))).is_not_null()
		assert_object(WorldGrid.island_at(seed_val, Coord.from_json(d["to"]))).is_not_null()


func test_advance_caps_at_capacity() -> void:
	var d := {
		"resources": {"wood": 7950.0}, "productionPerHour": {"wood": 120.0},
		"capacity": 8000.0, "lastSyncAt": "2026-09-07T12:00:00Z",
	}
	MockProvider.advance(d, NOW + 3600.0)
	assert_float(d["resources"]["wood"]).is_equal(8000.0)
