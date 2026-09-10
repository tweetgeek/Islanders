extends Node2D

const CHUNK_REFRESH := 0.2
const CHUNKS_PER_FRAME := 2
const LABEL_MIN_ZOOM := 0.6
const OWN_COLOR := MedievalTheme.BRASS
const FOREIGN_COLOR := MedievalTheme.CREAM_SOFT
const LABEL_FONT_SIZE := 32
## Etykieta osady pod wyspą. Szerokość musi zostać mniejsza niż najmniejsza odległość środków
## sąsiadów (CELL_SIZE × (1 − 2 × OFFSET_RANGE) = 332 px) - pilnuje tego world_map_test.
const LABEL_SIZE := Vector2(240, 56)
const UI_MARGIN := 10.0
const TOOL := 46.0

@onready var water: Node2D = $Water
@onready var chunks: Node2D = $Chunks
@onready var labels: Node2D = $Labels
@onready var fleets: FleetRenderer = $Fleets
@onready var camera: MapCamera = $Camera
@onready var back_plaque: Button = $UI/BackPlaque
@onready var coord_panel: PanelContainer = $UI/CoordPanel
@onready var coord_label: Label = $UI/CoordPanel/Coord
@onready var zoom_controls: VBoxContainer = $UI/ZoomControls
@onready var zoom_in: Button = $UI/ZoomControls/ZoomIn
@onready var zoom_out: Button = $UI/ZoomControls/ZoomOut

## Vector2i chunk -> Node2D
var _loaded_chunks: Dictionary = {}
var _pending: Array[Vector2i] = []
var _refresh_accum := 0.0


func _ready() -> void:
	camera.tapped.connect(_on_tapped)
	GameState.settlement_updated.connect(_on_settlement_updated)
	GameState.fleets_updated.connect(fleets.refresh)
	var saved: Dictionary = SceneManager.map_camera_state
	if saved.has("position"):
		camera.position = saved["position"]
	elif GameState.active_settlement != null:
		camera.position = WorldGrid.island_center(GameState.world_seed(), GameState.active_settlement.coord)
	if saved.has("zoom"):
		camera.zoom = saved["zoom"]
	if GameState.world != null:
		camera.set_bounds(Rect2(Vector2.ZERO, Vector2(GameState.world.size) * WorldGrid.CELL_SIZE))
	_rebuild_labels()
	_refresh_chunks()
	back_plaque.pressed.connect(SceneManager.show_island_detail)
	zoom_in.pressed.connect(camera.zoom_by.bind(1.25))
	zoom_out.pressed.connect(camera.zoom_by.bind(0.8))
	_style_ui()
	get_viewport().size_changed.connect(_layout_ui)
	var hud := _hud()
	if hud != null:
		hud.bar_height_changed.connect(_layout_ui)
	_layout_ui()


func _exit_tree() -> void:
	SceneManager.map_camera_state["position"] = camera.position
	SceneManager.map_camera_state["zoom"] = camera.zoom


## Natychmiastowy skok kamery (arkusz flot).
func focus(world_pos: Vector2) -> void:
	camera.jump_to(world_pos)


func _process(delta: float) -> void:
	_refresh_accum += delta
	if _refresh_accum >= CHUNK_REFRESH:
		_refresh_accum = 0.0
		_refresh_chunks()
	_spawn_pending(CHUNKS_PER_FRAME)
	labels.visible = camera.zoom.x >= LABEL_MIN_ZOOM
	water.visible_rect = camera.visible_world_rect()
	water.queue_redraw()
	var cell := WorldGrid.world_to_cell(camera.position)
	coord_label.text = "X %d · Y %d · zoom %.1f" % [cell.x, cell.y, camera.zoom.x]


func _refresh_chunks() -> void:
	var rect := camera.visible_world_rect().grow(WorldGrid.CELL_SIZE * WorldGrid.CHUNK_SIZE)
	var c0 := WorldGrid.chunk_of(WorldGrid.world_to_cell(rect.position))
	var c1 := WorldGrid.chunk_of(WorldGrid.world_to_cell(rect.end))
	var wanted := {}
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			wanted[Vector2i(cx, cy)] = true
	for key in _loaded_chunks.keys():
		if not wanted.has(key):
			_loaded_chunks[key].queue_free()
			_loaded_chunks.erase(key)
	for key in wanted:
		if not _loaded_chunks.has(key) and not _pending.has(key):
			_pending.append(key)


func _spawn_pending(max_count: int) -> void:
	for i in max_count:
		if _pending.is_empty():
			return
		var key: Vector2i = _pending.pop_front()
		if not _loaded_chunks.has(key):
			_spawn_chunk(key)


func _spawn_chunk(chunk: Vector2i) -> void:
	var node := Node2D.new()
	node.name = "Chunk_%d_%d" % [chunk.x, chunk.y]
	for y in WorldGrid.CHUNK_SIZE:
		for x in WorldGrid.CHUNK_SIZE:
			var cell := chunk * WorldGrid.CHUNK_SIZE + Vector2i(x, y)
			var island := GameState.island_at(cell)
			if island == null:
				continue
			var s := GameState.settlement_at(cell)
			var gen := IslandGenerator.new()
			gen.name = "Island_" + Coord.key(cell)
			gen.seed_val = island.seed_val
			gen.radius = island.radius
			gen.biome = island.biome
			gen.show_slots = false
			gen.show_deposit = s == null
			gen.deposit = island.deposit
			gen.position = WorldGrid.island_center(GameState.world_seed(), cell)
			node.add_child(gen)
			if s != null:
				node.add_child(_settlement_ring(gen.position, island.radius, s))
	chunks.add_child(node)
	_loaded_chunks[chunk] = node


func _settlement_ring(pos: Vector2, radius: float, s: Settlement) -> Line2D:
	var ring := Line2D.new()
	ring.name = "Ring_" + Coord.key(s.coord)
	var pts := PackedVector2Array()
	for i in 32:
		pts.append(pos + Vector2.from_angle(float(i) / 32.0 * TAU) * radius * 1.3)
	ring.points = pts
	ring.closed = true
	ring.width = 3.0
	ring.default_color = OWN_COLOR if s.is_own else FOREIGN_COLOR
	return ring


func _style_ui() -> void:
	var tool := MedievalTheme.px(TOOL)
	# Sama strzałka, jak przyciski doku i przybliżania: napis zasłaniał wyspę pod paskiem.
	back_plaque.custom_minimum_size = Vector2(tool, tool)
	Icon.into_button(back_plaque, &"back", MedievalTheme.CREAM, MedievalTheme.px(12))
	coord_label.add_theme_color_override("font_color", MedievalTheme.PARCHMENT)
	zoom_controls.add_theme_constant_override("separation", MedievalTheme.gap(8))
	for b in [zoom_in, zoom_out]:
		b.custom_minimum_size = Vector2(tool, tool)
	Icon.into_button(zoom_in, &"plus", MedievalTheme.CREAM, MedievalTheme.px(13))
	Icon.into_button(zoom_out, &"minus", MedievalTheme.CREAM, MedievalTheme.px(13))


func _hud() -> Node:
	return get_tree().get_first_node_in_group("hud")


func _hud_bar_height() -> float:
	var hud := _hud()
	return hud.bar_height() if hud != null else 0.0


## Plakietka powrotu i panel współrzędnych pod paskiem HUD, zoom nad safe area.
func _layout_ui() -> void:
	var m := MedievalTheme.gap(UI_MARGIN)
	var top := _hud_bar_height() + m
	back_plaque.position = Vector2(m, top)
	coord_panel.offset_top = top
	coord_panel.offset_right = -m
	zoom_controls.offset_right = -m
	zoom_controls.offset_bottom = -(SafeArea.bottom_inset(get_viewport()) + m)


func _rebuild_labels() -> void:
	for c in labels.get_children():
		c.queue_free()
	for s: Settlement in GameState.settlements.values():
		var island := GameState.island_at(s.coord)
		var radius := island.radius if island != null else 80.0
		var label := Label.new()
		label.text = "%s\n%s" % [s.name, "Ty" if s.is_own else "gracz %d" % s.owner_id]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = LABEL_SIZE
		label.position = WorldGrid.island_center(GameState.world_seed(), s.coord) \
			+ Vector2(-LABEL_SIZE.x / 2.0, radius * 1.3 + 4)
		label.theme_type_variation = &"Title"
		label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
		label.add_theme_color_override("font_color", OWN_COLOR if s.is_own else FOREIGN_COLOR)
		labels.add_child(label)


func _on_settlement_updated(coord: Vector2i) -> void:
	var chunk := WorldGrid.chunk_of(coord)
	if _loaded_chunks.has(chunk):
		_loaded_chunks[chunk].queue_free()
		_loaded_chunks.erase(chunk)
		_pending.append(chunk)
	_rebuild_labels()


## Pasek HUD jest przezroczysty dla inputu (żeby dało się z niego przeciągać mapę), więc
## martwa strefa na tapnięcia musi być tutaj: inaczej stacjonarny tap w kartę zasobu wybierałby
## wyspę leżącą pod paskiem. Przeciąganie idzie inną drogą i pozostaje nietknięte.
func _on_tapped(world_pos: Vector2, screen_pos: Vector2) -> void:
	if screen_pos.y < _hud_bar_height():
		return
	var cell := WorldGrid.world_to_cell(world_pos)
	var island := GameState.island_at(cell)
	if island == null:
		return
	# Od środka wyspy, nie komórki. Sąsiednich komórek nie trzeba sprawdzać: dysk trafienia
	# nigdy nie wychodzi poza własną komórkę (world_map_test, test_tap_disc_never_leaves_its_cell).
	var local := world_pos - WorldGrid.island_center(GameState.world_seed(), cell)
	if not IslandGenerator.contains(local, island.radius):
		return
	# Tapnięcie zawsze ogląda, także własną i aktywną osadę; osadę aktywną zmienia wyłącznie
	# akcja w arkuszu (glosariusz: Active Settlement).
	GameState.inspect(cell)
	var sheets := get_tree().get_first_node_in_group("sheets")
	if sheets != null:
		sheets.open_inspect(cell)
