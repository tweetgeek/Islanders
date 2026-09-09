extends GdUnitTestSuite

const CARD := preload("res://scenes/ui/FleetCard.tscn")
const DEPART := 1788782400.0
const ARRIVE := DEPART + 3600.0


func _fleet(mission: String, owner: int) -> Fleet:
	return Fleet.from_json({
		"id": "f1", "ownerId": owner, "mission": mission,
		"from": {"x": 0, "y": 0}, "to": {"x": 4, "y": 0},
		"ships": {"SLOOP": 10, "GALLEON": 2},
		"cargo": {"units": {"MILITIA": 20}, "resources": {"iron": 300}},
		"departAt": TimeUtil.to_iso8601(DEPART), "arriveAt": TimeUtil.to_iso8601(ARRIVE),
	})


func _card() -> FleetCard:
	var c: FleetCard = auto_free(CARD.instantiate())
	add_child(c)
	return c


func test_own_fleet_shows_title_eta_and_composition() -> void:
	var c := _card()
	c.refresh(_fleet("EXPEDITION", 7), DEPART + 1800.0, 7)
	assert_str(c.title.text).is_equal("Wyprawa → (4, 0)")
	assert_str(c.eta_label.text).is_equal("30:00")
	assert_float(c.eta_bar.value).is_equal_approx(0.5, 0.001)
	assert_str(c.composition.text).is_equal("10 × slup · 2 × galeon · 20 × MILITIA · 300 żelazo")
	assert_str(String(c.eta_bar.theme_type_variation)).is_equal("ScoutBar")
	assert_that((c.get_theme_stylebox("panel") as StyleBoxFlat).border_color).is_equal(MedievalTheme.MOSS)


func test_foreign_attack_hides_details_and_is_red() -> void:
	var c := _card()
	c.refresh(_fleet("ATTACK", 9), DEPART, 7)
	assert_str(c.title.text).is_equal("Atak → (4, 0)")
	assert_str(c.composition.text).is_equal("gracz 9 · szczegóły niewidoczne")
	assert_str(String(c.eta_bar.theme_type_variation)).is_equal("RaidBar")
	assert_that((c.get_theme_stylebox("panel") as StyleBoxFlat).border_color).is_equal(MedievalTheme.BLOOD)
	assert_str(String(c.mission_icon.kind)).is_equal("raid")


func test_arrived_fleet_is_full_and_zero_eta() -> void:
	var c := _card()
	c.refresh(_fleet("TRANSPORT", 7), ARRIVE + 10.0, 7)
	assert_float(c.eta_bar.value).is_equal(1.0)
	assert_str(c.eta_label.text).is_equal("00:00")
	assert_that((c.get_theme_stylebox("panel") as StyleBoxFlat).border_color).is_equal(MedievalTheme.BRASS)


func test_unknown_mission_falls_back() -> void:
	var c := _card()
	c.refresh(_fleet("PATROL", 7), DEPART, 7)
	assert_str(c.title.text).is_equal("PATROL → (4, 0)")
	assert_str(String(c.mission_icon.kind)).is_equal("fleet")


func test_touch_release_emits_tapped() -> void:
	var c := _card()
	var f := _fleet("TRANSPORT", 7)
	c.refresh(f, DEPART, 7)
	var got: Array = []
	c.tapped.connect(func(x: Fleet) -> void: got.append(x))
	var touch := InputEventScreenTouch.new()
	touch.pressed = false
	c.gui_input.emit(touch)
	assert_that(got).is_equal([f])
