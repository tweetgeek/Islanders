class_name Icon
extends Control

## Płaski glif rysowany w _draw() na siatce 24 × 24 skalowanej do size. Zero tekstur, zero emoji.
## Nieznany kind: kółko z obrysem i jedno push_warning na instancję.

const GRID := 24.0
const KINDS: Array[StringName] = [
	&"wood", &"stone", &"food", &"iron", &"sulfur",
	&"town_hall", &"barracks", &"shipyard", &"warehouse",
	&"anchor", &"map", &"fleet", &"people", &"gold",
	&"plus", &"minus", &"close", &"back",
	&"raid", &"trade", &"scout", &"colonize", &"return",
]

@export var kind: StringName = &"":
	set(v):
		kind = v
		_warned = false
		queue_redraw()
@export var color: Color = MedievalTheme.INK:
	set(v):
		color = v
		queue_redraw()

var _warned := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func is_known(k: StringName) -> bool:
	return KINDS.has(k)


## Dodaje ikonę jako dziecko przycisku, rozciągniętą na cały przycisk z marginesem inset (px).
static func into_button(button: Button, k: StringName, c: Color, inset: float) -> Icon:
	var icon := Icon.new()
	icon.name = "Icon"
	icon.kind = k
	icon.color = c
	button.add_child(icon)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = inset
	icon.offset_top = inset
	icon.offset_right = -inset
	icon.offset_bottom = -inset
	return icon


func _draw() -> void:
	var s := minf(size.x, size.y) / GRID
	if s <= 0.0:
		return
	# wyśrodkowanie, gdy kontrolka nie jest kwadratem
	draw_set_transform((size - Vector2.ONE * GRID * s) / 2.0, 0.0, Vector2(s, s))
	if not is_known(kind):
		if not _warned:
			_warned = true
			push_warning("Icon: nieznany kind '%s'" % kind)
		draw_arc(Vector2(12, 12), 9.0, 0.0, TAU, 32, color, 2.0, true)
		return
	call("_draw_" + String(kind))


func _p(x: float, y: float) -> Vector2:
	return Vector2(x, y)


func _poly(points: Array) -> void:
	var packed := PackedVector2Array()
	for pt in points:
		packed.append(pt)
	draw_colored_polygon(packed, color)


func _line(a: Vector2, b: Vector2, width: float = 2.0) -> void:
	draw_line(a, b, color, width, true)


func _draw_wood() -> void:
	_line(_p(4, 17), _p(20, 7), 4.5)
	_line(_p(4, 10), _p(14, 4), 3.0)
	_line(_p(11, 20), _p(20, 14), 3.0)


func _draw_stone() -> void:
	var pts: Array = []
	for i in 6:
		pts.append(Vector2(12, 12) + Vector2.from_angle(float(i) / 6.0 * TAU) * 9.0)
	_poly(pts)


func _draw_food() -> void:
	_line(_p(12, 21), _p(12, 6), 2.0)
	draw_circle(_p(12, 5), 2.6, color)
	draw_circle(_p(8, 9), 2.4, color)
	draw_circle(_p(16, 9), 2.4, color)
	draw_circle(_p(9, 13.5), 2.2, color)
	draw_circle(_p(15, 13.5), 2.2, color)


func _draw_iron() -> void:
	_poly([_p(3, 18), _p(21, 18), _p(17.5, 9), _p(6.5, 9)])


func _draw_sulfur() -> void:
	_poly([_p(12, 3), _p(21.5, 20.5), _p(2.5, 20.5)])
	draw_circle(_p(12, 15.5), 2.4, MedievalTheme.PARCHMENT)


func _draw_town_hall() -> void:
	draw_rect(Rect2(_p(5, 12), _p(14, 9)), color)
	_poly([_p(3, 12.5), _p(12, 5), _p(21, 12.5)])
	draw_rect(Rect2(_p(15, 3), _p(4, 6)), color)
	draw_rect(Rect2(_p(10.5, 15), _p(3, 6)), MedievalTheme.PARCHMENT)


func _draw_barracks() -> void:
	_poly([_p(4, 4), _p(20, 4), _p(20, 12), _p(12, 21), _p(4, 12)])
	_line(_p(12, 7), _p(12, 17), 1.6)
	_line(_p(7, 9), _p(17, 9), 1.6)


func _draw_shipyard() -> void:
	_draw_anchor()


func _draw_anchor() -> void:
	draw_arc(_p(12, 5), 2.2, 0.0, TAU, 20, color, 1.8, true)
	_line(_p(12, 7.5), _p(12, 20), 2.4)
	_line(_p(7, 10), _p(17, 10), 2.0)
	draw_arc(_p(12, 13), 7.0, 0.3, PI - 0.3, 20, color, 2.4, true)


func _draw_warehouse() -> void:
	draw_rect(Rect2(_p(4, 9), _p(16, 12)), color)
	_poly([_p(3, 9), _p(12, 4), _p(21, 9)])
	_line(_p(4, 14.5), _p(20, 14.5), 1.4)
	draw_rect(Rect2(_p(10, 15.5), _p(4, 5.5)), MedievalTheme.PARCHMENT)


func _draw_map() -> void:
	_poly([_p(3, 5), _p(9, 3), _p(15, 5), _p(21, 3), _p(21, 19), _p(15, 21), _p(9, 19), _p(3, 21)])
	draw_line(_p(9, 3), _p(9, 19), MedievalTheme.PARCHMENT, 1.4, true)
	draw_line(_p(15, 5), _p(15, 21), MedievalTheme.PARCHMENT, 1.4, true)


func _draw_fleet() -> void:
	_line(_p(11, 3), _p(11, 16), 2.0)
	_poly([_p(12, 4), _p(20, 15), _p(12, 15)])
	_poly([_p(3, 17), _p(21, 17), _p(18, 21), _p(6, 21)])


func _draw_people() -> void:
	draw_circle(_p(8, 8), 3.2, color)
	draw_circle(_p(16.5, 8), 3.2, color)
	_poly([_p(3, 21), _p(3, 16), _p(6, 13), _p(10, 13), _p(13, 16), _p(13, 21)])
	_poly([_p(11.5, 21), _p(11.5, 16), _p(14.5, 13), _p(18.5, 13), _p(21.5, 16), _p(21.5, 21)])


func _draw_gold() -> void:
	draw_circle(_p(12, 12), 9.0, color)
	draw_arc(_p(12, 12), 5.0, 0.0, TAU, 32, MedievalTheme.PARCHMENT, 1.8, true)


func _draw_plus() -> void:
	_line(_p(12, 4), _p(12, 20), 3.0)
	_line(_p(4, 12), _p(20, 12), 3.0)


func _draw_minus() -> void:
	_line(_p(4, 12), _p(20, 12), 3.0)


func _draw_close() -> void:
	_line(_p(5, 5), _p(19, 19), 2.6)
	_line(_p(19, 5), _p(5, 19), 2.6)


func _draw_back() -> void:
	_line(_p(20, 12), _p(6, 12), 2.6)
	_line(_p(6, 12), _p(12, 6), 2.6)
	_line(_p(6, 12), _p(12, 18), 2.6)


func _draw_raid() -> void:
	_line(_p(4, 20), _p(19, 5), 2.6)
	_line(_p(20, 20), _p(5, 5), 2.6)
	_line(_p(4, 15), _p(9, 20), 2.0)
	_line(_p(20, 15), _p(15, 20), 2.0)


func _draw_trade() -> void:
	draw_rect(Rect2(_p(4, 9), _p(16, 11)), color)
	draw_arc(_p(12, 9), 4.0, PI, TAU, 16, color, 2.0, true)
	draw_line(_p(12, 9), _p(12, 20), MedievalTheme.PARCHMENT, 1.6, true)


func _draw_scout() -> void:
	_poly([_p(4, 16), _p(8, 20), _p(20, 8), _p(16, 4)])
	draw_circle(_p(5.5, 18.5), 2.6, color)
	_line(_p(14, 7), _p(17, 10), 1.2)


func _draw_colonize() -> void:
	_line(_p(6, 3), _p(6, 21), 2.2)
	_poly([_p(7, 4), _p(20, 8), _p(7, 12)])


func _draw_return() -> void:
	draw_arc(_p(12, 12), 7.0, -PI / 2.0, PI, 24, color, 2.4, true)
	_poly([_p(3, 12), _p(8, 8), _p(8, 16)])
