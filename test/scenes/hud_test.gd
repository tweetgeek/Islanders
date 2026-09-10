extends GdUnitTestSuite

const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")
const HOME := FixtureCells.HOME


func before_test() -> void:
	# Geometria paska zależy od fontów i rozmiarów z motywu; bez tego test mierzyłby domyślny
	# motyw silnika, a nie to, co widzi gracz.
	MedievalTheme.install()
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


func test_cards_show_amounts_and_rates() -> void:
	var hud := _hud()
	hud._process(0.0)
	assert_str(hud.amount_of("wood").text).is_equal("12" + TimeUtil.THIN_SPACE + "480")
	assert_str(hud.rate_of("wood").text).is_equal("+120/h")
	assert_str(hud.rate_of("stone").text).is_equal("")
	# Color.a jest float32, więc zapis i odczyt 0.45 różni się o 1 ULP - stąd tolerancja.
	assert_float(hud.cards["stone"].modulate.a).is_equal_approx(hud.DIMMED, 0.001)
	assert_float(hud.cards["wood"].modulate.a).is_equal(1.0)


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


## Szerokość, jakiej etykieta potrzebuje, żeby pokazać swój własny tekst w swoim własnym foncie.
func _needed_width(label: Label) -> float:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _labels_with_text(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if child is Label and not (child as Label).text.is_empty():
			out.append(child)
		out.append_array(_labels_with_text(child))
	return out


## Etykieta z clip_text ma zerowy rozmiar minimalny, więc w kontenerze poziomym bez flagi
## rozciągania dostaje jeden piksel i nazwa osady znika z ekranu. Asercja na .text tego nie
## widzi - ta mierzy wyrenderowaną szerokość względem szerokości własnego tekstu.
func test_settlement_name_is_wide_enough_to_render_its_text() -> void:
	var hud := _hud()
	await await_idle_frame()
	await await_idle_frame()
	var needed := _needed_width(hud.settlement_name)
	assert_float(needed).is_greater(0.0)
	assert_float(hud.settlement_name.size.x).is_greater_equal(needed)


## Siatka na całą rodzinę zapadnięć układu: przy tych danych każda etykieta paska mieści się
## w całości, więc żadna nie może być węższa niż jej tekst.
func test_no_hud_label_is_narrower_than_its_text() -> void:
	var hud := _hud()
	await await_idle_frame()
	await await_idle_frame()
	for label: Label in _labels_with_text(hud):
		assert_float(label.size.x) \
			.override_failure_message("etykieta %s ma tekst %s i szerokość %.1f, potrzebuje %.1f" % [
				label.name, label.text, label.size.x, _needed_width(label)
			]) \
			.is_greater_equal(_needed_width(label))


## Wybrany wariant: dwa wiersze, cel około 14 %, próg 16 %. Mierzone przy oknie w proporcjach
## telefonu i z wgranym motywem, czyli w konfiguracji, którą widzi gracz.
func test_bar_stays_within_the_height_budget() -> void:
	var original := get_tree().root.size
	get_tree().root.size = Vector2i(1080, 1920)
	var hud := _hud()
	await await_idle_frame()
	await await_idle_frame()
	await await_idle_frame()
	# Adnotacja typu (zamiast := ) omija kaprys tego builda: dzielenie wyniku "niebezpiecznego"
	# wywołania metody (hud jest typu CanvasLayer, bar_height() zna dopiero HUD.gd) daje typ,
	# którego := nie potrafi wywnioskować - choć samo wywołanie działa poprawnie w runtime.
	var ratio: float = hud.bar_height() / hud.get_viewport().get_visible_rect().size.y
	get_tree().root.size = original
	assert_float(ratio).is_greater(0.0)
	assert_float(ratio).is_less_equal(0.16)


func test_bar_has_only_identity_and_resource_rows() -> void:
	var hud := _hud()
	assert_int(hud.bar_rows.get_child_count()).is_equal(2)
	assert_object(hud.settlement_name.get_parent()).is_same(hud.identity_row)
	assert_object(hud.biome_badge.get_parent()).is_same(hud.identity_row)
	assert_object(hud.subtitle.get_parent()).is_same(hud.identity_row)
	for gone in ["avatar", "gold_label", "pop_label", "pop_bar"]:
		assert_bool(gone in hud).override_failure_message("pasek wciąż ma %s" % gone).is_false()
