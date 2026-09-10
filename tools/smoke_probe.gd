extends Node

## Smoke test scen: start w osadzie, mapa przez dock, arkusze inspekcji, budynku i flot, powrót do osady.
## Użycie: ./run_smoke.sh  (kończy się kodem 0 przy sukcesie, 1 przy błędzie)

const MAIN := preload("res://scenes/views/Main.tscn")

## Przesunięcia przeciągnięcia w pikselach VIEWPORTU (nie okna) - przeliczane na piksele okna
## dokładną transformacją roota tuż przed wysłaniem zdarzenia, więc ten sam dystans oznacza
## to samo pod headless (malutkie fałszywe okno) i w prawdziwym oknie gry.
const SEA_DRAG_DELTA := Vector2(-260.0, -180.0)
## Pasek ma teraz ok. 400 px, ale gest zostaje poziomy, żeby na pewno nie opuścić paska
## i wciąż zaczynać dokładnie na ikonie zasobu.
const BAR_DRAG_DELTA := Vector2(-150.0, 0.0)

var _frame := 0
var _failed := false
var _pan_start := Vector2.ZERO
## Pozycja (w pikselach okna) ostatniego "przyciśnięcia", potrzebna w kolejnej klatce do _mouse_move.
var _drag_from_win := Vector2.ZERO

## Zamknięcie arkusza (backdrop albo Sheets.close()) zostawia CanvasLayer Sheets w stanie
## visible=true (a jego pełnoekranowy Backdrop wciąż ma mouse_filter STOP, więc łapie każdy tap)
## aż tween zamknięcia (SLIDE_TIME 0.26s + FADE_TIME 0.18s) faktycznie dobiegnie końca w
## tween_callback. Bez --fixed-fps liczba surowych klatek _process potrzebna na pokrycie tego
## realnego czasu zależy od obciążenia maszyny - zmierzone empirycznie: od ~500 do ~1400 klatek
## w kolejnych przebiegach na tej samej maszynie. Stała liczba klatek byłaby więc zgadywaniem
## (sprawdzone: 800 klatek nie wystarczało w ~2/3 przebiegów) - zamiast tego _phase/_gate aktywnie
## czekają na sheets.visible == false i dopiero wtedy odpalają kolejny pełnoekranowy tap, a resztę
## kroków w danej fazie liczą względem klatki, w które faktycznie się to stało (_gate + N).
var _phase := 0
var _gate := 0


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


## Środek ikony drewna w pasku HUD (piksele viewportu).
func _chip_icon_center(hud: CanvasLayer) -> Vector2:
	return (hud.icon_of("wood") as Control).get_global_rect().get_center()


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


## Punkt w górnej połowie ekranu, poniżej HUD i powyżej każdego arkusza (backdrop).
func _backdrop_point() -> Vector2:
	var vis := get_viewport().get_visible_rect()
	var hud := get_node("Main/HUD")
	return Vector2(vis.get_center().x, hud.bar_height() + (vis.size.y * 0.5 - hud.bar_height()) * 0.5)


func _sheets() -> CanvasLayer:
	return get_node("Main/Sheets")


func _map() -> Node2D:
	return get_node_or_null("Main/ViewContainer/WorldMap")


func _tap_control(c: Control) -> void:
	var at := _control_center(c)
	_mouse_press(at)
	_mouse_release(at)


## Prawda, gdy warstwa arkuszy przestała blokować pełny ekran (patrz komentarz przy _phase/_gate).
func _settled() -> bool:
	return not _sheets().visible


## Prawda, gdy arkusz jest otwarty i skończył wjeżdżać. Tapnięcie przycisku w arkuszu w trakcie
## animacji trafiałoby w miejsce, z którego przycisk właśnie odjeżdża.
func _opened() -> bool:
	var sheets := _sheets()
	return sheets.is_open() and (sheets._tween == null or not sheets._tween.is_running())


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
			_check(SceneManager.current_view == SceneManager.VIEW_ISLAND_DETAIL, "start w widoku osady")
			_check(ThemeDB.get_default_theme().get_type_variation_base(&"Plaque") == &"PanelContainer", "motyw wgrany")
			var hud := get_node("Main/HUD")
			_check(hud.settlement_name.text == "Koralowa", "HUD pokazuje osadę aktywną")
			var det := get_node_or_null("Main/ViewContainer/IslandDetail")
			_check(det != null and det.pop_label.text == "42 / 120", "widok osady pokazuje populację")
			var gen: IslandGenerator = det.get_node("Generator") if det != null else null
			_check(det != null and gen.show_slots and gen._slot_positions.size() == 6, "osada ma 6 slotów")
			var dock := get_node("Main/Dock")
			_check(dock.map_button.visible, "dock pokazuje przycisk mapy w osadzie")
			_check(dock.badge.visible and dock.badge.text == "3", "odznaka flot pokazuje 3")
			_check(dock.is_alarmed(), "odznaka alarmuje o cudzej flocie")
		# --- Tap w slot ratusza otwiera arkusz budynku; backdrop go zamyka. ---
		22:
			var det := get_node("Main/ViewContainer/IslandDetail")
			var at := _viewport_to_window(_slot_viewport_point(det, det.get_node("Generator"), Buildings.Type.TOWN_HALL))
			_mouse_press(at)
			_mouse_release(at)
		25:
			var sheets := _sheets()
			_check(sheets.is_open() and sheets.current_sheet() == sheets.building_sheet, "tap w slot otwiera arkusz budynku")
			_check(sheets.building_sheet.name_label.text == "Ratusz", "arkusz pokazuje ratusz")
			_check(sheets.building_sheet.level_badge.text == "LV 1", "arkusz pokazuje poziom 1")
			var at := _viewport_to_window(_backdrop_point())
			_mouse_press(at)
			_mouse_release(at)
		28:
			_check(not _sheets().is_open(), "tap w backdrop zamyka arkusz")
			_phase = 1   # dalej czekamy aż Sheets faktycznie przestanie blokować ekran (patrz _settled())
	# --- Dock: przycisk mapy otwiera mapę. Odstęp od fazy 1 do dalszych kroków nie jest stałą
	# liczbą klatek: Sheets zostaje "visible" (backdrop wciąż STOP-filtruje cały ekran) aż tween
	# zamknięcia (SLIDE_TIME 0.26s + FADE_TIME 0.18s, równolegle) faktycznie dobiegnie końca w
	# tween_callback, a bez --fixed-fps liczba surowych klatek _process potrzebna na pokrycie tego
	# realnego czasu zależy od obciążenia maszyny (zmierzone empirycznie: od ~500 do ~1400 klatek
	# w kolejnych przebiegach na tej samej maszynie - stała liczba klatek okazała się zawodna:
	# 800 nie wystarczało w ~2/3 przebiegów). Dlatego _phase/_gate aktywnie czekają na
	# sheets.visible == false i dopiero wtedy odpalają kolejny pełnoekranowy tap, a resztę kroków
	# w danej fazie liczą względem klatki, w które faktycznie się to stało (_gate + N klatek -
	# te odstępy są małe i stałe, tak jak w resztę testu). ---
	if _phase == 1 and _frame > 28 and _settled():
		_gate = _frame
		_phase = 2
		_tap_control(get_node("Main/Dock").map_button)
	elif _phase == 2:
		if _frame == _gate + 4:
			_check(SceneManager.current_view == SceneManager.VIEW_WORLD_MAP, "przycisk docku otwiera mapę")
			var map := _map()
			_check(map != null and map.get_node("Chunks").get_child_count() > 0, "chunki załadowane")
			_check(map != null and map.get_node("Labels").get_child_count() == 3, "3 etykiety osad")
			_check(not get_node("Main/Dock").map_button.visible, "dock chowa przycisk mapy na mapie")
			if map:
				var bounds := Rect2(Vector2.ZERO, Vector2(GameState.world.size) * WorldGrid.CELL_SIZE)
				_check(bounds.has_point(map.camera.position), "kamera mapy w granicach świata")
		# --- Przeciągnięcie nad otwartym morzem przesuwa mapę. ---
		elif _frame == _gate + 6:
			_pan_start = _map().camera.position
			_drag_from_win = _viewport_to_window(_sea_point())
			_mouse_press(_drag_from_win)
		elif _frame == _gate + 8:
			_mouse_move(_drag_from_win, _viewport_to_window(_sea_point() + SEA_DRAG_DELTA))
		elif _frame == _gate + 10:
			_mouse_release(_viewport_to_window(_sea_point() + SEA_DRAG_DELTA))
			_check(_map().camera.position != _pan_start, "przeciągnięcie nad otwartym morzem przesuwa mapę")
		# --- Przeciągnięcie zaczęte na ikonie zasobu w HUD też przesuwa mapę (dekoracje nie łapią inputu). ---
		elif _frame == _gate + 12:
			_pan_start = _map().camera.position
			_drag_from_win = _viewport_to_window(_chip_icon_center(get_node("Main/HUD")))
			_mouse_press(_drag_from_win)
		elif _frame == _gate + 14:
			_mouse_move(_drag_from_win, _viewport_to_window(_chip_icon_center(get_node("Main/HUD")) + BAR_DRAG_DELTA))
		elif _frame == _gate + 16:
			_mouse_release(_viewport_to_window(_chip_icon_center(get_node("Main/HUD")) + BAR_DRAG_DELTA))
			_check(_map().camera.position != _pan_start, "przeciągnięcie na ikonie zasobu przesuwa mapę")
		# --- Tap cudzej osady otwiera arkusz inspekcji; gest na arkuszu nie rusza mapy. ---
		elif _frame == _gate + 18:
			_map().camera.position = WorldGrid.island_center(GameState.world_seed(), FixtureCells.FOREIGN)
			_mouse_press(_viewport_to_window(get_viewport().get_visible_rect().get_center()))
		elif _frame == _gate + 20:
			_mouse_release(_viewport_to_window(get_viewport().get_visible_rect().get_center()))
		elif _frame == _gate + 23:
			var sheets := _sheets()
			_check(sheets.is_open() and sheets.current_sheet() == sheets.inspect_sheet, "tap cudzej osady otwiera arkusz inspekcji")
			_check(sheets.inspect_sheet.subtitle.text.contains("gracz 9"), "arkusz inspekcji pokazuje właściciela")
			_check(SceneManager.current_view == SceneManager.VIEW_WORLD_MAP, "mapa zostaje pod arkuszem")
			_pan_start = _map().camera.position
			_drag_from_win = _control_center(sheets.inspect_sheet)
			_mouse_press(_drag_from_win)
		elif _frame == _gate + 25:
			_mouse_move(_drag_from_win, _drag_from_win + _viewport_delta_to_window(SEA_DRAG_DELTA))
		elif _frame == _gate + 27:
			_mouse_release(_drag_from_win + _viewport_delta_to_window(SEA_DRAG_DELTA))
			_check(_map().camera.position == _pan_start, "przeciągnięcie po arkuszu nie rusza mapy")
			var at := _viewport_to_window(_backdrop_point())
			_mouse_press(at)
			_mouse_release(at)
			_phase = 3   # kolejny backdrop-close - znowu czekamy aż Sheets przestanie blokować ekran
	elif _phase == 3 and _settled():
		_gate = _frame
		_phase = 4
		_check(not _sheets().is_open(), "backdrop zamyka arkusz inspekcji")
		_map().camera.position = WorldGrid.island_center(GameState.world_seed(), FixtureCells.DEPOSIT)
		_mouse_press(_viewport_to_window(get_viewport().get_visible_rect().get_center()))
	elif _phase == 4:
		if _frame == _gate + 2:
			_mouse_release(_viewport_to_window(get_viewport().get_visible_rect().get_center()))
		elif _frame == _gate + 5:
			var sheets := _sheets()
			_check(sheets.is_open() and sheets.inspect_sheet.deposit_header.visible, "wyspa niczyja pokazuje znalezisko")
			sheets.close()
			_phase = 5   # sheets.close() woła ten sam tween co zamknięcie przez backdrop - znów czekamy
	# --- Tap własnej, aktywnej osady tylko ją ogląda; wejście to jawna akcja w arkuszu. ---
	elif _phase == 5 and _settled():
		_gate = _frame
		_phase = 6
		_map().camera.position = WorldGrid.island_center(GameState.world_seed(), FixtureCells.HOME)
		_mouse_press(_viewport_to_window(get_viewport().get_visible_rect().get_center()))
	elif _phase == 6:
		if _frame == _gate + 2:
			_mouse_release(_viewport_to_window(get_viewport().get_visible_rect().get_center()))
		elif _frame == _gate + 5:
			var sheets := _sheets()
			_check(sheets.is_open() and sheets.current_sheet() == sheets.inspect_sheet, "tap własnej osady otwiera arkusz")
			_check(SceneManager.current_view == SceneManager.VIEW_WORLD_MAP, "tap własnej osady zostawia mapę")
			_check(GameState.active_settlement.name == "Koralowa", "tap nie zmienia osady aktywnej")
			_check(sheets.inspect_sheet.action_button.text == InspectSheet.RETURN_TEXT, "arkusz aktywnej osady proponuje powrót")
			_phase = 7   # przycisk tapiemy dopiero, gdy arkusz skończy wjeżdżać (patrz _opened())
	elif _phase == 7 and _opened():
		_gate = _frame
		_phase = 8
		_tap_control(_sheets().inspect_sheet.action_button)
	elif _phase == 8:
		if _frame == _gate + 5:
			_check(SceneManager.current_view == SceneManager.VIEW_ISLAND_DETAIL, "WRÓĆ DO OSADY przełącza do widoku osady")
			_check(not _sheets().is_open(), "zmiana widoku zamyka arkusze")
			_check(GameState.active_settlement.name == "Koralowa", "powrót nie zmienia osady aktywnej")
		# --- Dock: floty jako arkusz, tap w kartę przenosi na mapę przy flocie. Widoki są tu
		# zmieniane przez SceneManager.show_world_map_at(), które od razu (bez animacji) zamyka
		# Sheets przez _hide_now() na sygnale view_changed - stąd od tego miejsca do końca testu
		# stałe, małe odstępy znów wystarczają, tak jak w oryginalnym harmonogramie. ---
		elif _frame == _gate + 7:
			_tap_control(get_node("Main/Dock").fleets_button)
		elif _frame == _gate + 10:
			var sheets := _sheets()
			_check(sheets.is_open() and sheets.current_sheet() == sheets.fleets_sheet, "przycisk docku otwiera arkusz flot")
			_check(sheets.fleets_sheet.cards().size() == 3, "arkusz flot ma 3 karty")
			_check(sheets.fleets_sheet.incoming_header.visible, "sekcja nadchodzących widoczna")
			var card: Control = sheets.fleets_sheet.cards()[0]
			var at := _control_center(card)
			_mouse_press(at)
			_mouse_release(at)
		elif _frame == _gate + 14:
			_check(SceneManager.current_view == SceneManager.VIEW_WORLD_MAP, "tap w kartę floty otwiera mapę")
			_check(not _sheets().is_open(), "arkusz flot zamknięty po tapie")
			var incoming: Fleet = GameState.fleets["f3"]
			var dist: float = _map().camera.position.distance_to(incoming.position_at(TimeUtil.now(), GameState.world_seed()))
			_check(dist < WorldGrid.CELL_SIZE * 2.0, "kamera przy pozycji floty")
			ApiClient.resync()
		elif _frame == _gate + 20:
			_check(GameState.settlements.size() == 3, "resync zachowuje osady")
			_check(get_node("Main/HUD").settlement_name.text == "Koralowa", "HUD po resyncu")
			_tap_control(_map().back_plaque)
		elif _frame == _gate + 24:
			_check(SceneManager.current_view == SceneManager.VIEW_ISLAND_DETAIL, "plakietka OSADA wraca do osady")
			print("SMOKE %s" % ("FAILED" if _failed else "PASSED"))
			get_tree().quit(1 if _failed else 0)
	elif _frame > 60000:
		# Bezpiecznik: jeśli Sheets nigdy nie przestanie blokować ekranu, test kończy się z
		# jawnym błędem zamiast wisieć w nieskończoność.
		_check(false, "warstwa arkuszy nie odblokowała ekranu w rozsądnym czasie (faza %d)" % _phase)
		print("SMOKE FAILED")
		get_tree().quit(1)
