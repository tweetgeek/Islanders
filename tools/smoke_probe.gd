extends Node

## Smoke test scen: uruchamia Main, klika osadę domową, przechodzi przez trzy tryby detalu i wraca.
## Użycie: ./run_smoke.sh  (kończy się kodem 0 przy sukcesie, 1 przy błędzie)

const MAIN := preload("res://scenes/views/Main.tscn")

var _frame := 0
var _failed := false
var _pan_start := Vector2.ZERO


func _ready() -> void:
	add_child(MAIN.instantiate())


## Wysyła zdarzenie myszy tą samą drogą co system operacyjny, więc emulacja dotyku
## z myszy zamienia je na zdarzenia ekranowe, których używa MapCamera.
func _mouse_press(at: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = at
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _mouse_move(from: Vector2, to: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = to
	e.relative = to - from
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _mouse_release(at: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = false
	e.position = at
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _window_center() -> Vector2:
	return Vector2(get_window().size) / 2.0


## Środek kontrolki w układzie okna; zdarzenia wejścia przychodzą w pikselach okna,
## a kontrolki są rozmieszczone w pikselach viewportu, więc trzeba przeskalować.
func _control_center(c: Control) -> Vector2:
	var scale := Vector2(get_window().size) / get_viewport().get_visible_rect().size
	return c.get_global_rect().get_center() * scale


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
		22:
			var map := get_node("Main/ViewContainer/WorldMap")
			_pan_start = map.camera.position
			_mouse_press(_window_center() + Vector2(0, 200))
		24:
			_mouse_move(_window_center() + Vector2(0, 200), _window_center() + Vector2(-80, 140))
		26:
			_mouse_release(_window_center() + Vector2(-80, 140))
			var map := get_node("Main/ViewContainer/WorldMap")
			_check(map.camera.position != _pan_start, "przeciągnięcie myszą przesuwa mapę")
		28:
			var map := get_node("Main/ViewContainer/WorldMap")
			map.camera.position = WorldGrid.cell_to_world(Vector2i(103, 100))
			_mouse_press(_window_center())
		30:
			_mouse_release(_window_center())
		33:
			_check(
				SceneManager.current_view == SceneManager.VIEW_ISLAND_DETAIL,
				"kliknięcie w wyspę otwiera detal"
			)
			var det := get_node_or_null("Main/ViewContainer/IslandDetail")
			_check(det != null and det.get_node("Generator").show_slots, "własna osada ma sloty")
			_check(det != null and det.get_node("Generator")._slot_positions.size() == 6, "6 slotów")
			GameState.inspect(Vector2i(95, 100))
		38:
			var det := get_node_or_null("Main/ViewContainer/IslandDetail")
			_check(det != null and not det.get_node("Generator").show_slots, "cudza osada bez slotów")
			_check(
				det != null and det.get_node("UI/InfoPanel/Info").text.contains("gracz 9"),
				"cudza osada pokazuje właściciela"
			)
			GameState.inspect(Vector2i(95, 98))
		43:
			var det := get_node_or_null("Main/ViewContainer/IslandDetail")
			_check(det != null and det.get_node("Generator").show_deposit, "wyspa niczyja pokazuje znalezisko")
			var hud := get_node("Main/HUD")
			_check(hud.name_label.text.begins_with("Koralowa"), "HUD pokazuje osadę aktywną")
			_check(hud.population_label.text == "42 / 120", "HUD pokazuje populację")
			ApiClient.resync()
		48:
			_check(GameState.settlements.size() == 3, "resync zachowuje osady")
			var back: Button = get_node("Main/ViewContainer/IslandDetail/UI/BackButton")
			var at := _control_center(back)
			_mouse_press(at)
			_mouse_release(at)
		53:
			_check(
				SceneManager.current_view == SceneManager.VIEW_WORLD_MAP,
				"kliknięcie w przycisk powrotu wraca na mapę"
			)
			print("SMOKE %s" % ("FAILED" if _failed else "PASSED"))
			get_tree().quit(1 if _failed else 0)
