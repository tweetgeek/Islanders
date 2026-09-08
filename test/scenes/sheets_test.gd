extends GdUnitTestSuite

const SHEETS := preload("res://scenes/ui/Sheets.tscn")


func before_test() -> void:
	GameState.reset()


func after_test() -> void:
	GameState.reset()


func _sheets() -> CanvasLayer:
	var s: CanvasLayer = auto_free(SHEETS.instantiate())
	add_child(s)
	return s


func _settlement() -> Settlement:
	return Settlement.from_json({
		"x": FixtureCells.HOME.x, "y": FixtureCells.HOME.y, "ownerId": 7, "name": "Koralowa",
		"resources": {},
	}, Biome.Type.TROPICAL)


func test_starts_closed_and_hidden() -> void:
	var s := _sheets()
	assert_bool(s.visible).is_false()
	assert_bool(s.is_open()).is_false()
	assert_bool(s.is_in_group("sheets")).is_true()


func test_open_building_shows_layer_and_sheet() -> void:
	var s := _sheets()
	assert_bool(s.open_building(_settlement(), Buildings.Type.TOWN_HALL)).is_true()
	assert_bool(s.visible).is_true()
	assert_bool(s.is_open()).is_true()
	assert_object(s.current_sheet()).is_same(s.building_sheet)
	assert_bool(s.building_sheet.visible).is_true()


func test_rejected_building_keeps_layer_closed() -> void:
	var s := _sheets()
	await assert_error(func() -> void: s.open_building(_settlement(), Buildings.Type.IRON_MINE)) \
		.is_push_error("BuildingSheet: budynek IRON_MINE poza slotami biomu TROPICAL")
	assert_bool(s.is_open()).is_false()
	assert_bool(s.visible).is_false()


func test_close_hides_layer_after_animation() -> void:
	var s := _sheets()
	s.open_building(_settlement(), Buildings.Type.TOWN_HALL)
	s.close()
	assert_bool(s.is_open()).is_false()
	await await_millis(500)
	assert_bool(s.visible).is_false()
	assert_bool(s.building_sheet.visible).is_false()


func test_backdrop_touch_closes() -> void:
	var s := _sheets()
	s.open_building(_settlement(), Buildings.Type.TOWN_HALL)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	s.backdrop.gui_input.emit(touch)
	assert_bool(s.is_open()).is_false()


func test_view_change_closes_immediately() -> void:
	var s := _sheets()
	s.open_building(_settlement(), Buildings.Type.TOWN_HALL)
	SceneManager.view_changed.emit("x")
	assert_bool(s.is_open()).is_false()
	assert_bool(s.visible).is_false()


func test_upgrade_is_forwarded_and_closes() -> void:
	var s := _sheets()
	var got: Array = []
	s.upgrade_requested.connect(func(c: Vector2i, b: int) -> void: got.append(b))
	s.open_building(_settlement(), Buildings.Type.TOWN_HALL)
	s.building_sheet.upgrade_button.pressed.emit()
	assert_that(got).is_equal([Buildings.Type.TOWN_HALL])
	assert_bool(s.is_open()).is_false()


func test_open_inspect_on_sea_keeps_layer_closed() -> void:
	var s := _sheets()
	GameState.apply_world(FixtureCells.world_json())
	await assert_error(func() -> void: s.open_inspect(FixtureCells.SEA)) \
		.is_push_error("InspectSheet: %s nie jest wyspą" % FixtureCells.SEA)
	assert_bool(s.is_open()).is_false()


func test_open_inspect_replaces_open_building_sheet() -> void:
	var s := _sheets()
	GameState.apply_world(FixtureCells.world_json())
	s.open_building(_settlement(), Buildings.Type.TOWN_HALL)
	assert_bool(s.open_inspect(FixtureCells.DEPOSIT)).is_true()
	assert_object(s.current_sheet()).is_same(s.inspect_sheet)
	assert_bool(s.building_sheet.visible).is_false()
	assert_bool(s.inspect_sheet.visible).is_true()


func test_open_fleets_shows_fleets_sheet() -> void:
	var s := _sheets()
	s.open_fleets()
	assert_object(s.current_sheet()).is_same(s.fleets_sheet)
	assert_bool(s.fleets_sheet.visible).is_true()
