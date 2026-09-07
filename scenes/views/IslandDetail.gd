extends Node2D

## Trzy tryby wg stanu oglądanej wyspy: własna osada (sloty), cudza osada (dane publiczne),
## wyspa niczyja (znalezisko).

const DETAIL_RADIUS := 400.0

@onready var generator: IslandGenerator = $Generator
@onready var back_button: Button = $UI/BackButton
@onready var info: Label = $UI/InfoPanel/Info
@onready var building_menu: BuildingMenu = $UI/BuildingMenu

var _settlement: Settlement = null


func _ready() -> void:
	back_button.pressed.connect(SceneManager.show_world_map)
	building_menu.upgrade_requested.connect(_on_upgrade_requested)
	GameState.inspected_island_changed.connect(_show)
	GameState.settlement_updated.connect(_on_settlement_updated)
	_show(GameState.inspected_coord)


func _show(coord: Vector2i) -> void:
	var island := GameState.island_at(coord)
	if island == null:
		info.text = "Morze"
		return
	_settlement = GameState.settlement_at(coord)
	generator.seed_val = island.seed_val
	generator.biome = island.biome
	generator.radius = DETAIL_RADIUS
	generator.deposit = island.deposit
	generator.show_deposit = _settlement == null
	generator.settlement = _settlement
	generator.show_slots = _settlement != null and _settlement.is_own
	generator.build()
	info.text = _describe(island, _settlement)


func _describe(island: Island, s: Settlement) -> String:
	var where := "(%d, %d) · %s" % [island.coord.x, island.coord.y, Biome.key(island.biome)]
	if s == null:
		if island.has_deposit():
			var parts: Array[String] = []
			for k in island.deposit:
				parts.append("%s %d" % [ResourceTypes.LABELS[k], int(island.deposit[k])])
			return "Wyspa niczyja %s\nZnalezisko: %s" % [where, ", ".join(parts)]
		return "Wyspa niczyja %s\nBrak znaleziska" % where
	if s.is_own:
		return "%s %s\nLudność %d / %d · Magazyn %d" % [
			s.name, where, s.population, s.population_max, int(s.capacity)
		]
	return "%s %s\nWłaściciel: gracz %d" % [s.name, where, s.owner_id]


func _on_settlement_updated(coord: Vector2i) -> void:
	if coord == GameState.inspected_coord:
		_show(coord)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch) or event.pressed or not generator.show_slots:
		return
	var world_pos: Vector2 = get_canvas_transform().affine_inverse() * event.position
	var slot := generator.slot_at(generator.to_local(world_pos))
	if slot >= 0:
		building_menu.open(slot, _settlement.level(slot))


func _on_upgrade_requested(building: int) -> void:
	print("upgrade_requested: %s w %s" % [Buildings.key(building), Coord.key(GameState.inspected_coord)])
