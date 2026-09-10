extends GdUnitTestSuite

const SHEETS := preload("res://scenes/ui/Sheets.tscn")

var _container: Node = null


func before_test() -> void:
	GameState.reset()
	_container = Node.new()
	add_child(_container)
	SceneManager.register_container(_container)


func after_test() -> void:
	# Najpierw zrywamy referencje autoloadu, potem zwalniamy węzły.
	SceneManager._current = null
	SceneManager.current_view = ""
	SceneManager.register_container(null)
	SceneManager.map_camera_state.clear()
	if is_instance_valid(_container):
		_container.queue_free()
	_container = null
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


## Regresja: _layout() liczony zanim panel dostał realną szerokość (przed panel.show()
## przechodzącym przez kontenery) sprawiał, że autowrapowany Label (np. Description) mierzył się
## przy szerokości 0 i zawyżał swój minimalny rozmiar, przez co PanelContainer rósł poza
## przydzielony ułamek ekranu i zostawał tak na stałe (nic później nie woła _layout() ponownie).
func test_building_sheet_height_matches_fraction() -> void:
	var s := _sheets()
	s.open_building(_settlement(), Buildings.Type.TOWN_HALL)
	await await_idle_frame()
	await await_idle_frame()
	var vis_h: float = get_viewport().get_visible_rect().size.y
	var expected: float = vis_h * s.HEIGHT_BUILDING
	assert_float(s.building_sheet.size.y).is_between(expected - 2.0, expected + 2.0)


func test_inspect_sheet_height_matches_fraction() -> void:
	var s := _sheets()
	GameState.apply_world(FixtureCells.world_json())
	GameState.apply_settlements([{"x": FixtureCells.FOREIGN.x, "y": FixtureCells.FOREIGN.y, "ownerId": 9, "name": "Szara Skała"}])
	assert_bool(s.open_inspect(FixtureCells.FOREIGN)).is_true()
	await await_idle_frame()
	await await_idle_frame()
	var vis_h: float = get_viewport().get_visible_rect().size.y
	var expected: float = vis_h * s.HEIGHT_INSPECT
	assert_float(s.inspect_sheet.size.y).is_between(expected - 2.0, expected + 2.0)


func test_sheet_margins_and_body_separation_are_gaps() -> void:
	var s := _sheets()
	var margin: MarginContainer = s.building_sheet.get_node("SheetMargin")
	assert_int(margin.get_theme_constant("margin_left")).is_equal(MedievalTheme.gap(SheetStyle.MARGIN))
	var body: Control = margin.get_node("Body")
	assert_int(body.get_theme_constant("separation")).is_equal(MedievalTheme.gap(11))


func _two_own_settlements() -> void:
	GameState.apply_world(FixtureCells.world_json())
	GameState.apply_settlements([
		{"x": FixtureCells.HOME.x, "y": FixtureCells.HOME.y, "ownerId": 7, "name": "Koralowa", "resources": {}},
		{"x": FixtureCells.OWN_SECOND.x, "y": FixtureCells.OWN_SECOND.y, "ownerId": 7, "name": "Popielna", "resources": {}},
	])
	GameState.set_active_settlement(FixtureCells.HOME)


func test_enter_settlement_activates_it_and_switches_to_the_settlement_view() -> void:
	_two_own_settlements()
	var s := _sheets()
	s.open_inspect(FixtureCells.OWN_SECOND)
	s.inspect_sheet.action_button.pressed.emit()
	assert_that(GameState.active_settlement.coord).is_equal(FixtureCells.OWN_SECOND)
	assert_str(SceneManager.current_view).is_equal(SceneManager.VIEW_ISLAND_DETAIL)
	assert_bool(s.is_open()).is_false()


## „Wróć do osady” nie przełącza osady aktywnej na nowo: bez tego każdy powrót przebudowywałby
## pasek i widok osady, jakby gracz wybrał inną osadę.
func test_return_to_the_active_settlement_only_switches_the_view() -> void:
	_two_own_settlements()
	var s := _sheets()
	var changes := [0]
	var on_change := func() -> void: changes[0] += 1
	GameState.active_settlement_changed.connect(on_change)
	s.open_inspect(FixtureCells.HOME)
	s.inspect_sheet.action_button.pressed.emit()
	# GameState to autoload: lambda zostałaby podpięta do następnych testów.
	GameState.active_settlement_changed.disconnect(on_change)
	assert_int(changes[0]).is_equal(0)
	assert_that(GameState.active_settlement.coord).is_equal(FixtureCells.HOME)
	assert_str(SceneManager.current_view).is_equal(SceneManager.VIEW_ISLAND_DETAIL)
