extends Node2D

const CHUNK_REFRESH := 0.2
const CHUNKS_PER_FRAME := 2
const LABEL_MIN_ZOOM := 0.6
const OWN_COLOR := Color(1.0, 0.85, 0.2)
const FOREIGN_COLOR := Color(0.85, 0.85, 0.9)

@onready var water: Node2D = $Water
@onready var chunks: Node2D = $Chunks
@onready var labels: Node2D = $Labels
@onready var fleets: FleetRenderer = $Fleets
@onready var camera: MapCamera = $Camera

## Vector2i chunk -> Node2D
var _loaded_chunks: Dictionary = {}
var _pending: Array[Vector2i] = []
var _refresh_accum := 0.0


func _ready() -> void:
	camera.tapped.connect(_on_tapped)
	GameState.settlement_updated.connect(_on_settlement_updated)
	GameState.fleets_updated.connect(fleets.refresh)
	if GameState.active_settlement != null:
		camera.position = WorldGrid.cell_to_world(GameState.active_settlement.coord)
	if GameState.world != null:
		camera.set_bounds(Rect2(Vector2.ZERO, Vector2(GameState.world.size) * WorldGrid.CELL_SIZE))
	_rebuild_labels()
	_refresh_chunks()


func _process(delta: float) -> void:
	_refresh_accum += delta
	if _refresh_accum >= CHUNK_REFRESH:
		_refresh_accum = 0.0
		_refresh_chunks()
	_spawn_pending(CHUNKS_PER_FRAME)
	labels.visible = camera.zoom.x >= LABEL_MIN_ZOOM
	water.visible_rect = camera.visible_world_rect()
	water.queue_redraw()


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
			gen.position = WorldGrid.cell_to_world(cell)
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


func _rebuild_labels() -> void:
	for c in labels.get_children():
		c.queue_free()
	for s: Settlement in GameState.settlements.values():
		var island := GameState.island_at(s.coord)
		var radius := island.radius if island != null else 80.0
		var label := Label.new()
		label.text = "%s\n%s" % [s.name, "Ty" if s.is_own else "gracz %d" % s.owner_id]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(240, 56)
		label.position = WorldGrid.cell_to_world(s.coord) + Vector2(-120, radius * 1.3 + 4)
		label.add_theme_font_size_override("font_size", 20)
		label.modulate = OWN_COLOR if s.is_own else FOREIGN_COLOR
		labels.add_child(label)


func _on_settlement_updated(coord: Vector2i) -> void:
	var chunk := WorldGrid.chunk_of(coord)
	if _loaded_chunks.has(chunk):
		_loaded_chunks[chunk].queue_free()
		_loaded_chunks.erase(chunk)
		_pending.append(chunk)
	_rebuild_labels()


func _on_tapped(world_pos: Vector2) -> void:
	var cell := WorldGrid.world_to_cell(world_pos)
	var island := GameState.island_at(cell)
	if island == null:
		return
	var local := world_pos - WorldGrid.cell_to_world(cell)
	if local.length() > island.radius * IslandGenerator.TAP_RADIUS_FACTOR:
		return
	GameState.inspect(cell)
	var s := GameState.settlement_at(cell)
	if s != null and s.is_own:
		GameState.set_active_settlement(cell)
	SceneManager.show_island_detail()
