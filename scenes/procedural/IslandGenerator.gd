@tool
class_name IslandGenerator
extends Node2D

## Rysuje wyspę z (seed_val, radius, biome) wyłącznie z Polygon2D / Line2D / Label.
## W edytorze zmiana eksportu przebudowuje podgląd; w grze wołaj build() po ustawieniu pól.

const POINTS := 48
const SHALLOW_SCALE := 1.18
const LAND_SCALE := 0.78
const LAND_ROUGHNESS := 0.25
const CRATER_SCALE := 0.18
const SLOT_RING := 0.45
const SLOT_SIZE := 0.12
const SLOT_HIT := 1.4
const SHALLOW_COLOR := Color(0.55, 0.85, 0.95, 0.45)
const EMPTY_SLOT_FILL := Color(0.5, 0.5, 0.5, 0.35)
const EMPTY_SLOT_LINE := Color(0.6, 0.6, 0.6)

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


func build() -> void:
	for c in get_children():
		remove_child(c)
		c.free()
	_slot_positions.clear()
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
	var size := radius * SLOT_SIZE
	var node := Node2D.new()
	node.name = "Slot_" + Buildings.key(t)
	node.position = pos
	var hex := Polygon2D.new()
	hex.polygon = hexagon(size)
	hex.color = Biome.colors(biome)["land"].darkened(0.35) if lvl > 0 else EMPTY_SLOT_FILL
	node.add_child(hex)
	var outline := Line2D.new()
	outline.points = hexagon(size)
	outline.closed = true
	outline.width = 2.0
	outline.default_color = Color.WHITE if lvl > 0 else EMPTY_SLOT_LINE
	node.add_child(outline)
	var label := Label.new()
	label.text = "%s\n%d" % [Buildings.label(t), lvl] if lvl > 0 else Buildings.label(t)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(160, 48)
	label.position = Vector2(-80, size + 4)
	label.add_theme_font_size_override("font_size", 16)
	node.add_child(label)
	add_child(node)


## Typ budynku pod pozycją lokalną albo -1.
func slot_at(local_pos: Vector2) -> int:
	for t in _slot_positions:
		if local_pos.distance_to(_slot_positions[t]) <= radius * SLOT_SIZE * SLOT_HIT:
			return t
	return -1


func contains(local_pos: Vector2) -> bool:
	return local_pos.length() <= radius * 1.1


static func hexagon(r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 6:
		out.append(Vector2.from_angle(float(i) / 6.0 * TAU) * r)
	return out
