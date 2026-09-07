extends Node

## Smoke test scen: uruchamia Main, klika osadę domową, przechodzi przez trzy tryby detalu i wraca.
## Użycie: ./run_smoke.sh  (kończy się kodem 0 przy sukcesie, 1 przy błędzie)

const MAIN := preload("res://scenes/views/Main.tscn")

var _frame := 0
var _failed := false


func _ready() -> void:
	add_child(MAIN.instantiate())


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["OK  " if ok else "FAIL", what])
	if not ok:
		_failed = true


func _process(_delta: float) -> void:
	_frame += 1
	match _frame:
		20:
			_check(GameState.world != null and GameState.world.id == "w1", "świat załadowany")
			_check(GameState.settlements.size() == 3, "3 osady")
			_check(GameState.fleets.size() == 3, "3 floty")
			_check(
				GameState.active_settlement != null and GameState.active_settlement.name == "Koralowa",
				"osada domowa aktywna"
			)
			_check(SceneManager.current_view == SceneManager.VIEW_WORLD_MAP, "widok mapy")
			var map := get_node_or_null("Main/ViewContainer/WorldMap")
			_check(map != null and map.get_node("Chunks").get_child_count() > 0, "chunki załadowane")
			_check(map != null and map.get_node("Labels").get_child_count() == 3, "3 etykiety osad")
			if map:
				var bounds := Rect2(Vector2.ZERO, Vector2(GameState.world.size) * WorldGrid.CELL_SIZE)
				_check(bounds.has_point(map.camera.position), "kamera mapy w granicach świata")
				map._on_tapped(WorldGrid.cell_to_world(Vector2i(103, 100)))
		30:
			_check(SceneManager.current_view == SceneManager.VIEW_ISLAND_DETAIL, "tap otwiera detal")
			var det := get_node_or_null("Main/ViewContainer/IslandDetail")
			_check(det != null and det.get_node("Generator").show_slots, "własna osada ma sloty")
			_check(det != null and det.get_node("Generator")._slot_positions.size() == 6, "6 slotów")
			GameState.inspect(Vector2i(95, 100))
		35:
			var det := get_node_or_null("Main/ViewContainer/IslandDetail")
			_check(det != null and not det.get_node("Generator").show_slots, "cudza osada bez slotów")
			_check(
				det != null and det.get_node("UI/InfoPanel/Info").text.contains("gracz 9"),
				"cudza osada pokazuje właściciela"
			)
			GameState.inspect(Vector2i(95, 98))
		40:
			var det := get_node_or_null("Main/ViewContainer/IslandDetail")
			_check(det != null and det.get_node("Generator").show_deposit, "wyspa niczyja pokazuje znalezisko")
			var hud := get_node("Main/HUD")
			_check(hud.name_label.text.begins_with("Koralowa"), "HUD pokazuje osadę aktywną")
			_check(hud.population_label.text == "42 / 120", "HUD pokazuje populację")
			ApiClient.resync()
		45:
			_check(GameState.settlements.size() == 3, "resync zachowuje osady")
			SceneManager.show_world_map()
		50:
			_check(SceneManager.current_view == SceneManager.VIEW_WORLD_MAP, "powrót do mapy")
			print("SMOKE %s" % ("FAILED" if _failed else "PASSED"))
			get_tree().quit(1 if _failed else 0)
