extends GdUnitTestSuite


func _plaque(building: int, level: int) -> SlotPlaque:
	var p: SlotPlaque = auto_free(SlotPlaque.new())
	p.setup(building, level)
	add_child(p)
	return p


func test_built_slot_shows_icon_and_level() -> void:
	var p := _plaque(Buildings.Type.SAWMILL, 3)
	assert_str(String((p.get_node("Icon") as Icon).kind)).is_equal("wood")
	assert_str((p.get_node("Level") as Label).text).is_equal("LV 3")
	assert_bool((p.get_node("Level") as Label).visible).is_true()


func test_empty_slot_shows_plus_without_level() -> void:
	var p := _plaque(Buildings.Type.BARRACKS, 0)
	assert_str(String((p.get_node("Icon") as Icon).kind)).is_equal("plus")
	assert_bool((p.get_node("Level") as Label).visible).is_false()


func test_contains_is_rectangular() -> void:
	var p := _plaque(Buildings.Type.TOWN_HALL, 1)
	assert_bool(p.contains(Vector2.ZERO)).is_true()
	assert_bool(p.contains(Vector2(SlotPlaque.WIDTH / 2.0 - 1.0, 0.0))).is_true()
	assert_bool(p.contains(Vector2(SlotPlaque.WIDTH / 2.0 + 1.0, 0.0))).is_false()
	assert_bool(p.contains(Vector2(0.0, SlotPlaque.HEIGHT / 2.0 + 1.0))).is_false()


func test_pressed_moves_children_down() -> void:
	var p := _plaque(Buildings.Type.TOWN_HALL, 1)
	var before: float = (p.get_node("Icon") as Control).position.y
	p.pressed = true
	assert_float((p.get_node("Icon") as Control).position.y).is_equal(before + SlotPlaque.PRESS_TRAVEL)
	p.pressed = false
	assert_float((p.get_node("Icon") as Control).position.y).is_equal(before)
