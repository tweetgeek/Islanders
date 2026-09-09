extends GdUnitTestSuite

const SHEET := preload("res://scenes/ui/BuildingSheet.tscn")


func _settlement() -> Settlement:
	return Settlement.from_json({
		"x": FixtureCells.HOME.x, "y": FixtureCells.HOME.y, "ownerId": 7, "name": "Koralowa",
		"resources": {"wood": 100}, "buildings": {"TOWN_HALL": 1, "SAWMILL": 2},
	}, Biome.Type.TROPICAL)


func _sheet() -> BuildingSheet:
	var s: BuildingSheet = auto_free(SHEET.instantiate())
	add_child(s)
	return s


func test_open_fills_header_and_hides_cost_and_timer() -> void:
	var s := _sheet()
	assert_bool(s.open(_settlement(), Buildings.Type.SAWMILL)).is_true()
	assert_str(s.name_label.text).is_equal("Tartak")
	assert_str(s.level_badge.text).is_equal("LV 2")
	assert_str(s.subtitle.text).is_equal("Koralowa · slot 5 z 6")
	assert_str(s.description.text).is_equal(Buildings.DESCRIPTIONS[Buildings.Type.SAWMILL])
	assert_str(s.upgrade_button.text).is_equal("ULEPSZ")
	assert_bool(s.cost_section.visible).is_false()
	assert_bool(s.timer_section.visible).is_false()
	assert_bool(s.upgrade_button.disabled).is_false()


func test_empty_slot_offers_build() -> void:
	var s := _sheet()
	s.open(_settlement(), Buildings.Type.BARRACKS)
	assert_str(s.level_badge.text).is_equal("LV 0")
	assert_str(s.upgrade_button.text).is_equal("BUDUJ")


func test_building_outside_biome_is_rejected() -> void:
	var s := _sheet()
	await assert_error(func() -> void: s.open(_settlement(), Buildings.Type.IRON_MINE)) \
		.is_push_error("BuildingSheet: budynek IRON_MINE poza slotami biomu TROPICAL")


func test_refresh_costs_marks_short_resources() -> void:
	var s := _sheet()
	s.open(_settlement(), Buildings.Type.SAWMILL)
	s.refresh_costs({"wood": 50, "stone": 200}, {"wood": 100, "stone": 20})
	assert_bool(s.cost_section.visible).is_true()
	assert_bool(s.cost_chips["wood"].visible).is_true()
	assert_bool(s.cost_chips["food"].visible).is_false()
	var stone_chip: PanelContainer = s.cost_chips["stone"]
	var sb: StyleBoxFlat = stone_chip.get_theme_stylebox("panel")
	assert_that(sb.bg_color).is_equal(MedievalTheme.SHORT_BG)
	assert_str(s.cost_header.text).is_equal("KOSZT ULEPSZENIA DO 3")


func test_refresh_timer_disables_upgrade_until_done() -> void:
	var s := _sheet()
	s.open(_settlement(), Buildings.Type.SAWMILL)
	s.refresh_timer(90.0, 180.0)
	assert_bool(s.timer_section.visible).is_true()
	assert_str(s.timer_label.text).is_equal("00:01:30")
	assert_float(s.construction_bar.value).is_equal_approx(0.5, 0.001)
	assert_bool(s.upgrade_button.disabled).is_true()
	s.refresh_timer(0.0, 180.0)
	assert_bool(s.upgrade_button.disabled).is_false()


func test_upgrade_emits_coord_and_building() -> void:
	var s := _sheet()
	s.open(_settlement(), Buildings.Type.SAWMILL)
	var got: Array = []
	s.upgrade_requested.connect(func(c: Vector2i, b: int) -> void: got.append([c, b]))
	s.upgrade_button.pressed.emit()
	assert_that(got).is_equal([[FixtureCells.HOME, Buildings.Type.SAWMILL]])
