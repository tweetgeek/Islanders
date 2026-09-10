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
## Daleko od krawędzi świata (0..1_792_000, czyli 4000 komórek × 448 px), żeby kamera nigdy
## nie była przycinana przez bounds.
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


## Ustawia kamerę tak, żeby wskazany punkt ekranu pokrywał się ze środkiem wyspy w komórce.
func _aim(camera: MapCamera, screen_pos: Vector2, cell: Vector2i) -> void:
	var half := camera.get_viewport_rect().size / 2.0
	camera.position = WorldGrid.island_center(WORLD_SEED, cell) - (screen_pos - half) / camera.zoom


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


## Najmniejszy dopuszczalny prześwit między obwódkami wody przybrzeżnej sąsiednich wysp.
## Pomiar przy CELL_SIZE 448 i OFFSET_RANGE 0.13 dał ~52 px na ~14 000 par (spec, sekcja 5.2).
const MIN_SHALLOW_GAP := 40.0


func _shallow_at(cell: Vector2i, island: Island) -> PackedVector2Array:
	var center := WorldGrid.island_center(WORLD_SEED, cell)
	var out := PackedVector2Array()
	for p in IslandGenerator.shallow_outline(island.seed_val, island.radius):
		out.append(p + center)
	return out


## Niezmiennik geometrii na tych samych wielokątach, które widać na ekranie: każdą obwódkę
## poszerzamy o połowę prześwitu i żadne dwie sąsiednie (także po przekątnej) nie mogą się
## wtedy przeciąć. Zmniejszenie komórki albo zwiększenie przesunięcia musi przejść ten test.
func test_neighbouring_shallows_keep_a_clear_gap() -> void:
	var inflated := {}
	for y in range(50, 110):
		for x in range(50, 110):
			var cell := Vector2i(x, y)
			var island := WorldGrid.island_at(WORLD_SEED, cell)
			if island != null:
				var grown := Geometry2D.offset_polygon(_shallow_at(cell, island), MIN_SHALLOW_GAP / 2.0, Geometry2D.JOIN_ROUND)
				inflated[cell] = grown[0]
	var pairs := 0
	for cell: Vector2i in inflated:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
			var other := cell + d
			if not inflated.has(other):
				continue
			pairs += 1
			assert_bool(Geometry2D.intersect_polygons(inflated[cell], inflated[other]).is_empty()) \
				.override_failure_message("obwódki %s i %s bliżej niż %d px" % [cell, other, MIN_SHALLOW_GAP]) \
				.is_true()
	assert_int(pairs).is_greater(100)


## _on_tapped sprawdza wyłącznie wyspę tapniętej komórki. To wystarcza, dopóki dysk trafienia
## największej, najbardziej przesuniętej wyspy mieści się w połowie komórki na każdej osi:
## 0,13 × 448 + 1,1 × 110 = 179 px < 224 px.
func test_tap_disc_never_leaves_its_cell() -> void:
	var reach := WorldGrid.OFFSET_RANGE * WorldGrid.CELL_SIZE + WorldGrid.RADIUS_MAX * IslandGenerator.TAP_RADIUS_FACTOR
	assert_float(reach).is_less(WorldGrid.CELL_SIZE / 2.0)


## Punkt po stronie przesunięcia wyspy, w 95 % promienia trafienia od jej środka, ale dalej od
## środka komórki niż promień trafienia. Liczone od środka komórki - jak przed tą zmianą - byłoby
## pudłem; liczone od środka wyspy jest trafieniem.
func test_tap_measures_from_the_offset_island_centre() -> void:
	_apply_world()
	GameState.apply_settlements([_foreign(FOREIGN_CELL, "Szara Skała")])
	var sheets := _sheets()
	var world_map := _spawn_map(START_POS)
	await _resize_window(PORTRAIT_WINDOW)
	var camera: MapCamera = world_map.camera
	var island := WorldGrid.island_at(WORLD_SEED, FOREIGN_CELL)
	var tap_radius := island.radius * IslandGenerator.TAP_RADIUS_FACTOR
	var centre := WorldGrid.island_center(WORLD_SEED, FOREIGN_CELL)
	var cell_centre := WorldGrid.cell_to_world(FOREIGN_CELL)
	var target := centre + (centre - cell_centre).normalized() * tap_radius * 0.95
	assert_float(target.distance_to(cell_centre)).is_greater(tap_radius)
	camera.position = target   # środek ekranu wskazuje pozycję kamery
	_tap(camera, camera.get_viewport_rect().size / 2.0)
	await await_idle_frame()
	assert_bool(sheets.is_open()).is_true()
	assert_object(sheets.current_sheet()).is_same(sheets.inspect_sheet)


func test_labels_sit_under_their_island_and_do_not_overlap() -> void:
	_apply_world()
	GameState.apply_settlements([_own(HOME_CELL.x, HOME_CELL.y, "Koralowa"), _foreign(FOREIGN_CELL, "Szara Skała")])
	var world_map := _spawn_map(WorldGrid.island_center(WORLD_SEED, HOME_CELL))
	await _settle(world_map)
	var rects: Array[Rect2] = []
	for label: Label in world_map.labels.get_children():
		rects.append(Rect2(label.position, label.size))
		if label.text.begins_with("Koralowa"):
			var centre := WorldGrid.island_center(WORLD_SEED, HOME_CELL)
			assert_float(label.position.x + label.size.x / 2.0).is_equal_approx(centre.x, 0.01)
	assert_int(rects.size()).is_equal(2)
	assert_bool(rects[0].intersects(rects[1])).is_false()


## Etykieta jest węższa niż najmniejsza możliwa odległość środków sąsiadów w poziomie,
## więc dwie etykiety nie mogą się nałożyć niezależnie od tego, które wyspy są zajęte.
func test_label_is_narrower_than_the_closest_possible_neighbour() -> void:
	var closest := WorldGrid.CELL_SIZE * (1.0 - 2.0 * WorldGrid.OFFSET_RANGE)
	assert_float(WORLD_MAP_SCRIPT.LABEL_SIZE.x).is_less(closest)


func test_back_plaque_is_a_square_icon_button() -> void:
	_apply_world()
	var world_map := _spawn_map(START_POS)
	await _settle(world_map)
	var back: Button = world_map.back_plaque
	var tool := float(MedievalTheme.px(WORLD_MAP_SCRIPT.TOOL))
	assert_str(back.text).is_empty()
	assert_str(back.tooltip_text).is_equal("Wróć do osady")
	assert_that(back.size).is_equal(Vector2(tool, tool))
	var icon: Icon = back.get_node("Icon")
	assert_str(String(icon.kind)).is_equal("back")
	assert_float(icon.anchor_right).is_equal(1.0)
	assert_bool(world_map.get_script().get_script_constant_map().has("BACK_WIDTH")).is_false()


## Glosariusz, Active Settlement: obejrzenie wyspy nigdy nie zmienia osady aktywnej.
## Dotyczy także własnej osady - inaczej nie dałoby się jej wskazać jako celu transportu.
func test_tapping_an_own_settlement_inspects_it_without_activating() -> void:
	_apply_world()
	GameState.apply_settlements([_own(HOME_CELL.x, HOME_CELL.y, "Koralowa"), _own(FixtureCells.OWN_SECOND.x, FixtureCells.OWN_SECOND.y, "Popielna")])
	GameState.set_active_settlement(HOME_CELL)
	var sheets := _sheets()
	var world_map := _spawn_map(START_POS)
	await _resize_window(PORTRAIT_WINDOW)
	var camera: MapCamera = world_map.camera
	var view_before := SceneManager.current_view
	var centre := camera.get_viewport_rect().size / 2.0
	for cell in [FixtureCells.OWN_SECOND, HOME_CELL]:
		_aim(camera, centre, cell)
		_tap(camera, centre)
		await await_idle_frame()
		assert_bool(sheets.is_open()).override_failure_message("tap %s nie otworzył arkusza" % cell).is_true()
		assert_object(sheets.current_sheet()).is_same(sheets.inspect_sheet)
		assert_that(GameState.active_settlement.coord).is_equal(HOME_CELL)
		assert_str(SceneManager.current_view).is_equal(view_before)
		assert_that(GameState.inspected_coord).is_equal(cell)
