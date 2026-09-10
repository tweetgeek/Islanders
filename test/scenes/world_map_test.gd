extends GdUnitTestSuite

## Testy WorldMap.gd: synchronizacja słownika załadowanych chunków, kolejki oczekujących
## i drzewa sceny podczas przesuwania kamery, w tym ewikcja, brak duplikatów, budżet
## spawnu na klatkę i przebudowa chunka po aktualizacji osady. Dalej chrome mapy: układ
## pod paskiem HUD po obrocie ekranu i martwa strefa tapnięć w obrębie paska.

const WORLD_MAP_SCENE := preload("res://scenes/views/WorldMap.tscn")
const WORLD_MAP_SCRIPT := preload("res://scenes/views/WorldMap.gd")
const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")
const SHEETS_SCENE := preload("res://scenes/ui/Sheets.tscn")

const WORLD_SEED := FixtureCells.WORLD_SEED
const WORLD_SIZE := 4000
const HOME_CELL := FixtureCells.HOME
const FOREIGN_CELL := FixtureCells.FOREIGN
## Daleko od krawędzi świata (0..1_024_000), żeby kamera nigdy nie była przycinana przez bounds.
const START_POS := Vector2(200000.0, 200000.0)
## Portret projektu; testy obracające ekran wracają do niego, żeby nie zmieniać stanu innym testom.
const PORTRAIT_WINDOW := Vector2i(1080, 1920)
const LANDSCAPE_WINDOW := Vector2i(1920, 1080)

var _window_size := Vector2i.ZERO


func before_test() -> void:
	GameState.reset()
	SceneManager.map_camera_state.clear()
	_window_size = get_tree().root.size


func after_test() -> void:
	GameState.reset()
	SceneManager.map_camera_state.clear()
	get_tree().root.size = _window_size


func _chunk_world_size() -> float:
	return WorldGrid.CELL_SIZE * WorldGrid.CHUNK_SIZE


func _apply_world() -> void:
	GameState.apply_world(
		{
			"id": "w1",
			"seed": WORLD_SEED,
			"size": {"w": WORLD_SIZE, "h": WORLD_SIZE},
			"playerId": 7,
			"homeSettlement": {"x": HOME_CELL.x, "y": HOME_CELL.y},
		}
	)


func _own(x: int, y: int, settlement_name: String) -> Dictionary:
	return {
		"x": x,
		"y": y,
		"ownerId": 7,
		"name": settlement_name,
		"resources": {},
		"productionPerHour": {},
		"capacity": 100,
	}


## Cudza osada: kontrakt API nie przysyła dla niej "resources" i po tym poznaje ją Settlement.
func _foreign(cell: Vector2i, settlement_name: String) -> Dictionary:
	return {"x": cell.x, "y": cell.y, "ownerId": 9, "name": settlement_name}


func _hud() -> CanvasLayer:
	var hud: CanvasLayer = auto_free(HUD_SCENE.instantiate())
	add_child(hud)
	return hud


func _sheets() -> CanvasLayer:
	var s: CanvasLayer = auto_free(SHEETS_SCENE.instantiate())
	add_child(s)
	return s


## Zmienia rozmiar okna (a więc i widocznego prostokąta viewportu) i czeka, aż kontenery
## przesortują się po odroczonym queue_sort - dopiero wtedy rozmiary są ostateczne.
func _resize_window(size: Vector2i) -> void:
	get_tree().root.size = size
	await await_idle_frame()
	await await_idle_frame()
	await await_idle_frame()


## Tap tą samą drogą co MapCamera._unhandled_input: przyciśnięcie i puszczenie jednym palcem
## w tym samym punkcie, czyli poniżej progu czasu i dystansu MapCamera.
func _tap(camera: MapCamera, screen_pos: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.pressed = pressed
		e.position = screen_pos
		camera._on_touch(e)


## Ustawia kamerę tak, żeby wskazany punkt ekranu pokrywał się ze środkiem komórki.
func _aim(camera: MapCamera, screen_pos: Vector2, cell: Vector2i) -> void:
	var half := camera.get_viewport_rect().size / 2.0
	camera.position = WorldGrid.cell_to_world(cell) - (screen_pos - half) / camera.zoom


func _spawn_map(cam_pos: Vector2) -> Node2D:
	var world_map: Node2D = auto_free(WORLD_MAP_SCENE.instantiate())
	# Kamera to jeszcze nie @onready var (węzeł poza drzewem) - ustawiamy ją na dziecku wprost,
	# żeby pierwsze _refresh_chunks() w _ready() liczyło już od właściwej pozycji.
	(world_map.get_node("Camera") as MapCamera).position = cam_pos
	add_child(world_map)
	return world_map


## Czeka realny czas (nie sztywną liczbę klatek), bo CHUNK_REFRESH i budżet spawnu działają
## na akumulatorze delty w _process. Najpierw czekamy dłużej niż CHUNK_REFRESH, żeby timer
## odświeżania na pewno zdążył choć raz zadziałać (bez tego _pending bywa puste tuż po ruchu
## kamery, bo odświeżenie jeszcze się nie zdarzyło), potem dosypujemy klatek, aż kolejka
## oczekujących wyschnie.
func _settle(world_map: Node2D, max_wait_ms: int = 2000) -> void:
	var refresh_wait_ms := int(WORLD_MAP_SCRIPT.CHUNK_REFRESH * 1000.0) + 100
	await await_millis(refresh_wait_ms)
	var waited := 0
	while not (world_map._pending as Array).is_empty() and waited < max_wait_ms:
		await await_millis(20)
		waited += 20


## Niezależny od implementacji sposób policzenia oczekiwanego zbioru chunków: rdzeń wyliczony
## z samego widocznego prostokąta kamery (bez marginesu), rozszerzony o dokładnie jeden chunk
## w każdą stronę - to jest właśnie obietnica "margines jednego chunka".
func _expected_wanted(camera: MapCamera) -> Dictionary:
	var rect := camera.visible_world_rect()
	var c0 := WorldGrid.chunk_of(WorldGrid.world_to_cell(rect.position))
	var c1 := WorldGrid.chunk_of(WorldGrid.world_to_cell(rect.end))
	var wanted := {}
	for cy in range(c0.y - 1, c1.y + 2):
		for cx in range(c0.x - 1, c1.x + 2):
			wanted[Vector2i(cx, cy)] = true
	return wanted


func _descendant_count(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		count += 1
		count += _descendant_count(child)
	return count


## true, jeśli węzeł nadal istnieje i jest wciąż dzieckiem kontenera - dokładnie ten stan
## byłby wyciekiem, gdyby chunk zniknął ze słownika, ale nie został zwolniony/odpięty.
## `node` celowo bez typu: po queue_free() przekazanie już zwolnionej referencji do parametru
## typowanego jako Node wywala silnik błędem "previously freed" jeszcze przed wejściem do funkcji.
func _still_parented(container: Node, node) -> bool:
	if not is_instance_valid(node):
		return false
	return (node as Node).get_parent() == container


func test_map_saves_camera_state_on_exit_and_restores_it() -> void:
	_apply_world()
	SceneManager.map_camera_state.clear()
	var world_map := _spawn_map(START_POS)
	await _settle(world_map)
	var camera: MapCamera = world_map.camera
	camera.position = START_POS + Vector2(1234.0, 567.0)
	camera.zoom = Vector2(0.5, 0.5)
	var saved_pos := camera.position
	remove_child(world_map)
	assert_that(SceneManager.map_camera_state.get("position")).is_equal(saved_pos)
	assert_that(SceneManager.map_camera_state.get("zoom")).is_equal(Vector2(0.5, 0.5))

	var again := _spawn_map(Vector2.ZERO)
	await _settle(again)
	assert_that((again.camera as MapCamera).position).is_equal(saved_pos)
	assert_that((again.camera as MapCamera).zoom).is_equal(Vector2(0.5, 0.5))
	SceneManager.map_camera_state.clear()


func test_focus_moves_camera_and_kills_inertia() -> void:
	_apply_world()
	SceneManager.map_camera_state.clear()
	var world_map := _spawn_map(START_POS)
	await _settle(world_map)
	var camera: MapCamera = world_map.camera
	# Bez nadania pędu test przechodziłby także wtedy, gdyby focus() w ogóle nie ruszał _velocity.
	camera._velocity = Vector2(900.0, -450.0)
	var target := START_POS + Vector2(5000.0, -3000.0)
	world_map.focus(target)
	assert_that(camera.position).is_equal(target)
	assert_that(camera._velocity).is_equal(Vector2.ZERO)


func test_loaded_chunks_match_visible_area_with_margin_after_opening_map() -> void:
	_apply_world()
	var world_map := _spawn_map(START_POS)
	await _settle(world_map)

	assert_int((world_map._pending as Array).size()).is_equal(0)
	var camera: MapCamera = world_map.camera
	var expected := _expected_wanted(camera)
	var loaded: Dictionary = world_map._loaded_chunks
	assert_int(loaded.size()).is_equal(expected.size())
	for key: Vector2i in expected.keys():
		assert_bool(loaded.has(key)).is_true()


func test_moving_camera_away_evicts_chunks_from_dict_and_tree() -> void:
	_apply_world()
	var world_map := _spawn_map(START_POS)
	await _settle(world_map)

	var chunks_container: Node2D = world_map.chunks
	var old_loaded: Dictionary = (world_map._loaded_chunks as Dictionary).duplicate()

	var camera: MapCamera = world_map.camera
	camera.position = START_POS + Vector2(300.0 * _chunk_world_size(), 300.0 * _chunk_world_size())
	await _settle(world_map)

	var new_loaded: Dictionary = world_map._loaded_chunks
	var evicted_count := 0
	for key: Vector2i in old_loaded.keys():
		if new_loaded.has(key):
			continue
		evicted_count += 1
		# Bug tej klasy: klucz zniknął ze słownika, ale węzeł został osierocony pod Chunks.
		assert_bool(_still_parented(chunks_container, old_loaded[key])).is_false()
	assert_int(evicted_count).is_greater(0)


func test_long_camera_pan_does_not_grow_nodes_unbounded() -> void:
	_apply_world()
	var world_map := _spawn_map(START_POS)
	await _settle(world_map)

	var camera: MapCamera = world_map.camera
	var chunks_container: Node2D = world_map.chunks
	var step := Vector2(20.0 * _chunk_world_size(), 0.0)
	for i in 15:
		camera.position += step
		await _settle(world_map)
		var expected := _expected_wanted(camera)
		# Górny teoretyczny sufit: każdy chciany chunk, w najgorszym razie z wyspą i pierścieniem
		# osady na każdej komórce, plus sam węzeł chunka. To twardy limit niezależny od tego,
		# ile wysp faktycznie wylosował szum - realny wzrost bez ewikcji przekroczyłby go po
		# kilku krokach.
		var bound: int = expected.size() * (1 + WorldGrid.CHUNK_SIZE * WorldGrid.CHUNK_SIZE * 2)
		assert_int(_descendant_count(chunks_container)).is_less_equal(bound)
		assert_int((world_map._loaded_chunks as Dictionary).size()).is_equal(expected.size())


func test_returning_camera_to_same_spot_does_not_duplicate_chunks() -> void:
	_apply_world()
	var world_map := _spawn_map(START_POS)
	await _settle(world_map)

	var camera: MapCamera = world_map.camera
	var chunks_container: Node2D = world_map.chunks
	var away := START_POS + Vector2(30.0 * _chunk_world_size(), 0.0)

	camera.position = away
	await _settle(world_map)
	camera.position = START_POS
	await _settle(world_map)
	camera.position = away
	await _settle(world_map)
	camera.position = START_POS
	await _settle(world_map)

	var loaded: Dictionary = world_map._loaded_chunks
	assert_int(chunks_container.get_child_count()).is_equal(loaded.size())
	for key: Vector2i in loaded.keys():
		var node_name := "Chunk_%d_%d" % [key.x, key.y]
		assert_object(chunks_container.get_node_or_null(node_name)).is_not_null()


func test_single_frame_respects_spawn_budget() -> void:
	_apply_world()
	var world_map := _spawn_map(START_POS)
	await _settle(world_map)

	var camera: MapCamera = world_map.camera
	camera.position = START_POS + Vector2(80.0 * _chunk_world_size(), 80.0 * _chunk_world_size())
	world_map._refresh_chunks()
	var pending_before: int = (world_map._pending as Array).size()
	var budget: int = WORLD_MAP_SCRIPT.CHUNKS_PER_FRAME
	# Test ma sens tylko, gdy w kolejce czeka więcej niż budżet - inaczej limit nie zostałby
	# w ogóle wystawiony na próbę.
	assert_int(pending_before).is_greater(budget)
	var loaded_before: int = (world_map._loaded_chunks as Dictionary).size()

	# Wołamy dokładnie tę metodę, którą silnik wywołuje raz na klatkę - jedno jawne wywołanie
	# = jedna klatka, bez niejednoznaczności "await_idle_frame" co do kolejności sygnałów.
	world_map._process(0.001)

	var loaded_after: int = (world_map._loaded_chunks as Dictionary).size()
	assert_int(loaded_after - loaded_before).is_equal(budget)


func test_settlement_update_rebuilds_chunk_without_duplicating() -> void:
	_apply_world()
	GameState.apply_settlements([_own(HOME_CELL.x, HOME_CELL.y, "Pierwsza")])
	var world_map := _spawn_map(WorldGrid.cell_to_world(HOME_CELL))
	await _settle(world_map)

	var chunk_key := WorldGrid.chunk_of(HOME_CELL)
	var loaded: Dictionary = world_map._loaded_chunks
	assert_bool(loaded.has(chunk_key)).is_true()
	# Celowo bez typu Node: po przebudowie ten węzeł zostanie zwolniony, a przekazanie już
	# zwolnionej referencji do zmiennej/parametru typowanego jako Node wywala silnik błędem.
	var old_node = loaded[chunk_key]
	var chunks_container: Node2D = world_map.chunks

	GameState.apply_settlements([_own(HOME_CELL.x, HOME_CELL.y, "Druga")])
	await _settle(world_map)

	var new_loaded: Dictionary = world_map._loaded_chunks
	assert_bool(new_loaded.has(chunk_key)).is_true()
	var new_node = new_loaded[chunk_key]
	assert_bool(new_node == old_node).is_false()
	assert_bool(_still_parented(chunks_container, old_node)).is_false()

	# Mapa musi zostać spójna po przebudowie: bez duplikatów i wciąż zgodna z widokiem kamery.
	var camera: MapCamera = world_map.camera
	var expected := _expected_wanted(camera)
	assert_int(new_loaded.size()).is_equal(expected.size())
	assert_int(chunks_container.get_child_count()).is_equal(new_loaded.size())


func test_ui_layer_exists_with_back_and_zoom_buttons() -> void:
	_apply_world()
	var world_map := _spawn_map(START_POS)
	await _settle(world_map)
	assert_object(world_map.back_plaque).is_instanceof(Button)
	assert_object(world_map.zoom_in).is_instanceof(Button)
	assert_object(world_map.zoom_out).is_instanceof(Button)
	var before: float = (world_map.camera as MapCamera).zoom.x
	world_map.zoom_in.pressed.emit()
	assert_float((world_map.camera as MapCamera).zoom.x).is_greater(before)


func test_coord_panel_follows_camera() -> void:
	_apply_world()
	var world_map := _spawn_map(WorldGrid.cell_to_world(HOME_CELL))
	await _settle(world_map)
	world_map._process(0.0)
	assert_str(world_map.coord_label.text).is_equal("X %d · Y %d · zoom 1.0" % [HOME_CELL.x, HOME_CELL.y])


## Regresja: HUD przy size_changed przepina ResourceGrid między BarRows a ProfileRow, a
## przesortowanie kontenera jest odroczone do fazy layoutu. Widok podpięty do tego samego
## size_changed odczytuje więc bar_height() sprzed przepięcia i zostaje z nim na zawsze -
## chrome mapy wisi o cały rząd kart za nisko (albo za wysoko) aż do kolejnego obrotu.
func test_map_ui_follows_hud_bar_after_rotation() -> void:
	_apply_world()
	var hud := _hud()
	var world_map := _spawn_map(START_POS)
	await _resize_window(PORTRAIT_WINDOW)
	var m := MedievalTheme.gap(WORLD_MAP_SCRIPT.UI_MARGIN)
	assert_float(world_map.coord_panel.offset_top).is_equal_approx(hud.bar_height() + m, 0.5)

	await _resize_window(LANDSCAPE_WINDOW)
	# Obrót musi realnie zmienić wysokość paska, inaczej test przechodziłby bez naprawy.
	assert_object(hud.resource_grid.get_parent()).is_same(hud.identity_row)
	assert_float(world_map.coord_panel.offset_top).is_equal_approx(hud.bar_height() + m, 0.5)
	assert_float(world_map.back_plaque.position.y).is_equal_approx(hud.bar_height() + m, 0.5)


## Pasek HUD jest przezroczysty dla inputu (żeby dało się z niego przeciągać mapę), więc
## stacjonarny tap w kartę zasobu docierał do MapCamera i uruchamiał trafienie w wyspę.
func test_tap_inside_hud_bar_does_not_open_inspect_sheet() -> void:
	_apply_world()
	GameState.apply_settlements([_foreign(FOREIGN_CELL, "Szara Skała")])
	var hud := _hud()
	var sheets := _sheets()
	var world_map := _spawn_map(START_POS)
	await _resize_window(PORTRAIT_WINDOW)
	var camera: MapCamera = world_map.camera
	var vis := camera.get_viewport_rect().size
	assert_float(hud.bar_height()).is_greater(0.0)

	var bar_point := Vector2(vis.x / 2.0, hud.bar_height() / 2.0)
	_aim(camera, bar_point, FOREIGN_CELL)
	_tap(camera, bar_point)
	await await_idle_frame()
	assert_bool(sheets.is_open()).is_false()

	# Kontrola: ten sam tap poniżej paska nadal otwiera arkusz.
	var below := vis / 2.0
	_aim(camera, below, FOREIGN_CELL)
	_tap(camera, below)
	await await_idle_frame()
	assert_bool(sheets.is_open()).is_true()
	assert_object(sheets.current_sheet()).is_same(sheets.inspect_sheet)


## Ta sama martwa strefa od drugiej strony: tap w pasek nad własną wyspą nie może przestawić
## osady aktywnej ani przerzucić gracza do widoku osady.
func test_tap_inside_hud_bar_does_not_enter_own_settlement() -> void:
	_apply_world()
	GameState.apply_settlements([_own(HOME_CELL.x, HOME_CELL.y, "Koralowa")])
	var hud := _hud()
	var _sheets_layer := _sheets()
	var world_map := _spawn_map(START_POS)
	await _resize_window(PORTRAIT_WINDOW)
	var camera: MapCamera = world_map.camera
	var vis := camera.get_viewport_rect().size

	var view_before := SceneManager.current_view
	var bar_point := Vector2(vis.x / 2.0, hud.bar_height() / 2.0)
	_aim(camera, bar_point, HOME_CELL)
	_tap(camera, bar_point)
	await await_idle_frame()
	assert_object(GameState.active_settlement).is_null()
	assert_str(SceneManager.current_view).is_equal(view_before)


func test_map_ui_margins_are_gaps() -> void:
	_apply_world()
	var world_map := _spawn_map(START_POS)
	await _settle(world_map)
	assert_float(world_map.back_plaque.position.x).is_equal(float(MedievalTheme.gap(world_map.UI_MARGIN)))
	assert_int(world_map.zoom_controls.get_theme_constant("separation")).is_equal(MedievalTheme.gap(8))
