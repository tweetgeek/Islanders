extends GdUnitTestSuite


func test_each_biome_has_two_resources_and_two_extraction_buildings() -> void:
	for b in Biome.Type.values():
		assert_int(Biome.resources(b).size()).is_equal(2)
		assert_int(Biome.extraction_buildings(b).size()).is_equal(2)
		for t in Biome.extraction_buildings(b):
			assert_bool(Biome.resources(b).has(Buildings.EXTRACTS[t])).is_true()


func test_slots_are_six_with_common_first() -> void:
	var slots := Biome.slots(Biome.Type.VOLCANIC)
	assert_int(slots.size()).is_equal(6)
	assert_that(slots.slice(0, 4)).is_equal(Buildings.COMMON)
	assert_bool(slots.has(Buildings.Type.IRON_MINE)).is_true()
	assert_bool(slots.has(Buildings.Type.SAWMILL)).is_false()


func test_unknown_biome_falls_back_to_temperate() -> void:
	assert_int(Biome.from_key("XYZ")).is_equal(Biome.Type.TEMPERATE)
	assert_int(Biome.from_key("VOLCANIC")).is_equal(Biome.Type.VOLCANIC)


func test_mock_production_has_all_five_keys() -> void:
	var p := Biome.mock_production(Biome.Type.TROPICAL)
	assert_int(p.size()).is_equal(5)
	assert_float(p["wood"]).is_greater(0.0)
	assert_float(p["iron"]).is_equal(0.0)


func test_resource_types_normalize_drops_unknown_keys() -> void:
	var d := ResourceTypes.normalize({"wood": 5, "gold": 9})
	assert_int(d.size()).is_equal(5)
	assert_float(d["wood"]).is_equal(5.0)
	assert_bool(d.has("gold")).is_false()


func test_buildings_key_roundtrip() -> void:
	for t in Buildings.Type.values():
		assert_int(Buildings.from_key(Buildings.key(t))).is_equal(t)
	assert_int(Buildings.from_key("CASTLE")).is_equal(-1)
