extends GdUnitTestSuite


func _generator(biome: Biome.Type, slots: bool) -> IslandGenerator:
	var gen: IslandGenerator = auto_free(IslandGenerator.new())
	gen.seed_val = 84920
	gen.radius = 100.0
	gen.biome = biome
	gen.show_slots = slots
	add_child(gen)
	return gen


func test_map_mode_draws_three_polygons_and_coast() -> void:
	var gen := _generator(Biome.Type.TROPICAL, false)
	assert_int(gen.get_child_count()).is_equal(4)
	assert_object(gen.get_node("Shallow")).is_instanceof(Polygon2D)
	assert_object(gen.get_node("Sand")).is_instanceof(Polygon2D)
	assert_object(gen.get_node("Land")).is_instanceof(Polygon2D)
	assert_object(gen.get_node("Coast")).is_instanceof(Line2D)
	assert_int((gen.get_node("Coast") as Line2D).points.size()).is_equal(IslandGenerator.POINTS)


func test_volcanic_adds_crater() -> void:
	var gen := _generator(Biome.Type.VOLCANIC, false)
	assert_object(gen.get_node_or_null("Crater")).is_not_null()


func test_slots_follow_biome() -> void:
	var gen := _generator(Biome.Type.VOLCANIC, true)
	assert_int(gen.get_child_count()).is_equal(5 + 6)
	assert_object(gen.get_node_or_null("Slot_IRON_MINE")).is_not_null()
	assert_object(gen.get_node_or_null("Slot_SAWMILL")).is_null()
	assert_int(gen.slot_at(Vector2.ZERO)).is_equal(Buildings.Type.TOWN_HALL)
	assert_int(gen.slot_at(Vector2(9999, 0))).is_equal(-1)


func test_deposit_marker_only_when_requested() -> void:
	var gen := _generator(Biome.Type.TEMPERATE, false)
	gen.deposit = {"iron": 300.0}
	gen.build()
	assert_object(gen.get_node_or_null("Deposit")).is_null()
	gen.show_deposit = true
	gen.build()
	assert_object(gen.get_node_or_null("Deposit")).is_not_null()


func test_rebuild_clears_previous_children() -> void:
	var gen := _generator(Biome.Type.TROPICAL, true)
	var before := gen.get_child_count()
	gen.build()
	assert_int(gen.get_child_count()).is_equal(before)


func test_settlement_levels_reach_labels() -> void:
	var gen := _generator(Biome.Type.TROPICAL, true)
	var s := Settlement.from_json({"x": 1, "y": 1, "resources": {}, "buildings": {"SAWMILL": 3}}, Biome.Type.TROPICAL)
	gen.settlement = s
	gen.build()
	var label: Label = gen.get_node("Slot_SAWMILL").get_child(2)
	assert_str(label.text).is_equal("Tartak\n3")
