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


func test_slots_follow_biome_tropical() -> void:
	var gen := _generator(Biome.Type.TROPICAL, true)
	assert_object(gen.get_node_or_null("Slot_SAWMILL")).is_not_null()
	assert_object(gen.get_node_or_null("Slot_IRON_MINE")).is_null()


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


func test_settlement_levels_reach_plaques() -> void:
	var gen := _generator(Biome.Type.TROPICAL, true)
	var s := Settlement.from_json({"x": 1, "y": 1, "resources": {}, "buildings": {"SAWMILL": 3}}, Biome.Type.TROPICAL)
	gen.settlement = s
	gen.build()
	var plaque: SlotPlaque = gen.get_node("Slot_SAWMILL")
	assert_int(plaque.level).is_equal(3)
	assert_str((plaque.get_node("Level") as Label).text).is_equal("LV 3")
	assert_int((gen.get_node("Slot_FARM") as SlotPlaque).level).is_equal(0)


func test_slot_at_uses_plaque_rectangle_at_detail_radius() -> void:
	var gen := _generator(Biome.Type.TROPICAL, true)
	gen.radius = 400.0
	gen.build()
	assert_int(gen.slot_at(Vector2.ZERO)).is_equal(Buildings.Type.TOWN_HALL)
	assert_int(gen.slot_at(Vector2(SlotPlaque.WIDTH / 2.0 - 1.0, 0.0))).is_equal(Buildings.Type.TOWN_HALL)
	# między plakietką ratusza (do 77 px) a pierścieniem slotów (od 180 - 80 = 100 px) jest pusto
	assert_int(gen.slot_at(Vector2(0.0, 90.0))).is_equal(-1)
	for t in gen._slot_positions:
		assert_int(gen.slot_at(gen._slot_positions[t])).is_equal(t)


func test_set_pressed_reaches_plaque() -> void:
	var gen := _generator(Biome.Type.TROPICAL, true)
	gen.set_pressed(Buildings.Type.TOWN_HALL, true)
	assert_bool((gen.get_node("Slot_TOWN_HALL") as SlotPlaque).pressed).is_true()
	gen.set_pressed(Buildings.Type.TOWN_HALL, false)
	assert_bool((gen.get_node("Slot_TOWN_HALL") as SlotPlaque).pressed).is_false()


func test_clear_removes_everything() -> void:
	var gen := _generator(Biome.Type.TROPICAL, true)
	gen.clear()
	assert_int(gen.get_child_count()).is_equal(0)
	assert_int(gen.slot_at(Vector2.ZERO)).is_equal(-1)


## Test prześwitu między wyspami (world_map_test) mierzy shallow_outline(), więc musi to być
## dokładnie ten wielokąt, który build() rysuje jako "Shallow".
func test_shallow_outline_is_what_build_draws() -> void:
	var gen := _generator(Biome.Type.TROPICAL, false)
	var drawn: Polygon2D = gen.get_node("Shallow")
	assert_that(drawn.polygon).is_equal(IslandGenerator.shallow_outline(gen.seed_val, gen.radius))
