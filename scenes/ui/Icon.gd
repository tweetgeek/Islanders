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
## Kolor wycięć w glifie (okno ratusza, fałdy mapy, żyłka kamienia). Ma być kolorem tła,
## na którym ikona leży - wtedy wycięcie czyta się jak dziura, a nie jak jasna plama.
@export var knockout: Color = MedievalTheme.PARCHMENT:
	set(v):
		knockout = v
		queue_redraw()

var _warned := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func is_known(k: StringName) -> bool:
	return KINDS.has(k)


## Dodaje ikonę jako dziecko przycisku, rozciągniętą na cały przycisk z marginesem inset (px).
## Wycięcie domyślnie dębowe, bo każdy przycisk z ikoną w tym projekcie to ToolButton na OAK.
static func into_button(button: Button, k: StringName, c: Color, inset: float,
		knockout_color: Color = MedievalTheme.OAK) -> Icon:
	var icon := Icon.new()
	icon.name = "Icon"
	icon.kind = k
	icon.color = c
	icon.knockout = knockout_color
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


func _poly(points: Array) -> void:
	var packed := PackedVector2Array()
	for pt in points:
		packed.append(pt)
	draw_colored_polygon(packed, color)


func _line(a: Vector2, b: Vector2, width: float = 2.0) -> void:
	draw_line(a, b, color, width, true)


func _draw_wood() -> void:
	_line(Vector2(4, 17), Vector2(20, 7), 4.5)
	_line(Vector2(4, 10), Vector2(14, 4), 3.0)
	_line(Vector2(11, 20), Vector2(20, 14), 3.0)


## Bryła z jedną wewnętrzną krawędzią, która dzieli ją na dwie płaszczyzny. Płaski sześciokąt
## czytał się w tej skali jak plama.
func _draw_stone() -> void:
	_poly([Vector2(5, 15), Vector2(8, 7), Vector2(14, 4), Vector2(20, 8), Vector2(21, 16), Vector2(15, 20), Vector2(8, 20)])
	draw_polyline(PackedVector2Array([Vector2(14, 4), Vector2(12, 12), Vector2(15, 20)]), knockout, 1.6, true)


func _draw_food() -> void:
	_line(Vector2(12, 21), Vector2(12, 6), 2.0)
	draw_circle(Vector2(12, 5), 2.6, color)
	draw_circle(Vector2(8, 9), 2.4, color)
	draw_circle(Vector2(16, 9), 2.4, color)
	draw_circle(Vector2(9, 13.5), 2.2, color)
	draw_circle(Vector2(15, 13.5), 2.2, color)


func _draw_iron() -> void:
	_poly([Vector2(3, 18), Vector2(21, 18), Vector2(17.5, 9), Vector2(6.5, 9)])


func _draw_sulfur() -> void:
	_poly([Vector2(12, 3), Vector2(21.5, 20.5), Vector2(2.5, 20.5)])
	draw_circle(Vector2(12, 15.5), 2.4, knockout)


func _draw_town_hall() -> void:
	draw_rect(Rect2(Vector2(5, 12), Vector2(14, 9)), color)
	_poly([Vector2(3, 12.5), Vector2(12, 5), Vector2(21, 12.5)])
	draw_rect(Rect2(Vector2(15, 3), Vector2(4, 6)), color)
	draw_rect(Rect2(Vector2(10.5, 15), Vector2(3, 6)), knockout)


func _draw_barracks() -> void:
	_poly([Vector2(4, 4), Vector2(20, 4), Vector2(20, 12), Vector2(12, 21), Vector2(4, 12)])
	_line(Vector2(12, 7), Vector2(12, 17), 1.6)
	_line(Vector2(7, 9), Vector2(17, 9), 1.6)


func _draw_shipyard() -> void:
	_draw_anchor()


func _draw_anchor() -> void:
	draw_arc(Vector2(12, 5), 2.2, 0.0, TAU, 20, color, 1.8, true)
	_line(Vector2(12, 7.5), Vector2(12, 20), 2.4)
	_line(Vector2(7, 10), Vector2(17, 10), 2.0)
	draw_arc(Vector2(12, 13), 7.0, 0.3, PI - 0.3, 20, color, 2.4, true)


func _draw_warehouse() -> void:
	draw_rect(Rect2(Vector2(4, 9), Vector2(16, 12)), color)
	_poly([Vector2(3, 9), Vector2(12, 4), Vector2(21, 9)])
	_line(Vector2(4, 14.5), Vector2(20, 14.5), 1.4)
	draw_rect(Rect2(Vector2(10, 15.5), Vector2(4, 5.5)), knockout)


func _draw_map() -> void:
	_poly([Vector2(3, 5), Vector2(9, 3), Vector2(15, 5), Vector2(21, 3), Vector2(21, 19), Vector2(15, 21), Vector2(9, 19), Vector2(3, 21)])
	draw_line(Vector2(9, 3), Vector2(9, 19), knockout, 1.4, true)
	draw_line(Vector2(15, 5), Vector2(15, 21), knockout, 1.4, true)


func _draw_fleet() -> void:
	_line(Vector2(11, 3), Vector2(11, 16), 2.0)
	_poly([Vector2(12, 4), Vector2(20, 15), Vector2(12, 15)])
	_poly([Vector2(3, 17), Vector2(21, 17), Vector2(18, 21), Vector2(6, 21)])


func _draw_people() -> void:
	draw_circle(Vector2(8, 8), 3.2, color)
	draw_circle(Vector2(16.5, 8), 3.2, color)
	_poly([Vector2(3, 21), Vector2(3, 16), Vector2(6, 13), Vector2(10, 13), Vector2(13, 16), Vector2(13, 21)])
	_poly([Vector2(11.5, 21), Vector2(11.5, 16), Vector2(14.5, 13), Vector2(18.5, 13), Vector2(21.5, 16), Vector2(21.5, 21)])


func _draw_gold() -> void:
	draw_circle(Vector2(12, 12), 9.0, color)
	draw_arc(Vector2(12, 12), 5.0, 0.0, TAU, 32, knockout, 1.8, true)


func _draw_plus() -> void:
	_line(Vector2(12, 4), Vector2(12, 20), 3.0)
	_line(Vector2(4, 12), Vector2(20, 12), 3.0)


func _draw_minus() -> void:
	_line(Vector2(4, 12), Vector2(20, 12), 3.0)


func _draw_close() -> void:
	_line(Vector2(5, 5), Vector2(19, 19), 2.6)
	_line(Vector2(19, 5), Vector2(5, 19), 2.6)


func _draw_back() -> void:
	_line(Vector2(20, 12), Vector2(6, 12), 2.6)
	_line(Vector2(6, 12), Vector2(12, 6), 2.6)
	_line(Vector2(6, 12), Vector2(12, 18), 2.6)


func _draw_raid() -> void:
	_line(Vector2(4, 20), Vector2(19, 5), 2.6)
	_line(Vector2(20, 20), Vector2(5, 5), 2.6)
	_line(Vector2(4, 15), Vector2(9, 20), 2.0)
	_line(Vector2(20, 15), Vector2(15, 20), 2.0)


func _draw_trade() -> void:
	draw_rect(Rect2(Vector2(4, 9), Vector2(16, 11)), color)
	draw_arc(Vector2(12, 9), 4.0, PI, TAU, 16, color, 2.0, true)
	draw_line(Vector2(12, 9), Vector2(12, 20), knockout, 1.6, true)


func _draw_scout() -> void:
	_poly([Vector2(4, 16), Vector2(8, 20), Vector2(20, 8), Vector2(16, 4)])
	draw_circle(Vector2(5.5, 18.5), 2.6, color)
	_line(Vector2(14, 7), Vector2(17, 10), 1.2)


func _draw_colonize() -> void:
	_line(Vector2(6, 3), Vector2(6, 21), 2.2)
	_poly([Vector2(7, 4), Vector2(20, 8), Vector2(7, 12)])


func _draw_return() -> void:
	draw_arc(Vector2(12, 12), 7.0, -PI / 2.0, PI, 24, color, 2.4, true)
	_poly([Vector2(3, 12), Vector2(8, 8), Vector2(8, 16)])
