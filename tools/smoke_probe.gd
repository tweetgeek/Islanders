extends Node

## Smoke test scen: uruchamia Main, klika osadę domową, przechodzi przez trzy tryby detalu i wraca.
## Użycie: ./run_smoke.sh  (kończy się kodem 0 przy sukcesie, 1 przy błędzie)

const MAIN := preload("res://scenes/views/Main.tscn")

## Przesunięcia przeciągnięcia w pikselach VIEWPORTU (nie okna) - przeliczane na piksele okna
## dokładną transformacją roota tuż przed wysłaniem zdarzenia, więc ten sam dystans oznacza
## to samo pod headless (malutkie fałszywe okno) i w prawdziwym oknie gry.
const SEA_DRAG_DELTA := Vector2(-260.0, -180.0)
## Czysto poziome, żeby cała trasa przeciągnięcia zostawała w wąskim pasku TopBar (wysokość
## tylko ~96 px viewportu) - inaczej test przypadkiem opuściłby pasek i nie sprawdzałby filtra.
const BAR_DRAG_DELTA := Vector2(-150.0, 0.0)

var _frame := 0
var _failed := false
var _pan_start := Vector2.ZERO
## Pozycja (w pikselach okna) ostatniego "przyciśnięcia", potrzebna w kolejnej klatce do _mouse_move.
var _drag_from_win := Vector2.ZERO


func _ready() -> void:
	add_child(MAIN.instantiate())


## Wysyła zdarzenie myszy tą samą drogą co system operacyjny, więc emulacja dotyku
## z myszy zamienia je na zdarzenia ekranowe, których używa MapCamera. `global_position` musi
## być ustawione obok `position`: emulacja dotyku Godota liczy pozycję przeciągnięcia
## (InputEventScreenDrag) z global_position wejściowego zdarzenia myszy, nie z position - bez
## tego każde przeciągnięcie z tego probe'a lądowało w (0, 0) niezależnie od zamierzonego miejsca.
func _mouse_press(at: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = at
	e.global_position = at
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _mouse_move(from: Vector2, to: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = to
	e.global_position = to
	e.relative = to - from
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _mouse_release(at: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = false
	e.position = at
	e.global_position = at
	Input.parse_input_event(e)
	Input.flush_buffered_events()


## Punkt roota (w pikselach viewportu) na piksele okna, w których Input.parse_input_event
## oczekuje position/global_position. `get_final_transform()` to dokładna transformacja
## viewport -> okno używana przez sam silnik pod dowolnym trybem stretch - w przeciwieństwie
## do zwykłego stosunku rozmiarów okno/viewport, działa poprawnie także z letterboxingiem.
func _viewport_to_window(viewport_pos: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * viewport_pos


## Jak wyżej, ale dla wektora przesunięcia (bez translacji) - do przeliczenia dystansu
## przeciągnięcia zadanego w pikselach viewportu na piksele okna.
func _viewport_delta_to_window(viewport_delta: Vector2) -> Vector2:
	return get_tree().root.get_final_transform().basis_xform(viewport_delta)


## Środek pierwszej ikony zasobu w pasku HUD (piksele viewportu).
func _chip_icon_center(hud: CanvasLayer) -> Vector2:
	var chip: Control = hud.chips.get_child(0)
	return (chip.get_child(0) as Control).get_global_rect().get_center()


## Środek widocznego obszaru viewportu, przesunięty w dół na tyle, żeby zawsze leżeć
## poniżej paska HUD (który zajmuje tylko górne ~5% ekranu) - "otwarte morze".
func _sea_point() -> Vector2:
	var vis := get_viewport().get_visible_rect()
	return vis.get_center() + Vector2(0.0, vis.size.y * 0.3)


## Środek kontrolki w pikselach okna; kontrolki są rozmieszczone w pikselach viewportu,
## więc trzeba przeliczyć dokładną transformacją roota (patrz _viewport_to_window).
func _control_center(c: Control) -> Vector2:
	return _viewport_to_window(c.get_global_rect().get_center())


## Punkt ekranowy (piksele viewportu) slotu budynku danego typu na wskazanej wyspie w detalu -
## przez transformację lokalna slotu -> globalna (świat) -> ekran (kamera detalu).
func _slot_viewport_point(detail: Node2D, generator: IslandGenerator, slot: Buildings.Type) -> Vector2:
	var world_pos: Vector2 = generator.to_global(generator._slot_positions[slot])
	return detail.get_canvas_transform() * world_pos


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
		# --- Przeciągnięcie zaczęte nad otwartym morzem: musi zawsze przesuwać mapę. ---
		22:
			var map := get_node("Main/ViewContainer/WorldMap")
			_pan_start = map.camera.position
			_drag_from_win = _viewport_to_window(_sea_point())
			_mouse_press(_drag_from_win)
		24:
			var to_win := _viewport_to_window(_sea_point() + SEA_DRAG_DELTA)
			_mouse_move(_drag_from_win, to_win)
		26:
			_mouse_release(_viewport_to_window(_sea_point() + SEA_DRAG_DELTA))
			var map := get_node("Main/ViewContainer/WorldMap")
			_check(map.camera.position != _pan_start, "przeciągnięcie nad otwartym morzem przesuwa mapę")
		# --- Przeciągnięcie zaczęte dokładnie na ikonie zasobu w pasku HUD. Ikony to ColorRect
		# tworzone w kodzie, więc mają domyślny mouse_filter = STOP i bez jawnego IGNORE
		# tworzą martwe strefy 24x24, w których gest nie dochodzi do kamery. ---
		28:
			var map := get_node("Main/ViewContainer/WorldMap")
			_pan_start = map.camera.position
			var hud := get_node("Main/HUD")
			_drag_from_win = _viewport_to_window(_chip_icon_center(hud))
			_mouse_press(_drag_from_win)
		30:
			var hud := get_node("Main/HUD")
			var to_win := _viewport_to_window(_chip_icon_center(hud) + BAR_DRAG_DELTA)
			_mouse_move(_drag_from_win, to_win)
		32:
			var hud := get_node("Main/HUD")
			_mouse_release(_viewport_to_window(_chip_icon_center(hud) + BAR_DRAG_DELTA))
			var map := get_node("Main/ViewContainer/WorldMap")
			_check(map.camera.position != _pan_start, "przeciągnięcie na ikonie zasobu przesuwa mapę")
		34:
			var map := get_node("Main/ViewContainer/WorldMap")
			map.camera.position = WorldGrid.cell_to_world(Vector2i(80, 73))
			_mouse_press(_viewport_to_window(get_viewport().get_visible_rect().get_center()))
		36:
			_mouse_release(_viewport_to_window(get_viewport().get_visible_rect().get_center()))
		39:
			_check(
				SceneManager.current_view == SceneManager.VIEW_ISLAND_DETAIL,
				"kliknięcie w wyspę otwiera detal"
			)
			var det := get_node_or_null("Main/ViewContainer/IslandDetail")
			var gen: IslandGenerator = det.get_node("Generator") if det != null else null
			_check(det != null and gen.show_slots, "własna osada ma sloty")
			_check(det != null and gen._slot_positions.size() == 6, "6 slotów")
			if det != null and gen.show_slots:
				var at := _viewport_to_window(_slot_viewport_point(det, gen, Buildings.Type.TOWN_HALL))
				_mouse_press(at)
				_mouse_release(at)
		41:
			var det := get_node_or_null("Main/ViewContainer/IslandDetail")
			_check(
				det != null and det.get_node("UI/BuildingMenu").visible,
				"tapnięcie w slot otwiera panel budynku"
			)
			GameState.inspect(Vector2i(81, 73))
		44:
			var det := get_node_or_null("Main/ViewContainer/IslandDetail")
			_check(det != null and not det.get_node("Generator").show_slots, "cudza osada bez slotów")
			_check(
				det != null and det.get_node("UI/InfoPanel/Info").text.contains("gracz 9"),
				"cudza osada pokazuje właściciela"
			)
			GameState.inspect(Vector2i(79, 73))
		49:
			var det := get_node_or_null("Main/ViewContainer/IslandDetail")
			_check(det != null and det.get_node("Generator").show_deposit, "wyspa niczyja pokazuje znalezisko")
			var hud := get_node("Main/HUD")
			_check(hud.name_label.text.begins_with("Koralowa"), "HUD pokazuje osadę aktywną")
			_check(hud.population_label.text == "42 / 120", "HUD pokazuje populację")
			ApiClient.resync()
		54:
			_check(GameState.settlements.size() == 3, "resync zachowuje osady")
			var back: Button = get_node("Main/ViewContainer/IslandDetail/UI/BackButton")
			var at := _control_center(back)
			_mouse_press(at)
			_mouse_release(at)
		59:
			_check(
				SceneManager.current_view == SceneManager.VIEW_WORLD_MAP,
				"kliknięcie w przycisk powrotu wraca na mapę"
			)
			print("SMOKE %s" % ("FAILED" if _failed else "PASSED"))
			get_tree().quit(1 if _failed else 0)
