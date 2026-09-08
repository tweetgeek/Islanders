@tool
class_name IslandGenerator
extends Node2D

## Rysuje wyspę z (seed_val, radius, biome) z Polygon2D / Line2D, a sloty budynków jako SlotPlaque.
## W edytorze zmiana eksportu przebudowuje podgląd; w grze wołaj build() po ustawieniu pól.

const POINTS := 48
const SHALLOW_SCALE := 1.18
const LAND_SCALE := 0.78
const LAND_ROUGHNESS := 0.25
const CRATER_SCALE := 0.18
const SLOT_RING := 0.45
## Promień trafienia w wyspę przy tapnięciu (tu i w WorldMap._on_tapped) - jedyne miejsce definicji.
const TAP_RADIUS_FACTOR := 1.1
const SHALLOW_COLOR := Color(0.55, 0.85, 0.95, 0.45)

@export var seed_val: int = 1:
	set(v):
		seed_val = v
		_editor_rebuild()
@export var radius: float = 96.0:
	set(v):
		radius = v
		_editor_rebuild()
@export var biome: Biome.Type = Biome.Type.TROPICAL:
	set(v):
		biome = v
		_editor_rebuild()
@export var show_slots: bool = false:
	set(v):
		show_slots = v
		_editor_rebuild()
@export var show_deposit: bool = false:
	set(v):
		show_deposit = v
		_editor_rebuild()

## Osada (może być null): poziomy budynków w slotach.
var settlement: Settlement = null
## Znalezisko: zasób -> ilość.
var deposit: Dictionary = {}

var _coast := PackedVector2Array()
## Buildings.Type -> pozycja lokalna
var _slot_positions: Dictionary = {}


func _ready() -> void:
	build()


func _editor_rebuild() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		build()


func clear() -> void:
	for c in get_children():
		remove_child(c)
		c.free()
	_slot_positions.clear()


func build() -> void:
	clear()
	_coast = CoastlineGenerator.generate(seed_val, radius, POINTS)
	var colors := Biome.colors(biome)
	_add_polygon("Shallow", CoastlineGenerator.scaled(_coast, SHALLOW_SCALE), SHALLOW_COLOR)
	_add_polygon("Sand", _coast, colors["sand"])
	var land_points := CoastlineGenerator.generate(seed_val, radius * LAND_SCALE, POINTS, LAND_ROUGHNESS)
	_add_polygon("Land", land_points, colors["land"])
	if biome == Biome.Type.VOLCANIC:
		_add_polygon("Crater", CoastlineGenerator.generate(seed_val + 1, radius * CRATER_SCALE, 16, 0.3), colors["crater"])
	var line := Line2D.new()
	line.name = "Coast"
	line.points = _coast
	line.closed = true
	line.width = 3.0
	line.default_color = colors["coast"]
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	add_child(line)
	if show_deposit and not deposit.is_empty():
		_add_deposit_marker()
	if show_slots:
		_build_slots()


func _add_polygon(node_name: String, points: PackedVector2Array, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.name = node_name
	poly.polygon = points
	poly.color = color
	add_child(poly)
	return poly


## Romb przy brzegu, po przeciwnej stronie niż zatoka, w kolorze pierwszego zasobu znaleziska.
func _add_deposit_marker() -> void:
	var angle := CoastlineGenerator.bay_angle(_coast) + PI
	var pos := Vector2.from_angle(angle) * radius * 0.85
	var s := radius * 0.1
	var marker := Polygon2D.new()
	marker.name = "Deposit"
	marker.polygon = PackedVector2Array([Vector2(0, -s), Vector2(s, 0), Vector2(0, s), Vector2(-s, 0)])
	marker.position = pos
	marker.color = ResourceTypes.COLORS[deposit.keys()[0]]
	add_child(marker)


## Ratusz w centrum, 5 slotów na okręgu co 72°, stocznia w kierunku zatoki.
func _build_slots() -> void:
	var ring: Array = Biome.slots(biome).filter(func(t: int) -> bool: return t != Buildings.Type.TOWN_HALL)
	ring.erase(Buildings.Type.SHIPYARD)
	ring.insert(0, Buildings.Type.SHIPYARD)
	var bay := CoastlineGenerator.bay_angle(_coast)
	_slot_positions[Buildings.Type.TOWN_HALL] = Vector2.ZERO
	for i in ring.size():
		var a := bay + float(i) / float(ring.size()) * TAU
		_slot_positions[ring[i]] = Vector2.from_angle(a) * radius * SLOT_RING
	for t in _slot_positions:
		_add_slot(t, _slot_positions[t])


func _add_slot(t: Buildings.Type, pos: Vector2) -> void:
	var lvl := settlement.level(t) if settlement != null else 0
	var plaque := SlotPlaque.new()
	plaque.name = "Slot_" + Buildings.key(t)
	plaque.position = pos
	plaque.setup(t, lvl)
	add_child(plaque)


## Typ budynku pod pozycją lokalną (prostokąt plakietki) albo -1.
func slot_at(local_pos: Vector2) -> int:
	for t in _slot_positions:
		var plaque := _plaque(t)
		if plaque != null and plaque.contains(local_pos - _slot_positions[t]):
			return t
	return -1


func set_pressed(t: int, pressed: bool) -> void:
	var plaque := _plaque(t)
	if plaque != null:
		plaque.pressed = pressed


func _plaque(t: int) -> SlotPlaque:
	return get_node_or_null("Slot_" + Buildings.key(t)) as SlotPlaque


## Czy punkt lokalny (środek = środek wyspy) mieści się w promieniu trafienia przy tapnięciu.
## Statyczna i przyjmuje promień jawnie, żeby wołać ją bez tworzenia instancji generatora
## (np. z WorldMap._on_tapped dla wysp w chunkach, które mogą być aktualnie niezaładowane).
static func contains(local_pos: Vector2, island_radius: float) -> bool:
	return local_pos.length() <= island_radius * TAP_RADIUS_FACTOR
