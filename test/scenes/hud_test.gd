extends GdUnitTestSuite

const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")
const HOME := FixtureCells.HOME


func before_test() -> void:
	GameState.reset()
	GameState.apply_world(FixtureCells.world_json())
	GameState.apply_settlements([{
		"x": HOME.x, "y": HOME.y, "ownerId": 7, "name": "Koralowa",
		"resources": {"wood": 12480, "food": 300},
		"productionPerHour": {"wood": 120, "food": 200},
		"capacity": 20000, "population": 118, "populationMax": 120,
		"lastSyncAt": TimeUtil.to_iso8601(TimeUtil.now()),
	}])
	GameState.set_active_settlement(HOME)


func after_test() -> void:
	GameState.reset()


func _hud() -> CanvasLayer:
	var hud: CanvasLayer = auto_free(HUD_SCENE.instantiate())
	add_child(hud)
	return hud


func test_profile_row_shows_active_settlement() -> void:
	var hud := _hud()
	assert_str(hud.settlement_name.text).is_equal("Koralowa")
	assert_str(hud.biome_badge.text).is_equal("TROPICAL")
	assert_str(hud.subtitle.text).is_equal("Świat w1 · (%d, %d)" % [HOME.x, HOME.y])
	assert_str(hud.gold_label.text).is_equal("0")


func test_cards_show_amounts_and_rates() -> void:
	var hud := _hud()
	hud._process(0.0)
	assert_str(hud.amount_of("wood").text).is_equal("12" + TimeUtil.THIN_SPACE + "480")
	assert_str(hud.rate_of("wood").text).is_equal("+120/h")
	assert_str(hud.rate_of("stone").text).is_equal("")
	# Color.a jest float32, więc zapis i odczyt 0.45 różni się o 1 ULP - stąd tolerancja.
	assert_float(hud.cards["stone"].modulate.a).is_equal_approx(hud.DIMMED, 0.001)
	assert_float(hud.cards["wood"].modulate.a).is_equal(1.0)


func test_population_bar_and_warning() -> void:
	var hud := _hud()
	assert_str(hud.pop_label.text).is_equal("118 / 120")
	assert_float(hud.pop_bar.max_value).is_equal(120.0)
	assert_float(hud.pop_bar.value).is_equal(118.0)
	assert_that(hud.pop_label.get_theme_color("font_color")).is_equal(MedievalTheme.BLOOD)


func test_no_settlement_shows_dashes() -> void:
	GameState.reset()
	var hud := _hud()
	assert_str(hud.settlement_name.text).is_equal("-")
	assert_str(hud.biome_badge.text).is_equal("")
	assert_str(hud.amount_of("wood").text).is_equal("0")


func test_is_in_hud_group_and_reports_height() -> void:
	var hud := _hud()
	assert_bool(hud.is_in_group("hud")).is_true()
	await await_idle_frame()
	assert_float(hud.bar_height()).is_greater(0.0)
