extends GdUnitTestSuite

## Testy WorldMap.gd: synchronizacja słownika załadowanych chunków, kolejki oczekujących
## i drzewa sceny podczas przesuwania kamery, w tym ewikcja, brak duplikatów, budżet
## spawnu na klatkę i przebudowa chunka po aktualizacji osady.

const WORLD_MAP_SCENE := preload("res://scenes/views/WorldMap.tscn")
const WORLD_MAP_SCRIPT := preload("res://scenes/views/WorldMap.gd")

const WORLD_SEED := 1337
const WORLD_SIZE := 4000
## (103, 100) to znany ląd (TROPICAL) dla ziarna 1337 - używany też w test/state/game_state_test.gd.
const HOME_CELL := Vector2i(103, 100)
## Daleko od krawędzi świata (0..1_024_000), żeby kamera nigdy nie była przycinana przez bounds.
const START_POS := Vector2(200000.0, 200000.0)


func before_test() -> void:
	GameState.reset()


func after_test() -> void:
	GameState.reset()


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


func test_po_otwarciu_mapy_zaladowane_chunki_odpowiadaja_widocznemu_obszarowi_z_marginesem() -> void:
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


func test_odsuniecie_kamery_usuwa_niechciane_chunki_ze_slownika_i_z_drzewa() -> void:
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


func test_dlugie_przesuwanie_kamery_nie_powoduje_nieograniczonego_wzrostu_wezlow() -> void:
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


func test_powrot_kamery_w_to_samo_miejsce_nie_dubluje_chunkow() -> void:
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


func test_pojedyncza_klatka_nie_przekracza_budzetu_spawnu_na_klatke() -> void:
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


func test_aktualizacja_osady_przebudowuje_chunk_zamiast_go_dublowac() -> void:
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
